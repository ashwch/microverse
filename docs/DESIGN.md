# Microverse Design System v3.0

## Design Philosophy

### Design Principles
- **Clarity**: Information hierarchy through semantic color and typography
- **Deference**: UI serves content, never competes with system metrics
- **Depth**: Layered information through blur effects and proper spacing

### Core Values
- **Semantic Color System**: Green=energy, Blue=computing, Purple=memory, White=system
- **Unified Interface**: Consistent design language across tabs and widgets
- **Adaptive Behavior**: Responsive to system state and user context
- **Glass Aesthetics**: Elegant blur backgrounds with subtle borders

## Current Interface (v3.0)

### Main Popover (280×500)
```
┌─────────────────────────────────┐
│ ◐ Overview  ⚡ Battery  ⚙ CPU   │ <- Tab Bar
│           🧠 Memory             │    
├─────────────────────────────────┤
│                                 │
│     [Dynamic Tab Content]       │ <- 400px content area
│                                 │
├─────────────────────────────────┤
│ ⚙ Settings     About    Quit   │ <- Action Bar
└─────────────────────────────────┘
```

### Tab Content Areas

#### Overview Tab
- Unified metrics display with consistent spacing
- Battery, CPU, Memory status in semantic colors
- Clean typography hierarchy

#### Battery Tab  
- Large percentage display (32pt SF Pro Rounded)
- Health metrics and cycle count
- Time remaining with proper contrast

#### CPU Tab
- Real-time usage percentage
- Basic system information
- Consistent with overall design language

#### Memory Tab
- Memory usage and pressure indicators
- Clean metric presentation
- Unified color coding

## Widget System (6 Styles)

### Single Metric Widgets
1. **Battery Simple (100×40)**: Just battery percentage with charging indicator
2. **CPU Monitor (160×80)**: CPU usage with progress bar and status text
3. **Memory Monitor (160×80)**: Memory usage percentage with pressure indicator

### Multi-Metric System Widgets
4. **System Glance (160×50)**: Compact horizontal view of Battery + CPU + Memory percentages
5. **System Status (240×80)**: Three-column layout with icons and percentages for all metrics
6. **System Dashboard (240×120)**: Full detailed view with system health, all metrics, battery cycles, and time remaining

### Unified Widget Background
```swift
.background(
    RoundedRectangle(cornerRadius: 16)
        .fill(Color.black.opacity(0.85))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
)
```

## Design Tokens

### Color System
```swift
enum Colors {
    // Semantic colors
    static let battery = success      // Energy = green
    static let processor = neutral    // Computing = blue  
    static let memory = Color.purple  // Storage = purple
    static let system = accent        // Overall = white
    
    // Status colors
    static let success = Color.green
    static let warning = Color.orange  
    static let critical = Color.red
    static let neutral = Color.blue
}
```

### Typography Hierarchy
```swift
enum Typography {
    static let display = Font.system(size: 32, weight: .bold, design: .rounded)    // Hero numbers
    static let largeTitle = Font.system(size: 24, weight: .bold, design: .rounded) // Section headers
    static let title = Font.system(size: 18, weight: .semibold, design: .rounded)  // Subsection headers
    static let body = Font.system(size: 14, weight: .medium, design: .rounded)     // Content
    static let caption = Font.system(size: 12, weight: .medium, design: .rounded)  // Labels
    static let label = Font.system(size: 10, weight: .semibold)                    // Small labels (uppercase)
}
```

### Layout System
```swift
enum Layout {
    static let space1: CGFloat = 4    // micro
    static let space2: CGFloat = 8    // small  
    static let space3: CGFloat = 12   // medium
    static let space4: CGFloat = 16   // large
    static let space5: CGFloat = 24   // xlarge
    static let space6: CGFloat = 32   // xxlarge
    
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16
}
```

## Component Library

### UnifiedMetric Component
Consistent metric display across all tabs:
```swift
UnifiedMetric(
    style: MicroverseDesign.batteryMetric,
    value: "85%",
    subtitle: "3:42 remaining"
)
```

### SectionHeader Component
Consistent section labeling:
```swift
SectionHeader("BATTERY HEALTH", systemIcon: "heart.fill")
```

### InsightRow Component  
Status and alert display:
```swift
InsightRow(
    icon: "checkmark.circle.fill",
    message: "Battery health is excellent",
    level: .normal
)
```

## Implementation Guidelines

### Visual Consistency
- All components use semantic color system
- Typography follows established hierarchy  
- Spacing adheres to 4px grid system
- Corner radius consistent across components

### Interaction Design
- 0.3s spring animations for state changes
- Hover states with subtle opacity changes
- Tab transitions with slide + fade effect
- Button interactions with haptic feedback

### Accessibility
- High contrast mode support
- VoiceOver descriptions for all metrics
- Keyboard navigation between tabs
- Reduced motion respect for animations

## Future Considerations

### Expandability
- Design system supports additional metric types
- Color palette accommodates new categories
- Layout system scales to more complex interfaces
- Component library enables rapid feature development

### Performance
- Efficient rendering with minimal redraws
- Cached color and font objects
- Optimized animation performance
- Lazy loading for complex views

## Detailed Implementation Specifications

### Tab Implementation Details

#### Tab Button Design (TabbedMainView.swift:140-168)
```swift
struct TabButton: View {
    // Fixed dimensions: maxWidth: .infinity, minHeight: 36
    // Background: RoundedRectangle(cornerRadius: 8)
    // Selected state: Color.black.opacity(0.3)
    // Icon: 14pt weight .medium
    // Text: 9pt weight .medium, tracking 0.5, uppercase
    // Color: .white (selected) vs .white.opacity(0.6) (unselected)
}
```

#### Section Header Pattern (UnifiedDesignSystem.swift:152-177)
```swift
struct SectionHeader: View {
    // Standard implementation across all tabs
    // Text: uppercased with tracking 1.2
    // Icon: 12pt weight .medium, optional leading icon
    // Color: accentSubtle (white.opacity(0.6))
    // Spacing: HStack with Spacer() trailing
}
```

### Widget Layout Specifications

#### DetailedSystemWidget (240×120)
- **Content**: Battery percentage, CPU/Memory/Health metrics
- **Layout**: Simplified without "SYSTEM" header to fit content
- **Padding**: Layout.space2 (8px) for maximum content area
- **Spacing**: Minimal (space1 = 4px) between elements
- **Note**: Removed status text to prevent cropping

### Widget Rendering Specifications

#### Widget Size Constraints
```swift
// DesktopWidget.swift:80-90
private func sizeForStyle(_ style: WidgetStyle) -> NSSize {
    switch style {
    case .minimal: return NSSize(width: 100, height: 40)
    case .compact: return NSSize(width: 160, height: 50)  
    case .standard: return NSSize(width: 180, height: 100)
    case .detailed: return NSSize(width: 240, height: 120)
    case .cpu, .memory: return NSSize(width: 160, height: 80)
    case .system: return NSSize(width: 240, height: 100) // Compact to prevent cropping
    }
}
```

#### Widget Background Implementation
```swift
// DesktopWidget.swift:388-404
extension View {
    func widgetBackground() -> some View {
        self.background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
```

### Color Threshold Specifications

#### Battery Color Logic (UnifiedBatteryTab.swift:111-121)
```swift
private var batteryColor: Color {
    if viewModel.batteryInfo.currentCharge <= 10 {
        return MicroverseDesign.Colors.critical  // Red
    } else if viewModel.batteryInfo.currentCharge <= 20 {
        return MicroverseDesign.Colors.warning   // Orange
    } else if viewModel.batteryInfo.isCharging {
        return MicroverseDesign.Colors.success   // Green
    } else {
        return MicroverseDesign.Colors.battery   // White/Green
    }
}
```

#### CPU Color Thresholds (UnifiedCPUTab.swift:82-90)
```swift
private var cpuColor: Color {
    if systemService.cpuUsage > 80 {
        return MicroverseDesign.Colors.critical  // Red
    } else if systemService.cpuUsage > 60 {
        return MicroverseDesign.Colors.warning   // Orange
    } else {
        return MicroverseDesign.Colors.processor // Blue
    }
}
```

#### Memory Pressure Colors (UnifiedMemoryTab.swift:99-112)
```swift
private var memoryColor: Color {
    switch systemService.memoryInfo.pressure {
    case .critical: return MicroverseDesign.Colors.critical  // Red
    case .warning: return MicroverseDesign.Colors.warning    // Orange
    case .normal:
        if systemService.memoryInfo.usagePercentage > 80 {
            return MicroverseDesign.Colors.warning           // Orange
        } else {
            return MicroverseDesign.Colors.memory            // Purple
        }
    }
}
```

### Animation Specifications

#### Progress Bar Animations (UnifiedCPUTab.swift:34)
```swift
.animation(MicroverseDesign.Animation.standard, value: systemService.cpuUsage)

// Where Animation.standard = SwiftUI.Animation.easeInOut(duration: 0.3)
```

#### Widget Recreation Animation (BatteryViewModel.swift:95-110)
```swift
// No explicit animation - immediate hide/show for setting changes
if showDesktopWidget {
    widgetManager?.hideWidget()
    widgetManager?.showWidget()
}
```

### Typography Implementation

#### Display Typography Usage
- **32pt Display**: CPU/Memory percentage displays, system health text
- **24pt Large Title**: Battery percentage in main tab
- **18pt Title**: Memory usage "X.X / Y.Y GB" format
- **14pt Body**: Standard content text, time remaining
- **12pt Caption**: Status text, info row labels
- **10pt Label**: Uppercase section headers, widget labels

#### Font Weight Strategy
- **Bold**: Hero numbers, important percentages
- **Semibold**: Section headers, subsection titles
- **Medium**: Body content, button text, metric labels
- **Regular**: Secondary information, descriptions

### Spacing Implementation

#### Card Padding Standards
```swift
// All cards use consistent 12pt internal padding
.padding(12)
.background(MicroverseDesign.cardBackground())

// Tab content uses 8pt external padding for breathing room
.padding(8)

// Widget cards use smaller 6pt external padding
.padding(6)
```

#### Element Spacing Patterns
```swift
// VStack spacing between cards: 8pt
VStack(spacing: 8) { ... }

// VStack spacing within cards: MicroverseDesign.Layout.space3 (12pt)
VStack(spacing: MicroverseDesign.Layout.space3) { ... }

// HStack spacing for metrics: 12pt
HStack(spacing: 12) { ... }

// Small element spacing: MicroverseDesign.Layout.space2 (8pt)
HStack(spacing: MicroverseDesign.Layout.space2) { ... }
```

### Error State Design

#### Default Value Strategy
```swift
// BatteryInfo defaults when system access fails
BatteryInfo(
    currentCharge: 0,
    isCharging: false,
    isPluggedIn: false,
    cycleCount: 0,
    maxCapacity: 100,
    timeRemaining: nil,
    health: 1.0
)

// MemoryInfo defaults for system call failures  
MemoryInfo(
    totalMemory: 0,
    usedMemory: 0,
    pressure: .normal,
    compressionRatio: 0
)
```

#### Fallback UI Patterns
- **Missing Time**: Show "—" dash character
- **Zero Values**: Display as 0% or 0 GB with normal styling
- **System Access Denied**: Graceful degradation with logging

### Accessibility Specifications

#### VoiceOver Support
- All metrics include descriptive labels
- Status indicators have semantic meaning
- Tab navigation follows logical order
- Button states are clearly announced

#### High Contrast Adaptation
- Color meanings preserved in high contrast mode
- Border weights increased for better definition
- Focus indicators meet WCAG standards

#### Reduced Motion Support
- Progress bar animations can be disabled
- Tab transitions respect motion preferences
- Widget updates remain functional without animation

This comprehensive design specification ensures consistent implementation and provides clear guidance for future development and maintenance.