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
///
/// Wi-Fi and audio come from the view model, which owns the only instances of those stores.
/// Weather stores are passed in because only some surfaces show weather.
@MainActor
struct WidgetModuleStatusResolver {
  let viewModel: BatteryViewModel
  var systemService: SystemMonitoringService = .shared
  var weatherSettings: WeatherSettingsStore? = nil
  var weatherStore: WeatherStore? = nil

  private var wifi: WiFiStore { viewModel.wifiStore }
  private var audio: AudioDevicesStore { viewModel.audioDevicesStore }

  func color(for module: WidgetModule) -> Color {
    status(for: module).color
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
    case .disk: return Self.diskStatus(systemService.diskInfo)
    case .systemHealth: return systemHealthStatus
    }
  }

  /// Bands: red when 95% full or under 5 GB left, orange at 90% or under 10 GB, yellow at 80%,
  /// green below. macOS itself starts complaining in the red band.
  static func diskStatus(_ disk: DiskInfo) -> WidgetModuleStatus {
    guard disk.totalBytes > 0 else { return .inactive }
    let used = disk.usagePercentage
    if used >= 95 || disk.availableGB < 5 { return .critical }
    if used >= 90 || disk.availableGB < 10 { return .poor }
    if used >= 80 { return .fair }
    return .good
  }

  /// SF Symbol for the battery on every surface: a level-aware outline while discharging, and
  /// the bolt variant while charging so the power state is visible without reading any text.
  /// SF Symbols only ships a bolt for the 100% glyph, hence the single charging icon.
  var batteryIconName: String {
    let battery = viewModel.batteryInfo
    return Self.batteryIconName(charge: battery.currentCharge, isCharging: battery.isCharging)
  }

  static func batteryIconName(charge: Int, isCharging: Bool) -> String {
    if isCharging { return "battery.100percent.bolt" }
    switch charge {
    case 90...: return "battery.100percent"
    case 65..<90: return "battery.75percent"
    case 40..<65: return "battery.50percent"
    case 15..<40: return "battery.25percent"
    default: return "battery.0percent"
    }
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
  /// Bands: red ≤ critical alert, orange ≤ low alert, yellow ≤ 60%, green above.
  private var batteryStatus: WidgetModuleStatus {
    let charge = viewModel.batteryInfo.currentCharge
    if charge <= viewModel.notchAlertCriticalBatteryThreshold { return .critical }
    if charge <= viewModel.notchAlertLowBatteryThreshold { return .poor }
    if charge <= 60 { return .fair }
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
  /// Bands: red > 80%, orange > 60%, yellow > 40%, green below.
  static func cpuStatus(usage: Double) -> WidgetModuleStatus {
    if usage > MicroverseDesign.Notch.Performance.cpuThresholdCritical { return .critical }
    if usage > MicroverseDesign.Notch.Performance.cpuThresholdWarning { return .poor }
    if usage > 40 { return .fair }
    return .good
  }

  /// Memory pressure wins when the kernel reports it; otherwise grade by how full memory is.
  /// Bands: red at critical pressure, orange at warning pressure or ≥ 90% used, yellow ≥ 70%,
  /// green below.
  static func memoryStatus(_ memory: MemoryInfo) -> WidgetModuleStatus {
    switch memory.pressure {
    case .critical: return .critical
    case .warning: return .poor
    case .normal:
      if memory.usagePercentage >= 90 { return .poor }
      if memory.usagePercentage >= 70 { return .fair }
      return .good
    }
  }

  /// The worst of CPU, memory, disk, and battery. A low battery on the charger is not a health
  /// problem, and an unknown disk (no reading yet) does not count.
  private var systemHealthStatus: WidgetModuleStatus {
    let batteryConcern: WidgetModuleStatus = viewModel.batteryInfo.isPluggedIn ? .good : batteryStatus
    let diskConcern = Self.diskStatus(systemService.diskInfo)
    let worst = [cpuStatus, memoryStatus, batteryConcern, diskConcern == .inactive ? .good : diskConcern]
    if worst.contains(.critical) { return .critical }
    if worst.contains(.poor) { return .poor }
    if worst.contains(.fair) { return .fair }
    return .good
  }

  /// Headline for the System Health card. Derived from the status so word and color always agree.
  var systemHealthHeadline: String {
    switch status(for: .systemHealth) {
    case .good: return "Optimal"
    case .fair: return "Steady"
    case .poor: return "Strained"
    case .critical: return "Under pressure"
    case .neutral, .inactive: return "—"
    }
  }

  /// Short form of `systemHealthHeadline` for the small widget tiles.
  var systemHealthShortLabel: String {
    switch status(for: .systemHealth) {
    case .good: return "OK"
    case .fair: return "Fair"
    case .poor: return "High"
    case .critical: return "Critical"
    case .neutral, .inactive: return "—"
    }
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

  /// Severity of an upcoming forecast event on the same scale, so warning rows match the tiles.
  static func status(for event: WeatherEvent) -> WidgetModuleStatus {
    switch event.kind {
    case .precipStart: return .neutral
    case .precipStop: return .good
    case .conditionShift: return event.toBucket == .thunder ? .critical : .fair
    case .tempRise, .tempDrop: return event.severity >= 0.7 ? .poor : .fair
    }
  }

  private var upcomingPrecipitation: Bool {
    guard let event = weatherStore?.nextEvent, event.kind == .precipStart else { return false }
    let lead = event.startTime.timeIntervalSinceNow
    return lead > 0 && lead <= 30 * 60
  }
}

extension BatteryViewModel {
  /// Status resolver for surfaces that do not show weather. Views with weather stores build
  /// `WidgetModuleStatusResolver` themselves and pass them in.
  var status: WidgetModuleStatusResolver {
    WidgetModuleStatusResolver(viewModel: self)
  }
}
