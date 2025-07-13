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
    private var timer: Timer?
    private let logger = Logger(subsystem: "com.microverse.app", category: "SystemMonitoringService")
    private var isUpdating = false
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    private func startMonitoring() {
        // Use a longer interval to reduce CPU overhead
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateMetrics()
            }
        }
        
        // Initial update
        Task {
            await updateMetrics()
        }
        
        logger.info("System monitoring service started with 10s interval")
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        logger.info("System monitoring service stopped")
    }
    
    private func updateMetrics() async {
        // Prevent concurrent updates
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }
        
        // Perform system calls on background queue to avoid blocking main thread
        let (newCpuUsage, newMemoryInfo) = await withTaskGroup(of: (Double?, MemoryInfo?).self) { group in
            group.addTask {
                let cpu = await self.systemMonitor.getCPUUsage()
                return (cpu, nil)
            }
            
            group.addTask {
                let memory = await self.systemMonitor.getMemoryInfo()
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