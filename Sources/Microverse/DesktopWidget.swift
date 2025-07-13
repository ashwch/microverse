import SwiftUI
import AppKit
import BatteryCore

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
                CompactWidget(batteryInfo: viewModel.batteryInfo)
            case .standard:
                StandardWidget(batteryInfo: viewModel.batteryInfo)
            case .detailed:
                DetailedWidget(batteryInfo: viewModel.batteryInfo)
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
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.batteryColor(for: batteryInfo))
            }
            
            Text("\(batteryInfo.currentCharge)%")
                .font(DesignSystem.Typography.widgetBody)
                .foregroundColor(.primary)
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
                    .font(DesignSystem.Typography.widgetCaption)
                    .foregroundColor(DesignSystem.batteryColor(for: batteryInfo))
                
                Text("\(batteryInfo.currentCharge)%")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
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
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                } else {
                    Text("—")
                        .font(.system(size: 14))
                        .foregroundColor(.primary.opacity(DesignSystem.Opacity.secondaryText))
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

// Standard widget - Vertical centered layout
// Design: Large %, status below, optional time
// Key approach: VStack with blur background, explicit frame size
struct StandardWidget: View {
    let batteryInfo: BatteryInfo
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.small) {
            // Battery percentage
            Text("\(batteryInfo.currentCharge)%")
                .font(DesignSystem.Typography.widgetTitle)
                .foregroundColor(DesignSystem.batteryColor(for: batteryInfo))
            
            // Status with icon
            HStack(spacing: DesignSystem.Spacing.micro) {
                if batteryInfo.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(DesignSystem.Typography.widgetSmallCaption)
                }
                Text(batteryInfo.isCharging ? "Charging" : "On Battery")
                    .font(DesignSystem.Typography.smallCaption)
            }
            .foregroundColor(.secondary)
            
            // Time if available
            if let timeString = batteryInfo.timeRemainingFormatted {
                Text(timeString)
                    .font(DesignSystem.Typography.widgetCaption.weight(.medium))
                    .foregroundColor(.primary)
            }
        }
        .padding(DesignSystem.Spacing.medium)
        .frame(width: DesignSystem.WidgetSize.standard.width,
               height: DesignSystem.WidgetSize.standard.height)
        .widgetBackground()
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
                            .foregroundColor(DesignSystem.batteryColor(for: batteryInfo))
                    }
                    Text("\(batteryInfo.currentCharge)%")
                        .font(DesignSystem.Typography.widgetHeadline)
                        .foregroundColor(DesignSystem.batteryColor(for: batteryInfo))
                }
                
                Spacer()
                
                // Status
                Text(batteryInfo.isCharging ? "Charging" : "On Battery")
                    .font(DesignSystem.Typography.widgetSmallCaption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .background(Color.white.opacity(DesignSystem.Opacity.divider))
            
            // Stats row
            HStack {
                // Cycles
                VStack(spacing: 2) {
                    Text("Cycles")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("\(batteryInfo.cycleCount)")
                        .font(DesignSystem.Typography.widgetCaption.weight(.medium))
                }
                
                Spacer()
                
                // Health
                VStack(spacing: 2) {
                    Text("Health")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("\(Int(batteryInfo.health * 100))%")
                        .font(DesignSystem.Typography.widgetCaption.weight(.medium))
                }
                
                Spacer()
                
                // Time
                VStack(spacing: 2) {
                    Text("Time")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    if let timeString = batteryInfo.timeRemainingFormatted {
                        Text(timeString)
                            .font(DesignSystem.Typography.widgetCaption.weight(.medium))
                    } else {
                        Text("—")
                            .font(DesignSystem.Typography.widgetCaption.weight(.medium))
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

// Widget Style Extension
extension WidgetStyle {
    var displayName: String {
        switch self {
        case .minimal: return "Minimal"
        case .compact: return "Compact"
        case .standard: return "Standard"
        case .detailed: return "Detailed"
        }
    }
}