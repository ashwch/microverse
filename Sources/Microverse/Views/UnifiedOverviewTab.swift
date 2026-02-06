import SwiftUI
import BatteryCore
import SystemCore

/// Elegant Overview tab with perfect consistency
struct UnifiedOverviewTab: View {
    @EnvironmentObject var viewModel: BatteryViewModel
    @StateObject private var systemService = SystemMonitoringService.shared
    
    var body: some View {
        VStack(spacing: 8) {
            // System Health Section - Compact
            VStack(spacing: 8) {
                SectionHeader("SYSTEM HEALTH", systemIcon: "circle.grid.2x2")
                
                Text(overallHealth)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(healthColor)
                
                // Compact metrics row
                HStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text("\(viewModel.batteryInfo.currentCharge)%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Text("BATTERY")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    VStack(spacing: 2) {
                        Image(systemName: "cpu")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        Text("\(Int(systemService.cpuUsage))%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Text("CPU")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    VStack(spacing: 2) {
                        Image(systemName: "memorychip")
                            .font(.system(size: 12))
                            .foregroundColor(.purple)
                        Text("\(Int(systemService.memoryInfo.usagePercentage))%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Text("MEMORY")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding(12)
            .background(MicroverseDesign.cardBackground())
            
            // Compact Insights
            VStack(spacing: 8) {
                SectionHeader("INSIGHTS", systemIcon: "lightbulb")
                
                VStack(spacing: 4) {
                    ForEach(Array(insights.prefix(3).enumerated()), id: \.offset) { _, insight in
                        HStack(spacing: 8) {
                            Image(systemName: insight.icon)
                                .font(.system(size: 10))
                                .foregroundColor(insight.level.color)
                                .frame(width: 12)
                            
                            Text(insight.message)
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                    }
                }
            }
            .padding(12)
            .background(MicroverseDesign.cardBackground())
        }
        .padding(8)
        .systemMonitoringActive()
    }
    
    // MARK: - Computed Properties
    
    private var overallHealth: String {
        if systemService.cpuUsage > 80 || systemService.memoryInfo.pressure == .critical {
            return "Stressed"
        } else if systemService.cpuUsage > 50 || systemService.memoryInfo.pressure == .warning {
            return "Moderate"
        } else {
            return "Excellent"
        }
    }
    
    private var healthColor: Color {
        if systemService.cpuUsage > 80 || systemService.memoryInfo.pressure == .critical {
            return MicroverseDesign.Colors.critical
        } else if systemService.cpuUsage > 50 || systemService.memoryInfo.pressure == .warning {
            return MicroverseDesign.Colors.warning
        } else {
            return MicroverseDesign.Colors.success
        }
    }
    
    private var memoryPressureText: String {
        switch systemService.memoryInfo.pressure {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
    
    private var insights: [(icon: String, message: String, level: InsightRow.InsightLevel)] {
        var results: [(icon: String, message: String, level: InsightRow.InsightLevel)] = []
        
        // CPU insights
        if systemService.cpuUsage > 80 {
            results.append(("exclamationmark.triangle", "High processor usage detected", .critical))
        } else if systemService.cpuUsage > 60 {
            results.append(("info.circle", "Moderate processor load", .warning))
        }
        
        // Memory insights
        if systemService.memoryInfo.pressure == .critical {
            results.append(("memorychip", "Memory pressure is critical", .critical))
        } else if systemService.memoryInfo.pressure == .warning {
            results.append(("memorychip", "Memory pressure elevated", .warning))
        }
        
        // Battery insights
        if viewModel.batteryInfo.currentCharge < 15 && !viewModel.batteryInfo.isPluggedIn {
            results.append(("battery.25", "Battery level is low", .warning))
        } else if viewModel.batteryInfo.isCharging && viewModel.batteryInfo.currentCharge > 95 {
            results.append(("bolt.fill", "Battery nearly full", .normal))
        }
        
        // Health insights
        if viewModel.batteryInfo.health < 0.8 {
            results.append(("heart", "Battery health declining", .warning))
        }
        
        // Default positive message
        if results.isEmpty {
            results.append(("checkmark.circle", "All systems operating normally", .normal))
        }
        
        return results
    }
}
