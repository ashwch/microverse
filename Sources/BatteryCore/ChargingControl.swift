import Foundation
import IOKit
import IOKit.pwr_mgt
import os.log
import SMCKit

/// Actual battery charging control implementation using native SMC
public class ChargingControl {
    private let logger = Logger(subsystem: "com.microverse.app", category: "ChargingControl")
    private let smcController = SMCBatteryController()
    
    public init() {}
    
    // MARK: - Apple Silicon Methods
    
    /// Control charging on Apple Silicon
    public func setAppleSiliconCharging(enabled: Bool) -> Bool {
        logger.info("Setting Apple Silicon charging to: \(enabled)")
        
        let result = smcController.setChargingEnabled(enabled)
        
        switch result {
        case .success:
            return true
        case .failed(let error):
            logger.error("Failed to control charging: \(error)")
            return false
        case .requiresRoot:
            logger.error("Root access required for charging control")
            return false
        case .notSupported:
            logger.error("Charging control not supported on this system")
            return false
        }
    }
    
    /// Set charge limit on Apple Silicon (80% or 100%)
    public func setAppleSiliconChargeLimit(_ limit: Int) -> Bool {
        logger.info("Setting Apple Silicon charge limit to: \(limit)%")
        
        // Apple Silicon only supports 80% and 100%
        guard [80, 100].contains(limit) else {
            logger.error("Invalid limit for Apple Silicon: \(limit)")
            return false
        }
        
        let result = smcController.setChargeLimit(limit)
        
        switch result {
        case .success:
            logger.info("Successfully set charge limit to \(limit)%")
            
            // Also use macOS battery optimization as a backup
            _ = updateSystemBatteryOptimization(enabled: limit == 80)
            return true
            
        case .failed(let error):
            logger.error("Failed to set charge limit: \(error)")
            
            // Fall back to system battery optimization
            return updateSystemBatteryOptimization(enabled: limit == 80)
            
        case .requiresRoot:
            logger.error("Root access required")
            return false
            
        case .notSupported:
            logger.error("Charge limit not supported")
            return false
        }
    }
    
    // MARK: - Intel Methods
    
    /// Control charging on Intel Macs
    public func setIntelCharging(enabled: Bool) -> Bool {
        logger.info("Setting Intel charging to: \(enabled)")
        
        let result = smcController.setChargingEnabled(enabled)
        
        switch result {
        case .success:
            return true
        case .failed(let error):
            logger.error("Failed to control charging: \(error)")
            return false
        case .requiresRoot:
            logger.error("Root access required")
            return false
        case .notSupported:
            logger.error("Not supported on this Intel Mac")
            return false
        }
    }
    
    /// Set charge limit on Intel Macs
    public func setIntelChargeLimit(_ limit: Int) -> Bool {
        logger.info("Setting Intel charge limit to: \(limit)%")
        
        guard (20...100).contains(limit) else {
            logger.error("Invalid limit: must be between 20 and 100")
            return false
        }
        
        let result = smcController.setChargeLimit(limit)
        
        switch result {
        case .success:
            logger.info("Successfully set charge limit to \(limit)%")
            return true
        case .failed(let error):
            logger.error("Failed to set charge limit: \(error)")
            return false
        case .requiresRoot:
            logger.error("Root access required")
            return false
        case .notSupported:
            logger.error("Not supported")
            return false
        }
    }
    
    // MARK: - Status Methods
    
    /// Get current charging status
    public func isChargingEnabled() -> Bool {
        return smcController.isChargingEnabled() ?? true
    }
    
    /// Get current charge limit
    public func getCurrentChargeLimit() -> Int? {
        return smcController.getChargeLimit()
    }
    
    /// Get battery temperature from SMC
    public func getBatteryTemperature() -> Double? {
        return smcController.getBatteryTemperature()
    }
    
    // MARK: - Diagnostic Methods
    
    /// Check which SMC keys are available
    public func getAvailableSMCKeys() -> [String] {
        return smcController.listAvailableBatteryKeys()
    }
    
    // MARK: - Private Helper Methods
    
    private func updateSystemBatteryOptimization(enabled: Bool) -> Bool {
        logger.info("Updating system battery optimization: \(enabled)")
        
        // Try to update the system's battery optimization setting
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        
        if enabled {
            task.arguments = ["write", "com.apple.battery.health", "MaximumChargeLevel", "80"]
        } else {
            task.arguments = ["delete", "com.apple.battery.health", "MaximumChargeLevel"]
        }
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                // Notify system of the change
                let notify = Process()
                notify.launchPath = "/usr/bin/killall"
                notify.arguments = ["-HUP", "SystemUIServer"]
                try notify.run()
                notify.waitUntilExit()
                
                return true
            }
        } catch {
            logger.error("Failed to update system battery optimization: \(error)")
        }
        
        return false
    }
}