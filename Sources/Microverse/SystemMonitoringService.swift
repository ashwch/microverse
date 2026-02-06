import Foundation
import Combine
import SystemCore
import os.log

/// Single source of truth for CPU and memory metrics.
///
/// ## Polling interval
///
/// Polls `SystemMonitor` every 3 seconds (with 1.5s tolerance for timer
/// coalescing). The 3s interval balances responsiveness against power:
///
///     Interval | Feel            | CPU overhead
///     ---------+-----------------+-------------
///      10s     | stale / laggy   | ~0%
///       3s     | near real-time  | <1%   <-- chosen
///       1s     | instant         | ~1-2%
///
/// Activity Monitor defaults to 5s; Stats app defaults to 1s.
///
/// ## Demand-driven lifecycle
///
/// Monitoring is demand-driven via `acquireClient()` / `releaseClient()`.
/// Polling starts when the first visible surface acquires the service and
/// stops when the last surface releases it. This avoids background wake-ups
/// when notch/widget/system tabs are all hidden.
///
/// Why not just `start()` / `stop()`? Multiple independent surfaces (notch,
/// popover CPU tab, desktop widget) share one service. Ref-counting lets each
/// surface manage its own lifecycle without needing to know about the others.
///
/// ## sampleID
///
/// A `UInt64` counter that increments only when a display-visible value
/// actually changed. Downstream views use `.onChange(of: sampleID)` instead
/// of a timer. Benefits:
/// - No heap allocation per tick (unlike `Date()`).
/// - SwiftUI `.onChange` fires only when the integer changes, which happens
///   only when quantized CPU or memory values differ from the previous sample.
///
/// ## Quantized publish suppression
///
/// The user sees "42 %", not "42.3178 %". A change from 42.1→42.9 is
/// invisible on screen. Publishing it would trigger a full SwiftUI diff for
/// zero visual change. So we quantize *before* comparing, and store only
/// the quantized value so downstream thresholds (e.g. >60%, >80%) see
/// exactly the same number the user sees:
///
///     syscall → raw Double → quantize ─┬─ same as stored? → skip publish
///                                      └─ different?      → store + publish + bump sampleID
///
/// CPU is stored as `Double(Int(raw))` (integer precision); memory fields
/// are rounded to 1 decimal place.
///
/// On the CPU side, the first sample after launch returns 0% because
/// tick-delta measurement needs two data points. Real values appear
/// after the first 3-second sleep.
@MainActor
class SystemMonitoringService: ObservableObject {
    static let shared = SystemMonitoringService()
    
    // Published properties for reactive UI updates
    @Published private(set) var cpuUsage: Double = 0
    @Published private(set) var memoryInfo = MemoryInfo()
    @Published private(set) var sampleID: UInt64 = 0
    
    private let systemMonitor = SystemMonitor()
    private let logger = Logger(subsystem: "com.microverse.app", category: "SystemMonitoringService")
    private var isUpdating = false
    private var monitoringTask: Task<Void, Never>?
    private var activeClients = 0
    
    private init() {}
    
    deinit {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    /// Increment the ref-count. Starts the polling timer on the 0→1 transition.
    func acquireClient() {
        activeClients += 1
        guard activeClients == 1 else { return }
        startMonitoring()
    }

    /// Decrement the ref-count. Stops polling on the 1→0 transition.
    func releaseClient() {
        activeClients = max(0, activeClients - 1)
        guard activeClients == 0 else { return }
        stopMonitoring()
    }

    private func startMonitoring() {
        monitoringTask?.cancel()
        systemMonitor.resetCPUUsageSampling()
        monitoringTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            // Initial update
            await self.updateMetrics()
            
            while !Task.isCancelled {
                do {
                    // Timer coalescing: tolerance of 1.5s lets macOS batch
                    // this timer with nearby system work, reducing discrete
                    // wake-ups and saving battery on laptops.
                    try await Task.sleep(for: .seconds(3), tolerance: .seconds(1.5))
                } catch {
                    break
                }
                
                if Task.isCancelled { break }
                await self.updateMetrics()
            }
        }
        
        logger.info("System monitoring service started with 3s interval")
    }
    
    private func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        logger.info("System monitoring service stopped")
    }
    
    /// Fetch CPU + memory from the kernel and publish only when display-visible values change.
    ///
    /// ## Why `Task.detached` instead of `TaskGroup`
    /// The two syscalls (`getCPUUsage`, `getMemoryInfo`) each take ~10μs.
    /// A `TaskGroup` would add 2 child-task allocations + structured-concurrency
    /// coordination overhead every 3 seconds — more expensive than the syscalls
    /// themselves. A single `Task.detached` runs both sequentially off the main
    /// actor, then we hop back to publish.
    private func updateMetrics() async {
        // Prevent concurrent updates
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        // Perform system calls off the main actor to avoid blocking UI.
        let systemMonitor = self.systemMonitor

        let (newCpuUsage, newMemoryInfo) = await Task.detached(priority: .utility) {
            let cpu = systemMonitor.getCPUUsage()
            let memory = systemMonitor.getMemoryInfo()
            return (cpu, memory)
        }.value

        // Quantize then compare: only publish when the user-visible value changed.
        // See class-level "Quantized publish suppression" doc.
        let quantizedCPUUsage = Double(Int(newCpuUsage))
        let quantizedMemoryInfo = quantize(memory: newMemoryInfo)

        var changed = false
        if quantizedCPUUsage != cpuUsage {
            cpuUsage = quantizedCPUUsage
            changed = true
        }
        if quantizedMemoryInfo != memoryInfo {
            memoryInfo = quantizedMemoryInfo
            changed = true
        }

        if changed {
            sampleID &+= 1
        }
    }

    private func quantize(memory info: MemoryInfo) -> MemoryInfo {
        MemoryInfo(
            totalMemory: round(info.totalMemory, places: 1),
            usedMemory: round(info.usedMemory, places: 1),
            cachedMemory: round(info.cachedMemory, places: 1),
            pressure: info.pressure,
            compressionRatio: round(info.compressionRatio, places: 2)
        )
    }

    private func round(_ value: Double, places: Int) -> Double {
        let scale = pow(10.0, Double(max(0, places)))
        return (value * scale).rounded() / scale
    }
}
