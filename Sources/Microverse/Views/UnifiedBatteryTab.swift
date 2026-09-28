import SwiftUI
import BatteryCore

/// Consistent Battery tab following unified design system
struct UnifiedBatteryTab: View {
    @EnvironmentObject var viewModel: BatteryViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            // Battery Status Section
            VStack(spacing: 8) {
                SectionHeader("BATTERY STATUS", systemIcon: "battery.100percent")
                
                // Compact battery display
                VStack(spacing: 6) {
                    // Battery icon
                    Image(systemName: batteryIconName)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(batteryColor)
                    
                    // Percentage
                    Text("\(viewModel.batteryInfo.currentCharge)%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(batteryColor)
                    
                    // Status with icon
                    HStack(spacing: MicroverseDesign.Layout.space2) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        
                        Text(statusText)
                            .font(MicroverseDesign.Typography.caption)
                            .foregroundColor(MicroverseDesign.Colors.accentMuted)
                    }
                    
                    // Time remaining
                    if let timeString = viewModel.batteryInfo.timeRemainingFormatted {
                        Text(timeString)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(12)
            .background(MicroverseDesign.cardBackground())
            
            // Battery Details Section
            VStack(spacing: 8) {
                SectionHeader("BATTERY DETAILS", systemIcon: "info.circle")
                
                VStack(spacing: 6) {
                    InfoRow(
                        label: "Current Charge",
                        value: "\(viewModel.batteryInfo.currentCharge)%"
                    )
                    
                    InfoRow(
                        label: "Maximum Capacity",
                        value: "\(viewModel.batteryInfo.maxCapacity)%"
                    )
                    
                    InfoRow(
                        label: "Battery Health",
                        value: "\(Int(viewModel.batteryInfo.health * 100))%"
                    )
                    
                    InfoRow(
                        label: "Cycle Count",
                        value: "\(viewModel.batteryInfo.cycleCount)"
                    )
                    
                    InfoRow(
                        label: "Power Source",
                        value: viewModel.batteryInfo.isPluggedIn ? "AC Power" : "Battery"
                    )
                    
                    InfoRow(
                        label: "Charging Status",
                        value: chargingStatusText
                    )
                }
            }
            .padding(12)
            .background(MicroverseDesign.cardBackground())
            
        }
        .padding(6)
    }
    
    // MARK: - Computed Properties
    
    private var batteryIconName: String {
        WidgetModuleStatusResolver(viewModel: viewModel).batteryIconName
    }
    
    private var batteryColor: Color {
        WidgetModuleStatusResolver(viewModel: viewModel).color(for: .battery)
    }
    
    private var statusColor: Color {
        if viewModel.batteryInfo.isPluggedIn {
            return MicroverseDesign.Colors.success
        } else if viewModel.batteryInfo.currentCharge <= 20 {
            return MicroverseDesign.Colors.warning
        } else {
            return MicroverseDesign.Colors.neutral
        }
    }
    
    private var statusText: String {
        if viewModel.batteryInfo.isCharging {
            return "Charging"
        } else if viewModel.batteryInfo.isPluggedIn {
            return "Plugged In"
        } else {
            return "On Battery"
        }
    }
    
    private var chargingStatusText: String {
        if viewModel.batteryInfo.isCharging {
            return "Charging"
        } else if viewModel.batteryInfo.isPluggedIn {
            return "Fully Charged"
        } else {
            return "Discharging"
        }
    }
}