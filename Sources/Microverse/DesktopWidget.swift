import AppKit
import BatteryCore
import SwiftUI
import SystemCore

// IMPORTANT: Widget Implementation Notes
// =====================================
// 1. NEVER use ZStack as the root container - it causes clipping issues
// 2. ALWAYS set explicit frame sizes that match the window dimensions
// 3. Apply backgrounds at the END of the view hierarchy, not as containers
// 4. Use padding INSIDE the frame, not outside
// 5. Keep font sizes small to ensure content fits
// 6. Test with edge cases: 100% battery, long time strings, etc.

// Widget style enum - Clear naming for system monitoring
enum WidgetStyle: String, CaseIterable {
  static var allCases: [WidgetStyle] {
    [
      .custom,
      .batterySimple,
      .systemGlance,
      .systemDashboard,
    ]
  }

  case custom = "Custom"  // 240×120: User-configurable modules (adaptive layout)
  // Single metric widgets
  case batterySimple = "Battery Simple"  // 100×40: Just battery %
  case cpuMonitor = "CPU Monitor"  // 160×80: CPU usage + graph
  case memoryMonitor = "Memory Monitor"  // 160×80: Memory usage + pressure

  // Multi-metric widgets
  case systemGlance = "System Glance"  // 160×50: Battery + CPU + Memory %
  case systemStatus = "System Status"  // 240×80: All metrics with basic info
  case systemDashboard = "System Dashboard"  // 240×120: Full detailed view
}

// Desktop widget manager
class DesktopWidgetManager: ObservableObject {
  private var window: DesktopWidgetWindow?
  private var hostingView: NSHostingView<AnyView>?
  private weak var viewModel: BatteryViewModel?
  private weak var weatherSettings: WeatherSettingsStore?
  private weak var weatherStore: WeatherStore?
  private weak var displayOrchestrator: DisplayOrchestrator?
  private weak var weatherAnimationBudget: WeatherAnimationBudget?

  init(viewModel: BatteryViewModel) {
    self.viewModel = viewModel
  }

  func setWeatherEnvironment(
    settings: WeatherSettingsStore,
    store: WeatherStore,
    orchestrator: DisplayOrchestrator,
    animationBudget: WeatherAnimationBudget
  ) {
    weatherSettings = settings
    weatherStore = store
    displayOrchestrator = orchestrator
    weatherAnimationBudget = animationBudget
  }

  @MainActor
  func showWidget() {
    guard window == nil else { return }

    guard let viewModel = viewModel else { return }

    // Get the appropriate size for the widget style
    let size = getWidgetSize(for: viewModel.widgetStyle)
    window = DesktopWidgetWindow(size: size)

    let base = DesktopWidgetView()
      .environmentObject(viewModel)
      .environmentObject(viewModel.wifiStore)
      .environmentObject(viewModel.audioDevicesStore)

    let widgetView: AnyView
    if let weatherSettings, let weatherStore, let displayOrchestrator, let weatherAnimationBudget {
      widgetView = AnyView(
        base
          .environmentObject(weatherSettings)
          .environmentObject(weatherStore)
          .environmentObject(displayOrchestrator)
          .environmentObject(weatherAnimationBudget)
      )
    } else {
      widgetView = AnyView(base)
    }

    // Create hosting view with exact window size
    hostingView = NSHostingView(rootView: widgetView)
    hostingView?.frame = NSRect(origin: .zero, size: size)

    // Configure window for transparency
    window?.contentView = hostingView
    window?.backgroundColor = .clear
    window?.isOpaque = false
    window?.makeKeyAndOrderFront(nil)

    // Position in top-right corner
    positionWindow()
  }

  @MainActor
  func hideWidget() {
    window?.close()
    window = nil
    hostingView = nil
  }

  // CRITICAL: These sizes MUST match the frame sizes in the widget views
  // Any mismatch will cause content to be clipped or not fill the window
  private func getWidgetSize(for style: WidgetStyle) -> NSSize {
    switch style {
    case .custom:
      return NSSize(width: 240, height: 120)
    case .batterySimple:
      return NSSize(width: 100, height: 40)
    case .cpuMonitor, .memoryMonitor:
      return NSSize(width: 160, height: 80)
    case .systemGlance:
      return NSSize(width: 160, height: 50)
    case .systemStatus:
      return NSSize(width: 240, height: 80)
    case .systemDashboard:
      return NSSize(width: 240, height: 120)
    }
  }

  @MainActor
  private func positionWindow() {
    guard let window = window,
      let screen = NSScreen.main
    else { return }

    let screenFrame = screen.visibleFrame
    let windowFrame = window.frame

    let x = screenFrame.maxX - windowFrame.width - 20
    let y = screenFrame.maxY - windowFrame.height - 20

    window.setFrameOrigin(NSPoint(x: x, y: y))
  }
}

// Custom window for widget
class DesktopWidgetWindow: NSWindow {
  init(size: NSSize = NSSize(width: 180, height: 100)) {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    self.level = .floating
    self.collectionBehavior = [.canJoinAllSpaces, .stationary]
    self.backgroundColor = .clear
    self.isOpaque = false
    self.hasShadow = true
    self.isMovableByWindowBackground = true
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true

    // Disable release when closed to prevent crashes
    isReleasedWhenClosed = false

    // Disable animations
    animationBehavior = .none
  }
}

// Widget view
struct DesktopWidgetView: View {
  @EnvironmentObject var viewModel: BatteryViewModel
  @EnvironmentObject private var audio: AudioDevicesStore

  var body: some View {
    Group {
      switch viewModel.widgetStyle {
      case .custom:
        CustomModularWidget()
      case .batterySimple:
        BatterySimpleWidget(batteryInfo: viewModel.batteryInfo)
      case .cpuMonitor:
        CPUMonitorWidget()
      case .memoryMonitor:
        MemoryMonitorWidget()
      case .systemGlance:
        SystemGlanceWidget(batteryInfo: viewModel.batteryInfo)
      case .systemStatus:
        SystemStatusWidget(batteryInfo: viewModel.batteryInfo)
      case .systemDashboard:
        SystemDashboardWidget(batteryInfo: viewModel.batteryInfo)
      }
    }
    .onAppear {
      audio.start()
    }
    .onDisappear {
      audio.stop()
    }
  }
}

// MARK: - Single Metric Widgets

// Battery Simple - Just battery percentage
struct BatterySimpleWidget: View {
  let batteryInfo: BatteryInfo

  var body: some View {
    HStack(spacing: MicroverseDesign.Layout.space1) {
      if batteryInfo.isCharging {
        Image(systemName: "bolt.fill")
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(MicroverseDesign.Colors.success)
      }

      Text("\(batteryInfo.currentCharge)%")
        .font(.system(size: 16, weight: .bold, design: .rounded))
        .foregroundColor(.white)
    }
    .padding(MicroverseDesign.Layout.space2)
    .frame(width: 100, height: 40)
    .widgetBackground()
  }
}

// MARK: - Multi-Metric Widgets

// System Glance - Compact view of all three metrics
struct SystemGlanceWidget: View {
  let batteryInfo: BatteryInfo
  @EnvironmentObject private var weatherSettings: WeatherSettingsStore
  @EnvironmentObject private var weatherStore: WeatherStore
  @EnvironmentObject private var displayOrchestrator: DisplayOrchestrator
  @EnvironmentObject private var weatherAnimationBudget: WeatherAnimationBudget
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @StateObject private var systemService = SystemMonitoringService.shared

  var body: some View {
    HStack(spacing: 0) {
      // Battery
      VStack(spacing: 1) {
        Image(systemName: batteryInfo.isCharging ? "bolt.fill" : "battery.100percent")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(batteryInfo.isCharging ? MicroverseDesign.Colors.success : .white)
        Text("\(batteryInfo.currentCharge)")
          .font(.system(size: 15, weight: .bold, design: .rounded))
          .foregroundColor(.white)
        Text("%")
          .font(.system(size: 6, weight: .semibold))
          .foregroundColor(.white.opacity(0.5))
      }
      .frame(maxWidth: .infinity)

      // CPU or Weather (swap-in)
      Group {
        if shouldShowWeatherInWidget {
          weatherColumn
        } else {
          cpuColumn
        }
      }
      .frame(maxWidth: .infinity)

      // Memory
      VStack(spacing: 1) {
        Image(systemName: "memorychip")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(MicroverseDesign.Colors.memory)
        Text("\(Int(systemService.memoryInfo.usagePercentage))")
          .font(.system(size: 15, weight: .bold, design: .rounded))
          .foregroundColor(.white)
        Text("%")  // Percent indicator
          .font(.system(size: 6))
          .foregroundColor(.white.opacity(0.5))
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 8)
    .frame(width: 160, height: 50)
    .widgetBackground()
  }

  private var shouldShowWeatherInWidget: Bool {
    weatherSettings.weatherEnabled
      && weatherSettings.weatherShowInWidget
      && weatherSettings.selectedLocation != nil
      && displayOrchestrator.compactTrailing == .weather
  }

  private var cpuColumn: some View {
    VStack(spacing: 1) {
      Image(systemName: "cpu")
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(MicroverseDesign.Colors.processor)

      Text("\(Int(systemService.cpuUsage))")
        .font(.system(size: 15, weight: .bold, design: .rounded))
        .foregroundColor(.white)

      Text("%")
        .font(.system(size: 6, weight: .semibold))
        .foregroundColor(.white.opacity(0.5))
    }
  }

  private var weatherColumn: some View {
    VStack(spacing: 1) {
      MicroverseWeatherGlyph(
        bucket: weatherStore.current?.bucket ?? .unknown,
        isDaylight: weatherStore.current?.isDaylight ?? true,
        renderMode: weatherAnimationBudget.renderMode(
          for: .desktopWidget, isVisible: shouldShowWeatherInWidget, reduceMotion: reduceMotion)
      )
      .font(.system(size: 12, weight: .medium))
      .foregroundColor(.white.opacity(0.9))
      .symbolRenderingMode(.hierarchical)
      .frame(width: 18, height: 18)

      Text(widgetTemperatureText)
        .font(.system(size: 15, weight: .bold, design: .rounded))
        .foregroundColor(.white)
        .monospacedDigit()

      Text(weatherStore.nextEvent != nil ? "•" : "...")
        .font(.system(size: 6))
        .foregroundColor(.white.opacity(0.3))
    }
  }

  private var widgetTemperatureText: String {
    guard let c = weatherStore.current?.temperatureC else { return "—" }
    return weatherSettings.weatherUnits.formatTemperatureShort(celsius: c)
  }
}

// System Status - Medium view with all metrics
struct SystemStatusWidget: View {
  let batteryInfo: BatteryInfo
  @StateObject private var systemService = SystemMonitoringService.shared

  var body: some View {
    HStack(spacing: MicroverseDesign.Layout.space4) {
      // Battery Column
      VStack(spacing: MicroverseDesign.Layout.space1) {
        Image(systemName: batteryInfo.isCharging ? "bolt.fill" : "battery.100percent")
          .font(MicroverseDesign.Typography.body)
          .foregroundColor(batteryColor)
        Text("\(batteryInfo.currentCharge)%")
          .font(MicroverseDesign.Typography.title)
          .foregroundColor(.white)
        Text("BATTERY")
          .font(MicroverseDesign.Typography.label)
          .foregroundColor(.white.opacity(0.7))
          .tracking(0.6)
      }

      Divider()
        .frame(width: 1)
        .background(MicroverseDesign.Colors.divider)

      // CPU Column
      VStack(spacing: MicroverseDesign.Layout.space1) {
        Image(systemName: "cpu")
          .font(MicroverseDesign.Typography.body)
          .foregroundColor(cpuColor)
        Text("\(Int(systemService.cpuUsage))%")
          .font(MicroverseDesign.Typography.title)
          .foregroundColor(.white)
        Text("CPU")
          .font(MicroverseDesign.Typography.label)
          .foregroundColor(.white.opacity(0.7))
          .tracking(0.6)
      }

      Divider()
        .frame(width: 1)
        .background(MicroverseDesign.Colors.divider)

      // Memory Column
      VStack(spacing: MicroverseDesign.Layout.space1) {
        Image(systemName: "memorychip")
          .font(MicroverseDesign.Typography.body)
          .foregroundColor(memoryColor)
        Text("\(Int(systemService.memoryInfo.usagePercentage))%")
          .font(MicroverseDesign.Typography.title)
          .foregroundColor(.white)
        Text("MEMORY")
          .font(MicroverseDesign.Typography.label)
          .foregroundColor(.white.opacity(0.7))
          .tracking(0.6)
      }
    }
    .padding(MicroverseDesign.Layout.space3)
    .frame(width: 240, height: 80)
    .widgetBackground()
  }

  private var batteryColor: Color {
    if batteryInfo.currentCharge <= 20 {
      return MicroverseDesign.Colors.warning
    } else if batteryInfo.isCharging {
      return MicroverseDesign.Colors.success
    } else {
      return .white
    }
  }

  private var cpuColor: Color {
    if systemService.cpuUsage > 80 {
      return MicroverseDesign.Colors.critical
    } else if systemService.cpuUsage > 60 {
      return MicroverseDesign.Colors.warning
    } else {
      return MicroverseDesign.Colors.processor
    }
  }

  private var memoryColor: Color {
    switch systemService.memoryInfo.pressure {
    case .critical: return MicroverseDesign.Colors.critical
    case .warning: return MicroverseDesign.Colors.warning
    case .normal: return MicroverseDesign.Colors.memory
    }
  }
}

// Visual effect blur
struct VisualEffectBlur: NSViewRepresentable {
  let material: NSVisualEffectView.Material
  let blendingMode: NSVisualEffectView.BlendingMode

  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = material
    view.blendingMode = blendingMode
    view.state = .active
    return view
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    nsView.material = material
    nsView.blendingMode = blendingMode
  }
}

// MARK: - Consistent Widget Background Extension

extension View {
  /// Applies consistent elegant widget background
  func widgetBackground() -> some View {
    self.background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.black.opacity(0.85))
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    )
  }
}

// Widget Style Extension
extension WidgetStyle {
  var displayName: String {
    switch self {
    case .custom: return "Custom"
    case .batterySimple: return "Battery Simple"
    case .cpuMonitor: return "CPU Monitor"
    case .memoryMonitor: return "Memory Monitor"
    case .systemGlance: return "System Glance"
    case .systemStatus: return "System Status"
    case .systemDashboard: return "System Dashboard"
    }
  }
}

// MARK: - Custom Modular Widget (User Configurable)

private struct CustomModularWidget: View {
  @EnvironmentObject private var viewModel: BatteryViewModel
  @EnvironmentObject private var weatherSettings: WeatherSettingsStore
  @EnvironmentObject private var weatherStore: WeatherStore
  @EnvironmentObject private var weatherAnimationBudget: WeatherAnimationBudget
  @EnvironmentObject private var wifi: WiFiStore
  @EnvironmentObject private var audio: AudioDevicesStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @StateObject private var systemService = SystemMonitoringService.shared
  @StateObject private var network = NetworkStore()

  @State private var primary: WidgetModule = WidgetModule.defaultSelection.first ?? .battery
  @State private var lastSwitchAt = Date.distantPast

  var body: some View {
    let modules = viewModel.widgetCustomModules
    let primaryModule = resolvedPrimary(in: modules)
    let secondary = modules.filter { $0 != primaryModule }

    VStack(spacing: 4) {
      WidgetPrimaryTile(module: primaryModule)
        .environmentObject(network)
        .transition(tileTransition)
        .id(primaryModule)

      WidgetSecondaryGrid(modules: Array(secondary.prefix(4)))
        .environmentObject(network)
        .animation(
          reduceMotion ? nil : MicroverseDesign.Animation.standard, value: secondary.map(\.rawValue)
        )
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .frame(width: 240, height: 120)
    .widgetBackground()
    .onAppear {
      network.start()
      wifi.start()
      audio.start()
      // Ensure we have a sensible starting primary.
      if let first = modules.first {
        primary = first
      }
      updatePrimaryIfNeeded(force: true)
    }
    .onDisappear {
      network.stop()
      wifi.stop()
      audio.stop()
    }
    .onChange(of: viewModel.widgetCustomModules) { _ in
      updatePrimaryIfNeeded(force: true)
    }
    .onChange(of: viewModel.widgetCustomAdaptiveEmphasis) { _ in
      updatePrimaryIfNeeded(force: true)
    }
    .onChange(of: viewModel.batteryInfo) { _ in
      updatePrimaryIfNeeded()
    }
    .onChange(of: systemService.lastUpdated) { _ in
      updatePrimaryIfNeeded()
    }
    .onChange(of: weatherStore.lastUpdated) { _ in
      updatePrimaryIfNeeded()
    }
    .onChange(of: network.lastUpdated) { _ in
      updatePrimaryIfNeeded()
    }
  }

  private var tileTransition: AnyTransition {
    guard !reduceMotion else { return .opacity }
    return .asymmetric(
      insertion: .opacity.combined(with: .move(edge: .top)),
      removal: .opacity.combined(with: .move(edge: .bottom))
    )
  }

  private func resolvedPrimary(in modules: [WidgetModule]) -> WidgetModule {
    guard modules.contains(primary) else { return modules.first ?? .battery }
    return primary
  }

  private func updatePrimaryIfNeeded(force: Bool = false) {
    let modules = viewModel.widgetCustomModules
    guard !modules.isEmpty else { return }

    let candidate: WidgetModule
    if viewModel.widgetCustomAdaptiveEmphasis {
      candidate = recommendedPrimary(in: modules)
    } else {
      candidate = modules.first ?? .battery
    }

    guard candidate != primary else { return }

    let now = Date()
    let dwell: TimeInterval = 8
    if !force, now.timeIntervalSince(lastSwitchAt) < dwell {
      return
    }

    if reduceMotion {
      var t = Transaction()
      t.animation = nil
      withTransaction(t) {
        primary = candidate
      }
    } else {
      withAnimation(MicroverseDesign.Animation.notchToggle) {
        primary = candidate
      }
    }
    lastSwitchAt = now
  }

  private func recommendedPrimary(in modules: [WidgetModule]) -> WidgetModule {
    struct Scored {
      let module: WidgetModule
      let score: Double
    }

    let scored = modules.map { module in
      Scored(module: module, score: urgencyScore(for: module))
    }

    guard let best = scored.max(by: { $0.score < $1.score }) else {
      return modules.first ?? .battery
    }
    let fallback = modules.first ?? .battery

    let threshold: Double = 0.55
    if best.score >= threshold {
      return best.module
    }

    return fallback
  }

  private func urgencyScore(for module: WidgetModule) -> Double {
    let battery = viewModel.batteryInfo
    let cpu = systemService.cpuUsage
    let memory = systemService.memoryInfo

    switch module {
    case .systemHealth:
      let batteryScore =
        battery.isPluggedIn ? 0.0 : max(0, min(1, (30 - Double(battery.currentCharge)) / 30))
      let cpuScore = max(0, min(1, cpu / 100))
      let memoryScore = max(0, min(1, memory.usagePercentage / 100))
      let pressureBoost: Double =
        switch memory.pressure {
        case .critical: 0.6
        case .warning: 0.35
        case .normal: 0.0
        }
      return max(batteryScore, cpuScore, memoryScore + pressureBoost)
    case .battery:
      if battery.isPluggedIn { return battery.isCharging ? 0.25 : 0.15 }
      return max(0, min(1, (35 - Double(battery.currentCharge)) / 35))
    case .batteryTime:
      guard !battery.isPluggedIn else { return 0.15 }
      guard let minutes = battery.timeRemaining, minutes > 0 else { return 0.2 }
      return max(0, min(1, (90 - Double(minutes)) / 90))
    case .batteryHealth:
      // Not "urgent" most of the time; elevate only when health is poor.
      let health = max(0, min(1, battery.health))
      return max(0, min(1, (0.9 - health) / 0.4))
    case .cpu:
      return max(0, min(1, cpu / 100))
    case .memory:
      let base = max(0, min(1, memory.usagePercentage / 100))
      let pressureBoost: Double =
        switch memory.pressure {
        case .critical: 0.6
        case .warning: 0.35
        case .normal: 0.0
        }
      return min(1, base + pressureBoost)
    case .network:
      let down = network.downloadBytesPerSecond
      let up = network.uploadBytesPerSecond
      let threshold: Double = 750_000  // ~0.75 MB/s
      let peak: Double = 8_000_000  // ~8 MB/s
      let activity = max(down, up)
      if activity <= threshold { return 0.1 }
      return max(0, min(1, (activity - threshold) / max(1, peak - threshold)))
    case .wifi:
      switch wifi.status {
      case .unavailable:
        return 0.05
      case .poweredOff:
        return 0.35
      case .disconnected:
        return 0.55
      case .connected:
        let percent = Double(wifi.signalPercent ?? 100) / 100.0
        // Low signal becomes increasingly urgent.
        return max(0.1, min(1, (0.55 - percent) / 0.55))
      }
    case .audioOutput:
      if audio.outputMuted == true { return 0.85 }
      if let v = audio.outputVolume {
        // Very low volume can be confusing; keep mild urgency.
        return max(0.1, min(0.4, (0.2 - Double(v)) * 2))
      }
      return 0.12
    case .audioInput:
      // Input device selection is usually not urgent.
      return 0.08
    case .weather:
      guard weatherSettings.weatherEnabled, weatherSettings.selectedLocation != nil else {
        return 0.05
      }
      guard let e = weatherStore.nextEvent else { return 0.15 }
      let now = Date()
      let dt = e.startTime.timeIntervalSince(now)
      if dt <= 0 { return 0.15 }
      let lead: TimeInterval = 30 * 60
      if dt > lead { return 0.2 }
      return max(0.2, min(1, (lead - dt) / lead))
    }
  }

  private struct WidgetPrimaryTile: View {
    @EnvironmentObject private var viewModel: BatteryViewModel
    @EnvironmentObject private var weatherSettings: WeatherSettingsStore
    @EnvironmentObject private var weatherStore: WeatherStore
    @EnvironmentObject private var weatherAnimationBudget: WeatherAnimationBudget
    @EnvironmentObject private var wifi: WiFiStore
    @EnvironmentObject private var audio: AudioDevicesStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var systemService = SystemMonitoringService.shared
    @EnvironmentObject private var network: NetworkStore

    let module: WidgetModule

    var body: some View {
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 8) {
          iconView
            .frame(width: 16, height: 16, alignment: .center)

          Text(module.title.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.white.opacity(0.55))
            .tracking(0.8)
            .lineLimit(1)

          Spacer(minLength: 0)

          if module == .systemHealth {
            Circle()
              .fill(systemHealthColor)
              .frame(width: 7, height: 7)
              .accessibilityHidden(true)
          }
        }

        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(primaryValue)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .layoutPriority(1)

          if let detail = primaryDetail {
            Text(detail)
              .font(.system(size: 10, weight: .medium))
              .foregroundColor(.white.opacity(0.6))
              .lineLimit(1)
              .truncationMode(.tail)
              .minimumScaleFactor(0.8)
          }
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .frame(maxWidth: .infinity)
      .frame(height: 50)
      .background(
        RoundedRectangle(cornerRadius: 14)
          .fill(Color.white.opacity(0.06))
          .overlay(
            RoundedRectangle(cornerRadius: 14)
              .fill(isAirPodsBatteryLow ? MicroverseDesign.Colors.critical.opacity(0.05) : .clear)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 14)
              .stroke(
                isAirPodsBatteryLow
                  ? MicroverseDesign.Colors.critical.opacity(0.35) : Color.white.opacity(0.12),
                lineWidth: 1
              )
          )
      )
    }

    @ViewBuilder
    private var iconView: some View {
      switch module {
      case .weather:
        MicroverseWeatherGlyph(
          bucket: weatherStore.current?.bucket ?? .unknown,
          isDaylight: weatherStore.current?.isDaylight ?? true,
          renderMode: weatherAnimationBudget.renderMode(
            for: .desktopWidget, isVisible: true, reduceMotion: reduceMotion)
        )
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.white.opacity(0.9))
        .symbolRenderingMode(.hierarchical)
      case .audioOutput:
        if let model = audio.defaultOutputAirPodsModel {
          MicroverseAirPodsIcon(
            model: model,
            size: 14,
            weight: .semibold,
            color: iconTint.opacity(0.95),
            renderingMode: .hierarchical,
            isAnimating: true
          )
        } else if audio.isSonyWH1000XMDefaultOutput {
          Image(systemName: "headphones")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(iconTint.opacity(0.95))
            .symbolRenderingMode(.hierarchical)
        } else {
          Image(systemName: module.systemIcon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(iconTint.opacity(0.95))
        }
      default:
        Image(systemName: module.systemIcon)
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(iconTint.opacity(0.95))
      }
    }

    private var iconTint: Color {
      switch module {
      case .battery, .batteryTime:
        if viewModel.batteryInfo.isCharging { return MicroverseDesign.Colors.success }
        if viewModel.batteryInfo.currentCharge <= 20 { return MicroverseDesign.Colors.warning }
        return .white.opacity(0.9)
      case .batteryHealth:
        return .white.opacity(0.9)
      case .cpu:
        return cpuColor
      case .memory:
        return memoryColor
      case .network:
        return MicroverseDesign.Colors.neutral
      case .wifi:
        switch wifi.status {
        case .connected:
          return wifi.signalBars <= 1
            ? MicroverseDesign.Colors.warning : MicroverseDesign.Colors.success
        case .disconnected:
          return MicroverseDesign.Colors.warning
        case .poweredOff, .unavailable:
          return .white.opacity(0.7)
        }
      case .audioOutput:
        if audio.defaultOutputAirPodsModel != nil,
          viewModel.notchAlertAirPodsLowBatteryEnabled,
          let percent = viewModel.airPodsBatteryPercent,
          percent <= viewModel.notchAlertAirPodsLowBatteryThreshold
        {
          return MicroverseDesign.Colors.critical
        }
        return audio.outputMuted == true ? MicroverseDesign.Colors.warning : .white.opacity(0.9)
      case .audioInput:
        return .white.opacity(0.9)
      case .weather:
        return .white
      case .systemHealth:
        return systemHealthColor
      }
    }

    private var isAirPodsBatteryLow: Bool {
      module == .audioOutput
        && audio.defaultOutputAirPodsModel != nil
        && viewModel.notchAlertAirPodsLowBatteryEnabled
        && (viewModel.airPodsBatteryPercent ?? 101)
          <= viewModel.notchAlertAirPodsLowBatteryThreshold
    }

    private var primaryValue: String {
      let battery = viewModel.batteryInfo

      switch module {
      case .battery:
        return "\(battery.currentCharge)%"
      case .batteryTime:
        return shortTimeRemaining(battery)
      case .batteryHealth:
        return "\(Int((battery.health * 100).rounded()))%"
      case .cpu:
        return "\(Int(systemService.cpuUsage))%"
      case .memory:
        return "\(Int(systemService.memoryInfo.usagePercentage))%"
      case .network:
        return "↓ \(network.formattedRate(network.downloadBytesPerSecond))"
      case .wifi:
        switch wifi.status {
        case .connected:
          if let percent = wifi.signalPercent {
            return "\(percent)%"
          }
          return wifi.qualityText
        case .disconnected:
          return "No Wi‑Fi"
        case .poweredOff:
          return "Wi‑Fi Off"
        case .unavailable:
          return "—"
        }
      case .audioOutput:
        if audio.outputMuted == true { return "Muted" }
        if let v = audio.outputVolume { return audio.formattedPercent(v) }
        return "—"
      case .audioInput:
        let id = audio.defaultInputDeviceID
        let name = audio.inputDevices.first(where: { $0.id == id })?.name
        return name ?? "—"
      case .weather:
        guard let c = weatherStore.current?.temperatureC else { return "—" }
        return weatherSettings.weatherUnits.formatTemperature(celsius: c)
      case .systemHealth:
        return systemHealthText
      }
    }

    private var primaryDetail: String? {
      let battery = viewModel.batteryInfo
      let memoryInfo = systemService.memoryInfo

      switch module {
      case .battery:
        if battery.isCharging { return "Charging" }
        if battery.isPluggedIn { return "Plugged in" }
        return shortTimeRemaining(battery)
      case .batteryTime:
        if battery.isCharging { return "To full" }
        if battery.isPluggedIn { return "Plugged in" }
        return "On battery"
      case .batteryHealth:
        if battery.cycleCount > 0 { return "Cycles: \(battery.cycleCount)" }
        return "Capacity: \(battery.maxCapacity)%"
      case .cpu:
        return cpuStatusText
      case .memory:
        let used = String(format: "%.1f", memoryInfo.usedMemory)
        let total = String(format: "%.1f", memoryInfo.totalMemory)
        return "\(memoryPressureText) • \(used)/\(total) GB"
      case .network:
        return "↑ \(network.formattedRate(network.uploadBytesPerSecond))"
      case .wifi:
        var parts: [String] = []
        if let rssi = wifi.rssi { parts.append("RSSI \(rssi)dBm") }
        if let rate = wifi.transmitRateMbps { parts.append(String(format: "Tx %.0f Mbps", rate)) }
        if parts.isEmpty { return nil }
        return parts.joined(separator: " • ")
      case .audioOutput:
        let id = audio.defaultOutputDeviceID
        let name = audio.outputDevices.first(where: { $0.id == id })?.name
        if audio.defaultOutputAirPodsModel != nil,
          let percent = viewModel.airPodsBatteryPercent
        {
          if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(name) • \(percent)%"
          }
          return "\(percent)%"
        }
        return name
      case .audioInput:
        return "Default input"
      case .weather:
        let city = weatherSettings.selectedLocation?.microversePrimaryName() ?? "—"
        if let e = upcomingEvent, let rel = relativeTime(to: e.startTime) {
          return "\(city) • \(e.title) \(rel)"
        }
        return city
      case .systemHealth:
        return systemHealthDetail
      }
    }

    private var cpuColor: Color {
      if systemService.cpuUsage > 80 { return MicroverseDesign.Colors.critical }
      if systemService.cpuUsage > 60 { return MicroverseDesign.Colors.warning }
      return MicroverseDesign.Colors.processor
    }

    private var memoryColor: Color {
      switch systemService.memoryInfo.pressure {
      case .critical:
        return MicroverseDesign.Colors.critical
      case .warning:
        return MicroverseDesign.Colors.warning
      case .normal:
        return MicroverseDesign.Colors.memory
      }
    }

    private var memoryPressureText: String {
      switch systemService.memoryInfo.pressure {
      case .critical:
        return "Critical"
      case .warning:
        return "Warning"
      case .normal:
        return "Normal"
      }
    }

    private var cpuStatusText: String {
      if systemService.cpuUsage > 80 { return "High load" }
      if systemService.cpuUsage > 60 { return "Moderate load" }
      return "Normal"
    }

    private var systemHealthColor: Color {
      let battery = viewModel.batteryInfo
      if systemService.cpuUsage > 80 || systemService.memoryInfo.pressure == .critical
        || (!battery.isPluggedIn && battery.currentCharge < 15)
      {
        return MicroverseDesign.Colors.critical
      }
      if systemService.cpuUsage > 60 || systemService.memoryInfo.pressure == .warning
        || (!battery.isPluggedIn && battery.currentCharge < 25)
      {
        return MicroverseDesign.Colors.warning
      }
      return MicroverseDesign.Colors.success
    }

    private var systemHealthText: String {
      let battery = viewModel.batteryInfo
      if systemService.cpuUsage > 80 || systemService.memoryInfo.pressure == .critical {
        return "High Load"
      }
      if systemService.cpuUsage > 60 || systemService.memoryInfo.pressure == .warning {
        return "Moderate"
      }
      if !battery.isPluggedIn && battery.currentCharge < 20 {
        return "Low Battery"
      }
      return "Optimal"
    }

    private var systemHealthDetail: String {
      let battery = viewModel.batteryInfo
      let mem = memoryPressureText
      return "CPU \(Int(systemService.cpuUsage))% • Mem \(mem) • \(battery.currentCharge)%"
    }

    private var upcomingEvent: WeatherEvent? {
      guard let e = weatherStore.nextEvent else { return nil }
      let now = Date()
      guard e.startTime > now else { return nil }
      guard e.startTime.timeIntervalSince(now) <= 30 * 60 else { return nil }
      return e
    }

    private func relativeTime(to date: Date) -> String? {
      let seconds = date.timeIntervalSince(Date())
      if seconds <= 0 { return nil }
      if seconds < 60 { return "\(Int(seconds))s" }
      let minutes = Int((seconds / 60).rounded(.down))
      if minutes < 60 { return "\(minutes)m" }
      let hours = Int((Double(minutes) / 60).rounded(.down))
      return "\(hours)h"
    }

    private func shortTimeRemaining(_ battery: BatteryInfo) -> String {
      guard let minutes = battery.timeRemaining, minutes > 0 else { return "—" }
      let hours = minutes / 60
      let mins = minutes % 60
      if hours > 0 {
        return "\(hours)h \(mins)m"
      }
      return "\(mins)m"
    }
  }

  private struct WidgetSecondaryGrid: View {
    @EnvironmentObject private var viewModel: BatteryViewModel
    @EnvironmentObject private var weatherSettings: WeatherSettingsStore
    @EnvironmentObject private var weatherStore: WeatherStore
    @EnvironmentObject private var weatherAnimationBudget: WeatherAnimationBudget
    @EnvironmentObject private var wifi: WiFiStore
    @EnvironmentObject private var audio: AudioDevicesStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var systemService = SystemMonitoringService.shared
    @EnvironmentObject private var network: NetworkStore

    let modules: [WidgetModule]

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
      LazyVGrid(columns: columns, spacing: 4) {
        ForEach(modules, id: \.self) { module in
          tile(module)
        }

        if modules.isEmpty {
          EmptyView()
        }
      }
    }

    @ViewBuilder
    private func tile(_ module: WidgetModule) -> some View {
      let isAirPodsLow =
        module == .audioOutput
        && audio.defaultOutputAirPodsModel != nil
        && viewModel.notchAlertAirPodsLowBatteryEnabled
        && (viewModel.airPodsBatteryPercent ?? 101)
          <= viewModel.notchAlertAirPodsLowBatteryThreshold

      HStack(spacing: 8) {
        secondaryIcon(module)
          .frame(width: 12, height: 12)

        Text(secondaryValue(module))
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .foregroundColor(.white.opacity(0.9))
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.75)

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .frame(minHeight: 24)
      .frame(maxWidth: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.white.opacity(0.04))
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .fill(isAirPodsLow ? MicroverseDesign.Colors.critical.opacity(0.05) : .clear)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(
                isAirPodsLow
                  ? MicroverseDesign.Colors.critical.opacity(0.35) : Color.white.opacity(0.10),
                lineWidth: 1
              )
          )
      )
      .help(module.title)
      .accessibilityLabel(module.title)
      .accessibilityValue(secondaryValue(module))
    }

    @ViewBuilder
    private func secondaryIcon(_ module: WidgetModule) -> some View {
      switch module {
      case .weather:
        MicroverseWeatherGlyph(
          bucket: weatherStore.current?.bucket ?? .unknown,
          isDaylight: weatherStore.current?.isDaylight ?? true,
          renderMode: weatherAnimationBudget.renderMode(
            for: .desktopWidget, isVisible: true, reduceMotion: reduceMotion)
        )
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.white.opacity(0.85))
        .symbolRenderingMode(.hierarchical)
      case .audioOutput:
        if let model = audio.defaultOutputAirPodsModel {
          let isLow =
            viewModel.notchAlertAirPodsLowBatteryEnabled
            && (viewModel.airPodsBatteryPercent ?? 101)
              <= viewModel.notchAlertAirPodsLowBatteryThreshold

          MicroverseAirPodsIcon(
            model: model,
            size: 11,
            weight: .semibold,
            color: isLow ? MicroverseDesign.Colors.critical.opacity(0.9) : .white.opacity(0.75),
            renderingMode: .hierarchical,
            isAnimating: true
          )
        } else {
          Image(systemName: module.systemIcon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white.opacity(0.7))
        }
      default:
        Image(systemName: module.systemIcon)
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(.white.opacity(0.7))
      }
    }

    private func secondaryValue(_ module: WidgetModule) -> String {
      let battery = viewModel.batteryInfo
      let memory = systemService.memoryInfo

      switch module {
      case .battery:
        return "\(battery.currentCharge)%"
      case .batteryTime:
        guard let minutes = battery.timeRemaining, minutes > 0 else { return "—" }
        let hours = minutes / 60
        let mins = minutes % 60
        return hours > 0 ? "\(hours)h" : "\(mins)m"
      case .batteryHealth:
        return "\(Int((battery.health * 100).rounded()))%"
      case .cpu:
        return "\(Int(systemService.cpuUsage))%"
      case .memory:
        switch memory.pressure {
        case .critical: return "Critical"
        case .warning: return "Warning"
        case .normal: return "\(Int(memory.usagePercentage))%"
        }
      case .network:
        return "↓ \(network.formattedRate(network.downloadBytesPerSecond))"
      case .wifi:
        if let percent = wifi.signalPercent { return "\(percent)%" }
        switch wifi.status {
        case .poweredOff:
          return "Off"
        case .disconnected:
          return "—"
        case .connected:
          return wifi.qualityText
        case .unavailable:
          return "—"
        }
      case .audioOutput:
        if audio.outputMuted == true { return "Muted" }
        if let v = audio.outputVolume { return audio.formattedPercent(v) }
        return "—"
      case .audioInput:
        let id = audio.defaultInputDeviceID
        let name = audio.inputDevices.first(where: { $0.id == id })?.name
        return name ?? "—"
      case .weather:
        guard let c = weatherStore.current?.temperatureC else { return "—" }
        return weatherSettings.weatherUnits.formatTemperatureShort(celsius: c)
      case .systemHealth:
        if systemService.cpuUsage > 80 || memory.pressure == .critical { return "High" }
        if systemService.cpuUsage > 60 || memory.pressure == .warning { return "Moderate" }
        return "OK"
      }
    }
  }
}

// CPU Monitor - Dedicated CPU tracking
struct CPUMonitorWidget: View {
  @StateObject private var systemService = SystemMonitoringService.shared

  var body: some View {
    VStack(spacing: MicroverseDesign.Layout.space2) {
      // Header
      HStack {
        Image(systemName: "cpu")
          .font(MicroverseDesign.Typography.body)
          .foregroundColor(MicroverseDesign.Colors.processor)

        Text("CPU")
          .font(MicroverseDesign.Typography.caption.weight(.semibold))
          .foregroundColor(.white)

        Spacer()

        Text("\(Int(systemService.cpuUsage))%")
          .font(MicroverseDesign.Typography.title)
          .foregroundColor(cpuColor)
      }

      // Progress Bar
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 3)
            .fill(Color.white.opacity(0.2))
            .frame(height: 6)

          RoundedRectangle(cornerRadius: 3)
            .fill(cpuColor)
            .frame(width: geometry.size.width * (systemService.cpuUsage / 100), height: 6)
            .animation(MicroverseDesign.Animation.standard, value: systemService.cpuUsage)
        }
      }
      .frame(height: 6)

      // Status
      Text(cpuStatusText)
        .font(MicroverseDesign.Typography.label)
        .foregroundColor(.white.opacity(0.8))
    }
    .padding(MicroverseDesign.Layout.space3)
    .frame(width: 160, height: 80)
    .widgetBackground()
  }

  private var cpuColor: Color {
    if systemService.cpuUsage > 80 {
      return MicroverseDesign.Colors.critical
    } else if systemService.cpuUsage > 60 {
      return MicroverseDesign.Colors.warning
    } else {
      return MicroverseDesign.Colors.processor
    }
  }

  private var cpuStatusText: String {
    if systemService.cpuUsage > 80 {
      return "High Usage"
    } else if systemService.cpuUsage > 60 {
      return "Moderate Load"
    } else {
      return "Normal Operation"
    }
  }
}

// Memory Monitor - Dedicated memory tracking
struct MemoryMonitorWidget: View {
  @StateObject private var systemService = SystemMonitoringService.shared

  var body: some View {
    VStack(spacing: MicroverseDesign.Layout.space2) {
      // Header
      HStack {
        Image(systemName: "memorychip")
          .font(MicroverseDesign.Typography.body)
          .foregroundColor(MicroverseDesign.Colors.memory)

        Text("MEMORY")
          .font(MicroverseDesign.Typography.caption.weight(.semibold))
          .foregroundColor(.white)

        Spacer()

        Text("\(Int(systemService.memoryInfo.usagePercentage))%")
          .font(MicroverseDesign.Typography.title)
          .foregroundColor(memoryColor)
      }

      // Progress Bar
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 3)
            .fill(Color.white.opacity(0.2))
            .frame(height: 6)

          RoundedRectangle(cornerRadius: 3)
            .fill(memoryColor)
            .frame(
              width: geometry.size.width * (systemService.memoryInfo.usagePercentage / 100),
              height: 6
            )
            .animation(
              MicroverseDesign.Animation.standard, value: systemService.memoryInfo.usagePercentage)
        }
      }
      .frame(height: 6)

      // Usage details
      Text(
        "\(String(format: "%.1f", systemService.memoryInfo.usedMemory)) / \(String(format: "%.1f", systemService.memoryInfo.totalMemory)) GB"
      )
      .font(MicroverseDesign.Typography.label)
      .foregroundColor(.white.opacity(0.8))
    }
    .padding(MicroverseDesign.Layout.space3)
    .frame(width: 160, height: 80)
    .widgetBackground()
  }

  private var memoryColor: Color {
    switch systemService.memoryInfo.pressure {
    case .critical: return MicroverseDesign.Colors.critical
    case .warning: return MicroverseDesign.Colors.warning
    case .normal: return MicroverseDesign.Colors.memory
    }
  }
}

// System Dashboard - Full detailed view
struct SystemDashboardWidget: View {
  let batteryInfo: BatteryInfo
  @StateObject private var systemService = SystemMonitoringService.shared

  var body: some View {
    VStack(spacing: 4) {
      // Compact header
      HStack {
        HStack(spacing: 4) {
          if batteryInfo.isCharging {
            Image(systemName: "bolt.fill")
              .font(.system(size: 14, weight: .medium))
              .foregroundColor(MicroverseDesign.Colors.success)
          }
          Text("\(batteryInfo.currentCharge)%")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(.white)
        }

        Spacer()

        HStack(spacing: 4) {
          Circle()
            .fill(systemHealthColor)
            .frame(width: 6, height: 6)
          Text(systemHealthText)
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.8))
        }
      }
      .padding(.top, 2)

      Divider()
        .background(MicroverseDesign.Colors.divider)

      // Three metrics
      HStack(spacing: 0) {
        // CPU
        VStack(spacing: 1) {
          Image(systemName: "cpu")
            .font(.system(size: 12))
            .foregroundColor(cpuColor)
          Text("\(Int(systemService.cpuUsage))%")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(.white)
          Text("CPU")
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(.white.opacity(0.6))
            .tracking(0.5)
        }
        .frame(maxWidth: .infinity)

        // Memory
        VStack(spacing: 1) {
          Image(systemName: "memorychip")
            .font(.system(size: 12))
            .foregroundColor(memoryColor)
          Text("\(Int(systemService.memoryInfo.usagePercentage))%")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(.white)
          Text("MEMORY")
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(.white.opacity(0.6))
            .tracking(0.5)
        }
        .frame(maxWidth: .infinity)

        // Health
        VStack(spacing: 1) {
          Image(systemName: "heart.fill")
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.9))
          Text("\(Int(batteryInfo.health * 100))%")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(.white)
          Text("HEALTH")
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(.white.opacity(0.6))
            .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
      }
      .padding(.vertical, 2)

      Divider()
        .background(MicroverseDesign.Colors.divider)

      // Bottom info
      HStack {
        Text("Cycles: \(batteryInfo.cycleCount)")
          .font(.system(size: 10))
          .foregroundColor(.white.opacity(0.7))

        Spacer()

        if let timeString = batteryInfo.timeRemainingFormatted {
          Text(timeString)
            .font(.system(size: 10))
            .foregroundColor(.white.opacity(0.7))
        }
      }
      .padding(.bottom, 2)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .frame(width: 240, height: 120)
    .widgetBackground()
  }

  private var systemHealthColor: Color {
    if systemService.cpuUsage > 80 || systemService.memoryInfo.pressure == .critical
      || batteryInfo.currentCharge < 15
    {
      return MicroverseDesign.Colors.critical
    } else if systemService.cpuUsage > 60 || systemService.memoryInfo.pressure == .warning
      || batteryInfo.currentCharge < 25
    {
      return MicroverseDesign.Colors.warning
    } else {
      return MicroverseDesign.Colors.success
    }
  }

  private var systemHealthText: String {
    if systemService.cpuUsage > 80 || systemService.memoryInfo.pressure == .critical {
      return "High Load"
    } else if systemService.cpuUsage > 60 || systemService.memoryInfo.pressure == .warning {
      return "Moderate"
    } else {
      return "Optimal"
    }
  }

  private var cpuColor: Color {
    if systemService.cpuUsage > 80 {
      return MicroverseDesign.Colors.critical
    } else if systemService.cpuUsage > 60 {
      return MicroverseDesign.Colors.warning
    } else {
      return MicroverseDesign.Colors.processor
    }
  }

  private var memoryColor: Color {
    switch systemService.memoryInfo.pressure {
    case .critical: return MicroverseDesign.Colors.critical
    case .warning: return MicroverseDesign.Colors.warning
    case .normal: return MicroverseDesign.Colors.memory
    }
  }
}
