import SwiftUI
import BatteryCore

/// Johnny Ive-inspired unified design system for Microverse
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
    }
}

// MARK: - Unified Components

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