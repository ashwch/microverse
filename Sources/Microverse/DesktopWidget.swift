import SwiftUI
import AppKit
import BatteryCore

// MARK: - Desktop Widget Window
class DesktopWidgetWindow: NSWindow {
    init(size: NSSize = NSSize(width: 200, height: 200)) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Window properties for floating widget
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        // Disable release when closed to prevent crashes
        isReleasedWhenClosed = false
        
        // Disable animations
        animationBehavior = .none
        
        // Position in bottom right corner by default
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - size.width - 20
            let y = screenFrame.minY + 20
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}

// MARK: - Widget Styles
enum WidgetStyle: String, CaseIterable {
    case circular = "Circular"
    case compact = "Compact"
    case detailed = "Detailed"
    case minimal = "Minimal"
}

// MARK: - Desktop Widget View
struct DesktopWidgetView: View {
    @ObservedObject var viewModel: BatteryViewModel
    @AppStorage("widgetStyle") var widgetStyle = WidgetStyle.circular
    @AppStorage("widgetOpacity") var widgetOpacity = 0.9
    @State private var isHovering = false
    
    var body: some View {
        Group {
            switch widgetStyle {
            case .circular:
                CircularWidget(info: viewModel.batteryInfo, isHovering: isHovering)
            case .compact:
                CompactWidget(info: viewModel.batteryInfo, isHovering: isHovering)
            case .detailed:
                DetailedWidget(info: viewModel.batteryInfo, isHovering: isHovering)
            case .minimal:
                MinimalWidget(info: viewModel.batteryInfo, isHovering: isHovering)
            }
        }
        .opacity(widgetOpacity)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Circular Widget
struct CircularWidget: View {
    let info: BatteryInfo
    let isHovering: Bool
    
    var batteryColor: Color {
        if info.currentCharge <= 20 {
            return .red
        } else if info.currentCharge <= 50 {
            return .yellow
        } else {
            return .green
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(Color.black.opacity(0.7))
                .frame(width: 180, height: 180)
            
            // Battery ring
            Circle()
                .trim(from: 0, to: CGFloat(info.currentCharge) / 100)
                .stroke(
                    batteryColor,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 150, height: 150)
                .animation(.easeInOut(duration: 0.3), value: info.currentCharge)
            
            // Content
            VStack(spacing: 8) {
                // Battery percentage
                Text("\(info.currentCharge)")
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundColor(.white)
                
                Text("%")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.gray)
                    .offset(y: -8)
                
                // Status
                Label(info.isCharging ? "Charging" : "Battery", 
                      systemImage: info.isCharging ? "bolt.fill" : "battery.75")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Time remaining on hover
                if isHovering, let time = info.timeRemaining, !info.isPluggedIn {
                    Text("\(time / 60):\(String(format: "%02d", time % 60))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .transition(.opacity)
                }
            }
        }
        .frame(width: 200, height: 200)
    }
}

// MARK: - Compact Widget
struct CompactWidget: View {
    let info: BatteryInfo
    let isHovering: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Battery icon
            Image(systemName: batteryIconName)
                .font(.system(size: 24))
                .foregroundColor(batteryColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(info.currentCharge)%")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                
                if info.isCharging {
                    Text("Charging")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else if let time = info.timeRemaining {
                    Text("\(time / 60):\(String(format: "%02d", time % 60))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 200, height: 70)
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
    }
    
    var batteryIconName: String {
        if info.isCharging {
            return "battery.100.bolt"
        } else if info.currentCharge > 75 {
            return "battery.100"
        } else if info.currentCharge > 50 {
            return "battery.75"
        } else if info.currentCharge > 25 {
            return "battery.50"
        } else {
            return "battery.25"
        }
    }
    
    var batteryColor: Color {
        if info.currentCharge <= 20 {
            return .red
        } else if info.currentCharge <= 50 {
            return .yellow
        } else {
            return .green
        }
    }
}

// MARK: - Detailed Widget
struct DetailedWidget: View {
    let info: BatteryInfo
    let isHovering: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "battery.75")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Spacer()
                
                Text("\(info.currentCharge)%")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.white)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(batteryColor)
                        .frame(width: geometry.size.width * CGFloat(info.currentCharge) / 100, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: info.currentCharge)
                }
            }
            .frame(height: 8)
            
            // Details
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(info.isCharging ? "Charging" : "On Battery", 
                          systemImage: info.isCharging ? "bolt.fill" : "battery.75")
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if let time = info.timeRemaining, !info.isPluggedIn {
                        Text("\(time / 60):\(String(format: "%02d", time % 60)) remaining")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                if isHovering {
                    HStack {
                        Text("Cycles: \(info.cycleCount)")
                        Spacer()
                        Text("Health: \(Int(info.health * 100))%")
                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .transition(.opacity)
                }
            }
        }
        .padding()
        .frame(width: 250)
        .background(Color.black.opacity(0.85))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    var batteryColor: Color {
        if info.currentCharge <= 20 {
            return .red
        } else if info.currentCharge <= 50 {
            return .yellow
        } else {
            return .green
        }
    }
}

// MARK: - Minimal Widget
struct MinimalWidget: View {
    let info: BatteryInfo
    let isHovering: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(info.currentCharge)")
                .font(.system(size: 28, weight: .ultraLight, design: .rounded))
                .foregroundColor(batteryColor)
            
            Text("%")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(.gray)
                .offset(y: -2)
            
            if info.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
            }
        }
        .frame(width: 120, height: 80)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.75))
                .overlay(
                    Capsule()
                        .stroke(batteryColor.opacity(0.3), lineWidth: 1)
                )
        )
        .scaleEffect(isHovering ? 1.05 : 1.0)
    }
    
    var batteryColor: Color {
        if info.currentCharge <= 20 {
            return .red
        } else if info.currentCharge <= 50 {
            return .yellow
        } else {
            return .green
        }
    }
}

// MARK: - Widget Manager
class DesktopWidgetManager {
    private var window: DesktopWidgetWindow?
    private let viewModel: BatteryViewModel
    
    init(viewModel: BatteryViewModel) {
        self.viewModel = viewModel
    }
    
    @MainActor func showWidget() {
        if window == nil {
            // Get appropriate size based on widget style
            let size = getWidgetSize()
            window = DesktopWidgetWindow(size: size)
            let widgetView = DesktopWidgetView(viewModel: viewModel)
            window?.contentView = NSHostingView(rootView: widgetView)
            window?.orderFront(nil)
        }
    }
    
    @MainActor private func getWidgetSize() -> NSSize {
        switch viewModel.widgetStyle {
        case .circular:
            return NSSize(width: 220, height: 220)
        case .compact:
            return NSSize(width: 220, height: 90)
        case .detailed:
            return NSSize(width: 280, height: 180)
        case .minimal:
            return NSSize(width: 140, height: 100)  // Increased size to prevent cropping
        }
    }
    
    @MainActor func hideWidget() {
        guard let window = window else { return }
        
        // Disable animations to prevent crashes
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0
            window.orderOut(nil)
        }) {
            window.close()
            self.window = nil
        }
    }
    
    @MainActor func toggleWidget() {
        if window != nil {
            hideWidget()
        } else {
            showWidget()
        }
    }
}