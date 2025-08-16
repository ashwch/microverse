import Foundation
import SwiftUI
import Combine
import os.log
import BatteryCore

@MainActor
class BatteryViewModel: ObservableObject {
    // Real battery info
    @Published var batteryInfo = BatteryInfo()
    
    // Error state for user feedback
    @Published var errorMessage: String? = nil
    
    // App settings
    @Published var launchAtStartup = LaunchAtStartup.isEnabled {
        didSet {
            LaunchAtStartup.isEnabled = launchAtStartup
            saveSetting("launchAtStartup", value: launchAtStartup)
        }
    }
    @Published var showPercentageInMenuBar = true {
        didSet {
            saveSetting("showPercentageInMenuBar", value: showPercentageInMenuBar)
        }
    }
    @Published var refreshInterval: TimeInterval = 5.0 {
        didSet {
            saveSetting("refreshInterval", value: refreshInterval)
            // Restart monitoring with new interval
            startMonitoring()
        }
    }
    
    // Widget settings
    @Published var showDesktopWidget = false {
        didSet {
            if showDesktopWidget {
                widgetManager?.showWidget()
            } else {
                widgetManager?.hideWidget()
            }
            saveSetting("showDesktopWidget", value: showDesktopWidget)
        }
    }
    @Published var widgetStyle = WidgetStyle.systemGlance {
        didSet {
            saveSetting("widgetStyle", value: widgetStyle.rawValue)
            // Recreate widget to apply new style
            if showDesktopWidget {
                widgetManager?.hideWidget()
                widgetManager?.showWidget()
            }
        }
    }
    
    // Auto-update settings
    @Published var checkForUpdatesAutomatically = false {
        didSet {
            saveSetting("checkForUpdatesAutomatically", value: checkForUpdatesAutomatically)
            SecureUpdateService.shared.setAutomaticUpdateChecking(enabled: checkForUpdatesAutomatically)
            if checkForUpdatesAutomatically {
                schedulePeriodicUpdateCheck()
            } else {
                cancelPeriodicUpdateCheck()
            }
        }
    }
    
    
    private let reader = BatteryReader()
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.microverse.app", category: "BatteryViewModel")
    private var widgetManager: DesktopWidgetManager?
    private var updateCheckTimer: Timer?
    
    // Enhanced notch system
    private let notchViewModel: MicroverseNotchViewModel
    
    init() {
        logger.info("BatteryViewModel initializing...")
        
        // Initialize notch system with proper dependency injection
        notchViewModel = MicroverseNotchViewModel()
        
        loadSettings()
        refreshBatteryInfo()
        startMonitoring()
        setupBindings()
        
        // Initialize widget manager
        widgetManager = DesktopWidgetManager(viewModel: self)
        
        // Initialize enhanced notch system
        notchViewModel.setBatteryViewModel(self)
        NotchServiceLocator.register(notchViewModel)
        
        // Observe notch layout mode changes to trigger UI updates
        notchViewModel.$layoutMode
            .sink { [weak self] _ in
                // Trigger UI update by changing @Published property
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Show notch if layout mode is not off (after settings are loaded)
        if notchViewModel.layoutMode != .off {
            Task { @MainActor in
                do {
                    try await notchViewModel.showNotch()
                    logger.info("Notch displayed on startup with mode: \(self.notchViewModel.layoutMode.displayName)")
                } catch {
                    logger.error("Failed to show notch on startup: \(error.localizedDescription)")
                }
            }
        }
        
        // Show widget if it was enabled (adaptive display service will manage this)
        if showDesktopWidget {
            widgetManager?.showWidget()
        }
        
        // Start automatic update checking if enabled
        if checkForUpdatesAutomatically {
            schedulePeriodicUpdateCheck()
        }
        
        logger.info("BatteryViewModel initialized")
    }
    
    deinit {
        timer?.invalidate()
        updateCheckTimer?.invalidate()
        
        // Manual cleanup - schedule on main actor
        Task { @MainActor in
            NotchServiceLocator.unregister()
        }
        logger.info("BatteryViewModel deallocated")
    }
    
    // MARK: - Public Methods
    
    func refreshBatteryInfo() {
        // Clear previous error
        errorMessage = nil
        
        // Use the safe method which handles errors gracefully
        batteryInfo = reader.getBatteryInfoSafe()
        
        // Check if we got default values (indicating an error)
        if batteryInfo.currentCharge == 0 && !batteryInfo.isCharging && !batteryInfo.isPluggedIn {
            // Try the throwing version to get the actual error
            do {
                _ = try reader.getBatteryInfo()
            } catch let error as BatteryError {
                errorMessage = error.userMessage
                logger.error("Battery error: \(error.localizedDescription)")
            } catch {
                errorMessage = "Unable to read battery information"
                logger.error("Unknown error: \(error)")
            }
        } else {
            logger.debug("Battery: \(self.batteryInfo.currentCharge)%, \(self.batteryInfo.isCharging ? "charging" : "not charging")")
        }
    }
    
    // MARK: - Enhanced Notch Display Methods
    
    var isNotchDisplayEnabled: Bool {
        notchViewModel.layoutMode != .off
    }
    
    var notchLayoutMode: MicroverseNotchViewModel.NotchLayoutMode {
        get { 
            let currentMode = notchViewModel.layoutMode
            logger.debug("Getting notch layout mode: \(currentMode.displayName)")
            return currentMode 
        }
        set { 
            let oldMode = notchViewModel.layoutMode
            logger.info("Setting notch layout mode from \(oldMode.displayName) to \(newValue.displayName)")
            notchViewModel.layoutMode = newValue
            saveSetting("notchLayoutMode", value: newValue.rawValue)
            
            // Update notch display based on new mode
            Task { @MainActor in
                if newValue == .off {
                    try? await notchViewModel.hideNotch()
                } else {
                    // Show notch if switching from off, or refresh if already visible
                    try? await notchViewModel.showNotch()
                }
            }
        }
    }
    
    func toggleNotchDisplay() {
        Task { @MainActor in
            do {
                if notchViewModel.isNotchVisible {
                    try await notchViewModel.hideNotch()
                } else {
                    try await notchViewModel.showNotch()
                }
            } catch {
                logger.error("Failed to toggle notch display: \(error.localizedDescription)")
                errorMessage = "Notch display error: \(error.localizedDescription)"
            }
        }
    }
    
    func setNotchDisplayEnabled(_ enabled: Bool) {
        if enabled {
            // Enable with current layout mode (default to split if off)
            if notchViewModel.layoutMode == .off {
                notchLayoutMode = .split
            }
            
            Task { @MainActor in
                do {
                    try await notchViewModel.showNotch()
                } catch {
                    logger.error("Failed to enable notch display: \(error.localizedDescription)")
                    errorMessage = "Notch setting error: \(error.localizedDescription)"
                }
            }
        } else {
            // Disable by setting to off mode
            notchLayoutMode = .off
        }
    }
    
    var isNotchAvailable: Bool {
        NSScreen.main?.hasNotch ?? false
    }
    
    var notchViewModelInstance: MicroverseNotchViewModel {
        notchViewModel
    }
    
    // MARK: - Private Methods
    
    /// Starts battery monitoring with adaptive refresh rates
    /// - Slower refresh when battery is stable (plugged in at 100%)
    /// - Normal refresh when charging or on battery power
    /// - Faster refresh when battery is critically low
    private func startMonitoring() {
        timer?.invalidate()
        
        // Calculate adaptive refresh interval based on battery state
        let adaptiveInterval = calculateAdaptiveRefreshInterval()
        
        timer = Timer.scheduledTimer(withTimeInterval: adaptiveInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.refreshBatteryInfo()
                // Schedule next update with potentially different interval
                self?.startMonitoring()
            }
        }
        
        logger.debug("Adaptive refresh: Next update in \(adaptiveInterval)s (battery: \(self.batteryInfo.currentCharge)%, charging: \(self.batteryInfo.isCharging))")
    }
    
    /// Calculates optimal refresh interval based on battery state
    /// Returns interval in seconds
    private func calculateAdaptiveRefreshInterval() -> TimeInterval {
        // Use user preference as base interval
        let baseInterval = refreshInterval
        
        // Adaptive logic based on battery state
        if batteryInfo.currentCharge <= 5 {
            // Critical battery: Update every 2 seconds
            return min(baseInterval, 2.0)
        } else if batteryInfo.currentCharge <= 20 {
            // Low battery: Update at normal rate
            return baseInterval
        } else if batteryInfo.isCharging {
            // Charging: Update at normal rate to show progress
            return baseInterval
        } else if batteryInfo.isPluggedIn && batteryInfo.currentCharge >= 100 {
            // Plugged in at 100%: Battery stable, slow updates
            return baseInterval * 6  // e.g., 30 seconds if base is 5
        } else if batteryInfo.isPluggedIn && batteryInfo.currentCharge >= 80 {
            // Plugged in at high charge: Slower updates
            return baseInterval * 3  // e.g., 15 seconds if base is 5
        } else {
            // On battery power: Normal rate
            return baseInterval
        }
    }
    
    private func setupBindings() {
        // All settings are now handled by didSet observers
    }
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        // Load all settings with defaults
        if defaults.object(forKey: "showPercentageInMenuBar") != nil {
            showPercentageInMenuBar = defaults.bool(forKey: "showPercentageInMenuBar")
        }
        
        let savedInterval = defaults.double(forKey: "refreshInterval")
        if savedInterval > 0 {
            refreshInterval = savedInterval
        }
        
        showDesktopWidget = defaults.bool(forKey: "showDesktopWidget")
        
        if let styleRaw = defaults.string(forKey: "widgetStyle"),
           let style = WidgetStyle(rawValue: styleRaw) {
            widgetStyle = style
        }
        
        // Load auto-update setting
        if defaults.object(forKey: "checkForUpdatesAutomatically") != nil {
            checkForUpdatesAutomatically = defaults.bool(forKey: "checkForUpdatesAutomatically")
        }
        
        // Load notch layout mode
        if let modeRaw = defaults.string(forKey: "notchLayoutMode"),
           let mode = MicroverseNotchViewModel.NotchLayoutMode(rawValue: modeRaw) {
            notchViewModel.layoutMode = mode
        }
        
        // Note: launchAtStartup is already loaded from LaunchAtStartup.isEnabled
    }
    
    private func saveSetting(_ key: String, value: Any) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    // MARK: - Auto-Update Methods
    
    private func schedulePeriodicUpdateCheck() {
        cancelPeriodicUpdateCheck()
        
        // Check every 24 hours
        updateCheckTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
            Task { @MainActor in
                SecureUpdateService.shared.checkForUpdates()
            }
        }
        
        logger.info("Scheduled periodic update checks every 24 hours")
    }
    
    private func cancelPeriodicUpdateCheck() {
        updateCheckTimer?.invalidate()
        updateCheckTimer = nil
        logger.info("Cancelled periodic update checks")
    }
}