import Foundation
import os.log

/// Comprehensive SMC testing utility
public class SMCTester {
    private let logger = Logger(subsystem: "com.microverse.app", category: "SMCTester")
    private let smc = SMCInterface()
    private let batteryController = SMCBatteryController()
    private let reader = BatteryReader()
    
    public init() {}
    
    /// Run comprehensive SMC tests
    public func runAllTests() -> SMCTestResults {
        logger.info("Starting comprehensive SMC tests...")
        
        var results = SMCTestResults()
        
        // Test 1: SMC Connection
        results.connectionTest = testSMCConnection()
        
        // Test 2: Key availability
        results.keyAvailability = testKeyAvailability()
        
        // Test 3: Read operations
        results.readTests = testReadOperations()
        
        // Test 4: Platform detection
        results.platformInfo = testPlatformDetection()
        
        // Test 5: Safe write test (if we have permissions)
        results.writeTestsAvailable = testSafeWriteCapability()
        
        logger.info("SMC tests completed")
        return results
    }
    
    // MARK: - Individual Tests
    
    private func testSMCConnection() -> Bool {
        logger.info("Testing SMC connection...")
        
        // Try to read a known-safe key
        let testKey = SMCKey("BNum") // Battery count - safe to read
        
        if let _ = smc.readValue(key: testKey) {
            logger.info("✓ SMC connection successful")
            return true
        } else {
            logger.error("✗ SMC connection failed")
            return false
        }
    }
    
    private func testKeyAvailability() -> [String: Bool] {
        logger.info("Testing key availability...")
        
        let testKeys: [(String, SMCKey)] = [
            ("CH0B (Intel charging)", BatterySMCKeys.chargeControl),
            ("CH0C (M1 charging)", BatterySMCKeys.chargeControlM1),
            ("BCLM (Intel limit)", BatterySMCKeys.chargeLimit),
            ("CHWA (M1 limit)", BatterySMCKeys.chargeLimitM1),
            ("BATP (Battery powered)", BatterySMCKeys.batteryPowered),
            ("BNum (Battery count)", BatterySMCKeys.batteryCount),
            ("TB0T (Battery temp 0)", BatterySMCKeys.batteryTemp0),
            ("TB1T (Battery temp 1)", BatterySMCKeys.batteryTemp1),
            ("B0CT (Cycle count)", BatterySMCKeys.cycleCount)
        ]
        
        var results: [String: Bool] = [:]
        
        for (name, key) in testKeys {
            let exists = smc.keyExists(key: key)
            results[name] = exists
            logger.info("\(exists ? "✓" : "✗") \(name)")
        }
        
        return results
    }
    
    private func testReadOperations() -> [String: Any] {
        logger.info("Testing read operations...")
        
        var results: [String: Any] = [:]
        
        // Test battery count
        if let result = smc.readValue(key: BatterySMCKeys.batteryCount),
           let count = result.ui8Value {
            results["batteryCount"] = Int(count)
            logger.info("✓ Battery count: \(count)")
        }
        
        // Test current charge limit
        if let limit = batteryController.getChargeLimit() {
            results["currentChargeLimit"] = limit
            logger.info("✓ Current charge limit: \(limit)%")
        }
        
        // Test charging status
        if let enabled = batteryController.isChargingEnabled() {
            results["chargingEnabled"] = enabled
            logger.info("✓ Charging enabled: \(enabled)")
        }
        
        // Test battery temperature
        if let temp = batteryController.getBatteryTemperature() {
            results["batteryTemperature"] = temp
            logger.info("✓ Battery temperature: \(String(format: "%.1f", temp))°C")
        }
        
        // Test cycle count from SMC
        if let cycles = batteryController.getCycleCount() {
            results["cycleCountSMC"] = cycles
            logger.info("✓ Cycle count (SMC): \(cycles)")
        }
        
        return results
    }
    
    private func testPlatformDetection() -> [String: Any] {
        logger.info("Testing platform detection...")
        
        let info = reader.getBatteryInfo()
        var results: [String: Any] = [:]
        
        results["isAppleSilicon"] = info.isAppleSilicon
        results["hardwareModel"] = info.hardwareModel
        
        // Check which charging method is available
        let hasIntelKeys = smc.keyExists(key: BatterySMCKeys.chargeLimit)
        let hasM1Keys = smc.keyExists(key: BatterySMCKeys.chargeLimitM1)
        
        results["hasIntelKeys"] = hasIntelKeys
        results["hasAppleSiliconKeys"] = hasM1Keys
        
        logger.info("✓ Platform: \(info.hardwareModel), Apple Silicon: \(info.isAppleSilicon)")
        logger.info("✓ Intel keys: \(hasIntelKeys), M1 keys: \(hasM1Keys)")
        
        return results
    }
    
    private func testSafeWriteCapability() -> Bool {
        logger.info("Testing write capability...")
        
        // Check if we can read the current charge limit
        guard let currentLimit = batteryController.getChargeLimit() else {
            logger.info("Cannot read current charge limit - write test skipped")
            return false
        }
        
        logger.info("Current charge limit: \(currentLimit)%")
        
        // We won't actually write without user permission
        // Just check if we theoretically could
        let isRoot = geteuid() == 0
        logger.info("Root access: \(isRoot)")
        
        return isRoot
    }
    
    /// Get diagnostic report
    public func getDiagnosticReport() -> String {
        let results = runAllTests()
        
        var report = """
        SMC Diagnostic Report
        ====================
        
        Connection Test: \(results.connectionTest ? "PASSED" : "FAILED")
        Write Capability: \(results.writeTestsAvailable ? "Available" : "Requires root")
        
        Available Keys:
        """
        
        for (key, available) in results.keyAvailability {
            report += "\n  \(available ? "✓" : "✗") \(key)"
        }
        
        report += "\n\nRead Test Results:"
        for (key, value) in results.readTests {
            report += "\n  \(key): \(value)"
        }
        
        report += "\n\nPlatform Info:"
        for (key, value) in results.platformInfo {
            report += "\n  \(key): \(value)"
        }
        
        report += "\n\nRecommendations:"
        
        if let isAppleSilicon = results.platformInfo["isAppleSilicon"] as? Bool {
            if isAppleSilicon {
                report += "\n  - Apple Silicon detected: Only 80% and 100% charge limits supported"
            } else {
                report += "\n  - Intel Mac detected: Full charge limit range (20-100%) supported"
            }
        }
        
        if !results.writeTestsAvailable {
            report += "\n  - Root access required for battery control features"
        }
        
        return report
    }
}

/// SMC test results structure
public struct SMCTestResults {
    var connectionTest: Bool = false
    var keyAvailability: [String: Bool] = [:]
    var readTests: [String: Any] = [:]
    var platformInfo: [String: Any] = [:]
    var writeTestsAvailable: Bool = false
}