#!/usr/bin/env swift

import Foundation
import AppKit
import SwiftUI
import os.log

// Simple debug app to test initialization
print("Starting Microverse debug test...")

// Test BatteryController directly
print("\n1. Testing BatteryController initialization...")
let startTime = Date()

do {
    // Import the BatteryCore module
    let controller = BatteryController()
    let elapsed = Date().timeIntervalSince(startTime)
    print("✅ BatteryController initialized in \(elapsed) seconds")
    
    // Test getting battery status
    print("\n2. Testing battery status retrieval...")
    let statusStart = Date()
    let status = controller.getBatteryStatus()
    let statusElapsed = Date().timeIntervalSince(statusStart)
    print("✅ Battery status retrieved in \(statusElapsed) seconds")
    print("   Charge: \(status.currentCharge)%")
    print("   Charging: \(status.isCharging)")
    print("   Plugged in: \(status.isPluggedIn)")
    print("   Temperature: \(status.temperature)°C")
    print("   Cycle count: \(status.cycleCount)")
    
} catch {
    print("❌ Failed to initialize BatteryController: \(error)")
}

print("\n3. Testing menu bar initialization...")
// Create a minimal menu bar app
let app = NSApplication.shared
let delegate = TestAppDelegate()
app.delegate = delegate
app.run()

class TestAppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("App launched, creating status item...")
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.title = "Test"
            print("✅ Status item created with title: \(button.title ?? "nil")")
        } else {
            print("❌ Failed to create status item button")
        }
        
        // Exit after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            print("\n✅ Test completed successfully")
            NSApp.terminate(nil)
        }
    }
}