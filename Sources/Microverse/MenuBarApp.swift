import SwiftUI
import AppKit
import os.log

@main
struct MicroverseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Required scene, but we handle everything through AppDelegate
        WindowGroup {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appInfo) { }
            CommandGroup(replacing: .appSettings) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var viewModel: BatteryViewModel!
    
    private let logger = Logger(subsystem: "com.microverse.app", category: "AppDelegate")
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Close the default window
        for window in NSApp.windows {
            window.close()
        }
        
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.title = "Microverse"
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Initialize battery manager
        setupBatteryManager()
    }
    
    @MainActor func setupBatteryManager() {
        logger.info("Setting up battery manager...")
        
        // Use shared view model
        viewModel = SharedViewModel.shared
        
        // Update menu bar
        updateMenuBarDisplay()
        
        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 500)
        popover.behavior = .transient
        
        let contentView = ContentView()
            .environmentObject(viewModel)
        
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        // Update periodically
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMenuBarDisplay()
            }
        }
        
        logger.info("Battery manager setup complete")
    }
    
    @MainActor func updateMenuBarDisplay() {
        guard let button = statusItem.button else { return }
        
        let info = viewModel.batteryInfo
        
        if viewModel.showPercentageInMenuBar {
            // Show custom battery icon with percentage
            button.image = createBatteryIcon(
                charge: info.currentCharge,
                isCharging: info.isCharging
            )
            button.title = " \(info.currentCharge)%"
            button.imagePosition = .imageLeft
        } else {
            // Show only icon
            button.image = createBatteryIcon(
                charge: info.currentCharge,
                isCharging: info.isCharging
            )
            button.title = ""
        }
    }
    
    func createBatteryIcon(charge: Int, isCharging: Bool) -> NSImage? {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Draw battery outline
        let batteryRect = NSRect(x: 1, y: 6, width: 16, height: 10)
        let batteryPath = NSBezierPath(roundedRect: batteryRect, xRadius: 1, yRadius: 1)
        
        NSColor.labelColor.setStroke()
        batteryPath.lineWidth = 1.5
        batteryPath.stroke()
        
        // Battery terminal
        let terminalRect = NSRect(x: 17, y: 9, width: 3, height: 4)
        let terminalPath = NSBezierPath(roundedRect: terminalRect, xRadius: 1, yRadius: 1)
        NSColor.labelColor.setFill()
        terminalPath.fill()
        
        // Fill based on charge level
        let fillWidth = (batteryRect.width - 3) * CGFloat(charge) / 100.0
        let fillRect = NSRect(
            x: batteryRect.minX + 1.5,
            y: batteryRect.minY + 1.5,
            width: fillWidth,
            height: batteryRect.height - 3
        )
        
        // Color based on charge
        let fillColor: NSColor
        if charge <= 20 {
            fillColor = .systemRed
        } else if charge <= 50 {
            fillColor = .systemYellow
        } else {
            fillColor = .systemGreen
        }
        
        fillColor.setFill()
        NSBezierPath(roundedRect: fillRect, xRadius: 0.5, yRadius: 0.5).fill()
        
        // Add lightning bolt if charging
        if isCharging {
            let boltPath = NSBezierPath()
            boltPath.move(to: NSPoint(x: 8, y: 14))
            boltPath.line(to: NSPoint(x: 10, y: 10))
            boltPath.line(to: NSPoint(x: 9, y: 10))
            boltPath.line(to: NSPoint(x: 11, y: 6))
            boltPath.line(to: NSPoint(x: 9, y: 10.5))
            boltPath.line(to: NSPoint(x: 10, y: 10.5))
            boltPath.close()
            
            NSColor.white.setFill()
            boltPath.fill()
            NSColor.labelColor.setStroke()
            boltPath.lineWidth = 0.5
            boltPath.stroke()
        }
        
        image.unlockFocus()
        return image
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover?.isShown == true {
                popover?.performClose(sender)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}