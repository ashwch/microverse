#!/usr/bin/swift

import Cocoa
import SwiftUI

// Simple test app to verify menu bar functionality
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("App launched")
        
        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "TEST"
            print("Menu bar item created with title: TEST")
        } else {
            print("Failed to create menu bar button")
        }
        
        // Keep app running
        NSApp.setActivationPolicy(.accessory)
    }
}

// Create and run app
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()