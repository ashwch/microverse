# Microverse Design System

> **A comprehensive design system for elegant macOS system monitoring with smart notch integration and sophisticated desktop widgets**

## Design Philosophy

### Design Principles
- **Clarity**: Information hierarchy through semantic color and typography systems
- **Deference**: UI serves content, never competes with system metrics
- **Depth**: Layered information through glass effects, blur backgrounds, and proper spacing
- **Integration**: Seamless harmony with macOS design language and system behaviors

### Core Values
- **Semantic Color System**: Green=energy, Blue=computing, Purple=memory, White=system
- **Unified Interface**: Consistent design language across tabs, widgets, and notch integration
- **Adaptive Behavior**: Responsive to system state, user context, and environmental changes
- **Glass Aesthetics**: Elegant blur backgrounds with subtle borders and transparency
- **Native Feel**: Follows macOS Human Interface Guidelines with modern enhancements

## Current Architecture

### Smart Notch Integration System
```
┌─────────────────────────────────────────────────────┐
│                    MacBook Notch                    │
├─────────────────────────────────────────────────────┤
│  🍎 [Compact Widget] 80% ⚙20% 🧠47%   [Brand] 👽   │ <- Left Mode
│                                                     │
│  🍎 80% ••• | 👽 Microverse | ••• ⚙19% 🧠48%      │ <- Split Mode  
├─────────────────────────────────────────────────────┤
│              DynamicNotchKit Integration            │
└─────────────────────────────────────────────────────┘
```

### Main Application Interface (280×500)
```
┌─────────────────────────────────┐
│ ◐ Overview  🔋 Battery  ⚙ CPU  │ <- Tab Bar
│           🧠 Memory             │    
├─────────────────────────────────┤
│                                 │
│     [Dynamic Tab Content]       │ <- 400px content area
│                                 │
├─────────────────────────────────┤
│ ⚙ Settings     About    Quit   │ <- Action Bar
└─────────────────────────────────┘
```

### Desktop Widget Ecosystem
```
System Glance (Horizontal)     System Status (3-Column)      System Dashboard (Full)
┌─────────────────────────┐    ┌──────────────────────────┐   ┌────────────────────────────┐
│ 🔋80 ⚙17 🧠47          │    │ 🔋   ⚙   🧠            │   │ 80%        • Optimal       │
│ ••• ••• %               │    │ 80%  20%  47%           │   │ 🔋 BATTERY    ⚙20% 🧠47%  │
└─────────────────────────┘    │                          │   │ Cycles: 79                 │
                               └──────────────────────────┘   └────────────────────────────┘
```

## Design Token System

### Semantic Color Architecture
```swift
// Core semantic colors that adapt to system state
enum SemanticColors {
    // Primary metric colors
    static let battery = Color.green        // Energy/Power (85% healthy -> green)
    static let processor = Color.blue       // Computing/Performance  
    static let memory = Color.purple        // Storage/Memory pressure
    static let system = Color.white         // Overall system status
    
    // Adaptive status colors
    static let optimal = Color.green        // Health score: Excellent
    static let moderate = Color.orange      // Health score: Moderate  
    static let stressed = Color.red         // Health score: Stressed
    
    // Glass system colors
    static let background = Color.black.opacity(0.85)
    static let border = Color.white.opacity(0.1)
    static let accent = Color.white
    static let accentSubtle = Color.white.opacity(0.6)
}
```

### Typography Hierarchy
```swift
// SF Pro Rounded for native macOS feel with modern enhancement
enum Typography {
    // Hero displays for main metrics
    static let display = Font.system(size: 32, weight: .bold, design: .rounded)
    
    // Section headers and prominent labels  
    static let largeTitle = Font.system(size: 24, weight: .bold, design: .rounded)
    
    // Subsection headers and formatted values
    static let title = Font.system(size: 18, weight: .semibold, design: .rounded)
    
    // Standard content and descriptions
    static let body = Font.system(size: 14, weight: .medium, design: .rounded)
    
    // Status text and secondary information
    static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
    
    // Compact labels and widget text
    static let small = Font.system(size: 10, weight: .semibold, design: .rounded)
}
```

### Layout System (4px Grid)
```swift
enum Layout {
    // Spacing scale
    static let space1: CGFloat = 4     // micro spacing
    static let space2: CGFloat = 8     // small spacing  
    static let space3: CGFloat = 12    // medium spacing
    static let space4: CGFloat = 16    // large spacing
    static let space5: CGFloat = 24    // xlarge spacing
    static let space6: CGFloat = 32    // xxlarge spacing
    
    // Corner radii
    static let cornerRadius: CGFloat = 12      // Standard components
    static let cornerRadiusLarge: CGFloat = 16 // Widget backgrounds
    static let cornerRadiusSmall: CGFloat = 8  // Tab buttons
    
    // Standard dimensions
    static let tabHeight: CGFloat = 36
    static let cardPadding: CGFloat = 12
    static let popoverWidth: CGFloat = 280
    static let popoverHeight: CGFloat = 500
}
```

## Smart Notch Integration

### MicroverseNotchSystem Architecture
```swift
// Core notch integration using DynamicNotchKit
class MicroverseNotchSystem {
    // Notch display modes
    enum NotchMode {
        case left       // All metrics on left side
        case split      // Metrics split around notch with branding
        case off        // Disabled notch integration
    }
    
    // State-driven notch content
    func updateNotchContent(
        battery: Int,
        cpu: Int, 
        memory: Int,
        health: SystemHealth
    )
}
```

### Notch Widget Design Specifications

#### Compact Mode (Left Aligned)
```swift
NotchWidgetCompact {
    HStack(spacing: 8) {
        BatteryIcon(percentage: 80)
        Text("80%").font(.system(size: 14, weight: .semibold))
        
        ProcessorIcon()
        Text("19%").font(.system(size: 14, weight: .semibold))
        
        MemoryIcon() 
        Text("48%").font(.system(size: 14, weight: .semibold))
    }
    .foregroundColor(.white)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
}
```

#### Expanded Mode (Health Status)
```swift
NotchWidgetExpanded {
    HStack(spacing: 12) {
        SystemHealthBadge("Optimal", color: .green)
        
        HStack(spacing: 8) {
            Text("80%").bold()
            Text("20%").foregroundColor(.blue)
            Text("47%").foregroundColor(.purple)
            Text("100%").foregroundColor(.green)
        }
        
        Text("Cycles: 79").caption()
    }
    .glassMorphismBackground()
}
```

## Desktop Widget System

### Widget Style Architecture
```swift
enum WidgetStyle: CaseIterable {
    case glance      // Horizontal compact: Battery, CPU, Memory
    case status      // Three-column detailed view  
    case dashboard   // Comprehensive with health status
    
    var size: NSSize {
        switch self {
        case .glance:    return NSSize(width: 374, height: 182)
        case .status:    return NSSize(width: 556, height: 230) 
        case .dashboard: return NSSize(width: 556, height: 304)
        }
    }
}
```

### Glass Morphism Background System
```swift
extension View {
    func glassMorphismBackground() -> some View {
        self.background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .backdrop(material: .ultraThinMaterial, blendMode: .overlay)
        )
    }
}
```

## Application Interface Design

### Tab System Implementation
```swift
// TabbedMainView with sophisticated state management
struct TabbedMainView: View {
    @State private var selectedTab: Tab = .overview
    @ObservedObject var viewModel: BatteryViewModel
    @ObservedObject var systemService: SystemMonitoringService
    
    enum Tab: CaseIterable {
        case overview, battery, cpu, memory
        
        var icon: String {
            switch self {
            case .overview: return "chart.pie.fill"
            case .battery: return "battery.100percent" 
            case .cpu: return "cpu.fill"
            case .memory: return "memorychip.fill"
            }
        }
    }
}
```

### Unified Component System

#### UnifiedMetric Component
```swift
struct UnifiedMetric: View {
    let value: String
    let subtitle: String?
    let color: Color
    let icon: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(color)
                }
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}
```

#### HealthStatusCard Component
```swift
struct HealthStatusCard: View {
    let status: SystemHealth
    let metrics: SystemMetrics
    
    var body: some View {
        HStack {
            SystemHealthIcon(status)
            
            VStack(alignment: .leading) {
                Text("SYSTEM HEALTH")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                Text(status.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(status.color)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                MetricPill("🔋\(metrics.battery)%", color: .green)
                MetricPill("⚙\(metrics.cpu)%", color: .blue)  
                MetricPill("🧠\(metrics.memory)%", color: .purple)
            }
        }
        .cardBackground()
    }
}
```

## State Management & Reactivity

### SystemMonitoringService Architecture
```swift
@MainActor
class SystemMonitoringService: ObservableObject {
    // Published state for reactive UI
    @Published var cpuUsage: Double = 0
    @Published var memoryInfo: MemoryInfo = MemoryInfo()
    @Published var systemHealth: SystemHealth = .optimal
    
    // Adaptive refresh rates based on system state
    private var refreshInterval: TimeInterval {
        switch systemHealth {
        case .stressed: return 2.0    // Frequent updates when stressed
        case .moderate: return 5.0    // Standard rate
        case .optimal: return 10.0    // Reduced when stable
        }
    }
}
```

### SecureUpdateService Integration
```swift
@MainActor
class SecureUpdateService: ObservableObject {
    @Published var updateState: UpdateState = .idle
    @Published var currentVersion: String = Bundle.main.version
    
    // Sparkle integration with design system
    func checkForUpdatesWithUI() {
        // Custom UI using MicroverseDesign components
        UpdateView(service: self)
            .presentAsSheet()
    }
}
```

## Color Psychology & Semantic Mapping

### Battery Status Colors
```swift
extension BatteryInfo {
    var semanticColor: Color {
        switch currentCharge {
        case ...10:   return .red      // Critical: Immediate attention
        case 11...20: return .orange   // Warning: Low power
        case 21...80: return .white    // Normal: Standard operation
        case 81...:   return .green    // Optimal: Healthy charge
        default:      return .white
        }
    }
}
```

### CPU Performance Colors  
```swift
extension Double {
    var cpuColor: Color {
        switch self {
        case ...40:   return .blue.opacity(0.7)  // Light load
        case 41...70: return .blue               // Moderate load
        case 71...85: return .orange             // High load
        case 86...:   return .red                // Critical load
        default:      return .blue
        }
    }
}
```

### Memory Pressure Mapping
```swift
enum MemoryPressure {
    case normal, warning, critical
    
    var color: Color {
        switch self {
        case .normal:   return .purple           // Healthy memory usage
        case .warning:  return .orange           // Approaching limits
        case .critical: return .red              // Swap/pressure detected
        }
    }
}
```

## Animation & Transition System

### Standard Animation Curves
```swift
enum Animation {
    static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
    static let spring = SwiftUI.Animation.spring(duration: 0.5, bounce: 0.3)
    static let quick = SwiftUI.Animation.easeOut(duration: 0.15)
    static let slow = SwiftUI.Animation.easeInOut(duration: 0.8)
}
```

### Progress Animation Implementation
```swift
struct AnimatedProgressBar: View {
    let value: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                
                Rectangle()
                    .fill(color)
                    .frame(width: geometry.size.width * value / 100)
                    .animation(.easeInOut(duration: 0.3), value: value)
            }
        }
        .frame(height: 4)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}
```

## Accessibility & Inclusive Design

### VoiceOver Support
```swift
extension View {
    func metricAccessibility(value: String, description: String) -> some View {
        self.accessibilityElement(children: .combine)
            .accessibilityLabel("\(description): \(value)")
            .accessibilityAddTraits(.updatesFrequently)
    }
}
```

### High Contrast Adaptation
```swift
extension Color {
    var highContrastVariant: Color {
        if AccessibilitySettings.isHighContrastEnabled {
            return self == .white ? .black : .white
        }
        return self
    }
}
```

### Reduced Motion Support
```swift
extension Animation {
    static var respectMotion: SwiftUI.Animation? {
        AccessibilitySettings.isReduceMotionEnabled ? nil : .standard
    }
}
```

## Advanced Features

### Adaptive Refresh System
```swift
class AdaptiveDisplayService {
    // Intelligently adjusts refresh rates based on:
    // - Battery level (2s when critical ≤5%)
    // - System load (faster when stressed)
    // - User interaction (immediate when active)
    // - Power state (slower when plugged at 100%)
    
    func calculateOptimalRefreshRate(
        battery: BatteryInfo,
        systemLoad: SystemMetrics,
        userActive: Bool
    ) -> TimeInterval {
        // Sophisticated algorithm for battery preservation
    }
}
```

### NotchDisplayManager
```swift
class NotchDisplayManager: ObservableObject {
    @Published var currentMode: NotchMode = .left
    @Published var isVisible: Bool = true
    
    // Manages notch content lifecycle
    func updateNotchDisplay(with metrics: SystemMetrics) {
        // DynamicNotchKit integration
        // Content layout optimization
        // State synchronization
    }
}
```

## Performance Optimization

### Rendering Efficiency
```swift
// Optimized view updates using @Published selectively
class OptimizedViewModel: ObservableObject {
    @Published private(set) var displayMetrics: DisplayMetrics
    
    private var _rawMetrics: RawMetrics {
        didSet {
            // Only update @Published when visual change needed
            let newDisplay = _rawMetrics.forDisplay()
            if newDisplay != displayMetrics {
                displayMetrics = newDisplay
            }
        }
    }
}
```

### Memory Management
```swift
// Weak references prevent retain cycles
class WidgetManager {
    weak var viewModel: BatteryViewModel?
    weak var notchManager: NotchDisplayManager?
    
    // Efficient widget recreation
    func updateWidget() {
        // Minimize object allocation
        // Reuse existing views when possible
    }
}
```

## Design Evolution & Future

### Extensibility Framework
- **New Metrics**: Color system accommodates additional categories
- **Widget Styles**: Component architecture supports infinite variations  
- **Notch Layouts**: DynamicNotchKit enables custom arrangements
- **Theme System**: Foundation for light/dark/auto themes

### Performance Targets
- **CPU Impact**: <1% average usage maintained
- **Memory Footprint**: <50MB target preserved
- **Battery Drain**: <2% daily impact achieved
- **Responsiveness**: <100ms interaction response time

This design system provides comprehensive guidance for maintaining visual consistency, implementing new features, and ensuring the elegant user experience that defines Microverse's sophisticated approach to system monitoring.