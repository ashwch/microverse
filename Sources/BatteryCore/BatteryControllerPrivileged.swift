import Foundation
import os.log
import SMCKit

/// Handles battery control operations that require elevated privileges
public class BatteryControllerPrivileged {
    private let logger = Logger(subsystem: "com.microverse.app", category: "BatteryControllerPrivileged")
    private let reader = BatteryReader()
    private let authHelper = AuthorizationHelper()
    private let smcController = SMCBatteryController()
    
    public init() {}
    
    /// Check if we have the necessary privileges
    public func hasAdminPrivileges() -> Bool {
        return authHelper.hasAuthorization()
    }
    
    /// Request admin authentication using macOS authorization services
    public func requestAdminPrivileges() -> Bool {
        logger.info("Requesting admin privileges...")
        return authHelper.requestAuthorization()
    }
    
    /// Set charge limit using macOS built-in optimization (80% or 100%)
    public func setChargeLimit(_ percentage: Int) -> BatteryControlResult {
        if percentage == 80 {
            let success = setBatteryOptimization(enabled: true)
            return success ? .success : .failed(error: NSError(domain: "Battery", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to enable 80% optimization"]))
        } else if percentage == 100 {
            let success = setBatteryOptimization(enabled: false)
            return success ? .success : .failed(error: NSError(domain: "Battery", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to disable optimization"]))
        } else {
            return .notSupported(reason: "Only 80% and 100% limits are supported")
        }
    }
    
    /// Check if battery optimization is currently enabled
    public func getBatteryOptimizationStatus() -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["read", "com.apple.BatteryMenuExtra", "OptimizeBatteryCharging"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return output == "1"
            }
        } catch {
            logger.error("Failed to read battery optimization status: \(error)")
        }
        
        return false // Default to disabled if we can't read it
    }
    
    /// Get the current effective charge limit (80% if optimization enabled, 100% if disabled)
    public func getCurrentEffectiveChargeLimit() -> Int {
        return getBatteryOptimizationStatus() ? 80 : 100
    }
    
    private func setBatteryOptimization(enabled: Bool) -> Bool {
        logger.info("Attempting to set battery optimization to: \(enabled)")
        
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = [
            "write",
            "com.apple.BatteryMenuExtra", 
            "OptimizeBatteryCharging",
            enabled ? "1" : "0"
        ]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let success = task.terminationStatus == 0
            if success {
                logger.info("✅ Battery optimization \(enabled ? "enabled (80%)" : "disabled (100%)") - SUCCESS")
                
                // Verify it was actually set
                let newStatus = getBatteryOptimizationStatus()
                logger.info("Verification: Current status is now \(newStatus ? "enabled" : "disabled")")
            } else {
                logger.error("❌ Failed to set battery optimization - exit code: \(task.terminationStatus)")
            }
            
            return success
        } catch {
            logger.error("❌ Failed to set battery optimization: \(error)")
            return false
        }
    }
    
    /// Enable/disable charging (requires admin)
    public func setChargingEnabled(_ enabled: Bool) -> BatteryControlResult {
        // Use real SMC controller
        let result = smcController.setChargingEnabled(enabled)
        
        switch result {
        case .success:
            return .success
        case .requiresRoot:
            return .requiresAuthentication
        case .failed(let error):
            return .failed(error: NSError(domain: "SMC", code: 2, userInfo: [NSLocalizedDescriptionKey: error]))
        case .notSupported:
            return .notSupported(reason: "Charging control not supported on this Mac")
        }
    }
    
    // MARK: - Additional SMC Functions
    
    /// Get current charge limit from SMC
    public func getCurrentChargeLimit() -> Int? {
        return smcController.getChargeLimit()
    }
    
    /// Check if charging is currently enabled
    public func isChargingEnabled() -> Bool? {
        return smcController.isChargingEnabled()
    }
    
    /// Get battery temperature from SMC
    public func getBatteryTemperature() -> Double? {
        return smcController.getBatteryTemperature()
    }
    
    /// List available battery SMC keys for debugging
    public func getAvailableBatteryKeys() -> [String] {
        return smcController.listAvailableBatteryKeys()
    }
    
}

public enum BatteryControlError: LocalizedError {
    case invalidPercentage
    case executionFailed
    case notImplemented
    
    public var errorDescription: String? {
        switch self {
        case .invalidPercentage:
            return "Invalid charge percentage. Must be between 20% and 100%."
        case .executionFailed:
            return "Failed to execute battery control command."
        case .notImplemented:
            return "This feature is not yet implemented."
        }
    }
}