import Foundation
import Combine
import SystemCore
import os.log

/// Shared system monitoring service to prevent multiple system calls
/// Provides a single source of truth for system metrics across the app
@MainActor
class SystemMonitoringService: ObservableObject {
    static let shared = SystemMonitoringService()
    
    // Published properties for reactive UI updates
    @Published private(set) var cpuUsage: Double = 0
    @Published private(set) var memoryInfo = MemoryInfo()
    @Published private(set) var lastUpdated = Date()
    
    private let systemMonitor = SystemMonitor()
    private let logger = Logger(subsystem: "com.microverse.app", category: "SystemMonitoringService")
    private var isUpdating = false
    private var monitoringTask: Task<Void, Never>?
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    private func startMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            // Initial update
            await self.updateMetrics()
            
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 10 * 1_000_000_000)
                } catch {
                    break
                }
                
                if Task.isCancelled { break }
                await self.updateMetrics()
            }
        }
        
        logger.info("System monitoring service started with 10s interval")
    }
    
    private func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        logger.info("System monitoring service stopped")
    }
    
    private func updateMetrics() async {
        // Prevent concurrent updates
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        // Perform system calls off the main actor to avoid blocking UI.
        let systemMonitor = self.systemMonitor

        let (newCpuUsage, newMemoryInfo) = await withTaskGroup(of: (Double?, MemoryInfo?).self) { group in
            group.addTask {
                let cpu = systemMonitor.getCPUUsage()
                return (cpu, nil)
            }
            
            group.addTask {
                let memory = systemMonitor.getMemoryInfo()
                return (nil, memory)
            }
            
            var cpuResult: Double = 0
            var memoryResult = MemoryInfo()
            
            for await result in group {
                if let cpu = result.0 {
                    cpuResult = cpu
                }
                if let memory = result.1 {
                    memoryResult = memory
                }
            }
            
            return (cpuResult, memoryResult)
        }
        
        // Update on main thread
        cpuUsage = newCpuUsage
        memoryInfo = newMemoryInfo
        lastUpdated = Date()
        
        logger.debug("System metrics updated: CPU=\(Int(self.cpuUsage))%, Memory=\(Int(self.memoryInfo.usagePercentage))%")
    }
    
    /// Force an immediate update (throttled to prevent abuse)
    func forceUpdate() async {
        guard Date().timeIntervalSince(lastUpdated) > 2.0 else { return }
        await updateMetrics()
    }
}
