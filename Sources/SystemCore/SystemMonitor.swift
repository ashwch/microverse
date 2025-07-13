import Foundation
import os.log
import Darwin

/// Simple system monitor for CPU and memory usage
/// Works within macOS sandbox constraints
public class SystemMonitor {
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
        
        let pageSize = UInt64(vm_page_size)
        
        // Calculate memory metrics
        let totalMemory = Double(physicalMemory) / (1024 * 1024 * 1024) // GB
        let freePages = UInt64(info.free_count)
        let activePages = UInt64(info.active_count)
        let inactivePages = UInt64(info.inactive_count)
        let wiredPages = UInt64(info.wire_count)
        let compressedPages = UInt64(info.compressor_page_count)
        
        let usedPages = activePages + inactivePages + wiredPages + compressedPages
        let usedMemory = Double(usedPages * pageSize) / (1024 * 1024 * 1024) // GB
        
        // Calculate memory pressure (simplified version of macOS calculation)
        let availablePages = freePages + inactivePages
        let pressureRatio = Double(availablePages) / Double(usedPages + availablePages)
        
        let pressure: MemoryPressure
        if pressureRatio < 0.2 {
            pressure = .critical
        } else if pressureRatio < 0.4 {
            pressure = .warning
        } else {
            pressure = .normal
        }
        
        let memoryString = String(format: "Memory: %.1f/%.1fGB, pressure: %@", usedMemory, totalMemory, pressure.rawValue)
        logger.debug("\(memoryString)")
        
        return MemoryInfo(
            totalMemory: totalMemory,
            usedMemory: usedMemory,
            pressure: pressure,
            compressionRatio: Double(compressedPages) / Double(usedPages)
        )
    }
}

/// Memory pressure levels matching macOS
public enum MemoryPressure: String, CaseIterable {
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
public struct MemoryInfo {
    public let totalMemory: Double // GB
    public let usedMemory: Double  // GB
    public let pressure: MemoryPressure
    public let compressionRatio: Double // 0-1
    
    public init(totalMemory: Double = 0, usedMemory: Double = 0, pressure: MemoryPressure = .normal, compressionRatio: Double = 0) {
        self.totalMemory = totalMemory
        self.usedMemory = usedMemory
        self.pressure = pressure
        self.compressionRatio = compressionRatio
    }
    
    public var usagePercentage: Double {
        guard totalMemory > 0 else { return 0 }
        return (usedMemory / totalMemory) * 100.0
    }
}