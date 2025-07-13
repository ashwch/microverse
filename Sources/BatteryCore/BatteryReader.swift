import Foundation
import IOKit
import IOKit.ps
import os.log

/// Reads battery information without requiring elevated privileges
public class BatteryReader {
    private let logger = Logger(subsystem: "com.microverse.app", category: "BatteryReader")
    
    public init() {}
    
    /// Get current battery information (no root required)
    public func getBatteryInfo() -> BatteryInfo {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any] ?? []
        
        var info = BatteryInfo()
        
        for source in sources {
            if let description = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any] {
                // Basic battery stats
                // Get cycle count efficiently from IOKit
                let cycleCount = getCycleCount()
                
                // Calculate time remaining based on charging state
                let timeRemaining: Int? = if description[kIOPSIsChargingKey] as? Bool == true {
                    description[kIOPSTimeToFullChargeKey] as? Int
                } else {
                    description[kIOPSTimeToEmptyKey] as? Int
                }
                
                info = BatteryInfo(
                    currentCharge: description[kIOPSCurrentCapacityKey] as? Int ?? 0,
                    isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                    isPluggedIn: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                    cycleCount: cycleCount,
                    maxCapacity: description[kIOPSMaxCapacityKey] as? Int ?? 100,
                    timeRemaining: timeRemaining,
                    health: calculateHealth(maxCapacity: description[kIOPSMaxCapacityKey] as? Int ?? 100)
                )
                
                logger.debug("Battery info: \(info.currentCharge)%, charging: \(info.isCharging), plugged: \(info.isPluggedIn)")
                break
            }
        }
        
        return info
    }
    
    
    // MARK: - Private Helpers
    
    private func getCycleCount() -> Int {
        // Use IOKit directly to get cycle count - no subprocess needed!
        let matching = IOServiceMatching("IOPMPowerSource")
        let entry = IOServiceGetMatchingService(kIOMasterPortDefault, matching)
        
        guard entry != IO_OBJECT_NULL else {
            logger.warning("Could not find IOPMPowerSource service")
            return 0
        }
        
        defer { IOObjectRelease(entry) }
        
        // Try to get the cycle count property
        if let cycleCountRef = IORegistryEntryCreateCFProperty(entry, 
                                                               "CycleCount" as CFString,
                                                               kCFAllocatorDefault,
                                                               0) {
            if let cycleCount = cycleCountRef.takeRetainedValue() as? Int {
                logger.debug("Got cycle count from IOKit: \(cycleCount)")
                return cycleCount
            }
        }
        
        // Fallback: Check BatteryData dictionary
        if let batteryDataRef = IORegistryEntryCreateCFProperty(entry,
                                                                "BatteryData" as CFString,
                                                                kCFAllocatorDefault,
                                                                0) {
            if let batteryData = batteryDataRef.takeRetainedValue() as? [String: Any],
               let cycleCount = batteryData["CycleCount"] as? Int {
                logger.debug("Got cycle count from BatteryData: \(cycleCount)")
                return cycleCount
            }
        }
        
        logger.warning("Could not get cycle count from IOKit")
        return 0
    }
    
    private func calculateHealth(maxCapacity: Int) -> Double {
        // Health is current max capacity vs design capacity (100)
        return Double(maxCapacity) / 100.0
    }
}