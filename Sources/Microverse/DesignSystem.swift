import SwiftUI
import BatteryCore

/// Centralized design system for consistent UI across the app
/// Following Johnny Ive's principles: clarity, deference, and depth
enum DesignSystem {
    
    // MARK: - Colors
    
    /// Battery color based on charge level and charging state
    static func batteryColor(for info: BatteryInfo) -> Color {
        if info.currentCharge <= 10 {
            return .red
        } else if info.currentCharge <= 20 {
            return .orange
        } else if info.isCharging {
            return .green
        } else {
            return .white
        }
    }
    
    /// Battery icon name based on charge level and charging state
    static func batteryIconName(for info: BatteryInfo) -> String {
        let baseIcon = info.currentCharge <= 10 ? "battery.0" :
                      info.currentCharge <= 25 ? "battery.25" :
                      info.currentCharge <= 50 ? "battery.50" :
                      info.currentCharge <= 75 ? "battery.75" : "battery.100"
        
        return info.isCharging ? "\(baseIcon).bolt" : baseIcon
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let micro: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xlarge: CGFloat = 32
    }
    
    // MARK: - Typography
    
    enum Typography {
        // Widget fonts
        static let widgetLargeTitle = Font.system(size: 36, weight: .bold, design: .rounded)
        static let widgetTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        static let widgetHeadline = Font.system(size: 20, weight: .medium, design: .rounded)
        static let widgetBody = Font.system(size: 16, weight: .medium, design: .rounded)
        static let widgetCaption = Font.system(size: 12)
        static let widgetSmallCaption = Font.system(size: 10)
        
        // Main UI fonts
        static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title = Font.system(size: 20, weight: .semibold)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 15)
        static let caption = Font.system(size: 13)
        static let smallCaption = Font.system(size: 11)
    }
    
    // MARK: - Corner Radius
    
    enum CornerRadius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let large: CGFloat = 10
        static let xlarge: CGFloat = 12
        static let xxlarge: CGFloat = 16
    }
    
    // MARK: - Animation
    
    enum Animation {
        static let defaultDuration: Double = 0.25
        static let springResponse: Double = 0.5
        static let springDamping: Double = 0.8
        
        static let defaultSpring = SwiftUI.Animation.spring(
            response: springResponse,
            dampingFraction: springDamping
        )
        
        static let easeInOut = SwiftUI.Animation.easeInOut(duration: defaultDuration)
    }
    
    // MARK: - Widget Sizes
    
    enum WidgetSize {
        static let minimal = CGSize(width: 100, height: 40)
        static let compact = CGSize(width: 160, height: 50)
        static let standard = CGSize(width: 180, height: 100)
        static let detailed = CGSize(width: 240, height: 120)
    }
    
    // MARK: - Opacity
    
    enum Opacity {
        static let background: Double = 0.7
        static let secondaryText: Double = 0.6
        static let divider: Double = 0.2
        static let border: Double = 0.1
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Apply standard widget background
    func widgetBackground(material: NSVisualEffectView.Material = .hudWindow) -> some View {
        self.background(
            VisualEffectBlur(material: material, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xlarge))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xlarge)
                        .stroke(Color.white.opacity(DesignSystem.Opacity.border), lineWidth: 0.5)
                )
        )
    }
    
    /// Apply standard dark background
    func darkBackground(cornerRadius: CGFloat = DesignSystem.CornerRadius.medium) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(DesignSystem.Opacity.background))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(DesignSystem.Opacity.border), lineWidth: 0.5)
                )
        )
    }
}