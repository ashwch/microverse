import Foundation
import IOKit
import IOKit.ps
import os.log

/// Reads battery information without requiring elevated privileges
public class BatteryReader {
    private let logger = Logger(subsystem: "com.microverse.app", category: "BatteryReader")
    
    public init() {}
    
    /// Get current battery information with proper error handling
    public func getBatteryInfo() throws -> BatteryInfo {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            logger.error("Failed to get power source info")
            throw BatteryError.noPowerSource
        }
        
        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              !sources.isEmpty else {
            logger.error("No power sources found")
            throw BatteryError.noPowerSource
        }
        
        for source in sources {
            if let description = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any] {
                // Validate required properties exist
                guard let currentCharge = description[kIOPSCurrentCapacityKey] as? Int,
                      let maxCapacity = description[kIOPSMaxCapacityKey] as? Int else {
                    logger.error("Missing required battery properties")
                    throw BatteryError.invalidPowerSourceData
                }
                
                // Get cycle count with error handling
                let cycleCount = (try? getCycleCountWithErrors()) ?? 0
                
                // Calculate time remaining based on charging state
                let timeRemaining: Int? = if description[kIOPSIsChargingKey] as? Bool == true {
                    description[kIOPSTimeToFullChargeKey] as? Int
                } else {
                    description[kIOPSTimeToEmptyKey] as? Int
                }
                
                let info = BatteryInfo(
                    currentCharge: currentCharge,
                    isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                    isPluggedIn: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                    cycleCount: cycleCount,
                    maxCapacity: maxCapacity,
                    timeRemaining: timeRemaining,
                    health: calculateHealth(maxCapacity: maxCapacity)
                )
                
                logger.debug("Battery info: \(info.currentCharge)%, charging: \(info.isCharging), plugged: \(info.isPluggedIn)")
                return info
            }
        }
        
        throw BatteryError.invalidPowerSourceData
    }
    
    /// Convenience method that returns default BatteryInfo on error
    public func getBatteryInfoSafe() -> BatteryInfo {
        do {
            return try getBatteryInfo()
        } catch {
            logger.error("Failed to get battery info: \(error.localizedDescription)")
            return BatteryInfo()
        }
    }
    
    
    // MARK: - Private Helpers
    
    private func getCycleCountWithErrors() throws -> Int {
        let matching = IOServiceMatching("IOPMPowerSource")
        let entry: io_object_t
        if #available(macOS 12.0, *) {
            entry = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        } else {
            entry = IOServiceGetMatchingService(kIOMasterPortDefault, matching)
        }
        
        guard entry != IO_OBJECT_NULL else {
            logger.warning("Could not find IOPMPowerSource service")
            throw BatteryError.iokitServiceNotFound
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
        throw BatteryError.iokitPropertyMissing("CycleCount")
    }
    
    private func getCycleCount() -> Int {
        // Use IOKit directly to get cycle count - no subprocess needed!
        let matching = IOServiceMatching("IOPMPowerSource")
        let entry: io_object_t
        if #available(macOS 12.0, *) {
            entry = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        } else {
            entry = IOServiceGetMatchingService(kIOMasterPortDefault, matching)
        }
        
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