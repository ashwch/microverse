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

// Widget style enum
enum WidgetStyle: String, CaseIterable {
    case minimal = "Minimal"    // 100×40: Just percentage
    case compact = "Compact"    // 160×50: Percentage + time
    case standard = "Standard"  // 180×100: Vertical layout
    case detailed = "Detailed"  // 240×120: Full stats
    case cpu = "CPU"           // 160×80: CPU focused
    case memory = "Memory"     // 160×80: Memory focused
    case system = "System"     // 240×120: All metrics
}

// Desktop widget manager
class DesktopWidgetManager: ObservableObject {
    private var window: DesktopWidgetWindow?
    private var hostingView: NSHostingView<AnyView>?
    private weak var viewModel: BatteryViewModel?
    
    init(viewModel: BatteryViewModel) {
        self.viewModel = viewModel
    }
    
    @MainActor
    func showWidget() {
        guard window == nil else { return }
        
        guard let viewModel = viewModel else { return }
        
        // Get the appropriate size for the widget style
        let size = getWidgetSize(for: viewModel.widgetStyle)
        window = DesktopWidgetWindow(size: size)
        
        // Create widget view without any frame modifier
        // The individual widget views will handle their own sizing
        let widgetView = AnyView(
            DesktopWidgetView(viewModel: viewModel)
        )
        
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
    
    func hideWidget() {
        window?.close()
        window = nil
        hostingView = nil
    }
    
    // CRITICAL: These sizes MUST match the frame sizes in the widget views
    // Any mismatch will cause content to be clipped or not fill the window
    private func getWidgetSize(for style: WidgetStyle) -> NSSize {
        switch style {
        case .minimal:
            let size = DesignSystem.WidgetSize.minimal
            return NSSize(width: size.width, height: size.height)
        case .compact:
            let size = DesignSystem.WidgetSize.compact
            return NSSize(width: size.width, height: size.height)
        case .standard:
            let size = DesignSystem.WidgetSize.standard
            return NSSize(width: size.width, height: size.height)
        case .detailed:
            let size = DesignSystem.WidgetSize.detailed
            return NSSize(width: size.width, height: size.height)
        case .cpu, .memory:
            return NSSize(width: 160, height: 80)
        case .system:
            return NSSize(width: 240, height: 100) // Compact to prevent cropping
        }
    }
    
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
    @ObservedObject var viewModel: BatteryViewModel
    
    var body: some View {
        Group {
            switch viewModel.widgetStyle {
            case .minimal:
                MinimalWidget(batteryInfo: viewModel.batteryInfo)
            case .compact:
                if viewModel.showSystemInfoInWidget {
                    CompactSystemWidget(batteryInfo: viewModel.batteryInfo)
                } else {
                    CompactWidget(batteryInfo: viewModel.batteryInfo)
                }
            case .standard:
                StandardWidget(batteryInfo: viewModel.batteryInfo)
            case .detailed:
                if viewModel.showSystemInfoInWidget {
                    DetailedSystemWidget(batteryInfo: viewModel.batteryInfo)
                } else {
                    DetailedWidget(batteryInfo: viewModel.batteryInfo)
                }
            case .cpu:
                CPUWidget()
            case .memory:
                MemoryWidget()
            case .system:
                SystemOverviewWidget(batteryInfo: viewModel.batteryInfo)
            }
        }
    }
}

// Minimal widget - Just percentage
// Design: Simple horizontal stack with icon + percentage
// Key approach: NO ZStack, explicit frame at the end, padding inside frame
struct MinimalWidget: View {
    let batteryInfo: BatteryInfo
    
    var body: some View {
        // Main content in simple HStack
        HStack(spacing: DesignSystem.Spacing.micro) {
            if batteryInfo.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.green)
            }
            
            Text("\(batteryInfo.currentCharge)%")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(DesignSystem.Spacing.small) // Padding INSIDE the frame
        .widgetBackground() // Use consistent blur background
        .frame(width: DesignSystem.WidgetSize.minimal.width, 
               height: DesignSystem.WidgetSize.minimal.height) // Explicit frame MUST match window size
    }
}

// Compact widget - Horizontal layout with time
// Design: Battery % | divider | time remaining
// Key approach: Fixed frame size, horizontal layout with divider
struct CompactWidget: View {
    let batteryInfo: BatteryInfo
    
    var body: some View {
        HStack(spacing: 0) {
            // Battery percentage section with fixed width
            HStack(spacing: DesignSystem.Spacing.micro) {
                Image(systemName: batteryInfo.isCharging ? "bolt.fill" : DesignSystem.batteryIconName(for: batteryInfo))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(batteryInfo.isCharging ? .green : .white)
                
                Text("\(batteryInfo.currentCharge)%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(width: 70, alignment: .leading) // Fixed width to prevent layout shifts
            
            // Visual separator
            Rectangle()
                .fill(Color.primary.opacity(DesignSystem.Opacity.divider))
                .frame(width: 1, height: 20) // Fixed height divider
                .padding(.horizontal, DesignSystem.Spacing.small)
            
            // Time remaining section
            Group {
                if let timeString = batteryInfo.timeRemainingFormatted {
                    Text(timeString)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                } else {
                    Text("—")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, DesignSystem.Spacing.small + 2) // Horizontal padding for content
        .padding(.vertical, DesignSystem.Spacing.small)    // Vertical padding for content
        .widgetBackground()
        .frame(width: DesignSystem.WidgetSize.compact.width, 
               height: DesignSystem.WidgetSize.compact.height) // MUST match window size exactly
    }
}

// Elegant standard widget with improved contrast
struct StandardWidget: View {
    let batteryInfo: BatteryInfo
    
    var body: some View {
        VStack(spacing: 8) {
            // Battery percentage with clear hierarchy
            Text("\(batteryInfo.currentCharge)%")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // Status with improved visibility
            HStack(spacing: 4) {
                if batteryInfo.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                Text(batteryInfo.isCharging ? "Charging" : "On Battery")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Time if available with better contrast
            if let timeString = batteryInfo.timeRemainingFormatted {
                Text(timeString)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .padding(16)
        .widgetBackground()
        .frame(width: DesignSystem.WidgetSize.standard.width,
               height: DesignSystem.WidgetSize.standard.height)
    }
}

// Detailed widget - Full stats display
// Design: Header with % and status, divider, then stats grid
// Key approach: Compact layout to fit all info in 240×120
struct DetailedWidget: View {
    let batteryInfo: BatteryInfo
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            // Header row
            HStack {
                // Percentage
                HStack(spacing: DesignSystem.Spacing.micro) {
                    if batteryInfo.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(DesignSystem.Typography.widgetCaption)
                            .foregroundColor(.green)
                    }
                    Text("\(batteryInfo.currentCharge)%")
                        .font(DesignSystem.Typography.widgetHeadline)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                // Status
                Text(batteryInfo.isCharging ? "Charging" : "On Battery")
                    .font(DesignSystem.Typography.widgetSmallCaption)
                    .foregroundColor(.white)
            }
            
            Divider()
                .background(Color.white.opacity(DesignSystem.Opacity.divider))
            
            // Stats row
            HStack {
                // Cycles
                VStack(spacing: 2) {
                    Text("Cycles")
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                    Text("\(batteryInfo.cycleCount)")
                        .font(DesignSystem.Typography.widgetCaption.weight(.medium))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Health
                VStack(spacing: 2) {
                    Text("Health")
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                    Text("\(Int(batteryInfo.health * 100))%")
                        .font(DesignSystem.Typography.widgetCaption.weight(.medium))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Time
                VStack(spacing: 2) {
                    Text("Time")
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                    if let timeString = batteryInfo.timeRemainingFormatted {
                        Text(timeString)
                            .font(DesignSystem.Typography.widgetCaption.weight(.medium))
                            .foregroundColor(.white)
                    } else {
                        Text("—")
                            .font(DesignSystem.Typography.widgetCaption.weight(.medium))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .frame(width: DesignSystem.WidgetSize.detailed.width,
               height: DesignSystem.WidgetSize.detailed.height)
        .widgetBackground()
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
    /// Applies consistent Johnny Ive-inspired widget background
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
        case .minimal: return "Minimal"
        case .compact: return "Compact"
        case .standard: return "Standard"
        case .detailed: return "Detailed"
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .system: return "System"
        }
    }
}

// MARK: - Dedicated CPU Widget

struct CPUWidget: View {
    @StateObject private var systemService = SystemMonitoringService.shared
    
    var body: some View {
        VStack(spacing: 8) {
            // CPU Header
            HStack {
                Image(systemName: "cpu")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("CPU")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(Int(systemService.cpuUsage))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
            }
            
            // CPU Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(cpuColor)
                        .frame(width: geometry.size.width * (systemService.cpuUsage / 100), height: 6)
                        .animation(.easeInOut(duration: 0.3), value: systemService.cpuUsage)
                }
            }
            .frame(height: 6)
            
            // Status
            Text(cpuStatusText)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(12)
        .frame(width: 160, height: 80)
        .widgetBackground()
    }
    
    private var cpuColor: Color {
        if systemService.cpuUsage > 80 { return .red }
        else if systemService.cpuUsage > 60 { return .orange }
        else { return .blue }
    }
    
    private var cpuStatusText: String {
        if systemService.cpuUsage > 80 { return "High Usage" }
        else if systemService.cpuUsage > 60 { return "Moderate Load" }
        else { return "Normal Operation" }
    }
}

// MARK: - Dedicated Memory Widget

struct MemoryWidget: View {
    @StateObject private var systemService = SystemMonitoringService.shared
    
    var body: some View {
        VStack(spacing: 8) {
            // Memory Header
            HStack {
                Image(systemName: "memorychip")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.purple)
                
                Text("MEMORY")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(Int(systemService.memoryInfo.usagePercentage))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.purple)
            }
            
            // Memory Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(memoryColor)
                        .frame(width: geometry.size.width * (systemService.memoryInfo.usagePercentage / 100), height: 6)
                        .animation(.easeInOut(duration: 0.3), value: systemService.memoryInfo.usagePercentage)
                }
            }
            .frame(height: 6)
            
            // Memory Usage
            Text("\(String(format: "%.1f", systemService.memoryInfo.usedMemory)) / \(String(format: "%.1f", systemService.memoryInfo.totalMemory)) GB")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(12)
        .frame(width: 160, height: 80)
        .widgetBackground()
    }
    
    private var memoryColor: Color {
        switch systemService.memoryInfo.pressure {
        case .critical: return .red
        case .warning: return .orange
        case .normal: return .purple
        }
    }
}

// MARK: - System Overview Widget (Replaces DetailedSystemWidget)

struct SystemOverviewWidget: View {
    let batteryInfo: BatteryInfo
    @StateObject private var systemService = SystemMonitoringService.shared
    
    var body: some View {
        VStack(spacing: 6) {
            // Header with battery prominently displayed
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                    Text("\(batteryInfo.currentCharge)%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Circle()
                    .fill(systemHealthColor)
                    .frame(width: 6, height: 6)
            }
            
            // Compact two-column metrics  
            HStack(spacing: 16) {
                // CPU
                VStack(spacing: 2) {
                    Image(systemName: "cpu")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                    Text("\(Int(systemService.cpuUsage))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("CPU")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(0.8)
                }
                .frame(maxWidth: .infinity)
                
                // Memory
                VStack(spacing: 2) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.purple)
                    Text("\(Int(systemService.memoryInfo.usagePercentage))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("MEMORY")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(0.8)
                }
                .frame(maxWidth: .infinity)
                
                // Health
                VStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    Text("\(Int(batteryInfo.health * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("HEALTH")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(0.8)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .frame(width: 240, height: 100)
        .widgetBackground()
    }
    
    private var systemHealthColor: Color {
        if systemService.cpuUsage > 80 || systemService.memoryInfo.pressure == .critical || batteryInfo.currentCharge < 15 {
            return .red
        } else if systemService.cpuUsage > 60 || systemService.memoryInfo.pressure == .warning || batteryInfo.currentCharge < 25 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var systemStatusText: String {
        if systemService.cpuUsage > 80 || systemService.memoryInfo.pressure == .critical {
            return "System under stress"
        } else if systemService.cpuUsage > 60 || systemService.memoryInfo.pressure == .warning {
            return "Moderate system load"
        } else {
            return "All systems optimal"
        }
    }
}

// Elegant compact widget with system monitoring
struct CompactSystemWidget: View {
    let batteryInfo: BatteryInfo
    @StateObject private var systemService = SystemMonitoringService.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // Battery with clean typography
            VStack(spacing: 2) {
                Image(systemName: batteryInfo.isCharging ? "bolt.fill" : "battery.100percent")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text("\(batteryInfo.currentCharge)%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            // CPU with proper contrast
            VStack(spacing: 2) {
                Image(systemName: "cpu")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                Text("\(Int(systemService.cpuUsage))%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            // Memory with clear visibility
            VStack(spacing: 2) {
                Image(systemName: "memorychip")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                Text("\(Int(systemService.memoryInfo.usagePercentage))%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .widgetBackground()
        .frame(width: DesignSystem.WidgetSize.compact.width, 
               height: DesignSystem.WidgetSize.compact.height)
    }
}

// Johnny Ive-inspired detailed system widget
struct DetailedSystemWidget: View {
    let batteryInfo: BatteryInfo
    @StateObject private var systemService = SystemMonitoringService.shared
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with clear hierarchy
            VStack(spacing: 6) {
                HStack {
                    Text("SYSTEM")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(1.2)
                    
                    Spacer()
                    
                    Circle()
                        .fill(systemHealthColor)
                        .frame(width: 8, height: 8)
                }
                
                HStack {
                    // Large battery percentage
                    HStack(spacing: 4) {
                        if batteryInfo.isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        Text("\(batteryInfo.currentCharge)%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
            }
            
            // Elegant metrics grid
            HStack(spacing: 0) {
                // CPU Metric
                MetricCard(
                    icon: "cpu",
                    value: "\(Int(systemService.cpuUsage))%",
                    label: "CPU",
                    color: cpuColor
                )
                
                Spacer()
                
                // Memory Metric
                MetricCard(
                    icon: "memorychip", 
                    value: "\(Int(systemService.memoryInfo.usagePercentage))%",
                    label: "Memory",
                    color: memoryColor
                )
                
                Spacer()
                
                // Health Metric
                MetricCard(
                    icon: "heart.fill",
                    value: "\(Int(batteryInfo.health * 100))%",
                    label: "Health",
                    color: .white.opacity(0.9)
                )
            }
            
            // Subtle warning for memory pressure
            if systemService.memoryInfo.pressure != .normal {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    
                    Text("Memory pressure elevated")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .widgetBackground()
        .frame(width: DesignSystem.WidgetSize.detailed.width,
               height: DesignSystem.WidgetSize.detailed.height)
    }
    
    private var systemHealthColor: Color {
        if systemService.cpuUsage > 80 || systemService.memoryInfo.pressure == .critical {
            return .red
        } else if systemService.cpuUsage > 50 || systemService.memoryInfo.pressure == .warning {
            return .orange
        } else {
            return .green
        }
    }
    
    private var cpuColor: Color {
        systemService.cpuUsage > 80 ? .red : systemService.cpuUsage > 50 ? .orange : .blue
    }
    
    private var memoryColor: Color {
        systemService.memoryInfo.pressure == .critical ? .red : 
        systemService.memoryInfo.pressure == .warning ? .orange : .purple
    }
}

// Elegant metric card component
struct MetricCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .tracking(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}