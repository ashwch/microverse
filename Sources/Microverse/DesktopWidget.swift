import SwiftUI
import AppKit
import BatteryCore
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
    // Single metric widgets
    case batterySimple = "Battery Simple"      // 100×40: Just battery %
    case cpuMonitor = "CPU Monitor"            // 160×80: CPU usage + graph
    case memoryMonitor = "Memory Monitor"      // 160×80: Memory usage + pressure
    
    // Multi-metric widgets
    case systemGlance = "System Glance"        // 160×50: Battery + CPU + Memory %
    case systemStatus = "System Status"        // 240×80: All metrics with basic info
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
              let screen = NSScreen.main else { return }
        
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
    
    var body: some View {
        Group {
            switch viewModel.widgetStyle {
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
                Text("...") // Visual separator
                    .font(.system(size: 6))
                    .foregroundColor(.white.opacity(0.3))
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
                Text("%") // Percent indicator
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
            && weatherSettings.weatherLocation != nil
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

            Text("...") // Visual separator
                .font(.system(size: 6))
                .foregroundColor(.white.opacity(0.3))
        }
    }

    private var weatherColumn: some View {
        VStack(spacing: 1) {
            MicroverseWeatherGlyph(
                bucket: weatherStore.current?.bucket ?? .unknown,
                isDaylight: weatherStore.current?.isDaylight ?? true,
                renderMode: weatherAnimationBudget.renderMode(for: .desktopWidget, isVisible: shouldShowWeatherInWidget, reduceMotion: reduceMotion)
            )
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white.opacity(0.9))
            .symbolRenderingMode(.hierarchical)
            .frame(width: 16, height: 16)

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
        if batteryInfo.currentCharge <= 20 { return MicroverseDesign.Colors.warning }
        else if batteryInfo.isCharging { return MicroverseDesign.Colors.success }
        else { return .white }
    }
    
    private var cpuColor: Color {
        if systemService.cpuUsage > 80 { return MicroverseDesign.Colors.critical }
        else if systemService.cpuUsage > 60 { return MicroverseDesign.Colors.warning }
        else { return MicroverseDesign.Colors.processor }
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
        case .batterySimple: return "Battery Simple"
        case .cpuMonitor: return "CPU Monitor"
        case .memoryMonitor: return "Memory Monitor"
        case .systemGlance: return "System Glance"
        case .systemStatus: return "System Status"
        case .systemDashboard: return "System Dashboard"
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
        if systemService.cpuUsage > 80 { return MicroverseDesign.Colors.critical }
        else if systemService.cpuUsage > 60 { return MicroverseDesign.Colors.warning }
        else { return MicroverseDesign.Colors.processor }
    }
    
    private var cpuStatusText: String {
        if systemService.cpuUsage > 80 { return "High Usage" }
        else if systemService.cpuUsage > 60 { return "Moderate Load" }
        else { return "Normal Operation" }
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
                        .frame(width: geometry.size.width * (systemService.memoryInfo.usagePercentage / 100), height: 6)
                        .animation(MicroverseDesign.Animation.standard, value: systemService.memoryInfo.usagePercentage)
                }
            }
            .frame(height: 6)
            
            // Usage details
            Text("\(String(format: "%.1f", systemService.memoryInfo.usedMemory)) / \(String(format: "%.1f", systemService.memoryInfo.totalMemory)) GB")
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
        if systemService.cpuUsage > 80 || systemService.memoryInfo.pressure == .critical || batteryInfo.currentCharge < 15 {
            return MicroverseDesign.Colors.critical
        } else if systemService.cpuUsage > 60 || systemService.memoryInfo.pressure == .warning || batteryInfo.currentCharge < 25 {
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
        if systemService.cpuUsage > 80 { return MicroverseDesign.Colors.critical }
        else if systemService.cpuUsage > 60 { return MicroverseDesign.Colors.warning }
        else { return MicroverseDesign.Colors.processor }
    }
    
    private var memoryColor: Color {
        switch systemService.memoryInfo.pressure {
        case .critical: return MicroverseDesign.Colors.critical
        case .warning: return MicroverseDesign.Colors.warning
        case .normal: return MicroverseDesign.Colors.memory
        }
    }
}
