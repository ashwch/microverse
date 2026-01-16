import SwiftUI
import BatteryCore

/// Elegant unified design system for Microverse
/// Principles: Clarity, Deference, Depth, Consistency
enum MicroverseDesign {
    
    // MARK: - Semantic Color System
    
    enum Colors {
        // Primary brand colors
        static let accent = Color.white
        static let accentMuted = Color.white.opacity(0.8)
        static let accentSubtle = Color.white.opacity(0.6)
        
        // System status colors
        static let success = Color.green
        static let warning = Color.orange  
        static let critical = Color.red
        static let neutral = Color.blue
        
        // Metric-specific colors (semantic, not arbitrary)
        static let battery = success      // Energy = green
        static let processor = neutral    // Computing = blue
        static let memory = Color.purple  // Storage = purple
        static let system = accent        // Overall = white
        
        // UI colors
        static let background = Color.black.opacity(0.6)
        static let backgroundDark = Color.black.opacity(0.8)
        static let border = Color.white.opacity(0.15)
        static let divider = Color.white.opacity(0.2)
    }
    
    // MARK: - Typography Hierarchy (Consistent Across App)
    
    enum Typography {
        // Primary hierarchy
        static let display = Font.system(size: 32, weight: .bold, design: .rounded)    // Hero numbers
        static let largeTitle = Font.system(size: 24, weight: .bold, design: .rounded) // Section headers
        static let title = Font.system(size: 18, weight: .semibold, design: .rounded)  // Subsection headers
        static let body = Font.system(size: 14, weight: .medium, design: .rounded)     // Content
        static let caption = Font.system(size: 12, weight: .medium, design: .rounded)  // Labels
        static let label = Font.system(size: 10, weight: .semibold)                    // Small labels (uppercase)
        
        // Special purpose
        static let tabLabel = Font.system(size: 10, weight: .medium)
        static let percentage = Font.system(size: 28, weight: .bold, design: .rounded)
        static let metric = Font.system(size: 16, weight: .semibold, design: .rounded)
    }
    
    // MARK: - Layout System
    
    enum Layout {
        // Consistent spacing scale
        static let space1: CGFloat = 4    // micro
        static let space2: CGFloat = 8    // small  
        static let space3: CGFloat = 12   // medium
        static let space4: CGFloat = 16   // large
        static let space5: CGFloat = 24   // xlarge
        static let space6: CGFloat = 32   // xxlarge
        
        // Component sizes
        static let cornerRadius: CGFloat = 12
        static let cornerRadiusLarge: CGFloat = 16
        static let iconSize: CGFloat = 16
        static let iconSizeSmall: CGFloat = 12
        
        // Layout constants
        static let mainWidth: CGFloat = 280
        static let contentPadding: CGFloat = space4
        static let sectionSpacing: CGFloat = space5
    }
    
    // MARK: - Component Styles
    
    /// Consistent card style for all components
    static func cardBackground() -> some View {
        RoundedRectangle(cornerRadius: Layout.cornerRadius)
            .fill(Colors.background)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cornerRadius)
                    .stroke(Colors.border, lineWidth: 0.5)
            )
    }
    
    /// Unified metric style
    struct MetricStyle {
        let icon: String
        let color: Color
        let title: String
    }
    
    static let batteryMetric = MetricStyle(icon: "bolt.fill", color: Colors.battery, title: "BATTERY")
    static let cpuMetric = MetricStyle(icon: "cpu", color: Colors.processor, title: "PROCESSOR") 
    static let memoryMetric = MetricStyle(icon: "memorychip", color: Colors.memory, title: "MEMORY")
    static let systemMetric = MetricStyle(icon: "circle.grid.2x2", color: Colors.system, title: "SYSTEM")
    
    // MARK: - Animation System
    
    enum Animation {
        static let quick = SwiftUI.Animation.easeOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let notchToggle = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.85, blendDuration: 0)
        static let notchPeek = SwiftUI.Animation.easeInOut(duration: 0.32)
        static let notchExpansion = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.9)
        static let statusPulse = SwiftUI.Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
    }
    
    // MARK: - Notch-Specific Design System
    
    enum Notch {
        // Typography hierarchy for notch components
        enum Typography {
            static let compactIcon = Font.system(size: 10, weight: .semibold) // Smaller icon
            static let compactValue = Font.system(size: 12, weight: .semibold, design: .rounded) // Smaller text
            static let expandedIcon = Font.system(size: 14, weight: .medium)
            static let expandedValue = Font.system(size: 20, weight: .semibold, design: .rounded)
            static let expandedSecondaryValue = Font.system(size: 16, weight: .semibold, design: .rounded)
            static let expandedLabel = Font.system(size: 8, weight: .medium)
            static let expandedDetail = Font.system(size: 7, weight: .regular)
            static let brandLabel = Font.system(size: 11, weight: .medium, design: .rounded)
            static let timeDisplay = Font.system(size: 12, weight: .semibold, design: .rounded)
            static let statusText = Font.system(size: 9, weight: .medium)
            static let liveIndicator = Font.system(size: 8, weight: .medium)
        }
        
        // Spacing system for notch components
        enum Spacing {
            static let compactInternal: CGFloat = Layout.space1 * 0.5   // 2pt - tighter
            static let compactHorizontal: CGFloat = Layout.space1       // 4pt - much more compact
            static let compactVertical: CGFloat = Layout.space1 * 0.5   // 2pt - tighter
            static let expandedSection: CGFloat = Layout.space6         // 32pt
            static let expandedInternal: CGFloat = Layout.space2        // 8pt
            static let expandedDivider: CGFloat = Layout.space2         // 8pt
            static let expandedContainer: CGFloat = Layout.space5       // 24pt
            static let separatorWidth: CGFloat = Layout.space1 - 1      // 3pt
            static let separatorHeight: CGFloat = Layout.space1 - 1     // 3pt
            static let metricSpacing: CGFloat = Layout.space2 - 2       // 6pt
            static let statusSpacing: CGFloat = Layout.space1           // 4pt
            static let brandSpacing: CGFloat = Layout.space2            // 8pt
        }
        
        // Dimensions and proportions
        enum Dimensions {
            static let expandedWidth: CGFloat = Layout.mainWidth + 40   // 320pt (Golden ratio)
            static let compactCornerRadius: CGFloat = Layout.space2 - 2 // 6pt
            static let expandedCornerRadius: CGFloat = Layout.space5 - 4 // 20pt
            static let brandIndicatorSize: CGFloat = Layout.space2 - 3  // 5pt
            static let statusIndicatorSize: CGFloat = Layout.space2 - 2 // 6pt
            
            // Compact, space-efficient notch widgets
            static let compactWidgetMinWidth: CGFloat = Layout.space5 + Layout.space2 // 32pt minimum - much more compact
            static let compactWidgetHeight: CGFloat = Layout.space4 + Layout.space1 // 20pt height - reduced
        }
        
        // Material system for notch
        enum Materials {
            static let compactBackground = Material.ultraThinMaterial
            static let compactOpacity: Double = 0.15
            static let expandedBackground = Material.ultraThinMaterial
            static let expandedOpacity: Double = 0.1
            static let expandedBackdrop = Color.black.opacity(0.75)
            static let strokeOpacity: Double = 0.1
            static let expandedStrokeOpacity: Double = 0.08
            static let strokeWidth: CGFloat = 0.5
            static let expandedStrokeWidth: CGFloat = 1.0
            static let dividerOpacity: Double = 0.15
            static let separatorOpacity: Double = 0.4
        }
        
        // Color opacity system
        enum Opacity {
            static let brandIndicator: Double = 0.9
            static let brandText: Double = 0.8
            static let timeText: Double = 0.95
            static let statusText: Double = 0.6
            static let liveText: Double = 0.4
            static let detailText: Double = 0.4
        }
        
        // Performance and behavior constants
        enum Performance {
            static let batteryThresholdLow: Int = 20
            static let batteryThresholdMedium: Int = 50
            static let cpuThresholdWarning: Double = 60
            static let cpuThresholdCritical: Double = 80
            static let systemHealthThresholdLow: Int = 15
            static let systemHealthThresholdMedium: Int = 25
        }
    }
}

// MARK: - Unified Components

/// Notch-specific compact metric component with proper design system compliance
struct NotchCompactMetric: View {
    let icon: String
    let value: Int
    let color: Color
    let isPrimary: Bool
    
    init(icon: String, value: Int, color: Color, isPrimary: Bool = false) {
        self.icon = icon
        self.value = value
        self.color = color
        self.isPrimary = isPrimary
    }
    
    var body: some View {
        HStack(spacing: isPrimary ? MicroverseDesign.Notch.Spacing.compactInternal : MicroverseDesign.Notch.Spacing.compactInternal - 1) {
            Image(systemName: icon)
                .font(isPrimary ? MicroverseDesign.Notch.Typography.compactIcon : MicroverseDesign.Notch.Typography.compactIcon.weight(.medium))
                .foregroundColor(color)
                .symbolRenderingMode(.monochrome)
                .frame(width: MicroverseDesign.Layout.iconSizeSmall, alignment: .center) // Compact icon width
            
            Text("\(value)")
                .font(isPrimary ? MicroverseDesign.Notch.Typography.compactValue : MicroverseDesign.Notch.Typography.compactValue.weight(.medium))
                .foregroundColor(MicroverseDesign.Colors.accent)
                .monospacedDigit()
                .frame(minWidth: MicroverseDesign.Layout.space3, alignment: .leading) // Compact minimum width
        }
        .frame(
            minWidth: MicroverseDesign.Notch.Dimensions.compactWidgetMinWidth,
            minHeight: MicroverseDesign.Notch.Dimensions.compactWidgetHeight
        ) // Perfect symmetry constraints
    }
}

/// Notch-specific expanded metric component
struct NotchExpandedMetric: View {
    let icon: String
    let label: String
    let value: String
    let detail: String
    let color: Color
    let isPrimary: Bool
    
    init(icon: String, label: String, value: String, detail: String, color: Color, isPrimary: Bool = false) {
        self.icon = icon
        self.label = label
        self.value = value
        self.detail = detail
        self.color = color
        self.isPrimary = isPrimary
    }
    
    var body: some View {
        VStack(spacing: MicroverseDesign.Notch.Spacing.metricSpacing) {
            Image(systemName: icon)
                .font(isPrimary ? MicroverseDesign.Notch.Typography.expandedIcon : MicroverseDesign.Notch.Typography.expandedIcon)
                .foregroundColor(color)
                .symbolRenderingMode(.monochrome)
            
            Text(value)
                .font(isPrimary ? MicroverseDesign.Notch.Typography.expandedValue : MicroverseDesign.Notch.Typography.expandedSecondaryValue)
                .foregroundColor(MicroverseDesign.Colors.accent)
                .monospacedDigit()
            
            Text(label.lowercased())
                .font(MicroverseDesign.Notch.Typography.expandedLabel)
                .foregroundColor(MicroverseDesign.Colors.accentSubtle)
                .tracking(0.8)
            
            Text(detail.lowercased())
                .font(MicroverseDesign.Notch.Typography.expandedDetail)
                .foregroundColor(.white.opacity(MicroverseDesign.Notch.Opacity.detailText))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Consistent metric display component
struct UnifiedMetric: View {
    let style: MicroverseDesign.MetricStyle
    let value: String
    let subtitle: String?
    
    init(style: MicroverseDesign.MetricStyle, value: String, subtitle: String? = nil) {
        self.style = style
        self.value = value
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(spacing: MicroverseDesign.Layout.space1) {
            // Icon with consistent size and color
            Image(systemName: style.icon)
                .font(.system(size: MicroverseDesign.Layout.iconSize, weight: .medium))
                .foregroundColor(style.color)
            
            // Value with consistent typography
            Text(value)
                .font(MicroverseDesign.Typography.metric)
                .foregroundColor(MicroverseDesign.Colors.accent)
            
            // Title label with consistent style
            Text(style.title)
                .font(MicroverseDesign.Typography.label)
                .foregroundColor(MicroverseDesign.Colors.accentSubtle)
                .tracking(0.8)
            
            // Optional subtitle
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(MicroverseDesign.Typography.caption)
                    .foregroundColor(MicroverseDesign.Colors.accentMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Consistent section header
struct SectionHeader: View {
    let title: String
    let systemIcon: String?
    
    init(_ title: String, systemIcon: String? = nil) {
        self.title = title
        self.systemIcon = systemIcon
    }
    
    var body: some View {
        HStack {
            if let icon = systemIcon {
                Image(systemName: icon)
                    .font(.system(size: MicroverseDesign.Layout.iconSizeSmall, weight: .medium))
                    .foregroundColor(MicroverseDesign.Colors.accentSubtle)
            }
            
            Text(title.uppercased())
                .font(MicroverseDesign.Typography.label)
                .foregroundColor(MicroverseDesign.Colors.accentSubtle)
                .tracking(1.2)
            
            Spacer()
        }
    }
}

/// Consistent insight row
struct InsightRow: View {
    let icon: String
    let message: String
    let level: InsightLevel
    
    enum InsightLevel {
        case normal, warning, critical
        
        var color: Color {
            switch self {
            case .normal: return MicroverseDesign.Colors.success
            case .warning: return MicroverseDesign.Colors.warning
            case .critical: return MicroverseDesign.Colors.critical
            }
        }
    }
    
    var body: some View {
        HStack(spacing: MicroverseDesign.Layout.space2) {
            Image(systemName: icon)
                .font(.system(size: MicroverseDesign.Layout.iconSizeSmall, weight: .medium))
                .foregroundColor(level.color)
                .frame(width: 16) // Consistent icon alignment
            
            Text(message)
                .font(MicroverseDesign.Typography.caption)
                .foregroundColor(MicroverseDesign.Colors.accent)
            
            Spacer()
        }
    }
}

/// Consistent info row for key-value pairs
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(MicroverseDesign.Typography.caption)
                .foregroundColor(MicroverseDesign.Colors.accentMuted)
            
            Spacer()
            
            Text(value)
                .font(MicroverseDesign.Typography.caption)
                .foregroundColor(MicroverseDesign.Colors.accent)
        }
    }
}
