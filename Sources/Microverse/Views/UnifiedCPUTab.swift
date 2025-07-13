import SwiftUI
import SystemCore

/// Consistent CPU tab following unified design system
struct UnifiedCPUTab: View {
    @StateObject private var systemService = SystemMonitoringService.shared
    
    var body: some View {
        VStack(spacing: 8) {
            // CPU Usage Section
            VStack(spacing: MicroverseDesign.Layout.space3) {
                SectionHeader("PROCESSOR USAGE", systemIcon: "cpu")
                
                // Large percentage display
                Text("\(Int(systemService.cpuUsage))%")
                    .font(MicroverseDesign.Typography.display)
                    .foregroundColor(cpuColor)
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(MicroverseDesign.Colors.background)
                            .frame(height: 8)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(cpuColor)
                            .frame(
                                width: geometry.size.width * (systemService.cpuUsage / 100),
                                height: 8
                            )
                            .animation(MicroverseDesign.Animation.standard, value: systemService.cpuUsage)
                    }
                }
                .frame(height: 8)
                
                // Status text
                Text(cpuStatusText)
                    .font(MicroverseDesign.Typography.caption)
                    .foregroundColor(MicroverseDesign.Colors.accentMuted)
            }
            .padding(12)
            .background(MicroverseDesign.cardBackground())
            
            // System Information Section
            VStack(spacing: 8) {
                SectionHeader("SYSTEM INFORMATION", systemIcon: "info.circle")
                
                VStack(spacing: 6) {
                    InfoRow(
                        label: "Processor",
                        value: processorType
                    )
                    
                    InfoRow(
                        label: "Total Cores",
                        value: "\(ProcessInfo.processInfo.processorCount)"
                    )
                    
                    InfoRow(
                        label: "Active Cores", 
                        value: "\(ProcessInfo.processInfo.activeProcessorCount)"
                    )
                    
                    InfoRow(
                        label: "Architecture",
                        value: processorArchitecture
                    )
                }
            }
            .padding(12)
            .background(MicroverseDesign.cardBackground())
            
        }
        .padding(8)
    }
    
    // MARK: - Computed Properties
    
    private var cpuColor: Color {
        if systemService.cpuUsage > 80 {
            return MicroverseDesign.Colors.critical
        } else if systemService.cpuUsage > 60 {
            return MicroverseDesign.Colors.warning
        } else {
            return MicroverseDesign.Colors.processor
        }
    }
    
    private var cpuStatusText: String {
        if systemService.cpuUsage > 80 {
            return "High load detected"
        } else if systemService.cpuUsage > 60 {
            return "Moderate load"
        } else if systemService.cpuUsage > 30 {
            return "Normal operation"
        } else {
            return "Low activity"
        }
    }
    
    private var processorType: String {
        ProcessInfo.processInfo.processorCount > 8 ? "Apple Silicon" : "Intel"
    }
    
    private var processorArchitecture: String {
        #if arch(arm64)
        return "ARM64"
        #else
        return "x86_64"
        #endif
    }
}

