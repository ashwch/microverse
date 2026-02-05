import Foundation
import os.log
import Darwin

/// System monitor for CPU and memory using Mach kernel APIs.
///
/// # CPU: Tick-Delta Measurement
///
/// The kernel tracks cumulative clock ticks spent in each state:
///
///     time ──────────────────────────────────────────────>
///     ticks:  [user][sys][idle][idle][user][sys][nice][idle]
///              ▲                       ▲
///              sample A                sample B
///
/// Each call to `HOST_CPU_LOAD_INFO` returns the running totals.
/// We store two consecutive samples and compute the delta:
///
///     usage = (userD + sysD + niceD) / (userD + sysD + niceD + idleD) * 100
///
/// This gives *instantaneous* CPU usage over the polling window — the same
/// technique Activity Monitor and the Stats app use. The old approach used
/// `HOST_LOAD_INFO` (Unix load average), which is a 1-minute trailing
/// exponential decay that includes I/O-blocked processes, so it could show
/// 100% while Activity Monitor showed 30%.
///
/// ## Counter Rollover
///
/// Kernel tick counters are `natural_t` (UInt32). They wrap every ~49 days
/// at 1000 Hz. Delta math *must* happen at UInt32 width so wrapping
/// subtraction produces the correct small positive result:
///
///     UInt32:  5 &- 0xFFFF_FFFE  =  7          (correct)
///     UInt64:  5  -  4294967294  = -4294967289  (garbage)
///
/// After the subtraction, we widen to UInt64 for the summation+division.
///
/// First call returns 0% (no previous sample). Real data arrives after one
/// polling interval (3 seconds).
///
/// # Memory: XNU Page Hierarchy
///
/// XNU partitions physical RAM into page categories:
///
///     +-------------------------------------------------------+
///     |                   Physical RAM                        |
///     +-------------------------------------------------------+
///     | Wired | Internal |  External  |  Free                 |
///     | (kern)|  (apps)  | (file cache)| +------------------+ |
///     |       | +------+ |            | | speculative (sub- | |
///     |       | |purgea| |            | | set of free, NOT  | |
///     |       | |ble   | |            | | additive)         | |
///     |       | +------+ |            | +------------------+ |
///     +-------------------------------------------------------+
///
/// Key insight: `vm_statistics.speculative_count` is already *included*
/// in `free_count`. Adding both double-counts free memory and understates
/// pressure. The corrected formula:
///
///     available = free + inactive + external   (no speculative)
///
/// We prefer the kernel's own pressure signal (`kern.memorystatus_vm_pressure_level`)
/// and only fall back to the ratio heuristic if the sysctl fails.
///
/// # Thread Safety
///
/// `SystemMonitor` is `@unchecked Sendable`. `getCPUUsage()` mutates
/// `previousCPUTicks` from a TaskGroup, so the read-write is guarded
/// by `cpuLock`. `getMemoryInfo()` is stateless and needs no lock.
public final class SystemMonitor: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.microverse.app", category: "SystemMonitor")

    /// A snapshot of the kernel's cumulative CPU tick counters.
    /// Keep this as UInt32 because kernel `natural_t` ticks are UInt32 and
    /// wrap at 32 bits. Delta math relies on UInt32 wrapping subtraction.
    private struct CPUTickSample {
        let user: UInt32
        let system: UInt32
        let idle: UInt32
        let nice: UInt32
    }
    /// Previous tick snapshot for delta computation. `nil` until first call.
    private var previousCPUTicks: CPUTickSample?
    /// Guards `previousCPUTicks` — getCPUUsage() runs off the main actor in a TaskGroup.
    private let cpuLock = NSLock()

    public init() {}
    
    /// Instantaneous CPU usage (0--100%) via tick deltas.
    ///
    /// Normal case:
    ///
    ///     poll N           poll N+1
    ///       |                 |
    ///       v                 v
    ///       [user=1200]       [user=1500]   -> userD   = 300
    ///       [sys =  80]       [sys = 100]   -> sysD    =  20
    ///       [idle=8000]       [idle=8350]   -> idleD   = 350
    ///       [nice=  20]       [nice=  50]   -> niceD   =  30
    ///                                          ----      ----
    ///                                          used    = 350
    ///                                          total   = 700
    ///                                          usage   = 50%
    ///
    /// UInt32 rollover case (~49 days uptime at 1000 Hz):
    ///
    ///     prev.idle = 0xFFFF_FF00      current.idle = 0x0000_0032
    ///     UInt32: 0x0000_0032 &- 0xFFFF_FF00 = 0x132 (306)   <-- correct
    ///     UInt64:         50  -  4294967040   = negative       <-- wrong
    ///
    /// Deltas are computed at UInt32 width, then widened for summation.
    ///
    /// Returns 0.0 on the very first call (no previous sample yet).
    public func getCPUUsage() -> Double {
        // --- 1. Read cumulative tick counters from the kernel ---------------
        var loadInfo = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &loadInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            logger.error("Failed to get CPU ticks: \(result)")
            return 0.0
        }

        // cpu_ticks layout: (.0=user, .1=system, .2=idle, .3=nice)
        // Keep raw UInt32 values to preserve correct 32-bit wrap behavior.
        let current = CPUTickSample(
            user: UInt32(loadInfo.cpu_ticks.0),
            system: UInt32(loadInfo.cpu_ticks.1),
            idle: UInt32(loadInfo.cpu_ticks.2),
            nice: UInt32(loadInfo.cpu_ticks.3)
        )

        // --- 2. Swap previous <-> current under lock -----------------------
        cpuLock.lock()
        let previous = previousCPUTicks
        previousCPUTicks = current
        cpuLock.unlock()

        guard let previous else {
            return 0.0  // first sample — no delta yet
        }

        // --- 3. Compute deltas ---------------------------------------------
        // Two-phase arithmetic:
        //   a) &- at UInt32 width  -> correct wrap on rollover
        //   b) widen to UInt64     -> safe summation without overflow
        let userDelta = UInt64(current.user &- previous.user)
        let systemDelta = UInt64(current.system &- previous.system)
        let idleDelta = UInt64(current.idle &- previous.idle)
        let niceDelta = UInt64(current.nice &- previous.nice)

        // --- 4. Derive percentage ------------------------------------------
        //   used  = user + system + nice   (all non-idle work)
        //   total = used + idle
        let used = userDelta &+ systemDelta &+ niceDelta
        let total = used &+ idleDelta

        guard total > 0 else { return 0.0 }

        let cpuUsage = (Double(used) / Double(total)) * 100.0
        let clamped = min(100.0, max(0.0, cpuUsage))

        logger.debug("CPU usage: \(String(format: "%.1f", clamped))% (user=\(userDelta) sys=\(systemDelta) idle=\(idleDelta) nice=\(niceDelta))")
        return clamped
    }
    
    /// Memory usage and pressure level.
    ///
    /// Breakdown (mirrors Activity Monitor's "Memory" tab):
    ///
    ///     +--------------------------------------------------+
    ///     | Used (reported %)                    |  Available |
    ///     |  App + Wired + Compressed            |            |
    ///     +--------------------------------------------------+
    ///     |  App = internal - purgeable                       |
    ///     |  Cached = external + purgeable  (shown separately)|
    ///     +--------------------------------------------------+
    ///
    /// Pressure comes from `kern.memorystatus_vm_pressure_level`, the same
    /// signal that drives macOS's own memory pressure graph. The sysctl
    /// returns an XNU constant (1=normal, 2=warn, 4=critical). If the
    /// sysctl fails, we fall back to:
    ///
    ///     available = free + inactive + external
    ///     ratio     = available / total
    ///     <0.05 => critical | <0.15 => warning | else => normal
    ///
    public func getMemoryInfo() -> MemoryInfo {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<natural_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            logger.error("Failed to get memory statistics: \(result)")
            return MemoryInfo()
        }
        
        // Get physical memory size
        var physicalMemory: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &physicalMemory, &size, nil, 0)
        
        // Avoid referencing the global `vm_page_size` var directly (not concurrency-safe in Swift 6).
        var pageSizeBytes: UInt64 = 4096
        var sysctlPageSize: Int = 0
        var sysctlPageSizeSize = MemoryLayout<Int>.size
        if sysctlbyname("hw.pagesize", &sysctlPageSize, &sysctlPageSizeSize, nil, 0) == 0, sysctlPageSize > 0 {
            pageSizeBytes = UInt64(sysctlPageSize)
        }
        
        // Calculate memory metrics
        let totalMemory = Double(physicalMemory) / (1024 * 1024 * 1024) // GB
        let freePages = UInt64(info.free_count)
        let inactivePages = UInt64(info.inactive_count)
        let wiredPages = UInt64(info.wire_count)
        let compressedPages = UInt64(info.compressor_page_count)
        let purgeablePages = UInt64(info.purgeable_count)
        let externalPages = UInt64(info.external_page_count)
        let internalPages = UInt64(info.internal_page_count)
        
        // Calculate memory used like Activity Monitor:
        // App Memory = internal_page_count - purgeable_count (these are anonymous/app pages)
        // Wired Memory = wire_count (kernel memory that can't be swapped)
        // Compressed = compressor_page_count (compressed memory pages)
        // Memory Used = App Memory + Wired + Compressed
        let appMemoryPages = internalPages > purgeablePages ? internalPages - purgeablePages : 0
        let usedMemory = Double((appMemoryPages + wiredPages + compressedPages) * pageSizeBytes) / (1024 * 1024 * 1024) // GB
        
        // Calculate cached files (file-backed memory that can be freed)
        // Cached = external_page_count + purgeable_count
        let cachedMemory = Double((externalPages + purgeablePages) * pageSizeBytes) / (1024 * 1024 * 1024) // GB
        
        // --- Pressure: prefer the kernel's own level, fall back to ratio ---
        //
        //   Primary:  kern.memorystatus_vm_pressure_level  (same source as
        //             the system memory pressure graph in Activity Monitor)
        //
        //   Fallback: ratio = (free + inactive + external) / total
        //             Note: speculative is *inside* free — adding it would
        //             double-count and understate pressure.
        //
        //             XNU vm_statistics.h (simplified):
        //               free_count
        //                 +-- speculative_count   <-- subset, NOT additive
        //
        let pressure: MemoryPressure
        if let kernelPressure = kernelMemoryPressureLevel() {
            pressure = kernelPressure
        } else {
            let availablePages = freePages + inactivePages + externalPages
            let totalPages = UInt64(physicalMemory / pageSizeBytes)
            let pressureRatio = Double(availablePages) / Double(totalPages)
            if pressureRatio < 0.05 {
                pressure = .critical
            } else if pressureRatio < 0.15 {
                pressure = .warning
            } else {
                pressure = .normal
            }
        }
        
        let memoryString = String(format: "Memory: %.1f/%.1fGB, cached: %.1fGB, pressure: %@", usedMemory, totalMemory, cachedMemory, pressure.rawValue)
        logger.debug("\(memoryString)")
        
        return MemoryInfo(
            totalMemory: totalMemory,
            usedMemory: usedMemory,
            cachedMemory: cachedMemory,
            pressure: pressure,
            compressionRatio: Double(compressedPages) / Double(max(1, appMemoryPages + wiredPages + compressedPages))
        )
    }

    /// Ask the kernel for its memory pressure verdict.
    ///
    ///     sysctl kern.memorystatus_vm_pressure_level
    ///       -> 1 = normal  (plenty of free/reclaimable pages)
    ///       -> 2 = warning (system is compressing / swapping)
    ///       -> 4 = critical (OOM killer may start terminating apps)
    ///
    /// Available since macOS 10.9. Works inside the app sandbox.
    /// Returns `nil` if the sysctl call fails (graceful fallback path).
    private func kernelMemoryPressureLevel() -> MemoryPressure? {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else {
            return nil
        }
        switch level {
        case 4: return .critical
        case 2: return .warning
        default: return .normal
        }
    }
}

/// Memory pressure levels matching macOS
public enum MemoryPressure: String, CaseIterable, Sendable {
    case normal = "Normal"
    case warning = "Warning" 
    case critical = "Critical"
    
    public var color: String {
        switch self {
        case .normal: return "green"
        case .warning: return "orange"
        case .critical: return "red"
        }
    }
}

/// System memory information
public struct MemoryInfo: Sendable {
    public let totalMemory: Double // GB
    public let usedMemory: Double  // GB
    public let cachedMemory: Double // GB
    public let pressure: MemoryPressure
    public let compressionRatio: Double // 0-1
    
    public init(totalMemory: Double = 0, usedMemory: Double = 0, cachedMemory: Double = 0, pressure: MemoryPressure = .normal, compressionRatio: Double = 0) {
        self.totalMemory = totalMemory
        self.usedMemory = usedMemory
        self.cachedMemory = cachedMemory
        self.pressure = pressure
        self.compressionRatio = compressionRatio
    }
    
    public var usagePercentage: Double {
        guard totalMemory > 0 else { return 0 }
        return (usedMemory / totalMemory) * 100.0
    }
}
