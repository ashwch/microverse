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
@MainActor
class DesktopWidgetManager: ObservableObject {
  private var window: DesktopWidgetWindow?
  private var hostingView: NSHostingView<AnyView>?
  private weak var viewModel: BatteryViewModel?
  private weak var weatherSettings: WeatherSettingsStore?
  private weak var weatherStore: WeatherStore?
  private weak var displayOrchestrator: DisplayOrchestrator?
  private weak var weatherAnimationBudget: WeatherAnimationBudget?
  private var screenChangeObserver: NSObjectProtocol?

  #if DEBUG
  /// DEBUG-only window access used by the screenshot exporter.
  var debugWindow: NSWindow? { window }
  #endif

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

  func showWidget() {
    guard window == nil, let viewModel else { return }

    // Every widget style reads these stores through @EnvironmentObject, so rendering without them
    // is a fatal error. The clamshell auto-show rule can fire from the view model's init, before the
    // app delegate has wired weather; `BatteryViewModel.setWeatherEnvironment` re-shows the widget
    // once the stores exist, so bailing out here loses nothing.
    guard let weatherSettings, let weatherStore, let displayOrchestrator, let weatherAnimationBudget
    else { return }

    let size = getWidgetSize(for: viewModel.widgetStyle)
    // The window is larger than the widget by a transparent margin so the alert glow has room
    // to spill outside the card, exactly as it does around the notch pill.
    let windowSize = NSSize(
      width: size.width + DesktopWidgetGlow.margin * 2,
      height: size.height + DesktopWidgetGlow.margin * 2)
    let widgetView = AnyView(
      DesktopWidgetView()
        .environmentObject(viewModel)
        .environmentObject(viewModel.wifiStore)
        .environmentObject(viewModel.audioDevicesStore)
        .environmentObject(weatherSettings)
        .environmentObject(weatherStore)
        .environmentObject(displayOrchestrator)
        .environmentObject(weatherAnimationBudget)
        .frame(width: size.width, height: size.height)
        .overlay(DesktopWidgetGlow.Decoration(contentSize: size))
        .padding(DesktopWidgetGlow.margin)
    )

    // The hosting view must match the window size exactly or the content gets clipped.
    hostingView = NSHostingView(rootView: widgetView)
    hostingView?.frame = NSRect(origin: .zero, size: windowSize)

    let window = DesktopWidgetWindow(size: windowSize)
    window.contentView = hostingView
    window.onDragEnded = { frame in DesktopWidgetPlacement.save(frame) }
    window.setFrameOrigin(DesktopWidgetPlacement.origin(for: size))
    window.makeKeyAndOrderFront(nil)
    self.window = window

    observeScreenChanges()
  }

  func hideWidget() {
    if let screenChangeObserver {
      NotificationCenter.default.removeObserver(screenChangeObserver)
      self.screenChangeObserver = nil
    }
    window?.close()
    window = nil
    hostingView = nil
  }

  /// Closing the lid or unplugging a monitor can leave the widget in space no display covers anymore.
  /// When that happens, fall back to the default corner; otherwise leave it where the user put it.
  private func observeScreenChanges() {
    guard screenChangeObserver == nil else { return }
    screenChangeObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        guard let window = self?.window, !DesktopWidgetPlacement.isOnScreen(window.frame) else { return }
        window.setFrameOrigin(DesktopWidgetPlacement.origin(for: window.frame.size))
      }
    }
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
}

/// Where the desktop widget goes on screen: the user's last dragged position when it is still visible,
/// otherwise the top-right corner of the main display.
enum DesktopWidgetPlacement {
  private static let defaultsKey = "desktopWidgetOrigin"
  private static let cornerInset: CGFloat = 20

  /// Remembers the widget's top-left corner. Anchoring on the top edge (rather than AppKit's
  /// bottom-left origin) keeps the widget in place when the user switches to a style with a
  /// different height.
  static func save(_ frame: NSRect) {
    UserDefaults.standard.set(["x": frame.minX, "top": frame.maxY], forKey: defaultsKey)
  }

  static func origin(for size: NSSize) -> NSPoint {
    if let saved = savedOrigin(for: size), isOnScreen(NSRect(origin: saved, size: size)) {
      return saved
    }
    return defaultOrigin(for: size)
  }

  /// True when at least half the frame lies on a connected display's usable area.
  static func isOnScreen(_ frame: NSRect) -> Bool {
    let minVisibleArea = frame.width * frame.height / 2
    return NSScreen.screens.contains { screen in
      let visible = screen.visibleFrame.intersection(frame)
      return visible.width * visible.height >= minVisibleArea
    }
  }

  private static func savedOrigin(for size: NSSize) -> NSPoint? {
    guard let saved = UserDefaults.standard.dictionary(forKey: defaultsKey),
      let x = saved["x"] as? CGFloat, let top = saved["top"] as? CGFloat
    else { return nil }
    return NSPoint(x: x, y: top - size.height)
  }

  private static func defaultOrigin(for size: NSSize) -> NSPoint {
    guard let screen = NSScreen.main ?? NSScreen.screens.first else { return .zero }
    let area = screen.visibleFrame
    return NSPoint(x: area.maxX - size.width - cornerInset, y: area.maxY - size.height - cornerInset)
  }
}

/// Alert glow around the desktop widget card, driven by the same triggers as the notch glow.
enum DesktopWidgetGlow {
  /// Transparent room around the card for blur and sparkles.
  static let margin: CGFloat = 28
  /// Matches `widgetBackground()`.
  static let cornerRadius: CGFloat = 16

  struct Decoration: View {
    let contentSize: NSSize
    @ObservedObject private var controller = NotchGlowInNotchController.shared

    var body: some View {
      if let trigger = controller.current {
        NotchGlowView(
          alertType: trigger.type,
          pillWidth: contentSize.width,
          pillHeight: contentSize.height,
          topCornerRadius: DesktopWidgetGlow.cornerRadius,
          bottomCornerRadius: DesktopWidgetGlow.cornerRadius,
          glowPadding: DesktopWidgetGlow.margin,
          rotations: trigger.pulseCount,
          motion: trigger.motion,
          animationDuration: trigger.duration,
          outline: .roundedRectangle
        )
        .id(trigger.id)
        // Make room for blur and sparkles, then align the padded container back onto the card.
        .frame(
          width: contentSize.width + DesktopWidgetGlow.margin * 2,
          height: contentSize.height + DesktopWidgetGlow.margin * 2)
        .allowsHitTesting(false)
      }
    }
  }
}

// Custom window for widget
class DesktopWidgetWindow: NSWindow {
  /// Called with the window's frame once the user finishes dragging it.
  var onDragEnded: ((NSRect) -> Void)?

  private var dragMonitor: Any?
  /// Cursor position relative to the window origin while a drag is in progress; nil otherwise.
  private var dragOffset: NSPoint?

  init(size: NSSize = NSSize(width: 180, height: 100)) {
    super.init(
      contentRect: NSRect(origin: .zero, size: size),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    level = .floating
    collectionBehavior = [.canJoinAllSpaces, .stationary]
    backgroundColor = .clear
    isOpaque = false
    hasShadow = true
    titleVisibility = .hidden
    titlebarAppearsTransparent = true

    // Dragging is done by hand below. On macOS 26+ a window whose content is an NSHostingView
    // never completes AppKit's background-move session, and SwiftUI swallows mouse events before
    // they reach the responder chain, so `mouseDown`/`mouseDragged` overrides never fire either.
    // A local event monitor runs ahead of that interception and sees the whole drag.
    isMovableByWindowBackground = false

    // Disable release when closed to prevent crashes
    isReleasedWhenClosed = false

    // Disable animations
    animationBehavior = .none

    dragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) {
      [weak self] event in
      self?.handleDrag(event)
      return event
    }
  }

  private func handleDrag(_ event: NSEvent) {
    guard event.window === self else { return }
    let mouse = NSEvent.mouseLocation

    switch event.type {
    case .leftMouseDown:
      dragOffset = NSPoint(x: mouse.x - frame.minX, y: mouse.y - frame.minY)
    case .leftMouseDragged:
      guard let dragOffset else { return }
      setFrameOrigin(NSPoint(x: mouse.x - dragOffset.x, y: mouse.y - dragOffset.y))
    case .leftMouseUp:
      guard dragOffset != nil else { return }
      dragOffset = nil
      onDragEnded?(frame)
    default:
      break
    }
  }

  override func close() {
    if let dragMonitor {
      NSEvent.removeMonitor(dragMonitor)
      self.dragMonitor = nil
    }
    super.close()
  }
}

// Widget view
struct DesktopWidgetView: View {
  @EnvironmentObject var viewModel: BatteryViewModel

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
    .systemMonitoringActive(requiresSystemMonitoring)
  }

  private var requiresSystemMonitoring: Bool {
    switch viewModel.widgetStyle {
    case .custom:
      let modules = Set(viewModel.widgetCustomModules)
      return modules.contains(.cpu) || modules.contains(.memory) || modules.contains(.systemHealth)
        || modules.contains(.disk)
    case .batterySimple:
      return false
    case .cpuMonitor, .memoryMonitor, .systemGlance, .systemStatus, .systemDashboard:
      return true
    }
  }
}

// MARK: - Single Metric Widgets

// Battery Simple - Just battery percentage
struct BatterySimpleWidget: View {
  let batteryInfo: BatteryInfo
  @EnvironmentObject private var viewModel: BatteryViewModel

  var body: some View {
    HStack(spacing: MicroverseDesign.Layout.space1) {
      Image(systemName: viewModel.status.batteryIconName)
        .font(.system(size: 12, weight: .bold))
        .foregroundColor(viewModel.status.color(for: .battery))

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
  @EnvironmentObject private var viewModel: BatteryViewModel
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
        Image(
          systemName: WidgetModuleStatusResolver.batteryIconName(
            charge: batteryInfo.currentCharge, isCharging: batteryInfo.isCharging)
        )
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(viewModel.status.color(for: .battery))
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
          .foregroundColor(WidgetModuleStatusResolver.memoryStatus(systemService.memoryInfo).color)
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
        .foregroundColor(WidgetModuleStatusResolver.cpuStatus(usage: systemService.cpuUsage).color)

      Text("\(Int(systemService.cpuUsage))")
        .font(.system(size: 15, weight: .bold, design: .rounded))
        .foregroundColor(.white)

      Text("%")
        .font(.system(size: 6, weight: .semibold))
        .foregroundColor(.white.opacity(0.5))
    }
  }

  /// Same peek cycle as the notch, stacked to fit the column.
  private var weatherColumn: some View {
    WeatherPeekView(
      slides: weatherStore.peekSlides(),
      units: weatherSettings.weatherUnits,
      isDaylight: weatherStore.current?.isDaylight ?? true,
      renderMode: weatherAnimationBudget.renderMode(
        for: .desktopWidget, isVisible: shouldShowWeatherInWidget, reduceMotion: reduceMotion),
      layout: .column
    )
  }

}

// System Status - Medium view with all metrics
struct SystemStatusWidget: View {
  let batteryInfo: BatteryInfo
  @EnvironmentObject private var viewModel: BatteryViewModel
  @StateObject private var systemService = SystemMonitoringService.shared

  var body: some View {
    // Four columns in 240pt: tight spacing, and values may shrink a little rather than truncate.
    HStack(spacing: MicroverseDesign.Layout.space2) {
      // Battery Column
      VStack(spacing: MicroverseDesign.Layout.space1) {
        Image(
          systemName: WidgetModuleStatusResolver.batteryIconName(
            charge: batteryInfo.currentCharge, isCharging: batteryInfo.isCharging)
        )
        .font(MicroverseDesign.Typography.body)
        .foregroundColor(batteryColor)
        Text("\(batteryInfo.currentCharge)%")
          .font(MicroverseDesign.Typography.title)
          .foregroundColor(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Text("BATTERY")
          .font(MicroverseDesign.Typography.label)
          .foregroundColor(.white.opacity(0.7))
          .tracking(0.6)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .frame(maxWidth: .infinity)

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
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Text("CPU")
          .font(MicroverseDesign.Typography.label)
          .foregroundColor(.white.opacity(0.7))
          .tracking(0.6)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .frame(maxWidth: .infinity)

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
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Text("MEMORY")
          .font(MicroverseDesign.Typography.label)
          .foregroundColor(.white.opacity(0.7))
          .tracking(0.6)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .frame(maxWidth: .infinity)

      Divider()
        .frame(width: 1)
        .background(MicroverseDesign.Colors.divider)

      // Disk Column
      VStack(spacing: MicroverseDesign.Layout.space1) {
        Image(systemName: "internaldrive")
          .font(MicroverseDesign.Typography.body)
          .foregroundColor(diskColor)
        Text("\(Int(systemService.diskInfo.usagePercentage))%")
          .font(MicroverseDesign.Typography.title)
          .foregroundColor(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Text("DISK")
          .font(MicroverseDesign.Typography.label)
          .foregroundColor(.white.opacity(0.7))
          .tracking(0.6)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .frame(maxWidth: .infinity)
    }
    .padding(.horizontal, MicroverseDesign.Layout.space2)
    .padding(.vertical, MicroverseDesign.Layout.space3)
    .frame(width: 240, height: 80)
    .widgetBackground()
  }

  private var batteryColor: Color { viewModel.status.color(for: .battery) }
  private var cpuColor: Color { WidgetModuleStatusResolver.cpuStatus(usage: systemService.cpuUsage).color }
  private var memoryColor: Color { WidgetModuleStatusResolver.memoryStatus(systemService.memoryInfo).color }
  private var diskColor: Color { WidgetModuleStatusResolver.diskStatus(systemService.diskInfo).color }
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
  @State private var dwellRetryTask: Task<Void, Never>?
  @State private var isNetworkMonitoring = false
  @State private var isWiFiMonitoring = false
  @State private var isAudioMonitoring = false

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
      reconcileModuleStores(using: modules)
      // Ensure we have a sensible starting primary.
      if let first = modules.first {
        primary = first
      }
      updatePrimaryIfNeeded(force: true)
    }
    .onDisappear {
      stopModuleStores()
      dwellRetryTask?.cancel()
      dwellRetryTask = nil
    }
    .onChange(of: viewModel.widgetCustomModules) { _ in
      reconcileModuleStores(using: viewModel.widgetCustomModules)
      updatePrimaryIfNeeded(force: true)
    }
    .onChange(of: viewModel.widgetCustomAdaptiveEmphasis) { _ in
      updatePrimaryIfNeeded(force: true)
    }
    .onChange(of: viewModel.batteryInfo) { _ in
      updatePrimaryIfNeeded()
    }
    .onChange(of: systemService.sampleID) { _ in
      updatePrimaryIfNeeded()
    }
    .onChange(of: weatherStore.lastUpdated) { _ in
      updatePrimaryIfNeeded()
    }
    .onChange(of: network.lastUpdated) { _ in
      updatePrimaryIfNeeded()
    }
  }

  private func reconcileModuleStores(using modules: [WidgetModule]) {
    let needsAudio = modules.contains(.audioOutput) || modules.contains(.audioInput)
    let needsWiFi = modules.contains(.wifi)
    let needsNetwork = modules.contains(.network) || needsWiFi

    if needsNetwork, !isNetworkMonitoring {
      network.start()
      isNetworkMonitoring = true
    } else if !needsNetwork, isNetworkMonitoring {
      network.stop()
      isNetworkMonitoring = false
    }

    if needsWiFi, !isWiFiMonitoring {
      wifi.start()
      isWiFiMonitoring = true
    } else if !needsWiFi, isWiFiMonitoring {
      wifi.stop()
      isWiFiMonitoring = false
    }

    if needsAudio, !isAudioMonitoring {
      audio.start()
      isAudioMonitoring = true
    } else if !needsAudio, isAudioMonitoring {
      audio.stop()
      isAudioMonitoring = false
    }
  }

  private func stopModuleStores() {
    if isNetworkMonitoring {
      network.stop()
      isNetworkMonitoring = false
    }
    if isWiFiMonitoring {
      wifi.stop()
      isWiFiMonitoring = false
    }
    if isAudioMonitoring {
      audio.stop()
      isAudioMonitoring = false
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

    guard candidate != primary else {
      dwellRetryTask?.cancel()
      dwellRetryTask = nil
      return
    }

    let now = Date()
    let dwell: TimeInterval = 8
    let timeSinceSwitch = now.timeIntervalSince(lastSwitchAt)
    if !force, timeSinceSwitch < dwell {
      // Dwell-blocked: schedule a one-shot retry after the remaining dwell
      // window. Without this, if sampleID stops changing (metrics stabilize),
      // the deferred switch would never be retried.
      schedulePrimaryDwellRetry(remaining: dwell - timeSinceSwitch)
      return
    }
    dwellRetryTask?.cancel()
    dwellRetryTask = nil

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

  /// Schedule a one-shot retry of `updatePrimaryIfNeeded` after the dwell
  /// window expires. This ensures deferred switches are picked up even when
  /// sampleID stops changing (metrics stabilize at quantized values).
  private func schedulePrimaryDwellRetry(remaining: TimeInterval) {
    dwellRetryTask?.cancel()
    dwellRetryTask = Task { @MainActor in
      do {
        try await Task.sleep(for: .seconds(max(0.1, remaining) + 0.05))
      } catch { return }
      guard !Task.isCancelled else { return }
      updatePrimaryIfNeeded()
    }
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
    case .disk:
      // Only urgent once the volume is nearly full.
      return max(0, min(1, (systemService.diskInfo.usagePercentage - 80) / 15))
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

    /// Shared good/poor/critical resolution so this tile and the secondary grid agree.
    private var resolver: WidgetModuleStatusResolver {
      WidgetModuleStatusResolver(
        viewModel: viewModel, systemService: systemService,
        weatherSettings: weatherSettings, weatherStore: weatherStore)
    }

    private var status: WidgetModuleStatus { resolver.status(for: module) }

    var body: some View {
      let status = status

      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 8) {
          iconView
            .frame(width: 16, height: 16, alignment: .center)

          Text(primaryTitle.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.white.opacity(0.55))
            .tracking(0.8)
            .lineLimit(1)

          Spacer(minLength: 0)

          // Status dot on every module, not just System Health.
          Circle()
            .fill(status.color)
            .frame(width: 7, height: 7)
            .accessibilityHidden(true)
        }

        if module == .weather {
          // Same cycling peek as the notch: conditions, upcoming changes, tomorrow in the evening.
          WeatherPeekView(
            slides: weatherStore.peekSlides(),
            units: weatherSettings.weatherUnits,
            isDaylight: weatherStore.current?.isDaylight ?? true,
            renderMode: weatherAnimationBudget.renderMode(
              for: .desktopWidget, isVisible: true, reduceMotion: reduceMotion),
            compact: false
          )
          .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(primaryValue)
              .font(.system(size: 18, weight: .bold, design: .rounded))
              .foregroundColor(status.tintsValue ? status.color : .white)
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
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .frame(maxWidth: .infinity)
      .frame(height: 50)
      .background(
        // Critical states (battery, AirPods, storm, no signal) also tint the card itself.
        RoundedRectangle(cornerRadius: 14)
          .fill(Color.white.opacity(0.06))
          .overlay(
            RoundedRectangle(cornerRadius: 14)
              .fill(status == .critical ? MicroverseDesign.Colors.critical.opacity(0.05) : .clear)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 14)
              .stroke(
                status == .critical
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
        .foregroundColor(weatherGlyphColor(size: 0.9))
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
      case .battery:
        Image(systemName: resolver.batteryIconName)
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(iconTint.opacity(0.95))
      default:
        Image(systemName: module.systemIcon)
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(iconTint.opacity(0.95))
      }
    }

    /// Icons carry the status colour; only "fair" falls back to plain white.
    private var iconTint: Color { status.color }

    /// The weather glyph is already a picture of the conditions, so it only takes a status colour
    /// when there is something to flag (rain, storm, disabled).
    private func weatherGlyphColor(size opacity: Double) -> Color {
      switch status {
      case .good, .fair: return .white.opacity(opacity)
      default: return status.color
      }
    }

    /// The weather card is titled by its city; every other module keeps its name.
    private var primaryTitle: String {
      guard module == .weather,
        let city = weatherSettings.selectedLocation?.microversePrimaryName(), !city.isEmpty
      else { return module.title }
      return city
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
      case .disk:
        return String(format: "%.0f GB", systemService.diskInfo.availableGB)
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
        if let snr = wifi.snr { parts.append("SNR \(snr)dB") }
        if let rate = wifi.transmitRateMbps { parts.append(String(format: "Tx %.0f Mbps", rate)) }
        if case .connected = wifi.status {
          let down = network.wifiDownloadBytesPerSecond
          let up = network.wifiUploadBytesPerSecond
          let minToShow: Double = 1_024  // 1 KB/s
          if down >= minToShow { parts.append("↓ \(network.formattedRate(down))") }
          if up >= minToShow { parts.append("↑ \(network.formattedRate(up))") }
        }
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
      case .disk:
        let disk = systemService.diskInfo
        return String(format: "free of %.0f GB • %d%% used", disk.totalGB, Int(disk.usagePercentage))
      case .systemHealth:
        return systemHealthDetail
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

    private var systemHealthText: String { resolver.systemHealthHeadline }

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

    private var resolver: WidgetModuleStatusResolver {
      WidgetModuleStatusResolver(
        viewModel: viewModel, systemService: systemService,
        weatherSettings: weatherSettings, weatherStore: weatherStore)
    }

    @ViewBuilder
    private func tile(_ module: WidgetModule) -> some View {
      let status = resolver.status(for: module)
      let isCritical = status == .critical

      HStack(spacing: 8) {
        if module == .weather {
          // The small tile cycles the same peek as the notch pill.
          WeatherPeekView(
            slides: weatherStore.peekSlides(),
            units: weatherSettings.weatherUnits,
            isDaylight: weatherStore.current?.isDaylight ?? true,
            renderMode: weatherAnimationBudget.renderMode(
              for: .desktopWidget, isVisible: true, reduceMotion: reduceMotion),
            layout: .narrowRow
          )
        } else {
          secondaryIcon(module, status: status)
            .frame(width: 12, height: 12)

          Text(secondaryValue(module))
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(status.tintsValue ? status.color : .white.opacity(0.9))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }

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
              .fill(isCritical ? MicroverseDesign.Colors.critical.opacity(0.05) : .clear)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(
                isCritical
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
    private func secondaryIcon(_ module: WidgetModule, status: WidgetModuleStatus) -> some View {
      let tint = status.color.opacity(0.9)

      switch module {
      case .weather:
        // The glyph already depicts the conditions; colour it only when there is something to flag.
        let glyphColor: Color = (status == .good || status == .fair) ? .white.opacity(0.85) : tint
        MicroverseWeatherGlyph(
          bucket: weatherStore.current?.bucket ?? .unknown,
          isDaylight: weatherStore.current?.isDaylight ?? true,
          renderMode: weatherAnimationBudget.renderMode(
            for: .desktopWidget, isVisible: true, reduceMotion: reduceMotion)
        )
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(glyphColor)
        .symbolRenderingMode(.hierarchical)
      case .audioOutput:
        if let model = audio.defaultOutputAirPodsModel {
          MicroverseAirPodsIcon(
            model: model,
            size: 11,
            weight: .semibold,
            color: tint,
            renderingMode: .hierarchical,
            isAnimating: true
          )
        } else {
          Image(systemName: module.systemIcon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(tint)
        }
      case .battery:
        Image(systemName: resolver.batteryIconName)
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(tint)
      default:
        Image(systemName: module.systemIcon)
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(tint)
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
      case .disk:
        return String(format: "%.0f GB", systemService.diskInfo.availableGB)
      case .systemHealth:
        return resolver.systemHealthShortLabel
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
          .foregroundColor(cpuColor)

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

  private var cpuColor: Color { WidgetModuleStatusResolver.cpuStatus(usage: systemService.cpuUsage).color }

  private var cpuStatusText: String {
    switch WidgetModuleStatusResolver.cpuStatus(usage: systemService.cpuUsage) {
    case .critical: return "High Usage"
    case .poor: return "Moderate Load"
    case .fair: return "Busy"
    default: return "Normal Operation"
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
          .foregroundColor(memoryColor)

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

  private var memoryColor: Color { WidgetModuleStatusResolver.memoryStatus(systemService.memoryInfo).color }
}

// System Dashboard - Full detailed view
struct SystemDashboardWidget: View {
  let batteryInfo: BatteryInfo
  @EnvironmentObject private var viewModel: BatteryViewModel
  @StateObject private var systemService = SystemMonitoringService.shared

  private var resolver: WidgetModuleStatusResolver {
    WidgetModuleStatusResolver(viewModel: viewModel, systemService: systemService)
  }

  var body: some View {
    VStack(spacing: 4) {
      // Compact header
      HStack {
        HStack(spacing: 4) {
          Image(systemName: resolver.batteryIconName)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(resolver.color(for: .battery))
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

        // Disk
        VStack(spacing: 1) {
          Image(systemName: "internaldrive")
            .font(.system(size: 12))
            .foregroundColor(resolver.color(for: .disk))
          Text("\(Int(systemService.diskInfo.usagePercentage))%")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(.white)
          Text("DISK")
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(.white.opacity(0.6))
            .tracking(0.5)
        }
        .frame(maxWidth: .infinity)

        // Health
        VStack(spacing: 1) {
          Image(systemName: "heart.fill")
            .font(.system(size: 12))
            .foregroundColor(resolver.color(for: .batteryHealth))
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

  private var systemHealthColor: Color { resolver.color(for: .systemHealth) }
  private var systemHealthText: String { resolver.systemHealthHeadline }
  private var cpuColor: Color { WidgetModuleStatusResolver.cpuStatus(usage: systemService.cpuUsage).color }
  private var memoryColor: Color { WidgetModuleStatusResolver.memoryStatus(systemService.memoryInfo).color }
}
