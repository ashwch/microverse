import SwiftUI
import SystemCore

/// Health of a Custom-widget module, expressed with the same palette the alerts use so the widget
/// gives the same cues as the Alerts tab and the notch glow: green is good, yellow is average,
/// orange needs attention, red is urgent, blue is informational, and dim white means the module
/// has nothing to report.
enum WidgetModuleStatus: Equatable {
  case good
  case fair
  case poor
  case critical
  /// Informational rather than good or bad (network throughput, incoming rain).
  case neutral
  /// Off, unavailable, or disabled.
  case inactive

  var color: Color {
    switch self {
    case .good: return MicroverseDesign.Colors.success
    case .fair: return MicroverseDesign.Colors.caution
    case .poor: return MicroverseDesign.Colors.warning
    case .critical: return MicroverseDesign.Colors.critical
    case .neutral: return MicroverseDesign.Colors.neutral
    case .inactive: return .white.opacity(0.5)
    }
  }

  /// Only states that call for attention tint the value text; the rest keep the text white so the
  /// number stays the most readable thing in the tile.
  var tintsValue: Bool {
    self == .poor || self == .critical
  }
}

/// Resolves a `WidgetModuleStatus` for each module from the live stores. The desktop widget tiles
/// and every notch surface go through this so the thresholds live in exactly one place.
@MainActor
struct WidgetModuleStatusResolver {
  let viewModel: BatteryViewModel
  let systemService: SystemMonitoringService
  let wifi: WiFiStore
  let audio: AudioDevicesStore
  /// Weather stores are optional because some notch views never show weather.
  let weatherSettings: WeatherSettingsStore?
  let weatherStore: WeatherStore?

  init(
    viewModel: BatteryViewModel,
    systemService: SystemMonitoringService = .shared,
    wifi: WiFiStore? = nil,
    audio: AudioDevicesStore? = nil,
    weatherSettings: WeatherSettingsStore? = nil,
    weatherStore: WeatherStore? = nil
  ) {
    self.viewModel = viewModel
    self.systemService = systemService
    self.wifi = wifi ?? viewModel.wifiStore
    self.audio = audio ?? viewModel.audioDevicesStore
    self.weatherSettings = weatherSettings
    self.weatherStore = weatherStore
  }

  func status(for module: WidgetModule) -> WidgetModuleStatus {
    switch module {
    case .battery: return batteryStatus
    case .batteryTime: return batteryTimeStatus
    case .batteryHealth: return batteryHealthStatus
    case .cpu: return cpuStatus
    case .memory: return memoryStatus
    case .network: return .neutral
    case .wifi: return wifiStatus
    case .audioOutput: return audioOutputStatus
    case .audioInput: return audio.defaultInputDeviceID == nil ? .poor : .good
    case .weather: return weatherStatus
    case .systemHealth: return systemHealthStatus
    }
  }

  /// SF Symbol for the battery module: a bolt variant while charging so the power state is
  /// visible without reading the detail text.
  var batteryIconName: String {
    viewModel.batteryInfo.isCharging ? "battery.100percent.bolt" : WidgetModule.battery.systemIcon
  }

  /// True when the module is in a state the user has an alert configured for (AirPods low battery).
  var isAirPodsBatteryLow: Bool {
    audio.defaultOutputAirPodsModel != nil
      && viewModel.notchAlertAirPodsLowBatteryEnabled
      && (viewModel.airPodsBatteryPercent ?? 101) <= viewModel.notchAlertAirPodsLowBatteryThreshold
  }

  // MARK: - Battery

  /// Follows the charge level even while charging, using the same low/critical thresholds as the
  /// notch battery alerts. Charging is shown separately with a bolt on the icon.
  private var batteryStatus: WidgetModuleStatus {
    let battery = viewModel.batteryInfo
    if battery.currentCharge <= viewModel.notchAlertCriticalBatteryThreshold { return .critical }
    if battery.currentCharge <= viewModel.notchAlertLowBatteryThreshold { return .poor }
    if battery.currentCharge <= MicroverseDesign.Notch.Performance.batteryThresholdMedium { return .fair }
    return .good
  }

  private var batteryTimeStatus: WidgetModuleStatus {
    let battery = viewModel.batteryInfo
    if battery.isPluggedIn { return .good }
    guard let minutes = battery.timeRemaining, minutes > 0 else { return .inactive }
    switch minutes {
    case ..<30: return .critical
    case ..<60: return .poor
    case ..<120: return .fair
    default: return .good
    }
  }

  private var batteryHealthStatus: WidgetModuleStatus {
    switch viewModel.batteryInfo.health {
    case 0.85...: return .good
    case 0.75..<0.85: return .fair
    case 0.6..<0.75: return .poor
    default: return .critical
    }
  }

  // MARK: - System

  private var cpuStatus: WidgetModuleStatus { Self.cpuStatus(usage: systemService.cpuUsage) }
  private var memoryStatus: WidgetModuleStatus { Self.memoryStatus(systemService.memoryInfo) }

  /// Static so views that only observe `SystemMonitoringService` can share the thresholds.
  static func cpuStatus(usage: Double) -> WidgetModuleStatus {
    if usage > MicroverseDesign.Notch.Performance.cpuThresholdCritical { return .critical }
    if usage > MicroverseDesign.Notch.Performance.cpuThresholdWarning { return .poor }
    return .good
  }

  static func memoryStatus(_ memory: MemoryInfo) -> WidgetModuleStatus {
    switch memory.pressure {
    case .critical: return .critical
    case .warning: return .poor
    case .normal: return memory.usagePercentage > 85 ? .fair : .good
    }
  }

  private var systemHealthStatus: WidgetModuleStatus {
    // A low battery on the charger is not a health problem.
    let batteryConcern: WidgetModuleStatus = viewModel.batteryInfo.isPluggedIn ? .good : batteryStatus
    let worst = [cpuStatus, memoryStatus, batteryConcern]
    if worst.contains(.critical) { return .critical }
    if worst.contains(.poor) { return .poor }
    return .good
  }

  // MARK: - Connectivity & audio

  private var wifiStatus: WidgetModuleStatus {
    switch wifi.status {
    case .connected:
      switch wifi.signalBars {
      case 3...: return .good
      case 2: return .fair
      case 1: return .poor
      default: return .critical
      }
    case .disconnected: return .poor
    case .poweredOff, .unavailable: return .inactive
    }
  }

  private var audioOutputStatus: WidgetModuleStatus {
    if isAirPodsBatteryLow { return .critical }
    if audio.outputMuted == true { return .poor }
    guard let volume = audio.outputVolume else { return .fair }
    // Effectively silent output is easy to mistake for a broken device.
    return volume <= 0.05 ? .poor : .good
  }

  // MARK: - Weather

  /// Mirrors the Alerts tab: rain is informational blue, storms are urgent.
  private var weatherStatus: WidgetModuleStatus {
    guard let weatherSettings, let weatherStore, weatherSettings.weatherEnabled,
      let current = weatherStore.current
    else { return .inactive }
    switch current.bucket {
    case .thunder: return .critical
    case .rain, .snow: return .neutral
    case .fog, .wind: return .fair
    case .clear, .cloudy: return upcomingPrecipitation ? .neutral : .good
    case .unknown: return .inactive
    }
  }

  private var upcomingPrecipitation: Bool {
    guard let event = weatherStore?.nextEvent, event.kind == .precipStart else { return false }
    let lead = event.startTime.timeIntervalSinceNow
    return lead > 0 && lead <= 30 * 60
  }
}
