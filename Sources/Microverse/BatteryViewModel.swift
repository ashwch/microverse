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
    
    
    private let reader = BatteryReader()
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.microverse.app", category: "BatteryViewModel")
    private var widgetManager: DesktopWidgetManager?
    
    init() {
        logger.info("BatteryViewModel initializing...")
        
        loadSettings()
        refreshBatteryInfo()
        startMonitoring()
        setupBindings()
        
        // Initialize widget manager
        widgetManager = DesktopWidgetManager(viewModel: self)
        
        // Show widget if it was enabled
        if showDesktopWidget {
            widgetManager?.showWidget()
        }
        
        logger.info("BatteryViewModel initialized")
    }
    
    deinit {
        timer?.invalidate()
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
        
        // Note: launchAtStartup is already loaded from LaunchAtStartup.isEnabled
    }
    
    private func saveSetting(_ key: String, value: Any) {
        UserDefaults.standard.set(value, forKey: key)
    }
}