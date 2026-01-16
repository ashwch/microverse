# Microverse Architecture

> **Comprehensive technical architecture for a unified macOS system monitoring application with smart notch integration, secure auto-updates, and elegant desktop widgets**

## Executive Summary

Microverse is a sophisticated system monitoring application that combines modern Swift architecture with elegant UI design. Built for macOS developers who need real-time insights into their system's health without compromising performance, it features smart notch integration via DynamicNotchKit, secure auto-updates through Sparkle, and a comprehensive widget ecosystem.
It also includes an optional Weather module for temperature glances across the popover, Smart Notch, desktop widget, and menu bar.

### Key Metrics & Achievements
- **Performance**: <1% CPU impact, <50MB memory footprint  
- **Architecture**: Async/await with @MainActor isolation and concurrent system monitoring
- **UI Framework**: SwiftUI with sophisticated design system and reactive state management
- **Compatibility**: macOS 13.0+, Universal Binary (Intel + Apple Silicon)
- **Security**: Sandboxed with minimal entitlements, secure auto-update system
- **Integration**: Native notch integration using DynamicNotchKit framework
- **Notch Glow Alerts**: In-notch glow animations triggered by battery events

## System Architecture Overview

### High-Level Component Diagram
```text
┌─────────────────────────────────────────────────────────────────────────┐
│                           Microverse Application                         │
├─────────────────────────────────────────────────────────────────────────┤
│  🎨 UI Layer (SwiftUI + Design System)                                  │
│  ├── TabbedMainView (Main 280×500 Interface)                            │
│  ├── UnifiedOverviewTab (System Health Dashboard)                       │
│  ├── UnifiedBatteryTab (Detailed Power Metrics)                         │
│  ├── UnifiedCPUTab (Processor Performance Analysis)                     │
│  ├── UnifiedMemoryTab (Memory Usage & Pressure)                         │
│  ├── WeatherTab (Temperature + “Up Next” Highlights)                    │
│  ├── DesktopWidget (Multi-style Widget System)                          │
│  ├── MicroverseNotchSystem (DynamicNotchKit Views)                      │
│  └── UpdateView (Sparkle Auto-Update UI)                                │
├─────────────────────────────────────────────────────────────────────────┤
│  🧠 Business Logic Layer                                                │
│  ├── BatteryViewModel (Settings & App State Management)                 │
│  ├── SystemMonitoringService (Reactive System Metrics)                  │
│  ├── WeatherSettingsStore (UserDefaults-backed Settings)                │
│  ├── WeatherStore (Fetch + Cache + Published Weather State)             │
│  ├── DisplayOrchestrator (Compact Surface Switching)                    │
│  ├── WeatherAnimationBudget (Power-safe Animation Policy)               │
│  ├── SecureUpdateService (Sparkle Integration)                          │
│  ├── AdaptiveDisplayService (Smart Refresh Management)                  │
│  ├── MicroverseNotchViewModel (DynamicNotchKit State)                   │
│  ├── NotchGlowManager (Notch Glow Alerts)                               │
│  └── MicroverseNotchSystem (Notch Content Coordination)                 │
├─────────────────────────────────────────────────────────────────────────┤
│  ⚙️ Core Frameworks (Direct System Access)                              │
│  ├── BatteryCore (IOKit Battery Hardware Interface)                     │
│  └── SystemCore (mach CPU/memory monitoring)                            │
├─────────────────────────────────────────────────────────────────────────┤
│  🎯 Design System & Components                                          │
│  ├── UnifiedDesignSystem (Colors, Typography, Layout Tokens)            │
│  ├── MicroverseDesign (Component Library & Glass Effects)               │
│  └── Semantic Color System (Battery=Green, CPU=Blue, Memory=Purple)     │
├─────────────────────────────────────────────────────────────────────────┤
│  🔗 External Dependencies                                               │
│  ├── Sparkle (Secure Auto-Updates with EdDSA Signatures)               │
│  └── DynamicNotchKit (Native Notch Integration)                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Data Flow Architecture
```text
Hardware APIs → Core Frameworks → Services → ViewModels → UI Components
     ↓               ↓              ↓          ↓            ↓
   IOKit         BatteryCore   SystemMonitoring BatteryVM  SwiftUI Views
   mach          SystemCore    Service          ↓          Desktop Widgets
   System        ↓             ↓                ↓          Notch Widgets
   Calls         Direct API    @Published       Reactive   Glass UI
                 Access        Properties       State      Components
```

## Detailed Component Architecture

### 1. Smart Notch Integration System

#### MicroverseNotchSystem.swift
```swift
@MainActor
class MicroverseNotchSystem: ObservableObject {
    // Core notch management using DynamicNotchKit
    @Published var isVisible: Bool = true
    @Published var currentMode: NotchMode = .left
    
    // Integration with system monitoring
    private let systemService: SystemMonitoringService
    private let batteryViewModel: BatteryViewModel
    
    // Notch content lifecycle management
    func updateNotchDisplay(with metrics: SystemMetrics)
    func handleNotchModeChange(_ mode: NotchMode)
    func synchronizeWithSystemState()
}
```

#### NotchDisplayManager.swift
```swift
class NotchDisplayManager: ObservableObject {
    // DynamicNotchKit integration layer
    private var notchController: DynamicNotchController
    
    // Content state management
    @Published var displayedMetrics: NotchMetrics
    @Published var layoutMode: NotchLayoutMode
    
    // Responsive layout system
    func adaptToNotchGeometry(_ geometry: NotchGeometry)
    func updateContentLayout(for metrics: SystemMetrics)
}
```

#### NotchWidgetViews.swift
```swift
// Sophisticated notch widget implementations
struct NotchWidgetCompact: View {
    // Horizontal layout: Battery, CPU, Memory percentages
    // Glass morphism background with semantic colors
    // Responsive to system state changes
}

struct NotchWidgetExpanded: View {
    // Comprehensive display: Health status, cycle count, metrics
    // Adaptive content based on available space
    // Elegant transitions between states
}
```

### 2. Desktop Widget Ecosystem

#### DesktopWidget.swift - Widget Management System
```swift
class DesktopWidgetManager: ObservableObject {
    // Widget lifecycle management
    private var currentWidget: NSWindow?
    private var widgetStyle: WidgetStyle = .glance
    
    // Multi-style widget system
    enum WidgetStyle: CaseIterable {
        case glance      // System Glance (374×182)
        case status      // System Status (556×230)  
        case dashboard   // System Dashboard (556×304)
    }
    
    // Window management
    func showWidget()
    func hideWidget()
    func updateWidgetContent(_ metrics: SystemMetrics)
    func repositionWidget(to position: CGPoint)
}
```

#### Glass Morphism Widget System
```swift
// Unified widget background system
extension View {
    func glassMorphismBackground() -> some View {
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

### 3. Application Interface Layer

#### TabbedMainView.swift - Main Interface Controller
```swift
struct TabbedMainView: View {
    // State management
    @State private var selectedTab: Tab = .overview
    @ObservedObject var viewModel: BatteryViewModel
    @ObservedObject var systemService: SystemMonitoringService
    
    // Tab system with sophisticated state management
    enum Tab: CaseIterable, Identifiable {
        case overview, battery, cpu, memory
        
        var systemIcon: String { /* SF Symbols mapping */ }
        var label: String { /* Localized labels */ }
    }
    
    // Cross-tab state synchronization
    func syncTabState()
    func handleTabSelection(_ tab: Tab)
}
```

#### Unified Tab Components

**UnifiedOverviewTab.swift**
```swift
struct UnifiedOverviewTab: View {
    // System health dashboard with intelligent insights
    @ObservedObject var viewModel: BatteryViewModel
    @ObservedObject var systemService: SystemMonitoringService
    
    // Health scoring algorithm
    private var systemHealth: SystemHealth {
        calculateSystemHealth(
            battery: viewModel.batteryInfo,
            cpu: systemService.cpuUsage,
            memory: systemService.memoryInfo
        )
    }
    
    // Insight generation system
    private var systemInsights: [SystemInsight] {
        generateInsights(from: systemHealth)
    }
}
```

**UnifiedBatteryTab.swift**
```swift
struct UnifiedBatteryTab: View {
    // Comprehensive battery monitoring interface
    // - Large percentage display (24pt SF Pro Bold)
    // - Health metrics and cycle count tracking
    // - Time remaining with adaptive estimates
    // - Charging optimization insights
    
    // Semantic color system
    private var batteryColor: Color {
        viewModel.batteryInfo.semanticColor
    }
}
```

**UnifiedCPUTab.swift**
```swift
struct UnifiedCPUTab: View {
    // Real-time processor performance analysis
    // - CPU usage percentage with progress bar
    // - Load average and thermal state
    // - Architecture-specific optimizations
    
    // Performance thresholds
    private var cpuColor: Color {
        systemService.cpuUsage.performanceColor
    }
}
```

**UnifiedMemoryTab.swift**
```swift
struct UnifiedMemoryTab: View {
    // Memory usage and pressure monitoring
    // - Memory pressure gauge with visual indicators
    // - Usage breakdown (used/cached/free)
    // - Swap activity monitoring
    
    // Memory pressure mapping
    private var memoryColor: Color {
        systemService.memoryInfo.pressureColor
    }
}
```

### 4. Business Logic & State Management

#### SystemMonitoringService.swift - Core Metrics Engine
```swift
@MainActor
class SystemMonitoringService: ObservableObject {
    // Reactive system metrics with @Published properties
    @Published var cpuUsage: Double = 0
    @Published var memoryInfo: MemoryInfo = MemoryInfo()
    @Published var systemHealth: SystemHealth = .optimal
    @Published var lastUpdateTime: Date = Date()
    
    // Concurrent monitoring system
    private let monitoringTask: Task<Void, Never>
    
    // Adaptive refresh system
    private var refreshInterval: TimeInterval {
        calculateAdaptiveRefreshRate()
    }
    
    // Core monitoring functions
    func startMonitoring() async
    func updateMetrics() async
    func calculateSystemHealth() -> SystemHealth
    
    // Performance optimization
    private func shouldUpdateMetrics(_ newMetrics: SystemMetrics) -> Bool {
        // Only update @Published when visual change needed
    }
}
```

#### BatteryViewModel.swift - Application State Controller
```swift
@MainActor
class BatteryViewModel: ObservableObject {
    // Core application state
    @Published var batteryInfo: BatteryInfo = BatteryInfo()
    @Published var showDesktopWidget: Bool = false
    @Published var widgetStyle: WidgetStyle = .glance
    @Published var notchMode: NotchMode = .left
    
    // Service coordination
    private let systemService: SystemMonitoringService
    private let updateService: SecureUpdateService
    private weak var widgetManager: DesktopWidgetManager?
    private weak var notchManager: NotchDisplayManager?
    
    // Settings management
    func updateSettings()
    func syncWidgetState()
    func handleNotchModeChange()
}
```

#### SecureUpdateService.swift - Sparkle Integration
```swift
@MainActor
class SecureUpdateService: ObservableObject {
    // Sparkle framework integration
    private let updater: SPUUpdater
    
    // Update state management
    @Published var updateState: UpdateState = .idle
    @Published var currentVersion: String = Bundle.main.version
    @Published var isCheckingForUpdates: Bool = false
    
    // Secure update operations
    func checkForUpdates()
    func installUpdate()
    func scheduleAutomaticChecks()
    
    // Design system integration
    func presentUpdateUI() {
        // Custom UI using MicroverseDesign components
    }
}
```

#### AdaptiveDisplayService.swift - Intelligent Refresh Management
```swift
class AdaptiveDisplayService {
    // Battery-aware refresh rate optimization
    func calculateOptimalRefreshRate(
        battery: BatteryInfo,
        systemLoad: SystemMetrics,
        userActive: Bool,
        powerState: PowerState
    ) -> TimeInterval {
        
        // Critical battery (≤5%): 2 seconds
        if battery.currentCharge <= 5 {
            return 2.0
        }
        
        // High system load: More frequent updates
        if systemLoad.isStressed {
            return 3.0
        }
        
        // Plugged at 100%: Reduced frequency
        if battery.isPluggedIn && battery.currentCharge >= 100 {
            return 30.0  // 6x slower
        }
        
        // Standard operation: 5 seconds
        return 5.0
    }
    
    // 83% CPU reduction when idle
    func optimizeForBatteryLife() -> TimeInterval
}
```

### 5. Core Framework Layer

#### BatteryCore Framework
```swift
// Sources/BatteryCore/
├── BatteryInfo.swift          // Data structures for battery metrics
├── BatteryReader.swift        // IOKit interface for hardware access
└── BatteryError.swift         // Error handling and recovery

// Direct IOKit access for optimal performance
public class BatteryReader {
    // No subprocess overhead - direct system calls
    func getBatteryInfo() throws -> BatteryInfo {
        // IOPSCopyPowerSourcesInfo() direct access
        // IORegistryEntryCreateCFProperty() for cycle count
        // Real-time power state monitoring
    }
    
    // Cycle count optimization
    func getCycleCount() -> Int {
        // Direct IOKit property access
        // Eliminated 100ms+ subprocess delay
    }
}
```

#### SystemCore Framework  
```swift
// Sources/SystemCore/
└── SystemMonitor.swift        // CPU & Memory monitoring via mach

// Direct mach API access
public class SystemMonitor {
    // CPU monitoring without subprocess overhead
    func getCPUUsage() -> Double {
        // host_statistics() direct mach calls
        // Real-time processor load calculation
    }
    
    // Memory pressure detection
    func getMemoryInfo() -> MemoryInfo {
        // vm_statistics64() mach interface
        // Memory pressure calculation
        // Swap activity monitoring
    }
}
```

### 6. Design System Architecture

#### UnifiedDesignSystem.swift - Design Token Foundation
```swift
// Comprehensive design system implementation
// See docs/DESIGN.md for complete specifications

enum MicroverseDesign {
    // Semantic color system
    enum Colors {
        static let battery = Color.green        // Energy/Power
        static let processor = Color.blue       // Computing/Performance  
        static let memory = Color.purple        // Storage/Memory
        static let system = Color.white         // Overall status
    }
    
    // Typography hierarchy (SF Pro Rounded)
    enum Typography {
        static let display = Font.system(size: 32, weight: .bold, design: .rounded)
        static let largeTitle = Font.system(size: 24, weight: .bold, design: .rounded)
        // ... complete typography system
    }
    
    // Layout system (4px grid)
    enum Layout {
        static let space1: CGFloat = 4     // micro spacing
        static let space2: CGFloat = 8     // small spacing
        // ... complete spacing scale
    }
}
```

#### Component Library Implementation
```swift
// Reusable UI components with consistent styling
struct UnifiedMetric: View {
    // Consistent metric display across all tabs
}

struct SectionHeader: View {
    // Standard section headers with SF Symbols
}

struct InsightRow: View {
    // System insight display with semantic colors
}

struct HealthStatusCard: View {
    // System health visualization
}
```

## Performance Architecture

### Concurrency & Threading Model
```swift
// @MainActor isolation for UI safety
@MainActor
class SystemMonitoringService: ObservableObject {
    // All UI updates on main thread
    @Published var cpuUsage: Double = 0
    
    // Background monitoring with Task
    private let monitoringTask: Task<Void, Never>
    
    func startMonitoring() async {
        // Concurrent system monitoring without blocking UI
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.monitorCPU() }
            group.addTask { await self.monitorMemory() }
            group.addTask { await self.monitorBattery() }
        }
    }
}
```

### Memory Management Strategy
```swift
// Weak references prevent retain cycles
class DesktopWidgetManager {
    weak var viewModel: BatteryViewModel?
    weak var notchManager: NotchDisplayManager?
    
    // Efficient widget recreation
    func updateWidget() {
        // Minimize object allocation
        // Reuse existing views when possible
    }
}

// Optimized @Published updates
class OptimizedViewModel: ObservableObject {
    @Published private(set) var displayMetrics: DisplayMetrics
    
    private var _rawMetrics: RawMetrics {
        didSet {
            // Only trigger UI updates when visually significant
            let newDisplay = _rawMetrics.forDisplay()
            if newDisplay != displayMetrics {
                displayMetrics = newDisplay
            }
        }
    }
}
```

### Adaptive Performance System
```swift
// Battery-aware performance optimization
class PerformanceManager {
    // Dynamic refresh rate adjustment
    func calculateRefreshInterval(
        batteryLevel: Int,
        systemLoad: Double,
        thermalState: ThermalState
    ) -> TimeInterval {
        // 2s critical → 30s idle optimization
        // Up to 83% CPU reduction achieved
    }
    
    // Widget rendering optimization
    func optimizeWidgetUpdates() {
        // Minimize redraws
        // Cache expensive calculations
        // Lazy loading for complex views
    }
}
```

## Security Architecture

### Sandboxing & Entitlements
```xml
<!-- Microverse.entitlements -->
<key>com.apple.security.app-sandbox</key>
<true/>

<!-- Minimal required entitlements -->
<key>com.apple.security.network.client</key>
<true/>  <!-- Sparkle auto-updates -->

<key>com.apple.security.files.downloads.read-write</key>
<true/>  <!-- Update downloads -->

<!-- Sparkle XPC service support -->
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
    <string>com.microverse.app-spks</string>
    <string>com.microverse.app-spki</string>
</array>
```

### Secure Auto-Update System
```swift
// Sparkle integration with EdDSA signature verification
class SecureUpdateService {
    // Code signature verification
    private let updater: SPUUpdater
    
    // Secure download verification
    func verifyUpdateSignature(_ update: UpdateItem) -> Bool {
        // EdDSA signature validation
        // Code signing verification
        // Integrity checks
    }
    
    // Automatic update scheduling
    func scheduleSecureUpdates() {
        // 24-hour check interval
        // User-controllable preferences
        // Background verification
    }
}
```

### Data Privacy & Local Storage
```swift
// No data collection - everything stays local
class PrivacyCompliantStorage {
    // UserDefaults for app preferences only
    private let defaults = UserDefaults.standard
    
    // No analytics, no telemetry, no external data transmission
    func storeLocalPreferences() {
        // Widget settings
        // Refresh rate preferences  
        // UI state persistence
    }
}
```

## Deployment & Distribution Architecture

### Universal Binary Build System
```swift
// Package.swift configuration
platforms: [.macOS(.v13)]

// Universal binary support
targets: [
    .executableTarget(
        name: "Microverse",
        dependencies: ["BatteryCore", "SystemCore", "Sparkle", "DynamicNotchKit"]
    )
]
```

### GitHub Actions CI/CD Pipeline
```yaml
# .github/workflows/release.yml
# - Semantic versioning (feat:/fix:/BREAKING CHANGE:)
# - DMG and ZIP artifact generation
# - Automatic GitHub releases
# - Sparkle appcast generation
# - Universal binary compilation
```

### Makefile Build System
```makefile
# Comprehensive build automation
build:     # Swift Package Manager release build
install:   # Create app bundle + install to /Applications
app:       # Bundle creation with Sparkle framework embedding
clean:     # Artifact cleanup
uninstall: # Complete removal including preferences
```

## Integration Points & External Dependencies

### DynamicNotchKit Integration
```swift
// Seamless notch area integration
import DynamicNotchKit

class NotchIntegrationLayer {
    // DynamicNotchKit controller
    private let notchController: DynamicNotchController
    
    // Content lifecycle management
    func presentNotchContent(_ content: NotchContent)
    func updateNotchLayout(_ layout: NotchLayout)
    func handleNotchVisibilityChange(_ visible: Bool)
}
```

### Sparkle Framework Integration
```swift
// Secure automatic updates
import Sparkle

class UpdateSystemIntegration {
    // Sparkle updater configuration
    private let updater: SPUUpdater
    
    // Custom UI integration with design system
    func presentUpdateInterface()
    func handleUpdateWorkflow()
    func configureAutomaticChecks()
}
```

## Development & Maintenance Guidelines

### Code Quality Standards
```swift
// SwiftUI best practices
// - @MainActor isolation for UI components
// - async/await for system operations
// - @Published properties for reactive state
// - Weak references for memory management

// Design system compliance
// - All UI uses MicroverseDesign tokens
// - Consistent component patterns
// - Semantic color system adherence

// Performance monitoring
// - <1% CPU usage target
// - <50MB memory footprint
// - Battery impact minimization
```

### Testing Strategy
```swift
// Current state: Identified technical debt
// - Zero test coverage (see docs/TECHNICAL_DEBT.md)
// - Priority areas for testing:
//   * System monitoring accuracy
//   * Performance regression prevention
//   * Battery health calculations
//   * Widget rendering consistency
```

### Documentation Cross-References
- **[Design System](DESIGN.md)**: Complete UI/UX specifications and component library
- **[Technical Debt](TECHNICAL_DEBT.md)**: Current optimization opportunities
- **[Auto-Update System](SPARKLE_AUTO_UPDATE_SYSTEM.md)**: Detailed Sparkle implementation
- **[Notch Features](NOTCH_FEATURES.md)**: Smart Notch + Notch Glow feature overview
- **[Contributing Guidelines](../CONTRIBUTING.md)**: Development standards and workflow

## Architecture Evolution & Future

### Scalability Considerations
- **New Metrics**: Framework supports additional system monitoring
- **Widget Expansion**: Component system enables new widget types
- **Notch Innovation**: DynamicNotchKit provides advanced layout options
- **Performance**: Direct system access architecture scales efficiently

### Maintainability Features
- **Modular Design**: Clear separation between frameworks and application
- **Reactive Architecture**: @Published properties enable predictable data flow
- **Design System**: Centralized tokens ensure consistent visual updates
- **Dependency Management**: Swift Package Manager for clean dependency resolution

This architecture document serves as the definitive technical reference for understanding, contributing to, and maintaining the Microverse codebase. It reflects the current sophisticated state of the application and provides clear guidance for future development.
