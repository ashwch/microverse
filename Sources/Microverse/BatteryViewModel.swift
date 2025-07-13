import Foundation
import SwiftUI
import Combine
import os.log
import BatteryCore

@MainActor
class BatteryViewModel: ObservableObject {
    // Real battery info
    @Published var batteryInfo = BatteryInfo()
    @Published var capabilities = BatteryControlCapabilities()
    
    // Settings that actually work
    @Published var targetChargeLimit: Int = 80
    @Published var showAdminFeatures = false
    
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
    @Published var widgetStyle = WidgetStyle.circular {
        didSet {
            saveSetting("widgetStyle", value: widgetStyle.rawValue)
            // Note: Widget will be recreated when user toggles it off/on
            // This avoids crashes from rapid window recreation
        }
    }
    
    // UI State
    @Published var isRequestingAdminAccess = false
    @Published var lastError: String?
    @Published var showBatteryControlGuide = false
    
    private let reader = BatteryReader()
    private let privilegedController = BatteryControllerPrivileged()
    private let modernAuth = ModernAuthHelper()
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.microverse.app", category: "BatteryViewModel")
    private var widgetManager: DesktopWidgetManager?
    
    init() {
        logger.info("BatteryViewModel initializing...")
        
        loadSettings()
        refreshBatteryInfo()
        checkCapabilities()
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
        batteryInfo = reader.getBatteryInfo()
        logger.debug("Battery: \(self.batteryInfo.currentCharge)%, \(self.batteryInfo.isCharging ? "charging" : "not charging")")
    }
    
    func checkCapabilities() {
        capabilities = reader.getCapabilities()
        
        // No admin features in simplified version
        showAdminFeatures = false
        
        logger.info("Battery monitoring ready")
    }
    
    func requestAdminAccess() {
        isRequestingAdminAccess = true
        lastError = nil
        
        // For now, just show the guide
        // In a real implementation, this would check for helper installation
        
        // Show battery control guide
        showBatteryControlGuide = true
        isRequestingAdminAccess = false
    }
    
    func setChargeLimit(_ limit: Int) {
        // Just try it directly - let the SMC controller handle the errors
        Task {
            let result = privilegedController.setChargeLimit(limit)
            
            await MainActor.run {
                switch result {
                case .success:
                    targetChargeLimit = limit
                    lastError = nil
                    saveSetting("targetChargeLimit", value: limit)
                case .requiresAuthentication:
                    requestAdminAccess()
                case .notSupported(let reason):
                    lastError = "Not supported: \(reason)"
                    logger.warning("Charge limit not supported: \(reason)")
                case .failed(let error):
                    lastError = "Failed: \(error.localizedDescription)"
                    logger.error("Charge limit failed: \(error)")
                }
            }
        }
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
        targetChargeLimit = defaults.integer(forKey: "targetChargeLimit") == 0 ? 80 : defaults.integer(forKey: "targetChargeLimit")
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