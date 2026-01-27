import BatteryCore
import AppKit
import Combine
import Foundation
import SwiftUI
import os.log

@MainActor
class BatteryViewModel: ObservableObject {
  // Real battery info
  @Published var batteryInfo = BatteryInfo()

  // Error state for user feedback
  @Published var errorMessage: String? = nil

  // Shared system stores (used across popover + desktop widget surfaces)
  //
  // First principle: multiple UI surfaces should share the same sampler to avoid duplicate timers / duplicated work.
  // These stores are injected into the popover, Smart Notch, and Desktop Widget via `EnvironmentObject`.
  let wifiStore = WiFiStore()
  let audioDevicesStore = AudioDevicesStore()
  let airPodsBatteryStore = AirPodsBatteryStore()

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
      let shouldPersist = desktopWidgetPersistenceOverride ?? true
      desktopWidgetPersistenceOverride = nil

      if showDesktopWidget {
        widgetManager?.showWidget()
      } else {
        widgetManager?.hideWidget()
      }

      if shouldPersist {
        saveSetting("showDesktopWidget", value: showDesktopWidget)
      }
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

  @Published var widgetCustomModules: [WidgetModule] = WidgetModule.defaultSelection {
    didSet {
      let normalized = Self.normalizedWidgetModules(widgetCustomModules)
      if normalized != widgetCustomModules {
        widgetCustomModules = normalized
        return
      }

      guard !isLoadingSettings else { return }
      saveSetting("widgetCustomModules", value: widgetCustomModules.map(\.rawValue))
    }
  }

  @Published var widgetCustomAdaptiveEmphasis: Bool = true {
    didSet {
      guard !isLoadingSettings else { return }
      saveSetting("widgetCustomAdaptiveEmphasis", value: widgetCustomAdaptiveEmphasis)
    }
  }

  @Published var autoEnableWidgetInClamshell = false {
    didSet {
      saveSetting("autoEnableWidgetInClamshell", value: autoEnableWidgetInClamshell)
      guard !isLoadingSettings else { return }
      configureClamshellWidgetAuto(reason: "setting_changed")
    }
  }

  @Published private(set) var isClamshellClosed = false
  @Published private(set) var hasExternalDisplay = false

  var isDesktopWidgetForcedByClamshell: Bool {
    autoEnableWidgetInClamshell && isClamshellClosed && hasExternalDisplay
  }

  var clamshellWidgetStatusText: String {
    let lid = isClamshellClosed ? "Lid closed" : "Lid open"
    let display = hasExternalDisplay ? "External display connected" : "No external display"
    if isDesktopWidgetForcedByClamshell {
      return "\(lid). \(display). Desktop Widget is currently enabled automatically."
    }
    return "\(lid). \(display)."
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

  // Notch glow alert rules (battery)
  @Published var notchAlertChargerConnected = true {
    didSet {
      saveSetting("notchAlertChargerConnected", value: notchAlertChargerConnected)
    }
  }

  @Published var notchAlertFullyCharged = true {
    didSet {
      saveSetting("notchAlertFullyCharged", value: notchAlertFullyCharged)
    }
  }

  @Published var notchAlertLowBatteryEnabled = true {
    didSet {
      saveSetting("notchAlertLowBatteryEnabled", value: notchAlertLowBatteryEnabled)
      if !notchAlertLowBatteryEnabled {
        hasShownLowBatteryAlert = false
      }
    }
  }

  @Published var notchAlertLowBatteryThreshold = 20 {
    didSet {
      let clamped = min(50, max(5, notchAlertLowBatteryThreshold))
      let snapped = Int((Double(clamped) / 5.0).rounded()) * 5
      let normalized = min(50, max(5, snapped))
      if notchAlertLowBatteryThreshold != normalized {
        notchAlertLowBatteryThreshold = normalized
        return
      }

      if notchAlertLowBatteryThreshold < notchAlertCriticalBatteryThreshold {
        notchAlertCriticalBatteryThreshold = notchAlertLowBatteryThreshold
      }

      saveSetting("notchAlertLowBatteryThreshold", value: notchAlertLowBatteryThreshold)
      hasShownLowBatteryAlert = false
    }
  }

  @Published var notchAlertCriticalBatteryEnabled = true {
    didSet {
      saveSetting("notchAlertCriticalBatteryEnabled", value: notchAlertCriticalBatteryEnabled)
      if !notchAlertCriticalBatteryEnabled {
        hasShownCriticalBatteryAlert = false
      }
    }
  }

  @Published var notchAlertCriticalBatteryThreshold = 10 {
    didSet {
      let clamped = min(notchAlertLowBatteryThreshold, max(5, notchAlertCriticalBatteryThreshold))
      let snapped = Int((Double(clamped) / 5.0).rounded()) * 5
      let normalized = min(notchAlertLowBatteryThreshold, max(5, snapped))
      if notchAlertCriticalBatteryThreshold != normalized {
        notchAlertCriticalBatteryThreshold = normalized
        return
      }

      saveSetting("notchAlertCriticalBatteryThreshold", value: notchAlertCriticalBatteryThreshold)
      hasShownCriticalBatteryAlert = false
    }
  }

  // Notch glow alert rules (AirPods)
  //
  // Why this exists:
  // - AirPods don’t expose a simple “battery percent” via CoreAudio.
  // - They often broadcast battery levels via Bluetooth LE advertisements.
  // Microverse treats this as a best-effort, opt-in feature: we only scan when the user enables the rule.
  @Published var notchAlertAirPodsLowBatteryEnabled = false {
    didSet {
      guard !isLoadingSettings else { return }
      saveSetting("notchAlertAirPodsLowBatteryEnabled", value: notchAlertAirPodsLowBatteryEnabled)
      if !notchAlertAirPodsLowBatteryEnabled {
        hasShownAirPodsLowBatteryAlert = false
        previousAirPodsBatteryPercent = -1
        clearDebugAirPodsBatteryOverride()
      }
      updateAirPodsBatteryMonitoring(reason: "airpods_alert_toggle")
    }
  }

  @Published var notchAlertAirPodsLowBatteryThreshold = 20 {
    didSet {
      let clamped = min(50, max(5, notchAlertAirPodsLowBatteryThreshold))
      let snapped = Int((Double(clamped) / 5.0).rounded()) * 5
      let normalized = min(50, max(5, snapped))
      if notchAlertAirPodsLowBatteryThreshold != normalized {
        notchAlertAirPodsLowBatteryThreshold = normalized
        return
      }

      guard !isLoadingSettings else { return }
      saveSetting(
        "notchAlertAirPodsLowBatteryThreshold", value: notchAlertAirPodsLowBatteryThreshold)
      hasShownAirPodsLowBatteryAlert = false
      previousAirPodsBatteryPercent = -1
    }
  }

  // AirPods battery state (derived from BLE broadcasts when enabled)
  @Published private(set) var airPodsBatteryAvailability: AirPodsBatteryStore.Availability =
    .unknown
  @Published private(set) var airPodsBatteryPercent: Int?
  @Published private(set) var airPodsBatteryLastUpdated: Date?

  @Published private(set) var debugAirPodsBatteryOverridePercent: Int?

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
  private var desktopWidgetPersistenceOverride: Bool?
  nonisolated(unsafe) private var clamshellDisplayObserver: NSObjectProtocol?
  nonisolated(unsafe) private var clamshellWakeObserver: NSObjectProtocol?
  private var clamshellPollTask: Task<Void, Never>?
  private var isLoadingSettings = false
  private weak var weatherSettingsStore: WeatherSettingsStore?
  private weak var weatherStore: WeatherStore?
  private weak var weatherLocationsStore: WeatherLocationsStore?
  private weak var displayOrchestrator: DisplayOrchestrator?
  private weak var weatherAnimationBudget: WeatherAnimationBudget?

  // Track previous state for alert transitions
  private var previousBatteryCharge: Int = -1
  private var previousIsCharging: Bool = false
  private var previousIsPluggedIn: Bool = false
  private var hasShownLowBatteryAlert = false
  private var hasShownCriticalBatteryAlert = false
  private var previousAirPodsBatteryPercent: Int = -1
  private var hasShownAirPodsLowBatteryAlert = false
  private var isAirPodsBatteryMonitoringActive = false
  private var debugAirPodsBatteryOverrideTask: Task<Void, Never>?
  private var hasPlayedStartupNotchAnimation = false

  // Enhanced notch system
  private let notchViewModel: MicroverseNotchViewModel

  init() {
    logger.info("BatteryViewModel initializing...")

    // Initialize notch system with proper dependency injection
    notchViewModel = MicroverseNotchViewModel()

    isLoadingSettings = true
    loadSettings()
    isLoadingSettings = false
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

    configureClamshellWidgetAuto(reason: "init")

    logger.info("BatteryViewModel initialized")
  }

  func setWeatherEnvironment(
    settings: WeatherSettingsStore,
    store: WeatherStore,
    locationsStore: WeatherLocationsStore,
    orchestrator: DisplayOrchestrator,
    animationBudget: WeatherAnimationBudget
  ) {
    weatherSettingsStore = settings
    weatherStore = store
    weatherLocationsStore = locationsStore
    displayOrchestrator = orchestrator
    weatherAnimationBudget = animationBudget

    notchViewModel.setWeatherEnvironment(
      settings: settings,
      store: store,
      locationsStore: locationsStore,
      orchestrator: orchestrator,
      animationBudget: animationBudget
    )
    widgetManager?.setWeatherEnvironment(
      settings: settings, store: store, orchestrator: orchestrator, animationBudget: animationBudget
    )

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
          logger.info(
            "Notch displayed on startup with mode: \(self.notchViewModel.layoutMode.displayName)")
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
    debugAirPodsBatteryOverrideTask?.cancel()
    if let observer = clamshellDisplayObserver {
      NotificationCenter.default.removeObserver(observer)
    }
    if let observer = clamshellWakeObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
    }
    clamshellPollTask?.cancel()

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

    logger.debug(
      "Battery: \(self.batteryInfo.currentCharge)%, \(self.batteryInfo.isCharging ? "charging" : "not charging")"
    )

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
      logger.info(
        "Setting notch layout mode from \(oldMode.displayName) to \(newValue.displayName)")
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

  #if DEBUG
  /// DEBUG-only access to the desktop widget window (for deterministic screenshot generation).
  var debugDesktopWidgetWindow: NSWindow? {
    widgetManager?.debugWindow
  }

  /// Toggle the Desktop Widget without persisting the preference.
  ///
  /// Why: screenshot automation wants to temporarily show widget variants without altering the user's setup.
  func debugSetDesktopWidgetVisible(_ visible: Bool) {
    desktopWidgetPersistenceOverride = false
    showDesktopWidget = visible
  }
  #endif

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
    if notchAlertChargerConnected, isPluggedIn && !previousIsPluggedIn {
      // Calm, deliberate ping-pong sweep for "charger connected".
      NotchGlowManager.shared.showSuccess(duration: 4.0)
      hasShownLowBatteryAlert = false
      hasShownCriticalBatteryAlert = false
      logger.info("Notch alert: Charger connected")
      return
    }

    // Alert: Fully charged (reached 100% while plugged in)
    if notchAlertFullyCharged, currentCharge >= 100 && previousBatteryCharge < 100 && isPluggedIn {
      NotchGlowManager.shared.showSuccess(duration: 2.0)
      logger.info("Notch alert: Fully charged")
      return
    }

    // Alert: Critical battery (≤10%)
    if notchAlertCriticalBatteryEnabled,
      currentCharge <= notchAlertCriticalBatteryThreshold,
      isOnBatteryPower,
      !hasShownCriticalBatteryAlert
    {
      NotchGlowManager.shared.showCritical(duration: 3.0)
      hasShownCriticalBatteryAlert = true
      logger.info("Notch alert: Critical battery")
      return
    }

    // Alert: Low battery (≤20%, crossed threshold)
    if notchAlertLowBatteryEnabled,
      currentCharge <= notchAlertLowBatteryThreshold,
      previousBatteryCharge > notchAlertLowBatteryThreshold,
      isOnBatteryPower,
      !hasShownLowBatteryAlert
    {
      NotchGlowManager.shared.showWarning(duration: 2.0)
      hasShownLowBatteryAlert = true
      logger.info("Notch alert: Low battery")
      return
    }

    // Reset alert flags when battery recovers
    if currentCharge > notchAlertLowBatteryThreshold {
      hasShownLowBatteryAlert = false
    }
    if currentCharge > notchAlertCriticalBatteryThreshold {
      hasShownCriticalBatteryAlert = false
    }
  }

  // MARK: - AirPods Battery (BLE-derived)
  //
  // Data flow:
  // 1) `AudioDevicesStore` determines whether the current default output looks like AirPods and exposes its name/model.
  // 2) `AirPodsBatteryStore` periodically scans BLE advertisements and publishes `Reading`s.
  // 3) We match by (normalized) device name and derive a single percent that can drive UI + “low battery” notch glow rules.
  //
  // This is intentionally best-effort: if any link in the chain is missing, we publish `nil` and do nothing.
  private func updateAirPodsBatteryMonitoring(reason: String) {
    if notchAlertAirPodsLowBatteryEnabled {
      if !isAirPodsBatteryMonitoringActive {
        airPodsBatteryStore.start(scanInterval: 30, scanDuration: 4)
        audioDevicesStore.start()
        isAirPodsBatteryMonitoringActive = true
      }
      refreshAirPodsBatteryState(reason: reason)
      return
    }

    if isAirPodsBatteryMonitoringActive {
      airPodsBatteryStore.stop()
      audioDevicesStore.stop()
      isAirPodsBatteryMonitoringActive = false
    }

    airPodsBatteryPercent = nil
    airPodsBatteryLastUpdated = nil
  }

  private func refreshAirPodsBatteryState(reason: String) {
    guard audioDevicesStore.defaultOutputAirPodsModel != nil else {
      airPodsBatteryPercent = nil
      airPodsBatteryLastUpdated = nil
      hasShownAirPodsLowBatteryAlert = false
      previousAirPodsBatteryPercent = -1
      return
    }

    if let override = debugAirPodsBatteryOverridePercent {
      airPodsBatteryPercent = override
      airPodsBatteryLastUpdated = Date()
      checkAndTriggerAirPodsLowBatteryAlert(currentPercent: override)
      return
    }

    guard let deviceName = audioDevicesStore.defaultOutputDevice?.trimmedName, !deviceName.isEmpty
    else {
      airPodsBatteryPercent = nil
      airPodsBatteryLastUpdated = nil
      return
    }

    guard let reading = airPodsBatteryStore.bestReading(matchingDeviceName: deviceName),
      let model = audioDevicesStore.defaultOutputAirPodsModel
    else {
      airPodsBatteryPercent = nil
      airPodsBatteryLastUpdated = nil
      return
    }

    airPodsBatteryPercent = resolvedAirPodsBatteryPercent(from: reading, model: model)
    airPodsBatteryLastUpdated = reading.updatedAt

    if let current = airPodsBatteryPercent {
      checkAndTriggerAirPodsLowBatteryAlert(currentPercent: current)
    }
  }

  private func resolvedAirPodsBatteryPercent(
    from reading: AirPodsBatteryStore.Reading,
    model: AudioDevicesStore.AirPodsModel
  ) -> Int? {
    let left = reading.leftPercent
    let right = reading.rightPercent

    if model == .airPodsMax {
      if left == nil, right == nil { return reading.casePercent }
      return max(left ?? 0, right ?? 0)
    }

    if let left, let right {
      return min(left, right)
    }

    return left ?? right ?? reading.casePercent
  }

  private func checkAndTriggerAirPodsLowBatteryAlert(currentPercent: Int) {
    defer { previousAirPodsBatteryPercent = currentPercent }

    guard notchAlertAirPodsLowBatteryEnabled else { return }
    guard enableNotchAlerts else { return }
    guard isNotchAvailable else { return }

    // Skip first run (no previous data)
    guard previousAirPodsBatteryPercent >= 0 else { return }

    if currentPercent <= notchAlertAirPodsLowBatteryThreshold,
      previousAirPodsBatteryPercent > notchAlertAirPodsLowBatteryThreshold,
      !hasShownAirPodsLowBatteryAlert
    {
      NotchGlowManager.shared.showCritical(duration: 2.0)
      hasShownAirPodsLowBatteryAlert = true
      logger.info("Notch alert: AirPods low battery (\(currentPercent)%)")
      return
    }

    if currentPercent > notchAlertAirPodsLowBatteryThreshold {
      hasShownAirPodsLowBatteryAlert = false
    }
  }

  func setDebugAirPodsBatteryOverride(percent: Int, ttl: TimeInterval = 15) {
    debugAirPodsBatteryOverrideTask?.cancel()
    debugAirPodsBatteryOverridePercent = max(0, min(100, percent))
    refreshAirPodsBatteryState(reason: "debug_override")

    debugAirPodsBatteryOverrideTask = Task { @MainActor [weak self] in
      do {
        try await Task.sleep(nanoseconds: UInt64(max(2, ttl) * 1_000_000_000))
      } catch {
        return
      }
      self?.clearDebugAirPodsBatteryOverride()
    }
  }

  func clearDebugAirPodsBatteryOverride() {
    debugAirPodsBatteryOverrideTask?.cancel()
    debugAirPodsBatteryOverrideTask = nil
    debugAirPodsBatteryOverridePercent = nil
    refreshAirPodsBatteryState(reason: "debug_override_clear")
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
        self.logger.debug(
          "Adaptive refresh: Next update in \(adaptiveInterval)s (battery: \(self.batteryInfo.currentCharge)%, charging: \(self.batteryInfo.isCharging))"
        )

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
    airPodsBatteryStore.$availability
      .sink { [weak self] availability in
        self?.airPodsBatteryAvailability = availability
      }
      .store(in: &cancellables)

    airPodsBatteryStore.$readings
      .sink { [weak self] _ in
        self?.refreshAirPodsBatteryState(reason: "ble_scan")
      }
      .store(in: &cancellables)

    audioDevicesStore.$lastUpdated
      .sink { [weak self] _ in
        self?.refreshAirPodsBatteryState(reason: "audio_refresh")
      }
      .store(in: &cancellables)

    updateAirPodsBatteryMonitoring(reason: "bindings_init")
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
      let style = WidgetStyle(rawValue: styleRaw)
    {
      widgetStyle = style
    }

    if let rawModules = defaults.array(forKey: "widgetCustomModules") as? [String] {
      let parsed = rawModules.compactMap(WidgetModule.init(rawValue:))
      widgetCustomModules = parsed
    }

    if defaults.object(forKey: "widgetCustomAdaptiveEmphasis") != nil {
      widgetCustomAdaptiveEmphasis = defaults.bool(forKey: "widgetCustomAdaptiveEmphasis")
    }

    if defaults.object(forKey: "autoEnableWidgetInClamshell") != nil {
      autoEnableWidgetInClamshell = defaults.bool(forKey: "autoEnableWidgetInClamshell")
    }

    // Load auto-update setting
    if defaults.object(forKey: "checkForUpdatesAutomatically") != nil {
      checkForUpdatesAutomatically = defaults.bool(forKey: "checkForUpdatesAutomatically")
    }

    // Load notch layout mode
    if let modeRaw = defaults.string(forKey: "notchLayoutMode"),
      let mode = MicroverseNotchViewModel.NotchLayoutMode(rawValue: modeRaw)
    {
      notchViewModel.layoutMode = mode
    }

    // Load notch alerts setting (default true)
    if defaults.object(forKey: "enableNotchAlerts") != nil {
      enableNotchAlerts = defaults.bool(forKey: "enableNotchAlerts")
    }

    // Load notch alert rules (battery)
    if defaults.object(forKey: "notchAlertChargerConnected") != nil {
      notchAlertChargerConnected = defaults.bool(forKey: "notchAlertChargerConnected")
    }

    if defaults.object(forKey: "notchAlertFullyCharged") != nil {
      notchAlertFullyCharged = defaults.bool(forKey: "notchAlertFullyCharged")
    }

    if defaults.object(forKey: "notchAlertLowBatteryEnabled") != nil {
      notchAlertLowBatteryEnabled = defaults.bool(forKey: "notchAlertLowBatteryEnabled")
    }

    if defaults.object(forKey: "notchAlertLowBatteryThreshold") != nil {
      notchAlertLowBatteryThreshold = defaults.integer(forKey: "notchAlertLowBatteryThreshold")
    }

    if defaults.object(forKey: "notchAlertCriticalBatteryEnabled") != nil {
      notchAlertCriticalBatteryEnabled = defaults.bool(forKey: "notchAlertCriticalBatteryEnabled")
    }

    if defaults.object(forKey: "notchAlertCriticalBatteryThreshold") != nil {
      notchAlertCriticalBatteryThreshold = defaults.integer(
        forKey: "notchAlertCriticalBatteryThreshold")
    }

    // Load AirPods low battery alert settings (default off)
    if defaults.object(forKey: "notchAlertAirPodsLowBatteryEnabled") != nil {
      notchAlertAirPodsLowBatteryEnabled = defaults.bool(
        forKey: "notchAlertAirPodsLowBatteryEnabled")
    }

    if defaults.object(forKey: "notchAlertAirPodsLowBatteryThreshold") != nil {
      notchAlertAirPodsLowBatteryThreshold = defaults.integer(
        forKey: "notchAlertAirPodsLowBatteryThreshold")
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

  private static func normalizedWidgetModules(_ modules: [WidgetModule]) -> [WidgetModule] {
    var seen = Set<WidgetModule>()
    let deduped = modules.filter { seen.insert($0).inserted }
    let clamped = Array(deduped.prefix(WidgetModule.maximumSelection))
    return clamped.isEmpty ? WidgetModule.defaultSelection : clamped
  }

  private func setDesktopWidgetVisible(_ visible: Bool, persist: Bool) {
    desktopWidgetPersistenceOverride = persist
    showDesktopWidget = visible
  }

  private func configureClamshellWidgetAuto(reason: String) {
    if autoEnableWidgetInClamshell {
      startClamshellWidgetMonitoring()
      applyClamshellWidgetRule(reason: reason)
    } else {
      stopClamshellWidgetMonitoring()
      restoreDesktopWidgetToUserPreference(reason: reason)
    }
  }

  private func startClamshellWidgetMonitoring() {
    guard clamshellDisplayObserver == nil else { return }

    clamshellDisplayObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.applyClamshellWidgetRule(reason: "display_changed")
      }
    }

    clamshellWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.applyClamshellWidgetRule(reason: "wake")
      }
    }

    clamshellPollTask?.cancel()
    clamshellPollTask = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        do {
          try await Task.sleep(nanoseconds: 15_000_000_000)
        } catch {
          break
        }
        self?.applyClamshellWidgetRule(reason: "poll")
      }
    }
  }

  private func stopClamshellWidgetMonitoring() {
    if let observer = clamshellDisplayObserver {
      NotificationCenter.default.removeObserver(observer)
      clamshellDisplayObserver = nil
    }
    if let observer = clamshellWakeObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(observer)
      clamshellWakeObserver = nil
    }
    clamshellPollTask?.cancel()
    clamshellPollTask = nil
  }

  private func applyClamshellWidgetRule(reason: String) {
    guard autoEnableWidgetInClamshell else { return }

    let clamshell = MicroverseClamshellStateProvider.current()
    let topology = MicroverseDisplayTopology.current()

    isClamshellClosed = clamshell == .closed
    hasExternalDisplay = topology.hasExternalDisplay

    let shouldForceWidget = isClamshellClosed && hasExternalDisplay
    let manualPreference = UserDefaults.standard.bool(forKey: "showDesktopWidget")
    let desired = shouldForceWidget ? true : manualPreference

    if showDesktopWidget != desired {
      setDesktopWidgetVisible(desired, persist: false)
    }

    #if DEBUG
      logger.debug(
        "Clamshell auto widget (\(reason)): clamshell=\(String(describing: clamshell)), external=\(self.hasExternalDisplay), manual=\(manualPreference), desired=\(desired)"
      )
    #endif
  }

  private func restoreDesktopWidgetToUserPreference(reason: String) {
    isClamshellClosed = false
    hasExternalDisplay = false

    let manualPreference = UserDefaults.standard.bool(forKey: "showDesktopWidget")
    if showDesktopWidget != manualPreference {
      setDesktopWidgetVisible(manualPreference, persist: false)
    }

    #if DEBUG
      logger.debug(
        "Clamshell auto widget disabled (\(reason)): restored manual=\(manualPreference)")
    #endif
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
