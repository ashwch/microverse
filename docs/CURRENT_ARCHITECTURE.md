# Microverse Current Architecture v3.0

## Executive Summary

Microverse is a unified system monitoring application that combines elegant UI design with performance-optimized engineering. Built for macOS developers who need real-time insights into their system's health without compromising performance.

### Key Metrics
- **Performance**: <1% CPU impact, <50MB memory footprint
- **Architecture**: Async/await with concurrent system monitoring
- **UI Framework**: SwiftUI with semantic design system
- **Compatibility**: macOS 11.0+, Intel & Apple Silicon

## Overview

Microverse features a tabbed interface monitoring Battery, CPU, Memory, and unified system overview, built with Johnny Ive design principles and John Carmack engineering excellence.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Microverse App                        │
├─────────────────────────────────────────────────────────┤
│  UI Layer (SwiftUI)                                     │
│  ├── TabbedMainView (Main Interface)                    │
│  ├── UnifiedOverviewTab                                 │
│  ├── UnifiedBatteryTab                                  │
│  ├── UnifiedCPUTab                                      │
│  ├── UnifiedMemoryTab                                   │
│  └── DesktopWidget (6 widget styles)                   │
├─────────────────────────────────────────────────────────┤
│  ViewModels & Services                                  │
│  ├── BatteryViewModel (Settings & Battery State)       │
│  ├── SystemMonitoringService (Shared System Metrics)   │
│  └── DesktopWidgetManager (Widget Lifecycle)           │
├─────────────────────────────────────────────────────────┤
│  Core Frameworks                                        │
│  ├── BatteryCore (Battery Hardware Interface)          │
│  └── SystemCore (CPU & Memory Monitoring)              │
├─────────────────────────────────────────────────────────┤
│  Design System                                          │
│  ├── UnifiedDesignSystem (Colors, Typography, Layout)  │
│  └── MicroverseDesign (Component Library)              │
└─────────────────────────────────────────────────────────┘
```

## Detailed Component Architecture

### 1. UI Layer (SwiftUI)
#### Main Interface Components
- **TabbedMainView**: 280×500px main interface with 4 tabs
  - Tab navigation with flat button styling
  - Unified action bar (Settings, About, Quit)
  - Dynamic content area (400px height)

#### Tab Implementation Details
- **UnifiedOverviewTab**: System health dashboard with compact metrics display
  - Health scoring algorithm (Excellent/Moderate/Stressed)
  - Insight generation based on CPU/memory thresholds
  - 3-metric compact display (Battery/CPU/Memory)

- **UnifiedBatteryTab**: Comprehensive battery monitoring
  - Large percentage display (24pt SF Pro Bold)
  - Battery icon with charge-level visualization
  - Status indicators with semantic colors
  - Detailed battery information (health, cycles, capacity)

- **UnifiedCPUTab**: Real-time processor monitoring
  - Display font: 32pt SF Pro Bold for percentage
  - Animated progress bar with smooth transitions
  - System architecture detection (ARM64/x86_64)
  - Apple Silicon vs Intel processor identification

- **UnifiedMemoryTab**: Memory pressure and usage tracking
  - Memory display format: "X.X / Y.Y GB"
  - Real-time pressure monitoring (Normal/Warning/Critical)
  - Compression ratio calculation and display
  - Color-coded pressure indicators

#### Desktop Widget System (6 Variants)
- **Battery-Focused Widgets**:
  1. Minimal (100×40): Essential battery percentage only
  2. Compact (160×50): Battery + time remaining horizontal layout
  3. Standard (180×100): Large percentage with status text
  4. Detailed (240×120): Complete battery statistics

- **System Monitoring Widgets**:
  5. CPU (160×80): Dedicated CPU usage with progress bar
  6. Memory (160×80): Memory pressure with usage metrics
  7. System (240×100): Unified overview of all system metrics

#### Widget Background System
```swift
// Unified glass background across all widgets
RoundedRectangle(cornerRadius: 16)
    .fill(Color.black.opacity(0.85))
    .overlay(
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color.white.opacity(0.1), lineWidth: 1)
    )
```

### 2. Data Layer & Services

#### SystemMonitoringService (@MainActor)
- **Singleton Pattern**: Single source of truth for system metrics
- **Update Interval**: 10-second polling to minimize CPU impact
- **Concurrent Collection**: Uses TaskGroup for parallel CPU/memory gathering
- **Throttling**: Prevents concurrent updates with isUpdating flag
- **Error Handling**: Graceful degradation with logging

#### BatteryViewModel (@ObservableObject)
- **Primary Responsibilities**: Battery state, app settings, widget management
- **Adaptive Refresh**: 5-second base interval with conditional acceleration
- **Settings Management**: UserDefaults integration for all preferences
- **Widget Integration**: Controls widget visibility and style selection

#### Core Frameworks

##### SystemCore Framework
```swift
// SystemMonitor.swift - Low-level system access
public class SystemMonitor {
    public func getCPUUsage() -> Double // mach host_statistics
    public func getMemoryInfo() -> MemoryInfo // vm_statistics64
}

// MemoryInfo structure
public struct MemoryInfo {
    public let totalMemory: Double // GB
    public let usedMemory: Double  // GB  
    public let pressure: MemoryPressure // .normal/.warning/.critical
    public let compressionRatio: Double // 0-1
    public var usagePercentage: Double // calculated property
}
```

##### BatteryCore Framework
```swift
// BatteryReader.swift - IOKit power source access
public class BatteryReader {
    public func getBatteryInfo() throws -> BatteryInfo
    public func getBatteryInfoSafe() -> BatteryInfo // No-throw version
    private func getCycleCount() -> Int // IOKit direct access
}

// BatteryInfo structure
public struct BatteryInfo: Equatable {
    public let currentCharge: Int        // 0-100%
    public let isCharging: Bool
    public let isPluggedIn: Bool  
    public let cycleCount: Int
    public let maxCapacity: Int          // Design capacity %
    public let timeRemaining: Int?       // Minutes
    public let health: Double            // 0.0-1.0
    public var timeRemainingFormatted: String? // "H:MM" format
}
```

### 3. Design System (UnifiedDesignSystem.swift)

#### Semantic Color System
```swift
enum Colors {
    // Semantic mapping
    static let battery = success      // Energy = green
    static let processor = neutral    // Computing = blue  
    static let memory = Color.purple  // Storage = purple
    static let system = accent        // Overall = white
    
    // Status colors
    static let success = Color.green   // Healthy state
    static let warning = Color.orange  // Caution needed
    static let critical = Color.red    // Immediate attention
    static let neutral = Color.blue    // Normal operation
}
```

#### Typography Hierarchy (SF Pro System)
```swift
enum Typography {
    // Primary hierarchy
    static let display = Font.system(size: 32, weight: .bold, design: .rounded)    // Hero numbers
    static let largeTitle = Font.system(size: 24, weight: .bold, design: .rounded) // Section headers
    static let title = Font.system(size: 18, weight: .semibold, design: .rounded)  // Subsection headers
    static let body = Font.system(size: 14, weight: .medium, design: .rounded)     // Content text
    static let caption = Font.system(size: 12, weight: .medium, design: .rounded)  // Labels
    static let label = Font.system(size: 10, weight: .semibold)                    // Small labels (uppercase)
}
```

#### Layout System (4px Grid)
```swift
enum Layout {
    static let space1: CGFloat = 4    // micro spacing
    static let space2: CGFloat = 8    // small spacing  
    static let space3: CGFloat = 12   // medium spacing
    static let space4: CGFloat = 16   // large spacing
    static let space5: CGFloat = 24   // xlarge spacing
    static let space6: CGFloat = 32   // xxlarge spacing
    
    static let cornerRadius: CGFloat = 12        // Standard corner radius
    static let cornerRadiusLarge: CGFloat = 16   // Widget corner radius
}
```

#### Component Library
- **UnifiedMetric**: Consistent metric display with icon, value, subtitle
- **SectionHeader**: Uppercase labels with optional system icons
- **InsightRow**: Status messages with severity levels
- **InfoRow**: Key-value pair display for technical details

## Performance Optimizations

### Async Architecture Implementation
```swift
@MainActor
class SystemMonitoringService: ObservableObject {
    // Concurrent system metric collection
    private func updateMetrics() async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }
        
        let (newCpuUsage, newMemoryInfo) = await withTaskGroup(of: (Double?, MemoryInfo?).self) { group in
            group.addTask {
                let cpu = self.systemMonitor.getCPUUsage()
                return (cpu, nil)
            }
            group.addTask {
                let memory = self.systemMonitor.getMemoryInfo()
                return (nil, memory)
            }
            // Process results concurrently
        }
        
        // Update @Published properties on main thread
        cpuUsage = newCpuUsage
        memoryInfo = newMemoryInfo
        lastUpdated = Date()
    }
}
```

### Polling Strategy & Performance Impact
- **SystemMonitoringService**: 10-second intervals (CPU overhead: <0.1%)
- **BatteryViewModel**: Adaptive refresh (5s base, 2s critical, 30s idle)
- **Widget Updates**: Reactive to @Published changes, no independent timers
- **Force Update Throttling**: Minimum 2-second interval between manual refreshes

### Memory Management & Resource Cleanup
```swift
// Proper lifecycle management
class SystemMonitoringService {
    deinit {
        timer?.invalidate()
        timer = nil
    }
}

// Weak references prevent retain cycles
class DesktopWidgetManager {
    private weak var parentWindow: NSWindow?
}
```

### Low-Level System Access Optimization
```swift
// SystemCore: Direct mach calls for efficiency
public func getCPUUsage() -> Double {
    var loadInfo = host_load_info_data_t()
    let result = host_statistics(mach_host_self(), HOST_LOAD_INFO, ...)
    // Direct calculation, no subprocess overhead
}

// BatteryCore: IOKit direct access (no system_profiler subprocess)
private func getCycleCount() -> Int {
    let entry = IOServiceGetMatchingService(kIOMainPortDefault, matching)
    let cycleCountRef = IORegistryEntryCreateCFProperty(entry, "CycleCount" as CFString, ...)
    // Direct IOKit property access
}
```

## Design Token System

### Colors (Semantic)
```swift
enum Colors {
    static let battery = success      // Energy = green
    static let processor = neutral    // Computing = blue  
    static let memory = Color.purple  // Storage = purple
    static let system = accent        // Overall = white
}
```

### Typography Hierarchy
```swift
enum Typography {
    static let display = Font.system(size: 32, weight: .bold, design: .rounded)
    static let largeTitle = Font.system(size: 24, weight: .bold, design: .rounded)
    static let title = Font.system(size: 18, weight: .semibold, design: .rounded)
}
```

### Layout System
```swift
enum Layout {
    static let space1: CGFloat = 4    // micro
    static let space2: CGFloat = 8    // small  
    static let space3: CGFloat = 12   // medium
    static let space4: CGFloat = 16   // large
}
```

## Widget Architecture

### Widget Styles & Sizes
1. **Minimal (100×40)**: Battery percentage only
2. **Compact (160×50)**: Battery + time or system metrics
3. **Standard (180×100)**: Large percentage with status
4. **Detailed (240×120)**: Full battery statistics
5. **CPU (160×80)**: CPU-focused monitoring
6. **Memory (160×80)**: Memory pressure monitoring  
7. **System (240×100)**: Unified system overview

### Shared Background System
```swift
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

## Data Flow

```
Hardware → SystemCore → SystemMonitoringService → UI Components
         → BatteryCore → BatteryViewModel      → Widgets
```

### Update Cycles
1. **SystemCore** collects CPU/Memory every 10s
2. **BatteryCore** collects battery data every 5s  
3. **SystemMonitoringService** publishes updates
4. **UI Components** react to @Published properties
5. **Widgets** update automatically via shared data

## Module Dependencies

```
Package.swift
├── Microverse (executable)
│   ├── depends: BatteryCore
│   └── depends: SystemCore
├── BatteryCore (framework)
│   └── dependencies: IOKit
└── SystemCore (framework)
    └── dependencies: Darwin.Mach
```

## File Organization

```
Sources/
├── Microverse/
│   ├── BatteryViewModel.swift
│   ├── SystemMonitoringService.swift
│   ├── UnifiedDesignSystem.swift
│   ├── MenuBarApp.swift
│   ├── DesktopWidget.swift
│   └── Views/
│       ├── TabbedMainView.swift
│       ├── UnifiedOverviewTab.swift
│       ├── UnifiedBatteryTab.swift
│       ├── UnifiedCPUTab.swift
│       └── UnifiedMemoryTab.swift
├── BatteryCore/
│   ├── BatteryInfo.swift
│   ├── BatteryReader.swift
│   └── BatteryError.swift
└── SystemCore/
    └── SystemMonitor.swift
```

## Key Design Decisions

### Why Tabbed Interface?
- Clear mental model for different metric types
- Room for future expansion (Network, GPU, Storage)
- Follows macOS design patterns

### Why Unified Design System?
- Consistency across all UI components
- Semantic color system for better UX
- Maintainable codebase with centralized tokens

### Why SystemMonitoringService?
- Single source of truth for system metrics
- Prevents multiple expensive system calls
- Reactive architecture with @Published properties

### Why Async/Await?
- Non-blocking UI updates
- Proper concurrency for system calls
- Better error handling and performance

## Future Architecture Considerations

1. **Modular Expansion**: Easy to add new monitoring modules
2. **Plugin System**: Framework allows for custom metrics
3. **Testing**: Architecture supports dependency injection
4. **Performance**: Optimized for minimal system impact
5. **Accessibility**: Design system includes accessibility tokens

## Critical Implementation Details

### Widget Manager Integration
```swift
// BatteryViewModel.swift:95-110
@Published var showSystemInfoInWidget = false {
    didSet {
        saveSetting("showSystemInfoInWidget", value: showSystemInfoInWidget)
        // Recreate widget to apply changes
        if showDesktopWidget {
            widgetManager?.hideWidget()
            widgetManager?.showWidget() 
        }
    }
}
```

### Menu Bar Icon Strategy
```swift
// MenuBarApp.swift:45-50
if let button = statusItem.button {
    // Uses elegant system monitoring icon instead of battery text
    button.image = createMicroverseIcon()
    button.action = #selector(togglePopover(_:))
    button.target = self
}
```

### Health Algorithm Implementation
```swift
// UnifiedOverviewTab.swift:92-110
private var overallHealth: String {
    if systemService.cpuUsage > 80 || systemService.memoryInfo.pressure == .critical {
        return "Stressed"
    } else if systemService.cpuUsage > 50 || systemService.memoryInfo.pressure == .warning {
        return "Moderate"  
    } else {
        return "Excellent"
    }
}
```

### Insight Generation Logic
```swift
// UnifiedOverviewTab.swift:120-155
private var insights: [(icon: String, message: String, level: InsightRow.InsightLevel)] {
    var results = []
    
    // CPU thresholds: 80% critical, 60% warning
    // Memory pressure: critical/warning enum matching
    // Battery: <15% low warning, >95% charging complete
    // Health: <80% declining warning
    
    // Fallback positive message when all systems normal
    if results.isEmpty {
        results.append(("checkmark.circle", "All systems operating normally", .normal))
    }
    return results
}
```

## Error Handling & Resilience

### Graceful Degradation Strategy
```swift
// BatteryReader.swift:62-70
public func getBatteryInfoSafe() -> BatteryInfo {
    do {
        return try getBatteryInfo()
    } catch {
        logger.error("Failed to get battery info: \(error.localizedDescription)")
        return BatteryInfo() // Returns safe defaults
    }
}
```

### IOKit Error Recovery
```swift
// BatteryReader.swift:75-116
private func getCycleCountWithErrors() throws -> Int {
    // Try direct CycleCount property first
    // Fallback to BatteryData dictionary
    // Throw specific error types for debugging
    throw BatteryError.iokitPropertyMissing("CycleCount")
}
```

## Build System & Dependencies

### Package.swift Configuration
```swift
let package = Package(
    name: "Microverse",
    platforms: [.macOS(.v11)],
    products: [.executable(name: "Microverse", targets: ["Microverse"])],
    targets: [
        .executableTarget(
            name: "Microverse",
            dependencies: ["BatteryCore", "SystemCore"]
        ),
        .target(name: "BatteryCore", dependencies: [], path: "Sources/BatteryCore"),
        .target(name: "SystemCore", dependencies: [], path: "Sources/SystemCore")
    ]
)
```

### Entitlements & Sandboxing
```xml
<!-- Microverse.entitlements -->
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.device.bluetooth</key>
<false/>
```

## Future Architecture Considerations

### Scalability Patterns
1. **Plugin Architecture**: Framework supports custom monitoring modules
2. **Data Provider Pattern**: Easy to add new metric sources
3. **Widget Extension System**: New widget types can be added without core changes
4. **Settings Architecture**: Centralized configuration system

### Performance Monitoring
- CPU usage logging every 10s for self-monitoring
- Memory footprint tracking with thresholds
- Widget render performance metrics
- Battery impact measurement

### Testing Strategy
- Unit tests for core algorithms (health scoring, insight generation)
- Performance tests for system monitoring overhead
- Widget rendering tests across different system states
- Battery simulation for edge case testing

This architecture provides a robust foundation optimized for performance while maintaining extensibility for future system monitoring capabilities.