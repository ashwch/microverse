# Microverse Current Architecture v3.0

## Overview

Microverse is now a unified system monitoring application with Johnny Ive-inspired design and John Carmack-level engineering. The app features a tabbed interface for monitoring Battery, CPU, Memory, and system overview.

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

## Key Components

### 1. UI Layer
- **TabbedMainView**: Main interface with 4 tabs (Overview, Battery, CPU, Memory)
- **Desktop Widgets**: 6 styles - Minimal, Compact, Standard, Detailed, CPU, Memory, System
- **Settings**: Integrated into main interface with widget configuration

### 2. Data Layer
- **SystemMonitoringService**: Singleton service managing CPU/Memory monitoring
- **BatteryViewModel**: Battery state and app settings management
- **SystemCore**: Low-level system monitoring using IOKit and mach APIs

### 3. Design System
- **UnifiedDesignSystem**: Centralized design tokens and components
- **Johnny Ive Principles**: Clarity, deference, depth through semantic colors
- **Consistent Typography**: SF Pro system with semantic sizing

## Performance Optimizations

### Async Architecture
```swift
@MainActor
class SystemMonitoringService: ObservableObject {
    // Background queue for system calls
    private func updateMetrics() async {
        let metrics = await withTaskGroup(...) { group in
            // Concurrent CPU and memory collection
        }
        // Update UI on main thread
    }
}
```

### Efficient Polling
- **Battery**: 5-second intervals with adaptive refresh
- **System Metrics**: 10-second intervals to reduce CPU overhead
- **Widget Updates**: Reactive to data changes, no separate timers

### Memory Management
- Weak references in widget manager
- Proper timer cleanup in deinit
- Throttled system calls to prevent overload

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

This architecture provides a solid foundation for current functionality while remaining extensible for future enhancements.