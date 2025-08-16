import SwiftUI
import AppKit
import BatteryCore
import SystemCore

// MARK: - Notch Widget Window

class NotchWidgetWindow: NSWindow {
    init(position: CGPoint) {
        super.init(
            contentRect: NSRect(origin: position, size: NSSize(width: 100, height: 22)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // Critical settings for menu bar overlay
        self.level = .statusBar + 1  // Above status bar but below screen saver
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true  // Click-through
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        
        // Disable release when closed to prevent crashes
        isReleasedWhenClosed = false
        
        // Disable animations for instant display
        animationBehavior = .none
        
        // Position the window
        self.setFrameOrigin(position)
    }
}

// MARK: - Notch Battery Widget (Left Side)

struct NotchBatteryWidget: View {
    @EnvironmentObject var viewModel: BatteryViewModel
    
    var body: some View {
        HStack(spacing: MicroverseDesign.Layout.space1) {
            Image(systemName: batteryIcon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(batteryColor)
            
            Text("\(viewModel.batteryInfo.currentCharge)")
                .font(MicroverseDesign.Typography.caption)
                .fontWeight(.semibold)
                .foregroundColor(MicroverseDesign.Colors.accent)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(MicroverseDesign.Colors.background.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(MicroverseDesign.Colors.accent.opacity(0.3), lineWidth: 1)
                )
        )
        .frame(height: 22)
    }
    
    private var batteryIcon: String {
        if viewModel.batteryInfo.isCharging {
            return "bolt.fill"
        } else if viewModel.batteryInfo.currentCharge <= 20 {
            return "battery.25percent"
        } else if viewModel.batteryInfo.currentCharge <= 50 {
            return "battery.50percent"
        } else {
            return "battery.100percent"
        }
    }
    
    private var batteryColor: Color {
        if viewModel.batteryInfo.isCharging {
            return MicroverseDesign.Colors.battery
        } else if viewModel.batteryInfo.currentCharge <= 20 {
            return MicroverseDesign.Colors.warning
        } else if viewModel.batteryInfo.currentCharge <= 10 {
            return MicroverseDesign.Colors.critical
        } else {
            return MicroverseDesign.Colors.accentMuted
        }
    }
}

// MARK: - Notch System Widget (Right Side)

struct NotchSystemWidget: View {
    @EnvironmentObject var viewModel: BatteryViewModel
    @StateObject private var systemService = SystemMonitoringService.shared
    
    var body: some View {
        HStack(spacing: MicroverseDesign.Layout.space2) {
            // CPU
            HStack(spacing: 2) {
                Image(systemName: "cpu")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(cpuColor)
                
                Text("\(Int(systemService.cpuUsage))")
                    .font(MicroverseDesign.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(MicroverseDesign.Colors.accent)
            }
            
            // Memory
            HStack(spacing: 2) {
                Image(systemName: "memorychip")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(memoryColor)
                
                Text("\(Int(systemService.memoryInfo.usagePercentage))")
                    .font(MicroverseDesign.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(MicroverseDesign.Colors.accent)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(MicroverseDesign.Colors.background.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(MicroverseDesign.Colors.accent.opacity(0.3), lineWidth: 1)
                )
        )
        .frame(height: 22)
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
        case .critical:
            return MicroverseDesign.Colors.critical
        case .warning:
            return MicroverseDesign.Colors.warning
        case .normal:
            return MicroverseDesign.Colors.memory
        }
    }
}

// MARK: - Notch Widget Preview Helpers

struct NotchBatteryWidget_Previews: PreviewProvider {
    static var previews: some View {
        NotchBatteryWidget()
            .environmentObject(BatteryViewModel())
            .preferredColorScheme(.dark)
    }
}

struct NotchSystemWidget_Previews: PreviewProvider {
    static var previews: some View {
        NotchSystemWidget()
            .environmentObject(BatteryViewModel())
            .preferredColorScheme(.dark)
    }
}