import SwiftUI
import AppKit
import os.log

@MainActor
class AdaptiveDisplayService: ObservableObject {
    @Published var enableNotchDisplay = false {
        didSet {
            UserDefaults.standard.set(enableNotchDisplay, forKey: "enableNotchDisplay")
            updateDisplayMode()
        }
    }
    
    @Published var autoSwitchDisplay = true {
        didSet {
            UserDefaults.standard.set(autoSwitchDisplay, forKey: "autoSwitchDisplay")
            updateDisplayMode()
        }
    }
    
    @Published var lastUsedWidgetStyle = WidgetStyle.systemGlance {
        didSet {
            UserDefaults.standard.set(lastUsedWidgetStyle.rawValue, forKey: "lastUsedWidgetStyle")
        }
    }
    
    @Published var currentMode: DisplayMode = .floatingWidget
    
    private var notchDisplayManager: NotchDisplayManager?
    private var floatingWidgetManager: DesktopWidgetManager?
    private weak var viewModel: BatteryViewModel?
    private let logger = Logger(subsystem: "com.microverse.app", category: "AdaptiveDisplayService")
    
    init(viewModel: BatteryViewModel) {
        self.viewModel = viewModel
        self.notchDisplayManager = NotchDisplayManager(viewModel: viewModel)
        self.floatingWidgetManager = DesktopWidgetManager(viewModel: viewModel)
        
        loadSettings()
        setupDisplayMonitoring()
        updateDisplayMode()
        
        logger.info("AdaptiveDisplayService initialized")
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    private func loadSettings() {
        enableNotchDisplay = UserDefaults.standard.bool(forKey: "enableNotchDisplay")
        autoSwitchDisplay = UserDefaults.standard.bool(forKey: "autoSwitchDisplay")
        
        // Set autoSwitchDisplay to true by default if not set
        if UserDefaults.standard.object(forKey: "autoSwitchDisplay") == nil {
            autoSwitchDisplay = true
            UserDefaults.standard.set(true, forKey: "autoSwitchDisplay")
        }
        
        // Enable notch display by default if a notch is available and not previously set
        if UserDefaults.standard.object(forKey: "enableNotchDisplay") == nil && isNotchAvailable {
            enableNotchDisplay = true
            UserDefaults.standard.set(true, forKey: "enableNotchDisplay")
            logger.info("Auto-enabled notch display (first run on notch Mac)")
        }
        
        if let widgetStyleRaw = UserDefaults.standard.string(forKey: "lastUsedWidgetStyle"),
           let widgetStyle = WidgetStyle(rawValue: widgetStyleRaw) {
            lastUsedWidgetStyle = widgetStyle
        }
        
        logger.info("Settings loaded: notch=\(self.enableNotchDisplay), auto=\(self.autoSwitchDisplay), widget=\(self.lastUsedWidgetStyle.rawValue)")
        logger.info("Notch available: \(self.isNotchAvailable)")
    }
    
    private func setupDisplayMonitoring() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(displayConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
    }
    
    @objc private func displayConfigurationChanged() {
        logger.info("Display configuration changed")
        updateDisplayMode()
    }
    
    @objc private func applicationDidBecomeActive() {
        updateDisplayMode()
    }
    
    @objc private func applicationDidResignActive() {
        // Optional: Hide notch widgets when app is not active for better system integration
    }
    
    func updateDisplayMode() {
        guard viewModel != nil else {
            logger.warning("ViewModel not available for display mode update")
            return
        }
        
        let shouldShowNotch = shouldUseNotchMode()
        let newMode: DisplayMode = shouldShowNotch ? .notch : .floatingWidget
        
        logger.info("updateDisplayMode: enableNotchDisplay=\(self.enableNotchDisplay), autoSwitchDisplay=\(self.autoSwitchDisplay), hasNotch=\(self.isNotchAvailable), shouldShowNotch=\(shouldShowNotch)")
        
        if newMode != currentMode {
            logger.info("Switching display mode from \(String(describing: self.currentMode)) to \(String(describing: newMode))")
            currentMode = newMode
            
            switch newMode {
            case .notch:
                hideFloatingWidget()
                showNotchDisplay()
            case .floatingWidget:
                hideNotchDisplay()
                showFloatingWidget()
            }
        } else {
            logger.info("Display mode unchanged: \(String(describing: self.currentMode))")
        }
    }
    
    private func shouldUseNotchMode() -> Bool {
        guard enableNotchDisplay else { return false }
        guard autoSwitchDisplay else { return enableNotchDisplay }
        guard let screen = NSScreen.main else { return false }
        
        return screen.hasNotch
    }
    
    private func showNotchDisplay() {
        notchDisplayManager?.showNotchDisplay()
        logger.info("Notch display shown")
    }
    
    private func hideNotchDisplay() {
        notchDisplayManager?.hideNotchDisplay()
        logger.info("Notch display hidden")
    }
    
    private func showFloatingWidget() {
        guard let viewModel = viewModel else { return }
        
        // Update viewModel's widget style to match our saved preference
        viewModel.widgetStyle = lastUsedWidgetStyle
        viewModel.showDesktopWidget = true
        
        logger.info("Floating widget shown with style: \(self.lastUsedWidgetStyle.rawValue)")
    }
    
    private func hideFloatingWidget() {
        guard let viewModel = viewModel else { return }
        
        // Save current widget style before hiding
        lastUsedWidgetStyle = viewModel.widgetStyle
        viewModel.showDesktopWidget = false
        
        logger.info("Floating widget hidden, saved style: \(self.lastUsedWidgetStyle.rawValue)")
    }
    
    func toggleNotchDisplay() {
        enableNotchDisplay.toggle()
        logger.info("Notch display toggled to: \(self.enableNotchDisplay)")
    }
    
    func setWidgetStyle(_ style: WidgetStyle) {
        lastUsedWidgetStyle = style
        
        // If currently in widget mode, update immediately
        if currentMode == .floatingWidget,
           let viewModel = viewModel {
            viewModel.widgetStyle = style
        }
        
        logger.info("Widget style set to: \(style.rawValue)")
    }
    
    var isNotchAvailable: Bool {
        NSScreen.screens.contains(where: { $0.hasNotch })
    }
    
    var displayModeDescription: String {
        switch currentMode {
        case .notch:
            return "Notch Display"
        case .floatingWidget:
            return "Floating Widget (\(lastUsedWidgetStyle.displayName))"
        }
    }
}
