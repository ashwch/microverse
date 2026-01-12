import Foundation
import os.log
import Darwin

/// Simple system monitor for CPU and memory usage
/// Works within macOS sandbox constraints
public final class SystemMonitor: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.microverse.app", category: "SystemMonitor")
    
    public init() {}
    
    /// Get current CPU usage percentage (0-100)
    /// Note: This provides system-wide CPU load average, not instantaneous usage
    public func getCPUUsage() -> Double {
        var loadInfo = host_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &loadInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(mach_host_self(), HOST_LOAD_INFO, intPtr, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            logger.error("Failed to get CPU load: \(result)")
            return 0.0
        }
        
        // Load average for 1 minute (index 0)
        let loadAverage = Double(loadInfo.avenrun.0) / Double(LOAD_SCALE)
        
        // Get number of CPUs
        var cpuCount: natural_t = 0
        var cpuCountSize = size_t(MemoryLayout<natural_t>.size)
        sysctlbyname("hw.ncpu", &cpuCount, &cpuCountSize, nil, 0)
        
        // Convert load average to percentage (rough approximation)
        // Load of 1.0 per CPU = 100% usage
        let cpuUsage = (loadAverage / Double(cpuCount)) * 100.0
        
        logger.debug("CPU load average: \(loadAverage), CPUs: \(cpuCount), usage: \(cpuUsage)%")
        return min(100.0, max(0.0, cpuUsage))
    }
    
    /// Get memory pressure and usage
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
        let speculativePages = UInt64(info.speculative_count)
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
        
        // Calculate memory pressure based on available memory
        // Available = Free + Inactive (can be reclaimed) + File Cache
        let availablePages = freePages + inactivePages + externalPages + speculativePages
        let totalPages = UInt64(physicalMemory / pageSizeBytes)
        let pressureRatio = Double(availablePages) / Double(totalPages)
        
        let pressure: MemoryPressure
        if pressureRatio < 0.05 {
            pressure = .critical
        } else if pressureRatio < 0.15 {
            pressure = .warning
        } else {
            pressure = .normal
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
