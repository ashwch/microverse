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

    // Notch glow alert settings
    @Published var enableNotchAlerts = true {
        didSet {
            saveSetting("enableNotchAlerts", value: enableNotchAlerts)
        }
    }

    // Startup notch glow animation
    @Published var enableNotchStartupAnimation = true {
        didSet {
            saveSetting("enableNotchStartupAnimation", value: enableNotchStartupAnimation)
        }
    }

    // Smart Notch interaction
    @Published var notchClickToToggleExpanded = false {
        didSet {
            saveSetting("notchClickToToggleExpanded", value: notchClickToToggleExpanded)
            if !notchClickToToggleExpanded, notchViewModel.notchStyle == .expanded {
                Task { @MainActor in
                    try? await self.notchViewModel.compactNotch()
                }
            }
        }
    }

    private let reader = BatteryReader()
    private var batteryRefreshTask: Task<Void, Never>?
    private var updateCheckTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.microverse.app", category: "BatteryViewModel")
    private var widgetManager: DesktopWidgetManager?
    private weak var weatherSettingsStore: WeatherSettingsStore?
    private weak var weatherStore: WeatherStore?
    private weak var displayOrchestrator: DisplayOrchestrator?
    private weak var weatherAnimationBudget: WeatherAnimationBudget?

    // Track previous state for alert transitions
    private var previousBatteryCharge: Int = -1
    private var previousIsCharging: Bool = false
    private var previousIsPluggedIn: Bool = false
    private var hasShownLowBatteryAlert = false
    private var hasShownCriticalBatteryAlert = false
    private var hasPlayedStartupNotchAnimation = false

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

        // Ensure Settings UI updates when notch mode changes externally (e.g., context menu)
        notchViewModel.$layoutMode
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Start automatic update checking if enabled
        if checkForUpdatesAutomatically {
            schedulePeriodicUpdateCheck()
        }

        logger.info("BatteryViewModel initialized")
    }

    func setWeatherEnvironment(
        settings: WeatherSettingsStore,
        store: WeatherStore,
        orchestrator: DisplayOrchestrator,
        animationBudget: WeatherAnimationBudget
    ) {
        weatherSettingsStore = settings
        weatherStore = store
        displayOrchestrator = orchestrator
        weatherAnimationBudget = animationBudget

        notchViewModel.setWeatherEnvironment(settings: settings, store: store, orchestrator: orchestrator, animationBudget: animationBudget)
        widgetManager?.setWeatherEnvironment(settings: settings, store: store, orchestrator: orchestrator, animationBudget: animationBudget)

        if showDesktopWidget {
            widgetManager?.hideWidget()
            widgetManager?.showWidget()
        }
    }

    /// Called once by the app delegate after services are fully constructed.
    func handleAppLaunchCompleted() {
        // Show notch on startup if enabled and supported.
        if notchViewModel.layoutMode != .off, isNotchAvailable {
            Task { @MainActor in
                do {
                    try await notchViewModel.showNotch()
                    logger.info("Notch displayed on startup with mode: \(self.notchViewModel.layoutMode.displayName)")
                    await playStartupNotchAnimationIfNeeded()
                } catch {
                    logger.error("Failed to show notch on startup: \(error.localizedDescription)")
                }
            }
        } else {
            // If the notch UI isn't enabled, we may still want a startup glow (physical notch fallback).
            Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: 900_000_000)
                await self.playStartupNotchAnimationIfNeeded()
            }
        }

        if showDesktopWidget {
            widgetManager?.showWidget()
        }
    }

    deinit {
        batteryRefreshTask?.cancel()
        updateCheckTask?.cancel()

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
            return
        }

        logger.debug("Battery: \(self.batteryInfo.currentCharge)%, \(self.batteryInfo.isCharging ? "charging" : "not charging")")

        // Check for alert conditions and trigger notch glow
        checkAndTriggerAlerts()
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

            Task { @MainActor in
                if newValue == .off {
                    try? await notchViewModel.hideNotch()
                } else {
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
        NSScreen.screens.contains(where: { $0.hasNotch })
    }

    var notchViewModelInstance: MicroverseNotchViewModel {
        notchViewModel
    }

    /// Triggers a test notch glow alert
    func testNotchAlert(type: NotchAlertType) {
        NotchGlowManager.shared.showAlert(type: type, duration: 2.0, pulseCount: 2)
    }

    // MARK: - Notch Alert Logic

    private func checkAndTriggerAlerts() {
        guard enableNotchAlerts else { return }
        guard isNotchAvailable else { return }

        let currentCharge = batteryInfo.currentCharge
        let isCharging = batteryInfo.isCharging
        let isPluggedIn = batteryInfo.isPluggedIn
        let isOnBatteryPower = !isPluggedIn

        // Defer storing previous state until after checks
        defer {
            previousBatteryCharge = currentCharge
            previousIsCharging = isCharging
            previousIsPluggedIn = isPluggedIn
        }

        // Skip first run (no previous data)
        guard previousBatteryCharge >= 0 else { return }

        // Alert: Charger connected (even if macOS reports not charging due to optimizations)
        if isPluggedIn && !previousIsPluggedIn {
            // Calm, deliberate ping-pong sweep for "charger connected".
            NotchGlowManager.shared.showSuccess(duration: 4.0)
            hasShownLowBatteryAlert = false
            hasShownCriticalBatteryAlert = false
            logger.info("Notch alert: Charger connected")
            return
        }

        // Alert: Fully charged (reached 100% while plugged in)
        if currentCharge >= 100 && previousBatteryCharge < 100 && isPluggedIn {
            NotchGlowManager.shared.showSuccess(duration: 2.0)
            logger.info("Notch alert: Fully charged")
            return
        }

        // Alert: Critical battery (≤10%)
        if currentCharge <= 10 && isOnBatteryPower && !hasShownCriticalBatteryAlert {
            NotchGlowManager.shared.showCritical(duration: 3.0)
            hasShownCriticalBatteryAlert = true
            logger.info("Notch alert: Critical battery")
            return
        }

        // Alert: Low battery (≤20%, crossed threshold)
        if currentCharge <= 20 && previousBatteryCharge > 20 && isOnBatteryPower && !hasShownLowBatteryAlert {
            NotchGlowManager.shared.showWarning(duration: 2.0)
            hasShownLowBatteryAlert = true
            logger.info("Notch alert: Low battery")
            return
        }

        // Reset alert flags when battery recovers
        if currentCharge > 20 {
            hasShownLowBatteryAlert = false
        }
        if currentCharge > 10 {
            hasShownCriticalBatteryAlert = false
        }
    }

    // MARK: - Private Methods

    /// Starts battery monitoring with adaptive refresh rates
    /// - Slower refresh when battery is stable (plugged in at 100%)
    /// - Normal refresh when charging or on battery power
    /// - Faster refresh when battery is critically low
    private func startMonitoring() {
        batteryRefreshTask?.cancel()

        batteryRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let adaptiveInterval = self.calculateAdaptiveRefreshInterval()
                self.logger.debug("Adaptive refresh: Next update in \(adaptiveInterval)s (battery: \(self.batteryInfo.currentCharge)%, charging: \(self.batteryInfo.isCharging))")

                do {
                    try await Task.sleep(nanoseconds: UInt64(adaptiveInterval * 1_000_000_000))
                } catch {
                    break
                }

                if Task.isCancelled { break }
                self.refreshBatteryInfo()
            }
        }
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

        // Load notch alerts setting (default true)
        if defaults.object(forKey: "enableNotchAlerts") != nil {
            enableNotchAlerts = defaults.bool(forKey: "enableNotchAlerts")
        }

        // Load startup notch animation setting (default true)
        if defaults.object(forKey: "enableNotchStartupAnimation") != nil {
            enableNotchStartupAnimation = defaults.bool(forKey: "enableNotchStartupAnimation")
        }

        // Load click-to-expand behavior (default off)
        if defaults.object(forKey: "notchClickToToggleExpanded") != nil {
            notchClickToToggleExpanded = defaults.bool(forKey: "notchClickToToggleExpanded")
        }

        // Note: launchAtStartup is already loaded from LaunchAtStartup.isEnabled
    }

    private func saveSetting(_ key: String, value: Any) {
        UserDefaults.standard.set(value, forKey: key)
    }

    private func playStartupNotchAnimationIfNeeded() async {
        guard !hasPlayedStartupNotchAnimation else { return }
        guard enableNotchAlerts, enableNotchStartupAnimation else { return }
        guard isNotchAvailable else { return }

        hasPlayedStartupNotchAnimation = true
        await NotchGlowManager.shared.playStartupAnimation()
    }

    // MARK: - Auto-Update Methods

    private func schedulePeriodicUpdateCheck() {
        cancelPeriodicUpdateCheck()

        updateCheckTask = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 24 * 60 * 60 * 1_000_000_000)
                } catch {
                    break
                }

                if Task.isCancelled { break }
                SecureUpdateService.shared.checkForUpdates()
            }
        }

        logger.info("Scheduled periodic update checks every 24 hours")
    }

    private func cancelPeriodicUpdateCheck() {
        updateCheckTask?.cancel()
        updateCheckTask = nil
        logger.info("Cancelled periodic update checks")
    }
}
