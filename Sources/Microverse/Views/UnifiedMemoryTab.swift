import SwiftUI
import SystemCore

/// Consistent Memory tab following unified design system
struct UnifiedMemoryTab: View {
    @StateObject private var systemService = SystemMonitoringService.shared
    
    var body: some View {
        VStack(spacing: 8) {
            // Memory Usage Section
            VStack(spacing: MicroverseDesign.Layout.space3) {
                SectionHeader("MEMORY USAGE", systemIcon: "memorychip")
                
                // Memory display
                VStack(spacing: MicroverseDesign.Layout.space2) {
                    Text(String(format: "%.1f / %.1f GB", systemService.memoryInfo.usedMemory, systemService.memoryInfo.totalMemory))
                        .font(MicroverseDesign.Typography.title)
                        .foregroundColor(MicroverseDesign.Colors.accent)
                    
                    Text("\(Int(systemService.memoryInfo.usagePercentage))%")
                        .font(MicroverseDesign.Typography.display)
                        .foregroundColor(memoryColor)
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(MicroverseDesign.Colors.background)
                            .frame(height: 8)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(memoryColor)
                            .frame(
                                width: geometry.size.width * (systemService.memoryInfo.usagePercentage / 100),
                                height: 8
                            )
                            .animation(MicroverseDesign.Animation.standard, value: systemService.memoryInfo.usagePercentage)
                    }
                }
                .frame(height: 8)
                
                // Pressure indicator
                HStack(spacing: MicroverseDesign.Layout.space2) {
                    Circle()
                        .fill(pressureColor)
                        .frame(width: 8, height: 8)
                    
                    Text("Pressure: \(systemService.memoryInfo.pressure.rawValue)")
                        .font(MicroverseDesign.Typography.caption)
                        .foregroundColor(MicroverseDesign.Colors.accentMuted)
                }
            }
            .padding(12)
            .background(MicroverseDesign.cardBackground())
            
            // Memory Details Section
            VStack(spacing: 8) {
                SectionHeader("MEMORY DETAILS", systemIcon: "info.circle")
                
                VStack(spacing: 6) {
                    InfoRow(
                        label: "Total Memory",
                        value: String(format: "%.1f GB", systemService.memoryInfo.totalMemory)
                    )
                    
                    InfoRow(
                        label: "Used Memory",
                        value: String(format: "%.1f GB", systemService.memoryInfo.usedMemory)
                    )
                    
                    InfoRow(
                        label: "Free Memory",
                        value: String(format: "%.1f GB", systemService.memoryInfo.totalMemory - systemService.memoryInfo.usedMemory - systemService.memoryInfo.cachedMemory)
                    )
                    
                    InfoRow(
                        label: "Cached Files",
                        value: String(format: "%.1f GB", systemService.memoryInfo.cachedMemory)
                    )
                    
                    InfoRow(
                        label: "Compression Ratio",
                        value: "\(Int(systemService.memoryInfo.compressionRatio * 100))%"
                    )
                    
                    InfoRow(
                        label: "Memory Pressure",
                        value: systemService.memoryInfo.pressure.rawValue
                    )
                }
            }
            .padding(12)
            .background(MicroverseDesign.cardBackground())
            
        }
        .padding(8)
    }
    
    // MARK: - Computed Properties
    
    private var memoryColor: Color {
        switch systemService.memoryInfo.pressure {
        case .critical:
            return MicroverseDesign.Colors.critical
        case .warning:
            return MicroverseDesign.Colors.warning
        case .normal:
            if systemService.memoryInfo.usagePercentage > 80 {
                return MicroverseDesign.Colors.warning
            } else {
                return MicroverseDesign.Colors.memory
            }
        }
    }
    
    private var pressureColor: Color {
        switch systemService.memoryInfo.pressure {
        case .critical:
            return MicroverseDesign.Colors.critical
        case .warning:
            return MicroverseDesign.Colors.warning
        case .normal:
            return MicroverseDesign.Colors.success
        }
    }
}