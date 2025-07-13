import SwiftUI
import AppKit
import BatteryCore

// Widget style enum
enum WidgetStyle: String, CaseIterable {
    case minimal = "Minimal"
    case compact = "Compact" 
    case standard = "Standard"
    case detailed = "Detailed"
}

// Desktop widget manager
class DesktopWidgetManager: ObservableObject {
    private var window: DesktopWidgetWindow?
    private var hostingView: NSHostingView<AnyView>?
    weak var viewModel: BatteryViewModel?
    
    init(viewModel: BatteryViewModel) {
        self.viewModel = viewModel
    }
    
    @MainActor
    func showWidget() {
        guard window == nil else { return }
        
        guard let viewModel = viewModel else { return }
        
        let size = getWidgetSize(for: viewModel.widgetStyle)
        window = DesktopWidgetWindow(size: size)
        
        let widgetView = AnyView(
            DesktopWidgetView(viewModel: viewModel)
                .frame(width: size.width, height: size.height)
        )
        
        hostingView = NSHostingView(rootView: widgetView)
        hostingView?.frame = NSRect(origin: .zero, size: size)
        
        window?.contentView = hostingView
        window?.makeKeyAndOrderFront(nil)
        
        // Position in top-right corner
        positionWindow()
    }
    
    func hideWidget() {
        window?.close()
        window = nil
        hostingView = nil
    }
    
    private func getWidgetSize(for style: WidgetStyle) -> NSSize {
        switch style {
        case .minimal:
            return NSSize(width: 100, height: 40)
        case .compact:
            return NSSize(width: 160, height: 60)
        case .standard:
            return NSSize(width: 180, height: 100)
        case .detailed:
            return NSSize(width: 200, height: 120)
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
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
            
            // Content
            HStack(spacing: 6) {
                if batteryInfo.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12))
                        .foregroundColor(batteryColor)
                }
                
                Text("\(batteryInfo.currentCharge)%")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(batteryColor)
            }
        }
        .frame(width: 100, height: 40)
    }
}

// Compact widget
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
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
            
            // Content
            HStack(spacing: 12) {
                // Battery icon with percentage
                HStack(spacing: 6) {
                    Image(systemName: batteryInfo.isCharging ? "bolt.fill" : "battery.100")
                        .font(.system(size: 14))
                        .foregroundColor(batteryColor)
                    
                    Text("\(batteryInfo.currentCharge)%")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(batteryColor)
                }
                
                Spacer()
                
                // Time if available
                if let timeString = batteryInfo.timeRemainingFormatted {
                    Text(timeString)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(width: 160, height: 60)
    }
}

// Standard widget
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
        ZStack {
            // Background with blur
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
            
            // Content
            VStack(spacing: 8) {
                // Battery percentage
                Text("\(batteryInfo.currentCharge)%")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(batteryColor)
                
                // Status with icon
                HStack(spacing: 4) {
                    if batteryInfo.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11))
                    }
                    Text(batteryInfo.isCharging ? "Charging" : "On Battery")
                        .font(.system(size: 12))
                }
                .foregroundColor(.secondary)
                
                // Time if available
                if let timeString = batteryInfo.timeRemainingFormatted {
                    Text(timeString)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
        }
        .frame(width: 180, height: 100)
    }
}

// Detailed widget - Clean grid layout
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
        ZStack {
            // Background
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 16) {
                // Header row
                HStack {
                    // Percentage
                    HStack(spacing: 6) {
                        if batteryInfo.isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 16))
                                .foregroundColor(batteryColor)
                        }
                        Text("\(batteryInfo.currentCharge)%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(batteryColor)
                    }
                    
                    Spacer()
                    
                    // Status
                    Text(batteryInfo.isCharging ? "Charging" : "On Battery")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                // Stats row
                HStack {
                    // Cycles
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cycles")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("\(batteryInfo.cycleCount)")
                            .font(.system(size: 14, weight: .medium))
                    }
                    
                    Spacer()
                    
                    // Health
                    VStack(alignment: .center, spacing: 2) {
                        Text("Health")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("\(Int(batteryInfo.health * 100))%")
                            .font(.system(size: 14, weight: .medium))
                    }
                    
                    Spacer()
                    
                    // Time
                    if let timeString = batteryInfo.timeRemainingFormatted {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Time")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(timeString)
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 200, height: 120)
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