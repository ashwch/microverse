#!/usr/bin/env swift

import Foundation

// Simple SMC test to verify our implementation
print("Testing SMC functionality...")
print("Note: This test requires running the built app with appropriate permissions")
print("")

// Create a test script that uses the app's SMC functionality
let testScript = """
import Foundation
import BatteryCore

let tester = SMCTester()
let report = tester.getDiagnosticReport()
print(report)

// Also test available keys
let controller = SMCBatteryController()
let keys = controller.listAvailableBatteryKeys()
print("\\nAvailable battery keys: \\(keys)")

// Test current values
if let limit = controller.getChargeLimit() {
    print("Current charge limit: \\(limit)%")
}

if let enabled = controller.isChargingEnabled() {
    print("Charging enabled: \\(enabled)")
}

if let temp = controller.getBatteryTemperature() {
    print("Battery temperature: \\(String(format: \"%.1f\", temp))°C")
}
"""

// Write and execute the test
let testFile = "/tmp/microverse-smc-test.swift"
try! testScript.write(toFile: testFile, atomically: true, encoding: .utf8)

print("To test SMC functionality, run:")
print("sudo swift -I .build/release -L .build/release -lBatteryCore \(testFile)")
print("")
print("Or use the app directly and check Console.app for SMC logs")