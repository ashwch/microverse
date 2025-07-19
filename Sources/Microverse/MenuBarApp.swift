import SwiftUI
import AppKit
import os.log
import Combine

@main
struct MicroverseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Empty scene - we handle everything through AppDelegate
        // This prevents SwiftUI from creating unwanted windows
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var viewModel: BatteryViewModel!
    var popoverContentViewController: NSViewController?
    private var cancellables = Set<AnyCancellable>()
    
    private let logger = Logger(subsystem: "com.microverse.app", category: "AppDelegate")
    
    // Constants
    private static let menuBarIconSize: CGFloat = 22
    private static let welcomeDelay: TimeInterval = 0.5
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Close any default windows that SwiftUI might create
        for window in NSApp.windows {
            window.close()
        }
        
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Use the actual Microverse app icon (alien face)
            if let appIcon = getAppIcon() {
                button.image = appIcon
                button.imagePosition = .imageOnly
                button.title = ""
            } else {
                // Fallback to system icon
                button.image = createMicroverseIcon()
            }
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Initialize battery manager
        setupBatteryManager()
        
        // Show first-run welcome if needed
        showFirstRunWelcomeIfNeeded()
    }
    
    private func showFirstRunWelcomeIfNeeded() {
        let hasShownWelcome = UserDefaults.standard.bool(forKey: "hasShownFirstRunWelcome")
        
        if !hasShownWelcome {
            // Delay to ensure menu bar icon is visible, then show welcome
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.welcomeDelay) { [weak self] in
                self?.showWelcomeMessage()
                // Only mark as shown after successfully showing the dialog
                UserDefaults.standard.set(true, forKey: "hasShownFirstRunWelcome")
            }
        }
    }
    
    private func showWelcomeMessage() {
        let alert = NSAlert()
        alert.messageText = "Welcome to Microverse! 🚀"
        
        // Clean, well-formatted text with better spacing
        alert.informativeText = """
Microverse is now running in your menu bar!

Look for the alien icon 👽 in the top-right corner of your screen.

Click it to access system monitoring, settings, and desktop widgets.

✨ Tip: Enable desktop widgets from the settings panel for continuous monitoring.
"""
        
        alert.addButton(withTitle: "Got it!")
        alert.addButton(withTitle: "Show me Microverse")
        alert.alertStyle = .informational
        
        // Use high quality app icon for dialog
        if let appIcon = getDialogAppIcon() {
            alert.icon = appIcon
        }
        
        let response = alert.runModal()
        
        if response == .alertSecondButtonReturn {
            // User clicked "Show me Microverse"
            if let button = statusItem.button {
                togglePopover(button)
            }
        }
    }
    
    @MainActor func setupBatteryManager() {
        logger.info("Setting up battery manager...")
        
        // Create battery view model
        viewModel = BatteryViewModel()
        
        // Update menu bar
        updateMenuBarDisplay()
        
        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 500)
        popover.behavior = .applicationDefined
        popover.delegate = self
        
        let tabbedMainView = TabbedMainView()
            .environmentObject(viewModel)
        
        popoverContentViewController = NSHostingController(rootView: tabbedMainView)
        popover.contentViewController = popoverContentViewController
        
        // Update menu bar display when battery info changes
        // Use Combine to observe changes instead of polling
        viewModel.$batteryInfo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarDisplay()
            }
            .store(in: &cancellables)
        
        // Also update when showPercentageInMenuBar changes
        viewModel.$showPercentageInMenuBar
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarDisplay()
            }
            .store(in: &cancellables)
        
        logger.info("Battery manager setup complete")
    }
    
    @MainActor func updateMenuBarDisplay() {
        guard let button = statusItem.button else { return }
        
        let info = viewModel.batteryInfo
        
        if viewModel.showPercentageInMenuBar {
            // Show alien icon with battery percentage
            if let alienIcon = getAppIcon() {
                button.image = alienIcon
            } else {
                // Fallback to system icon with health indicator
                button.image = createMicroverseIcon(
                    batteryLevel: info.currentCharge,
                    isCharging: info.isCharging,
                    showHealth: true
                )
            }
            button.title = " \(info.currentCharge)%"
            button.imagePosition = .imageLeft
        } else {
            // Show clean alien icon only
            if let alienIcon = getAppIcon() {
                button.image = alienIcon
            } else {
                // Fallback to system icon
                button.image = createMicroverseIcon()
            }
            button.title = ""
            button.imagePosition = .imageOnly
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
    
    /// Create elegant Microverse system monitoring icon
    func createMicroverseIcon(batteryLevel: Int? = nil, isCharging: Bool = false, showHealth: Bool = false) -> NSImage? {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Use clean system monitoring icon instead of battery
        let iconName = "circle.grid.2x2.fill"
        let systemImage = NSImage(systemSymbolName: iconName, accessibilityDescription: "Microverse")
        
        if let systemImage = systemImage {
            // Base icon color
            var iconColor = NSColor.controlAccentColor
            
            // Adjust color based on system health if requested
            if showHealth, let battery = batteryLevel {
                if battery <= 10 {
                    iconColor = NSColor.systemRed
                } else if battery <= 20 {
                    iconColor = NSColor.systemOrange
                } else if isCharging {
                    iconColor = NSColor.systemGreen
                } else {
                    iconColor = NSColor.controlAccentColor
                }
            }
            
            // Draw the icon
            iconColor.set()
            let iconRect = NSRect(x: 3, y: 3, width: 16, height: 16)
            systemImage.draw(in: iconRect)
            
            // Add subtle charging indicator if needed
            if isCharging && showHealth {
                let boltImage = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Charging")
                if let boltImage = boltImage {
                    NSColor.systemYellow.set()
                    let boltRect = NSRect(x: 13, y: 2, width: 8, height: 8)
                    boltImage.draw(in: boltRect)
                }
            }
        }
        
        image.unlockFocus()
        return image
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                // Recreate the content view to ensure fresh state
                let tabbedMainView = TabbedMainView()
                    .environmentObject(viewModel)
                
                popoverContentViewController = NSHostingController(rootView: tabbedMainView)
                popover.contentViewController = popoverContentViewController
                
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    // MARK: - NSPopoverDelegate
    
    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        return false
    }
    
    func popoverDidShow(_ notification: Notification) {
        // Set up event monitor for clicks outside
        if eventMonitor == nil {
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                if let strongSelf = self, strongSelf.popover.isShown {
                    // Check if click is within popover bounds
                    if let contentView = strongSelf.popover.contentViewController?.view,
                       let window = contentView.window {
                        let clickLocation = event.locationInWindow
                        let screenLocation = NSPoint(
                            x: window.frame.origin.x + clickLocation.x,
                            y: window.frame.origin.y + clickLocation.y
                        )
                        
                        // Don't close if click is within popover window
                        if window.frame.contains(screenLocation) {
                            return
                        }
                    }
                    
                    strongSelf.closePopover()
                }
            }
        }
    }
    
    func popoverDidClose(_ notification: Notification) {
        // Remove event monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    func closePopover() {
        popover.performClose(nil)
    }
    
    // Event monitor for clicks outside popover
    var eventMonitor: Any?
    
    // Helper function to get the app icon for consistent use
    private func getAppIcon() -> NSImage? {
        // First try to get the app icon from bundle resources
        if let resourcePath = Bundle.main.resourcePath {
            let iconPath = "\(resourcePath)/AppIcon.icns"
            
            if let appIcon = NSImage(contentsOfFile: iconPath) {
                return createResizedIcon(from: appIcon)
            }
        }
        
        // Fallback to application icon
        if let appIcon = NSApp.applicationIconImage {
            return createResizedIcon(from: appIcon)
        }
        
        return nil
    }
    
    // Helper to safely create resized icons
    private func createResizedIcon(from sourceIcon: NSImage) -> NSImage? {
        let iconSize = Self.menuBarIconSize
        let menuBarIcon = NSImage(size: NSSize(width: iconSize, height: iconSize))
        
        menuBarIcon.lockFocus()
        defer { menuBarIcon.unlockFocus() } // Ensure context is always unlocked
        
        sourceIcon.draw(in: NSRect(x: 0, y: 0, width: iconSize, height: iconSize), 
                       from: NSRect.zero, 
                       operation: .sourceOver, 
                       fraction: 1.0)
        
        menuBarIcon.isTemplate = false  // Don't make it a template (keep colors)
        return menuBarIcon
    }
    
    // Helper function to get high-quality app icon for dialogs (not resized)
    private func getDialogAppIcon() -> NSImage? {
        // Load the original high-quality icon without resizing
        if let resourcePath = Bundle.main.resourcePath {
            let iconPath = "\(resourcePath)/AppIcon.icns"
            
            if let appIcon = NSImage(contentsOfFile: iconPath) {
                // Return original size for crisp dialog display
                return appIcon
            }
        }
        
        // Fallback to application icon (original size)
        if let appIcon = NSApp.applicationIconImage {
            return appIcon
        }
        
        return nil
    }
}