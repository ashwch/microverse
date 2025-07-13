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
            return NSSize(width: 100, height: 40)
        case .compact:
            return NSSize(width: 160, height: 50)
        case .standard:
            return NSSize(width: 180, height: 100)
        case .detailed:
            return NSSize(width: 240, height: 120)
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
    
    var batteryColor: Color {
        if batteryInfo.currentCharge <= 10 {
            return .red
        } else if batteryInfo.currentCharge <= 20 {
            return .orange  
        } else if batteryInfo.isCharging {
            return .green
        } else {
            return .white
        }
    }
    
    var body: some View {
        // Main content in simple HStack
        HStack(spacing: 4) {
            if batteryInfo.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundColor(batteryColor)
            }
            
            Text("\(batteryInfo.currentCharge)%")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(batteryColor)
        }
        .padding(8) // Padding INSIDE the frame
        .background( // Background AFTER content and padding
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .frame(width: 100, height: 40) // Explicit frame MUST match window size
    }
}

// Compact widget - Horizontal layout with time
// Design: Battery % | divider | time remaining
// Key approach: Fixed frame size, horizontal layout with divider
struct CompactWidget: View {
    let batteryInfo: BatteryInfo
    
    var batteryColor: Color {
        if batteryInfo.currentCharge <= 10 {
            return .red
        } else if batteryInfo.currentCharge <= 20 {
            return .orange
        } else if batteryInfo.isCharging {
            return .green
        } else {
            return .white
        }
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Battery percentage section
            HStack(spacing: 3) {
                Image(systemName: batteryInfo.isCharging ? "bolt.fill" : "battery.100")
                    .font(.system(size: 12)) // Small icon to fit
                    .foregroundColor(batteryColor)
                
                Text("\(batteryInfo.currentCharge)%")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(batteryColor)
            }
            
            // Visual separator
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1, height: 20) // Fixed height divider
            
            // Time remaining section
            if let timeString = batteryInfo.timeRemainingFormatted {
                Text(timeString)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            } else {
                Text("—")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 10) // Horizontal padding for content
        .padding(.vertical, 8)    // Vertical padding for content
        .background( // Apply background AFTER padding
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .frame(width: 160, height: 50) // MUST match window size exactly
    }
}

// Standard widget - Vertical centered layout
// Design: Large %, status below, optional time
// Key approach: VStack with blur background, explicit frame size
struct StandardWidget: View {
    let batteryInfo: BatteryInfo
    
    var batteryColor: Color {
        if batteryInfo.currentCharge <= 10 {
            return .red
        } else if batteryInfo.currentCharge <= 20 {
            return .orange
        } else if batteryInfo.isCharging {
            return .green
        } else {
            return .white
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // Battery percentage
            Text("\(batteryInfo.currentCharge)%")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(batteryColor)
            
            // Status with icon
            HStack(spacing: 3) {
                if batteryInfo.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                }
                Text(batteryInfo.isCharging ? "Charging" : "On Battery")
                    .font(.system(size: 11))
            }
            .foregroundColor(.secondary)
            
            // Time if available
            if let timeString = batteryInfo.timeRemainingFormatted {
                Text(timeString)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .padding(12)
        .frame(width: 180, height: 100)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

// Detailed widget - Full stats display
// Design: Header with % and status, divider, then stats grid
// Key approach: Compact layout to fit all info in 240×120
struct DetailedWidget: View {
    let batteryInfo: BatteryInfo
    
    var batteryColor: Color {
        if batteryInfo.currentCharge <= 10 {
            return .red
        } else if batteryInfo.currentCharge <= 20 {
            return .orange
        } else if batteryInfo.isCharging {
            return .green
        } else {
            return .primary
        }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Header row
            HStack {
                // Percentage
                HStack(spacing: 3) {
                    if batteryInfo.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundColor(batteryColor)
                    }
                    Text("\(batteryInfo.currentCharge)%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(batteryColor)
                }
                
                Spacer()
                
                // Status
                Text(batteryInfo.isCharging ? "Charging" : "On Battery")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Stats row
            HStack {
                // Cycles
                VStack(spacing: 2) {
                    Text("Cycles")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("\(batteryInfo.cycleCount)")
                        .font(.system(size: 12, weight: .medium))
                }
                
                Spacer()
                
                // Health
                VStack(spacing: 2) {
                    Text("Health")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("\(Int(batteryInfo.health * 100))%")
                        .font(.system(size: 12, weight: .medium))
                }
                
                Spacer()
                
                // Time
                VStack(spacing: 2) {
                    Text("Time")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    if let timeString = batteryInfo.timeRemainingFormatted {
                        Text(timeString)
                            .font(.system(size: 12, weight: .medium))
                    } else {
                        Text("—")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 240, height: 120)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
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