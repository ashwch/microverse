import Foundation
import os.log

/// SMC-based battery controller for direct battery management
public class SMCBatteryController {
    private let logger = Logger(subsystem: "com.microverse.app", category: "SMCBatteryController")
    private let smc = SMCInterface()
    private let reader = BatteryReader()
    
    public init() {}
    
    // MARK: - Charge Limit Control
    
    /// Set battery charge limit percentage
    public func setChargeLimit(_ percentage: Int) -> SMCControlResult {
        guard (20...100).contains(percentage) else {
            return .failed(error: "Invalid percentage: must be between 20 and 100")
        }
        
        let isAppleSilicon = reader.getBatteryInfo().isAppleSilicon
        
        if isAppleSilicon {
            return setAppleSiliconChargeLimit(percentage)
        } else {
            return setIntelChargeLimit(percentage)
        }
    }
    
    /// Get current charge limit
    public func getChargeLimit() -> Int? {
        let isAppleSilicon = reader.getBatteryInfo().isAppleSilicon
        let key = isAppleSilicon ? BatterySMCKeys.chargeLimitM1 : BatterySMCKeys.chargeLimit
        
        guard let result = smc.readValue(key: key) else {
            logger.error("Failed to read charge limit")
            return nil
        }
        
        if isAppleSilicon {
            // CHWA returns 0 for 100%, 1 for 80%
            if let value = result.ui8Value {
                return value == 0 ? 100 : 80
            }
        } else {
            // BCLM returns the actual percentage
            return result.ui8Value.map { Int($0) }
        }
        
        return nil
    }
    
    // MARK: - Charging Control
    
    /// Enable or disable charging
    public func setChargingEnabled(_ enabled: Bool) -> SMCControlResult {
        // Check if we're running as root
        if geteuid() != 0 {
            logger.warning("SMC write requires root privileges")
            return .requiresRoot
        }
        
        let isAppleSilicon = reader.getBatteryInfo().isAppleSilicon
        
        // Try multiple keys based on platform
        let keys = isAppleSilicon ? 
            [BatterySMCKeys.chargeControlM1, BatterySMCKeys.chargeControl] :
            [BatterySMCKeys.chargeControl]
        
        for key in keys {
            // Check if key exists
            guard smc.keyExists(key: key) else {
                logger.info("Key \(key.string) not available")
                continue
            }
            
            // CH0B/CH0C: 0 = charging enabled, 1 = charging disabled
            let value = enabled ? UInt8(0) : UInt8(1)
            
            if smc.writeValue(key: key, value: .hex(value)) {
                logger.info("Successfully set charging to \(enabled) using key \(key.string)")
                return .success
            }
        }
        
        return .failed(error: "Failed to control charging - no compatible key found")
    }
    
    /// Check if charging is enabled
    public func isChargingEnabled() -> Bool? {
        let isAppleSilicon = reader.getBatteryInfo().isAppleSilicon
        let keys = isAppleSilicon ? 
            [BatterySMCKeys.chargeControlM1, BatterySMCKeys.chargeControl] :
            [BatterySMCKeys.chargeControl]
        
        for key in keys {
            if let result = smc.readValue(key: key),
               let value = result.ui8Value {
                // 0 = charging enabled, 1 = charging disabled
                return value == 0
            }
        }
        
        return nil
    }
    
    // MARK: - Battery Information
    
    /// Read battery temperature
    public func getBatteryTemperature() -> Double? {
        // Try multiple temperature sensors
        let tempKeys = [
            BatterySMCKeys.batteryTemp0,
            BatterySMCKeys.batteryTemp1,
            BatterySMCKeys.batteryTemp2,
            BatterySMCKeys.batteryTemp3
        ]
        
        for key in tempKeys {
            if let result = smc.readValue(key: key) {
                if let temp = result.temperatureValue, temp > 0 {
                    return temp
                }
            }
        }
        
        return nil
    }
    
    /// Read battery cycle count from SMC
    public func getCycleCount() -> Int? {
        guard let result = smc.readValue(key: BatterySMCKeys.cycleCount) else {
            return nil
        }
        
        return result.ui16Value.map { Int($0) }
    }
    
    // MARK: - Private Methods
    
    private func setIntelChargeLimit(_ percentage: Int) -> SMCControlResult {
        // Check if we're running as root
        if geteuid() != 0 {
            logger.warning("SMC write requires root privileges")
            return .requiresRoot
        }
        
        let value = UInt8(percentage)
        
        if smc.writeValue(key: BatterySMCKeys.chargeLimit, value: .ui8(value)) {
            logger.info("Successfully set Intel charge limit to \(percentage)%")
            return .success
        } else {
            return .failed(error: "Failed to write BCLM value")
        }
    }
    
    private func setAppleSiliconChargeLimit(_ percentage: Int) -> SMCControlResult {
        // Check if we're running as root
        if geteuid() != 0 {
            logger.warning("SMC write requires root privileges")
            return .requiresRoot
        }
        
        // Apple Silicon only supports 80% and 100%
        guard [80, 100].contains(percentage) else {
            return .failed(error: "Apple Silicon only supports 80% and 100% charge limits")
        }
        
        // CHWA: 0 = 100%, 1 = 80%
        let value = percentage == 80 ? UInt8(1) : UInt8(0)
        
        if smc.writeValue(key: BatterySMCKeys.chargeLimitM1, value: .ui8(value)) {
            logger.info("Successfully set Apple Silicon charge limit to \(percentage)%")
            return .success
        } else {
            return .failed(error: "Failed to write CHWA value")
        }
    }
    
    // MARK: - Diagnostic Methods
    
    /// List all available battery-related SMC keys
    public func listAvailableBatteryKeys() -> [String] {
        let allKeys = [
            BatterySMCKeys.chargeControl,
            BatterySMCKeys.chargeControlM1,
            BatterySMCKeys.chargeLimit,
            BatterySMCKeys.chargeLimitM1,
            BatterySMCKeys.batteryPowered,
            BatterySMCKeys.batteryCount,
            BatterySMCKeys.batteryInfo,
            BatterySMCKeys.batteryTemp0,
            BatterySMCKeys.batteryTemp1,
            BatterySMCKeys.batteryTemp2,
            BatterySMCKeys.batteryTemp3,
            BatterySMCKeys.cycleCount
        ]
        
        var availableKeys: [String] = []
        
        for key in allKeys {
            if smc.keyExists(key: key) {
                availableKeys.append(key.string)
            }
        }
        
        return availableKeys
    }
}

/// Result of SMC control operations
public enum SMCControlResult {
    case success
    case failed(error: String)
    case requiresRoot
    case notSupported
}