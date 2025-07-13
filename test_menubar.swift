#!/usr/bin/env swift

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("✅ App launched")
        
        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        print("✅ Status item created: \(statusItem != nil)")
        
        if let button = statusItem?.button {
            button.title = "TEST 100%"
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
            print("✅ Button configured with title: \(button.title ?? "nil")")
            print("✅ Button frame: \(button.frame)")
            print("✅ Button is hidden: \(button.isHidden)")
        } else {
            print("❌ Failed to get button from status item")
        }
        
        // Make sure we're not hiding it
        statusItem?.isVisible = true
        
        print("✅ Status bar setup complete")
    }
    
    @objc func statusBarButtonClicked(_ sender: Any?) {
        print("🖱️ Menu bar item clicked!")
    }
}

// Create app
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Don't hide dock icon for testing
app.setActivationPolicy(.regular)

print("🚀 Starting test app...")
app.run()