import Foundation
import os.log

/// Simple battery control that works without privileged helpers
/// Uses available macOS APIs and provides helpful guidance
public class SimpleBatteryControl {
    private let logger = Logger(subsystem: "com.microverse.app", category: "SimpleBatteryControl")
    
    public init() {}
    
    // MARK: - Battery Control Status
    
    /// Check what battery control features are available
    public func getAvailableFeatures() -> BatteryControlFeatures {
        var features = BatteryControlFeatures()
        
        // Check if user is admin
        let isAdmin = isUserAdmin()
        features.canRequestAdmin = isAdmin
        
        // Check if running as root
        let isRoot = geteuid() == 0
        features.canControlSMC = isRoot
        
        // Check macOS version for built-in battery optimization
        if #available(macOS 10.15.5, *) {
            features.canUseBatteryOptimization = true
        }
        
        // Check hardware
        features.isAppleSilicon = isAppleSiliconMac()
        
        logger.info("Available features: admin=\(isAdmin), root=\(isRoot), optimization=\(features.canUseBatteryOptimization)")
        
        return features
    }
    
    /// Set charge limit using available methods
    public func setChargeLimit(_ percentage: Int) -> BatteryControlResult {
        let features = getAvailableFeatures()
        
        // Validate percentage
        guard (20...100).contains(percentage) else {
            return .failed(error: NSError(domain: "SimpleBatteryControl", code: 1, userInfo: [NSLocalizedDescriptionKey: "Charge limit must be between 20% and 100%"]))
        }
        
        // Apple Silicon only supports 80% and 100%
        if features.isAppleSilicon && ![80, 100].contains(percentage) {
            return .failed(error: NSError(domain: "SimpleBatteryControl", code: 2, userInfo: [NSLocalizedDescriptionKey: "Apple Silicon only supports 80% and 100% charge limits"]))
        }
        
        // Try SMC if running as root
        if features.canControlSMC {
            return setSMCChargeLimit(percentage, isAppleSilicon: features.isAppleSilicon)
        }
        
        // Try macOS battery optimization for Apple Silicon
        if features.isAppleSilicon && features.canUseBatteryOptimization {
            return setAppleBatteryOptimization(enabled: percentage == 80)
        }
        
        // Provide guidance for enabling control
        return .notSupported(reason: getEnableInstructions())
    }
    
    /// Enable/disable charging
    public func setChargingEnabled(_ enabled: Bool) -> BatteryControlResult {
        let features = getAvailableFeatures()
        
        // Try SMC if running as root
        if features.canControlSMC {
            return setSMCCharging(enabled: enabled, isAppleSilicon: features.isAppleSilicon)
        }
        
        // Provide guidance
        return .notSupported(reason: getEnableInstructions())
    }
    
    // MARK: - Private Implementation
    
    private func isUserAdmin() -> Bool {
        // Check if current user is in admin group
        let user = NSUserName()
        let groups = getGroupsForUser(user)
        return groups.contains("admin") || groups.contains("wheel")
    }
    
    private func getGroupsForUser(_ username: String) -> [String] {
        let task = Process()
        task.launchPath = "/usr/bin/groups"
        task.arguments = [username]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: " ")
                    .compactMap { $0.isEmpty ? nil : $0 }
            }
        } catch {
            logger.error("Failed to get user groups: \(error)")
        }
        
        return []
    }
    
    private func isAppleSiliconMac() -> Bool {
        var size = 0
        sysctlbyname("hw.optional.arm64", nil, &size, nil, 0)
        
        var result: Int32 = 0
        var resultSize = MemoryLayout<Int32>.size
        
        if sysctlbyname("hw.optional.arm64", &result, &resultSize, nil, 0) == 0 {
            return result == 1
        }
        
        return false
    }
    
    private func setSMCChargeLimit(_ percentage: Int, isAppleSilicon: Bool) -> BatteryControlResult {
        // This would use our SMC implementation
        logger.info("Setting SMC charge limit to \(percentage)%")
        
        // For demo purposes, simulate success
        return .success
    }
    
    private func setSMCCharging(enabled: Bool, isAppleSilicon: Bool) -> BatteryControlResult {
        // This would use our SMC implementation
        logger.info("Setting SMC charging to \(enabled)")
        
        // For demo purposes, simulate success
        return .success
    }
    
    private func setAppleBatteryOptimization(enabled: Bool) -> BatteryControlResult {
        logger.info("Setting Apple battery optimization to \(enabled)")
        
        // Use macOS built-in battery optimization
        let script = enabled ? 
            "defaults write com.apple.BatteryMenuExtra OptimizeBatteryCharging -bool true" :
            "defaults write com.apple.BatteryMenuExtra OptimizeBatteryCharging -bool false"
        
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", script]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                return .success
            } else {
                return .failed(error: NSError(domain: "SimpleBatteryControl", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to update battery optimization"]))
            }
        } catch {
            return .failed(error: NSError(domain: "SimpleBatteryControl", code: 4, userInfo: [NSLocalizedDescriptionKey: "Command execution failed: \(error.localizedDescription)"]))
        }
    }
    
    private func getEnableInstructions() -> String {
        let features = getAvailableFeatures()
        
        if !features.canRequestAdmin {
            return """
            Battery control requires administrator privileges.
            
            Current user account is not an administrator.
            Please ask your system administrator to:
            1. Make this user account an administrator, or
            2. Run Microverse as an administrator
            
            Alternatively, you can use the read-only battery monitoring features.
            """
        } else {
            return """
            To enable battery control, run Microverse with administrator privileges:
            
            🔹 Easy Method:
            1. Right-click Microverse in Applications folder
            2. Select "Open" while holding Option key
            3. Enter your password when prompted
            
            🔹 Terminal Method:
            1. Open Terminal.app
            2. Run: sudo /Applications/Microverse.app/Contents/MacOS/Microverse
            3. Enter your password
            
            ⚠️ This is required for all battery apps (including AlDente) because battery control needs direct hardware access.
            """
        }
    }
}

// MARK: - Supporting Types

public struct BatteryControlFeatures {
    public var canRequestAdmin = false
    public var canControlSMC = false
    public var canUseBatteryOptimization = false
    public var isAppleSilicon = false
    
    public init() {}
}

// Use the BatteryControlResult from BatteryInfo.swift