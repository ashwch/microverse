import Foundation
import SwiftUI
import Combine
import os.log
import BatteryCore

@MainActor
class BatteryViewModel: ObservableObject {
    // Real battery info
    @Published var batteryInfo = BatteryInfo()
    
    // App settings
    @Published var launchAtStartup = LaunchAtStartup.isEnabled {
        didSet {
            LaunchAtStartup.isEnabled = launchAtStartup
        }
    }
    @Published var showPercentageInMenuBar = true
    @Published var refreshInterval: TimeInterval = 5.0
    
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
    @Published var widgetStyle = WidgetStyle.standard {
        didSet {
            saveSetting("widgetStyle", value: widgetStyle.rawValue)
            // Note: Widget will be recreated when user toggles it off/on
            // This avoids crashes from rapid window recreation
        }
    }
    
    
    private let reader = BatteryReader()
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.microverse.app", category: "BatteryViewModel")
    private weak var widgetManager: DesktopWidgetManager?
    
    init() {
        logger.info("BatteryViewModel initializing...")
        
        loadSettings()
        refreshBatteryInfo()
        startMonitoring()
        setupBindings()
        
        // Initialize widget manager
        let manager = DesktopWidgetManager(viewModel: self)
        SharedViewModel.widgetManager = manager  // Store strong reference
        widgetManager = manager  // Keep weak reference for access
        
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
        batteryInfo = reader.getBatteryInfo()
        logger.debug("Battery: \(self.batteryInfo.currentCharge)%, \(self.batteryInfo.isCharging ? "charging" : "not charging")")
    }
    
    
    
    // MARK: - Private Methods
    
    private func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshBatteryInfo()
            }
        }
    }
    
    private func setupBindings() {
        // Launch at startup is now handled by the didSet observer
        
        $showPercentageInMenuBar
            .sink { [weak self] enabled in
                self?.saveSetting("showPercentageInMenuBar", value: enabled)
            }
            .store(in: &cancellables)
        
        $refreshInterval
            .sink { [weak self] interval in
                self?.saveSetting("refreshInterval", value: interval)
                self?.startMonitoring()
            }
            .store(in: &cancellables)
    }
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        // Removed targetChargeLimit loading
        // launchAtStartup is now loaded from LaunchAtStartup.isEnabled in the property declaration
        showPercentageInMenuBar = defaults.bool(forKey: "showPercentageInMenuBar")
        refreshInterval = defaults.double(forKey: "refreshInterval") == 0 ? 5.0 : defaults.double(forKey: "refreshInterval")
        showDesktopWidget = defaults.bool(forKey: "showDesktopWidget")
        if let styleRaw = defaults.string(forKey: "widgetStyle"),
           let style = WidgetStyle(rawValue: styleRaw) {
            widgetStyle = style
        }
    }
    
    private func saveSetting(_ key: String, value: Any) {
        UserDefaults.standard.set(value, forKey: key)
    }
}