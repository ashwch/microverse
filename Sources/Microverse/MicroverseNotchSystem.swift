import SwiftUI
import DynamicNotchKit
import AppKit
import BatteryCore
import SystemCore
import os.log

// MARK: - Enhanced Notch System for Microverse

private final class ExpandedAutoDismissObservers {
    var workspace: NSObjectProtocol?
    var app: NSObjectProtocol?
    var window: NSObjectProtocol?
    weak var observedWindow: NSWindow?

    func removeAll() {
        if let observer = workspace {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspace = nil
        }
        if let observer = app {
            NotificationCenter.default.removeObserver(observer)
            app = nil
        }
        if let observer = window {
            NotificationCenter.default.removeObserver(observer)
            window = nil
        }
        observedWindow = nil
    }

    deinit {
        removeAll()
    }
}

// MARK: - Notch Service Errors

/// Errors that can occur during notch service operations
enum NotchServiceError: Error, LocalizedError {
    case noBatteryViewModel
    case invalidScreenIndex(Int, available: Int)
    case noNotchAvailable
    case notchCreationFailed
    case displayOperationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noBatteryViewModel:
            return "Battery view model not available"
        case .invalidScreenIndex(let index, let available):
            return "Screen index \(index) is invalid (0..<\(available) available)"
        case .noNotchAvailable:
            return "No notch is currently available"
        case .notchCreationFailed:
            return "Failed to create notch display"
        case .displayOperationFailed(let operation):
            return "Display operation failed: \(operation)"
        }
    }
}

// MARK: - Notch Service Protocol

/// Protocol defining the interface for notch display services
/// Provides methods for managing Dynamic Notch Kit integration
@MainActor
protocol NotchServiceProtocol: AnyObject {
    var isNotchVisible: Bool { get }
    var selectedScreen: Int { get set }
    var notchStyle: MicroverseNotchViewModel.NotchDisplayStyle { get }
    var availableScreens: [String] { get }
    
    func showNotch() async throws
    func hideNotch() async throws
    func expandNotch() async throws
    func compactNotch() async throws
    func setScreen(_ index: Int) throws
    func cleanup() async throws
}

/// Primary implementation of notch display functionality
/// Manages Dynamic Notch Kit integration with proper error handling and resource management
@MainActor
class MicroverseNotchViewModel: ObservableObject, NotchServiceProtocol {
    @Published var isNotchVisible = false
    @Published var selectedScreen: Int = 0
    @Published var notchStyle: NotchDisplayStyle = .compact
    @Published var layoutMode: NotchLayoutMode = .split

    // Captured widths for the DynamicNotchKit compact layout. These are used by NotchGlowManager to align
    // overlays to the *actual* pill geometry (which can be asymmetric when leading/trailing widths differ).
    @Published private(set) var compactLeadingContentWidth: CGFloat = 0
    @Published private(set) var compactTrailingContentWidth: CGFloat = 0
    
    private var currentNotch: (any DynamicNotchControllable)?
    private weak var notchWindow: NSWindow?
    private weak var batteryViewModel: BatteryViewModel?
    private weak var weatherSettings: WeatherSettingsStore?
    private weak var weatherStore: WeatherStore?
    private weak var displayOrchestrator: DisplayOrchestrator?
    private weak var weatherAnimationBudget: WeatherAnimationBudget?
    private let logger = Logger(subsystem: "com.microverse.app", category: "MicroverseNotch")

    private let expandedAutoDismiss = ExpandedAutoDismissObservers()
    
    /// Available display styles for the notch
    enum NotchDisplayStyle {
        case compact    /// Collapsed state showing minimal information
        case expanded   /// Full state showing detailed system metrics
        case minimal    /// Ultraminimal state for maximum screen space
    }
    
    /// Available layout modes for notch display
    enum NotchLayoutMode: String, CaseIterable {
        case left = "left"     /// All metrics unified on left side only
        case split = "split"   /// Battery left, CPU+Memory right (asymmetric)
        case off = "off"       /// Notch display disabled
        
        var displayName: String {
            switch self {
            case .left: return "Left"
            case .split: return "Split" 
            case .off: return "Off"
            }
        }
        
        var description: String {
            switch self {
            case .left: return "All metrics on left side"
            case .split: return "Battery left, system metrics right"
            case .off: return "Notch display disabled"
            }
        }
    }
    
    init(batteryViewModel: BatteryViewModel? = nil) {
        self.batteryViewModel = batteryViewModel
        setupKeyboardShortcuts()
    }
    
    func setBatteryViewModel(_ viewModel: BatteryViewModel) {
        self.batteryViewModel = viewModel
    }

    func setWeatherEnvironment(settings: WeatherSettingsStore, store: WeatherStore, orchestrator: DisplayOrchestrator, animationBudget: WeatherAnimationBudget) {
        self.weatherSettings = settings
        self.weatherStore = store
        self.displayOrchestrator = orchestrator
        self.weatherAnimationBudget = animationBudget

        // If the notch is already visible, rebuild so the environment objects are present.
        if isNotchVisible {
            Task { @MainActor [weak self] in
                guard let self else { return }
                try? await self.showNotch()
            }
        }
    }
    
    deinit {
        // Note: Cannot safely call async methods in deinit
        // Cleanup should be called manually before deallocation
        logger.info("MicroverseNotchViewModel deallocated")
    }
    
    // MARK: - Core Notch Management
    
    /// Displays the notch on the selected screen
    /// - Throws: `NotchServiceError` if display fails
    func showNotch() async throws {
        guard let batteryViewModel = batteryViewModel else {
            logger.error("No battery view model available")
            throw NotchServiceError.noBatteryViewModel
        }

        let weatherSettings = self.weatherSettings ?? WeatherSettingsStore()
        let weatherStore = self.weatherStore ?? WeatherStore(provider: UnavailableWeatherProvider(), settings: weatherSettings)
        let displayOrchestrator = self.displayOrchestrator ?? DisplayOrchestrator(
            settings: weatherSettings,
            weatherStore: weatherStore,
            batteryViewModel: batteryViewModel
        )
        let weatherAnimationBudget = self.weatherAnimationBudget ?? WeatherAnimationBudget(settings: weatherSettings)

        // Reset compact width measurements before building a new notch.
        compactLeadingContentWidth = 0
        compactTrailingContentWidth = 0
        
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            logger.error("No screens available for notch display")
            throw NotchServiceError.invalidScreenIndex(self.selectedScreen, available: screens.count)
        }

        // Ensure we target an actual notched display. Multi-monitor setups often have a non-notched primary
        // display (index 0) with a notched built-in display as a secondary screen.
        guard let firstNotchedIndex = screens.firstIndex(where: { $0.hasNotch }) else {
            logger.error("No notched display available")
            throw NotchServiceError.noNotchAvailable
        }

        let preferredIndex = self.selectedScreen
        let targetIndex: Int
        if preferredIndex >= 0, preferredIndex < screens.count, screens[preferredIndex].hasNotch {
            targetIndex = preferredIndex
        } else {
            targetIndex = firstNotchedIndex
            if preferredIndex != targetIndex {
                logger.info("Selected screen \(preferredIndex) has no notch; using notched screen \(targetIndex)")
                self.selectedScreen = targetIndex
            }
        }
        
        // Hide existing notch
        if let existing = currentNotch {
            await existing.hide()
            currentNotch = nil
        }
        
        // Create new DynamicNotch with Microverse content based on layout mode.
        let notch = DynamicNotch {
            // Expanded View
            MicroverseExpandedNotchView()
                .environmentObject(batteryViewModel)
                .environmentObject(weatherSettings)
                .environmentObject(weatherStore)
                .environmentObject(displayOrchestrator)
                .environmentObject(weatherAnimationBudget)
        } compactLeading: {
            // Left side content based on layout mode
            switch self.layoutMode {
            case .left:
                // All metrics unified on left side
                MicroverseCompactUnifiedView()
                    .environmentObject(batteryViewModel)
                    .environmentObject(weatherSettings)
                    .environmentObject(weatherStore)
                    .environmentObject(displayOrchestrator)
                    .environmentObject(weatherAnimationBudget)
                    .microverseReportWidth { self.compactLeadingContentWidth = $0 }
            case .split:
                // Battery only on left side (asymmetric)
                MicroverseCompactLeadingView()
                    .environmentObject(batteryViewModel)
                    .environmentObject(weatherSettings)
                    .environmentObject(weatherStore)
                    .environmentObject(displayOrchestrator)
                    .environmentObject(weatherAnimationBudget)
                    .microverseReportWidth { self.compactLeadingContentWidth = $0 }
            case .off:
                // Should not reach here, but provide fallback
                EmptyView()
            }
        } compactTrailing: {
            // Right side content based on layout mode
            switch self.layoutMode {
            case .left:
                // Nothing on right side for unified left layout
                EmptyView()
            case .split:
                // CPU + Memory on right side (asymmetric)
                MicroverseCompactTrailingView()
                    .environmentObject(batteryViewModel)
                    .environmentObject(weatherSettings)
                    .environmentObject(weatherStore)
                    .environmentObject(displayOrchestrator)
                    .environmentObject(weatherAnimationBudget)
                    .microverseReportWidth { self.compactTrailingContentWidth = $0 }
            case .off:
                // Should not reach here, but provide fallback
                EmptyView()
            }
        }

        // Render the glow inside the DynamicNotchKit pill coordinate space (avoids external overlay drift).
        notch.setDecoration {
            MicroverseNotchGlowDecorationView()
        }
        
        // Show on the resolved notched screen.
        let targetScreen = screens[targetIndex]
        await notch.compact(on: targetScreen)

        guard let window = notch.windowController?.window else {
            logger.error("Notch window controller missing after compact")
            throw NotchServiceError.notchCreationFailed
        }

        currentNotch = notch
        notchWindow = window
        isNotchVisible = true
        notchStyle = .compact
        endExpandedAutoDismiss()
        
        logger.info("Microverse notch displayed on screen \(self.selectedScreen)")
    }
    
    /// Hides the currently visible notch
    /// - Throws: `NotchServiceError` if hiding fails
    func hideNotch() async throws {
        guard let notch = currentNotch else { 
            logger.info("No notch to hide")
            return 
        }
        
        endExpandedAutoDismiss()
        await notch.hide()
        currentNotch = nil
        notchWindow = nil
        isNotchVisible = false
        notchStyle = .compact
        logger.info("Microverse notch hidden")
    }
    
    /// Expands the notch to show detailed system information
    /// - Throws: `NotchServiceError` if expansion fails
    func expandNotch() async throws {
        guard let notch = currentNotch else { 
            logger.error("No notch available to expand")
            throw NotchServiceError.noNotchAvailable
        }
        
        let screens = NSScreen.screens
        guard selectedScreen < screens.count else {
            logger.error("Cannot expand notch: invalid screen index")
            throw NotchServiceError.invalidScreenIndex(selectedScreen, available: screens.count)
        }
        
        let targetScreen = screens[selectedScreen]
        await notch.expand(on: targetScreen)
        notchStyle = .expanded

        // When click-to-toggle is enabled, treat expanded notch like a popover: activate and key the panel so
        // we can rely on native resign-active / resign-key signals instead of global event monitoring.
        if batteryViewModel?.notchClickToToggleExpanded == true {
            NSApp.activate(ignoringOtherApps: true)
            notchWindow?.makeKeyAndOrderFront(nil)
        }

        beginExpandedAutoDismissIfNeeded()
        logger.info("Microverse notch expanded")
    }
    
    /// Compacts the notch to minimal display mode
    /// - Throws: `NotchServiceError` if compacting fails
    func compactNotch() async throws {
        guard let notch = currentNotch else { 
            logger.error("No notch available to compact")
            throw NotchServiceError.noNotchAvailable
        }
        
        let screens = NSScreen.screens
        guard selectedScreen < screens.count else {
            logger.error("Cannot compact notch: invalid screen index")
            throw NotchServiceError.invalidScreenIndex(selectedScreen, available: screens.count)
        }
        
        let targetScreen = screens[selectedScreen]
        await notch.compact(on: targetScreen)
        notchStyle = .compact
        endExpandedAutoDismiss()
        logger.info("Microverse notch compacted")
    }

    private func beginExpandedAutoDismissIfNeeded() {
        guard batteryViewModel?.notchClickToToggleExpanded == true else { return }

        if expandedAutoDismiss.workspace == nil {
            expandedAutoDismiss.workspace = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let activated = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                let otherBundleID = activated?.bundleIdentifier
                let myBundleID = Bundle.main.bundleIdentifier

                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard self.notchStyle == .expanded else { return }
                    guard self.batteryViewModel?.notchClickToToggleExpanded == true else { return }
                    guard let otherBundleID, otherBundleID != myBundleID else { return }
                    try? await self.compactNotch()
                }
            }
        }

        // If the app resigns active (click into another app), compact the notch.
        if expandedAutoDismiss.app == nil {
            expandedAutoDismiss.app = NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard self.notchStyle == .expanded else { return }
                    guard self.batteryViewModel?.notchClickToToggleExpanded == true else { return }
                    try? await self.compactNotch()
                }
            }
        }

        // If the notch panel becomes key, treat loss of key as "click away".
        if let window = notchWindow {
            if expandedAutoDismiss.observedWindow !== window {
                if let observer = expandedAutoDismiss.window {
                    NotificationCenter.default.removeObserver(observer)
                    expandedAutoDismiss.window = nil
                }
                expandedAutoDismiss.observedWindow = window
            }

            if expandedAutoDismiss.window == nil {
                expandedAutoDismiss.window = NotificationCenter.default.addObserver(
                    forName: NSWindow.didResignKeyNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        guard self.notchStyle == .expanded else { return }
                        guard self.batteryViewModel?.notchClickToToggleExpanded == true else { return }
                        try? await self.compactNotch()
                    }
                }
            }
        }
    }

    private func endExpandedAutoDismiss() {
        expandedAutoDismiss.removeAll()
    }
    
    // MARK: - Keyboard Shortcuts
    
    private func setupKeyboardShortcuts() {
        // TODO: Implement keyboard shortcuts using KeyboardShortcuts framework
        // For now, we'll use basic NSEvent monitoring
    }
    
    // MARK: - Screen Management
    
    /// Changes the target screen for notch display
    /// - Parameter index: Zero-based screen index
    /// - Throws: `NotchServiceError.invalidScreenIndex` if index is out of bounds
    func setScreen(_ index: Int) throws {
        let screens = NSScreen.screens
        guard index >= 0 && index < screens.count else { 
            logger.error("Cannot set screen: index \(index) out of bounds (0..<\(screens.count))")
            throw NotchServiceError.invalidScreenIndex(index, available: screens.count)
        }
        
        selectedScreen = index
        logger.info("Screen changed to index \(index)")
        
        // If notch is currently visible, move it to the new screen
        if isNotchVisible {
            Task { @MainActor in
                do {
                    try await showNotch()
                } catch {
                    logger.error("Failed to move notch to new screen: \(error)")
                }
            }
        }
    }
    
    /// Performs cleanup of notch resources and state
    /// Should be called during service teardown
    /// - Throws: `NotchServiceError` if cleanup fails
    func cleanup() async throws {
        logger.info("Cleaning up notch service")
        if isNotchVisible {
            try await hideNotch()
        }
        batteryViewModel = nil
    }
    
    var availableScreens: [String] {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            logger.warning("No screens available")
            return ["No Displays"]
        }
        
        return screens.enumerated().map { index, screen in
            if screen == NSScreen.main {
                return "Built-in Display"
            } else {
                return "External Display \(index)"
            }
        }
    }
}

// MARK: - View Measurement Helpers

private struct MicroverseWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct MicroverseReportWidthModifier: ViewModifier {
    let onChange: (CGFloat) -> Void

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: MicroverseWidthPreferenceKey.self, value: proxy.size.width)
                }
            }
            .onPreferenceChange(MicroverseWidthPreferenceKey.self, perform: onChange)
    }
}

private extension View {
    func microverseReportWidth(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        modifier(MicroverseReportWidthModifier(onChange: onChange))
    }
}

private struct MicroverseNotchTapToToggleExpandedModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                // Avoid toggling on ctrl-click, which is commonly used to open context menus.
                if let event = NSApp.currentEvent, event.modifierFlags.contains(.control) {
                    return
                }
                Task { @MainActor in
                    guard let notchService = NotchServiceLocator.current else { return }
                    do {
                        if notchService.notchStyle == .expanded {
                            try await notchService.compactNotch()
                        } else {
                            guard enabled else { return }
                            try await notchService.expandNotch()
                        }
                    } catch {
                        // Swallow errors; the notch may not be visible/available.
                    }
                }
            }
    }
}

private extension View {
    func microverseNotchTapToToggleExpanded(enabled: Bool) -> some View {
        modifier(MicroverseNotchTapToToggleExpandedModifier(enabled: enabled))
    }
}

// MARK: - Compact Leading View (Battery)
// "Simplicity is not about the absence of clutter. It's about the presence of the right things."

/// Compact battery status view for the notch leading edge
/// Displays battery percentage with appropriate color coding and charging indicators
struct MicroverseCompactLeadingView: View {
    @EnvironmentObject var viewModel: BatteryViewModel
    
    var body: some View {
        HStack(spacing: MicroverseDesign.Notch.Spacing.compactInternal) {
            // App branding with actual app icon
            if let appIcon = NSImage(contentsOfFile: Bundle.main.path(forResource: "AppIcon", ofType: "icns") ?? "") {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(.white.opacity(0.15), lineWidth: 0.5)
                    )
            } else {
                // Fallback if app icon isn't found
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.2))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Text("M")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            
            // Subtle separator
            Circle()
                .fill(.white.opacity(MicroverseDesign.Notch.Materials.separatorOpacity))
                .frame(width: 2, height: 2)
            
            // Battery metric using same structure as system metrics
            NotchCompactMetric(
                icon: batteryIcon,
                value: viewModel.batteryInfo.currentCharge,
                color: batteryColor,
                isPrimary: true
            )
        }
        .frame(
            minWidth: MicroverseDesign.Notch.Dimensions.compactWidgetMinWidth * 1.3, // Slightly wider for icon
            minHeight: MicroverseDesign.Notch.Dimensions.compactWidgetHeight
        )
        .padding(.horizontal, MicroverseDesign.Notch.Spacing.compactHorizontal)
        .padding(.vertical, MicroverseDesign.Notch.Spacing.compactVertical)
        .background(
            // Unified glass material system
            RoundedRectangle(cornerRadius: MicroverseDesign.Notch.Dimensions.compactCornerRadius)
                .fill(MicroverseDesign.Notch.Materials.compactBackground)
                .opacity(MicroverseDesign.Notch.Materials.compactOpacity)
                .overlay(
                    RoundedRectangle(cornerRadius: MicroverseDesign.Notch.Dimensions.compactCornerRadius)
                        .stroke(.white.opacity(MicroverseDesign.Notch.Materials.strokeOpacity), lineWidth: MicroverseDesign.Notch.Materials.strokeWidth)
                )
        )
        .microverseNotchTapToToggleExpanded(enabled: viewModel.notchClickToToggleExpanded)
    }
    
    private var batteryIcon: String {
        if viewModel.batteryInfo.isCharging {
            return "bolt.fill"
        } else if viewModel.batteryInfo.currentCharge <= MicroverseDesign.Notch.Performance.batteryThresholdLow {
            return "battery.25percent"
        } else {
            return "battery.100percent"
        }
    }
    
    private var batteryColor: Color {
        if viewModel.batteryInfo.isCharging {
            return MicroverseDesign.Colors.battery
        } else if viewModel.batteryInfo.currentCharge <= MicroverseDesign.Notch.Performance.batteryThresholdLow {
            return MicroverseDesign.Colors.critical
        } else if viewModel.batteryInfo.currentCharge <= MicroverseDesign.Notch.Performance.batteryThresholdMedium {
            return MicroverseDesign.Colors.warning
        } else {
            return MicroverseDesign.Colors.accent
        }
    }
}

// MARK: - Compact Unified View (All Metrics on Left Side)
// "Asymmetric design creates visual interest and purposeful hierarchy." - Design Philosophy

/// Unified compact view combining all system metrics on the left side of the notch
/// Battery, CPU, and Memory in a single cohesive widget for minimal space usage
    struct MicroverseCompactUnifiedView: View {
        @EnvironmentObject var viewModel: BatteryViewModel
        @EnvironmentObject private var weatherSettings: WeatherSettingsStore
        @EnvironmentObject private var weatherStore: WeatherStore
        @EnvironmentObject private var displayOrchestrator: DisplayOrchestrator
        @EnvironmentObject private var weatherAnimationBudget: WeatherAnimationBudget
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @StateObject private var systemService = SystemMonitoringService.shared
        @State private var stableNonPinnedWidth: CGFloat?
        @State private var stablePinnedWidth: CGFloat?
        
        var body: some View {
            Group {
                if pinnedInNotch {
                    unifiedPinnedContent
                        .fixedSize(horizontal: true, vertical: false)
                        .microverseReportWidth(growPinnedWidth)
                } else {
                    ZStack {
                        unifiedSystemContent
                            .opacity(showWeather ? 0 : 1)
                            .offset(y: showWeather ? -1 : 0)
                            .allowsHitTesting(!showWeather)
                            .accessibilityHidden(showWeather)
                            .fixedSize(horizontal: true, vertical: false)
                            .microverseReportWidth(growNonPinnedWidth)
    
                        unifiedWeatherContent
                            .opacity(showWeather ? 1 : 0)
                            .offset(y: showWeather ? 0 : 1)
                            .allowsHitTesting(showWeather)
                            .accessibilityHidden(!showWeather)
                            .fixedSize(horizontal: true, vertical: false)
                            .microverseReportWidth(growNonPinnedWidth)
                    }
                    .compositingGroup()
                }
            }
            .frame(width: pinnedInNotch ? stablePinnedWidth : stableNonPinnedWidth, height: MicroverseDesign.Notch.Dimensions.compactWidgetHeight, alignment: .leading)
            .padding(.horizontal, MicroverseDesign.Notch.Spacing.compactHorizontal)
            .padding(.vertical, MicroverseDesign.Notch.Spacing.compactVertical)
            .background(
            RoundedRectangle(cornerRadius: MicroverseDesign.Notch.Dimensions.compactCornerRadius)
                .fill(MicroverseDesign.Notch.Materials.compactBackground)
                .opacity(MicroverseDesign.Notch.Materials.compactOpacity)
                .overlay(
                    RoundedRectangle(cornerRadius: MicroverseDesign.Notch.Dimensions.compactCornerRadius)
                        .stroke(.white.opacity(MicroverseDesign.Notch.Materials.strokeOpacity), lineWidth: MicroverseDesign.Notch.Materials.strokeWidth)
                )
            )
            .onAppear { displayOrchestrator.refresh(reason: "notch_unified") }
            .animation(MicroverseDesign.Animation.notchPeek, value: compactPresentation)
            .microverseNotchTapToToggleExpanded(enabled: viewModel.notchClickToToggleExpanded)
        }
    
        private enum CompactPresentation: Equatable {
            case system
            case weather
            case pinned
        }
    
        private var compactPresentation: CompactPresentation {
            if pinnedInNotch { return .pinned }
            return showWeather ? .weather : .system
        }

        private var showWeather: Bool {
            displayOrchestrator.compactTrailing == .weather
                && weatherSettings.weatherEnabled
                && weatherSettings.weatherShowInNotch
                && weatherSettings.weatherLocation != nil
        }
    
        private var pinnedInNotch: Bool {
            weatherSettings.weatherEnabled
                && weatherSettings.weatherShowInNotch
                && weatherSettings.weatherPinInNotch
                && weatherSettings.weatherLocation != nil
        }

        private var unifiedSystemContent: some View {
            HStack(spacing: MicroverseDesign.Notch.Spacing.compactInternal) {
                // Battery - Primary metric with charging indicator
                NotchCompactMetric(
                icon: batteryIcon,
                value: viewModel.batteryInfo.currentCharge,
                color: batteryColor,
                isPrimary: true
            )

            // Subtle separator
            Circle()
                .fill(.white.opacity(MicroverseDesign.Notch.Materials.separatorOpacity))
                .frame(width: MicroverseDesign.Notch.Spacing.separatorWidth, height: MicroverseDesign.Notch.Spacing.separatorHeight)

            // CPU - Secondary metric
            NotchCompactMetric(
                icon: "cpu",
                value: Int(systemService.cpuUsage),
                color: cpuColor,
                isPrimary: false
            )

            // Subtle separator
            Circle()
                .fill(.white.opacity(MicroverseDesign.Notch.Materials.separatorOpacity))
                .frame(width: MicroverseDesign.Notch.Spacing.separatorWidth, height: MicroverseDesign.Notch.Spacing.separatorHeight)

            // Memory - Secondary metric
            NotchCompactMetric(
                icon: "memorychip",
                value: Int(systemService.memoryInfo.usagePercentage),
                color: memoryColor,
                isPrimary: false
            )
        }
    }

        private var unifiedWeatherContent: some View {
            HStack(spacing: MicroverseDesign.Notch.Spacing.compactInternal) {
                MicroverseWeatherGlyph(
                    bucket: weatherStore.current?.bucket ?? .unknown,
                    isDaylight: weatherStore.current?.isDaylight ?? true,
                    renderMode: compactWeatherGlyphMode
                )
                .font(MicroverseDesign.Notch.Typography.compactIcon)
                .foregroundColor(.white.opacity(0.85))
                .symbolRenderingMode(.hierarchical)
                .frame(width: MicroverseDesign.Layout.iconSizeSmall, height: MicroverseDesign.Layout.iconSizeSmall, alignment: .center)

                Text(unifiedTemperatureText)
                    .font(MicroverseDesign.Notch.Typography.compactValue)
                    .foregroundColor(MicroverseDesign.Colors.accent)
                .monospacedDigit()

            if let e = compactUpcomingEvent {
                Circle()
                    .fill(.white.opacity(MicroverseDesign.Notch.Materials.separatorOpacity))
                    .frame(width: 2, height: 2)

                Image(systemName: MicroverseWeatherAnnouncement.symbolName(for: e, isDaylight: weatherStore.current?.isDaylight ?? true))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 10, alignment: .center)

                TimelineView(.periodic(from: .now, by: 60)) { tl in
                    Text(MicroverseWeatherAnnouncement.relativeTimeShort(from: tl.date, to: e.startTime))
                        .font(MicroverseDesign.Notch.Typography.statusText)
                        .foregroundColor(.white.opacity(0.55))
                        .monospacedDigit()
                }
            } else if weatherStore.nextEvent != nil {
                Circle()
                    .fill(.white.opacity(MicroverseDesign.Notch.Materials.separatorOpacity))
                    .frame(width: 2, height: 2)
            }
            }
        }
    
        private var unifiedPinnedContent: some View {
            HStack(spacing: MicroverseDesign.Notch.Spacing.compactInternal) {
                NotchCompactMetric(
                    icon: batteryIcon,
                    value: viewModel.batteryInfo.currentCharge,
                    color: batteryColor,
                    isPrimary: true
                )
    
                Circle()
                    .fill(.white.opacity(MicroverseDesign.Notch.Materials.separatorOpacity))
                    .frame(width: MicroverseDesign.Notch.Spacing.separatorWidth, height: MicroverseDesign.Notch.Spacing.separatorHeight)
    
                switch weatherSettings.weatherPinnedNotchReplaces {
                case .cpu:
                    NotchCompactMetric(
                        icon: "memorychip",
                        value: Int(systemService.memoryInfo.usagePercentage),
                        color: memoryColor,
                        isPrimary: false
                    )
                case .memory:
                    NotchCompactMetric(
                        icon: "cpu",
                        value: Int(systemService.cpuUsage),
                        color: cpuColor,
                        isPrimary: false
                    )
                }
    
                Circle()
                    .fill(.white.opacity(MicroverseDesign.Notch.Materials.separatorOpacity))
                    .frame(width: MicroverseDesign.Notch.Spacing.separatorWidth, height: MicroverseDesign.Notch.Spacing.separatorHeight)
    
                MicroverseWeatherGlyph(
                    bucket: weatherStore.current?.bucket ?? .unknown,
                    isDaylight: weatherStore.current?.isDaylight ?? true,
                    renderMode: compactWeatherGlyphMode
                    )
                    .font(MicroverseDesign.Notch.Typography.compactIcon)
                    .foregroundColor(.white.opacity(0.85))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: MicroverseDesign.Layout.iconSizeSmall, height: MicroverseDesign.Layout.iconSizeSmall, alignment: .center)
    
                Text(unifiedTemperatureText)
                    .font(MicroverseDesign.Notch.Typography.compactValue)
                    .foregroundColor(MicroverseDesign.Colors.accent)
                    .monospacedDigit()
    
                if let e = compactUpcomingEvent {
                    Circle()
                        .fill(.white.opacity(MicroverseDesign.Notch.Materials.separatorOpacity))
                        .frame(width: 2, height: 2)
    
                        Image(systemName: MicroverseWeatherAnnouncement.symbolName(for: e, isDaylight: weatherStore.current?.isDaylight ?? true))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.55))
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 10, alignment: .center)
    
                    TimelineView(.periodic(from: .now, by: 60)) { tl in
                        Text(MicroverseWeatherAnnouncement.relativeTimeShort(from: tl.date, to: e.startTime))
                            .font(MicroverseDesign.Notch.Typography.statusText)
                            .foregroundColor(.white.opacity(0.55))
                            .monospacedDigit()
                    }
                } else if weatherStore.nextEvent != nil {
                    Circle()
                        .fill(.white.opacity(MicroverseDesign.Notch.Materials.separatorOpacity))
                        .frame(width: 2, height: 2)
                }
            }
        }

        private var compactUpcomingEvent: WeatherEvent? {
            guard pinnedInNotch || showWeather else { return nil }
            guard let e = weatherStore.nextEvent else { return nil }
            let now = Date()
            guard e.startTime >= now else { return nil }
            guard e.startTime.timeIntervalSince(now) <= MicroverseWeatherAnnouncement.leadTime else { return nil }
        return e
    }

        private var unifiedTemperatureText: String {
            guard let c = weatherStore.current?.temperatureC else { return "—" }
            return weatherSettings.weatherUnits.formatTemperatureShort(celsius: c)
        }
    
        private var compactWeatherGlyphMode: WeatherRenderMode {
            weatherAnimationBudget.renderMode(for: .compactNotch, isVisible: pinnedInNotch || showWeather, reduceMotion: reduceMotion)
        }

    private func growNonPinnedWidth(_ width: CGFloat) {
        let maxSaneWidth: CGFloat = 240
        guard width > 0 else { return }
        let next = max(stableNonPinnedWidth ?? 0, min(width, maxSaneWidth))
        guard stableNonPinnedWidth == nil || next > (stableNonPinnedWidth ?? 0) + 0.5 else { return }

        var t = Transaction()
        t.animation = nil
        withTransaction(t) {
            stableNonPinnedWidth = next
        }
    }

    private func growPinnedWidth(_ width: CGFloat) {
        let maxSaneWidth: CGFloat = 240
        guard width > 0 else { return }
        let next = max(stablePinnedWidth ?? 0, min(width, maxSaneWidth))
        guard stablePinnedWidth == nil || next > (stablePinnedWidth ?? 0) + 0.5 else { return }

        var t = Transaction()
        t.animation = nil
        withTransaction(t) {
            stablePinnedWidth = next
        }
    }
    
    private var batteryIcon: String {
        if viewModel.batteryInfo.isCharging {
            return "bolt.fill"
        } else if viewModel.batteryInfo.currentCharge <= MicroverseDesign.Notch.Performance.batteryThresholdLow {
            return "battery.25percent"
        } else {
            return "battery.100percent"
        }
    }
    
    private var batteryColor: Color {
        if viewModel.batteryInfo.isCharging {
            return MicroverseDesign.Colors.battery
        } else if viewModel.batteryInfo.currentCharge <= MicroverseDesign.Notch.Performance.batteryThresholdLow {
            return MicroverseDesign.Colors.critical
        } else if viewModel.batteryInfo.currentCharge <= MicroverseDesign.Notch.Performance.batteryThresholdMedium {
            return MicroverseDesign.Colors.warning
        } else {
            return MicroverseDesign.Colors.accent
        }
    }
    
    private var cpuColor: Color {
        if systemService.cpuUsage > 80 {
            return MicroverseDesign.Colors.critical
        } else if systemService.cpuUsage > 60 {
            return MicroverseDesign.Colors.warning
        } else {
            return MicroverseDesign.Colors.processor
        }
    }
    
    private var memoryColor: Color {
        switch systemService.memoryInfo.pressure {
        case .critical:
            return MicroverseDesign.Colors.critical
        case .warning:
            return MicroverseDesign.Colors.warning
        case .normal:
            return MicroverseDesign.Colors.memory
        }
    }
}

// MARK: - Compact Trailing View (System Metrics)
// "Details are not details. They make the design." - Charles Eames (quoted by Jobs)

/// Compact system metrics view for the notch trailing edge
/// Shows CPU and memory usage with semantic color coding
    struct MicroverseCompactTrailingView: View {
        @EnvironmentObject var viewModel: BatteryViewModel
        @EnvironmentObject private var weatherSettings: WeatherSettingsStore
        @EnvironmentObject private var weatherStore: WeatherStore
        @EnvironmentObject private var displayOrchestrator: DisplayOrchestrator
        @EnvironmentObject private var weatherAnimationBudget: WeatherAnimationBudget
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @StateObject private var systemService = SystemMonitoringService.shared
        @State private var stableNonPinnedWidth: CGFloat?
        @State private var stablePinnedWidth: CGFloat?
        
        var body: some View {
            Group {
                if pinnedInNotch {
                    compactPinnedContent
                        .fixedSize(horizontal: true, vertical: false)
                        .microverseReportWidth(growPinnedWidth)
                } else {
                    ZStack {
                        compactSystemContent
                            .opacity(showWeather ? 0 : 1)
                            .offset(y: showWeather ? -1 : 0)
                            .allowsHitTesting(!showWeather)
                            .accessibilityHidden(showWeather)
                            .fixedSize(horizontal: true, vertical: false)
                            .microverseReportWidth(growNonPinnedWidth)
    
                        compactWeatherContent
                            .opacity(showWeather ? 1 : 0)
                            .offset(y: showWeather ? 0 : 1)
                            .allowsHitTesting(showWeather)
                            .accessibilityHidden(!showWeather)
                            .fixedSize(horizontal: true, vertical: false)
                            .microverseReportWidth(growNonPinnedWidth)
                    }
                    .compositingGroup()
                }
            }
            .frame(width: pinnedInNotch ? stablePinnedWidth : stableNonPinnedWidth, height: MicroverseDesign.Notch.Dimensions.compactWidgetHeight, alignment: .trailing)
            .padding(.horizontal, MicroverseDesign.Notch.Spacing.compactHorizontal)
            .padding(.vertical, MicroverseDesign.Notch.Spacing.compactVertical)
            .background(
            // Consistent material language
            RoundedRectangle(cornerRadius: MicroverseDesign.Notch.Dimensions.compactCornerRadius)
                .fill(MicroverseDesign.Notch.Materials.compactBackground)
                .opacity(MicroverseDesign.Notch.Materials.compactOpacity)
                .overlay(
                    RoundedRectangle(cornerRadius: MicroverseDesign.Notch.Dimensions.compactCornerRadius)
                        .stroke(.white.opacity(MicroverseDesign.Notch.Materials.strokeOpacity), lineWidth: MicroverseDesign.Notch.Materials.strokeWidth)
                )
            )
            .onAppear { displayOrchestrator.refresh(reason: "notch_compact") }
            .animation(MicroverseDesign.Animation.notchPeek, value: compactPresentation)
            .microverseNotchTapToToggleExpanded(enabled: viewModel.notchClickToToggleExpanded)
        }
    
        private enum CompactPresentation: Equatable {
            case system
            case weather
            case pinned
        }
    
        private var compactPresentation: CompactPresentation {
            if pinnedInNotch { return .pinned }
            return showWeather ? .weather : .system
        }

        private var showWeather: Bool {
            displayOrchestrator.compactTrailing == .weather
                && weatherSettings.weatherEnabled
                && weatherSettings.weatherShowInNotch
                && weatherSettings.weatherLocation != nil
        }
    
        private var pinnedInNotch: Bool {
            weatherSettings.weatherEnabled
                && weatherSettings.weatherShowInNotch
                && weatherSettings.weatherPinInNotch
                && weatherSettings.weatherLocation != nil
        }

    private var compactSystemContent: some View {
        HStack(spacing: MicroverseDesign.Notch.Spacing.compactInternal) {
            // CPU - Clear primary metric
            NotchCompactMetric(
                icon: "cpu",
                value: Int(systemService.cpuUsage),
                color: cpuColor,
                isPrimary: true
            )

            // Subtle separator
            Circle()
                .fill(.white.opacity(MicroverseDesign.Notch.Materials.separatorOpacity))
                .frame(width: 2, height: 2)

            // Memory - Secondary but equally important
            NotchCompactMetric(
                icon: "memorychip",
                value: Int(systemService.memoryInfo.usagePercentage),
                color: memoryColor,
                isPrimary: false
            )
        }
    }

        private var compactWeatherContent: some View {
            HStack(spacing: MicroverseDesign.Notch.Spacing.compactInternal) {
                MicroverseWeatherGlyph(
                    bucket: weatherStore.current?.bucket ?? .unknown,
                    isDaylight: weatherStore.current?.isDaylight ?? true,
                    renderMode: compactWeatherGlyphMode
                    )
                    .font(MicroverseDesign.Notch.Typography.compactIcon)
                    .foregroundColor(.white.opacity(0.85))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: MicroverseDesign.Layout.iconSizeSmall, height: MicroverseDesign.Layout.iconSizeSmall, alignment: .center)

            Text(compactTemperatureText)
                .font(MicroverseDesign.Notch.Typography.compactValue)
                .foregroundColor(MicroverseDesign.Colors.accent)
                .monospacedDigit()

            if let e = compactUpcomingEvent {
                Circle()
                    .fill(.white.opacity(MicroverseDesign.Notch.Materials.separatorOpacity))
                    .frame(width: 2, height: 2)

                Image(systemName: MicroverseWeatherAnnouncement.symbolName(for: e, isDaylight: weatherStore.current?.isDaylight ?? true))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 10, alignment: .center)

                TimelineView(.periodic(from: .now, by: 60)) { tl in
                    Text(MicroverseWeatherAnnouncement.relativeTimeShort(from: tl.date, to: e.startTime))
                        .font(MicroverseDesign.Notch.Typography.statusText)
                        .foregroundColor(.white.opacity(0.55))
                        .monospacedDigit()
                }
            } else if weatherStore.nextEvent != nil {
                Circle()
                    .fill(.white.opacity(MicroverseDesign.Notch.Materials.separatorOpacity))
                    .frame(width: 2, height: 2)
            }
            }
        }
    
        private var compactPinnedContent: some View {
            HStack(spacing: MicroverseDesign.Notch.Spacing.compactInternal) {
                switch weatherSettings.weatherPinnedNotchReplaces {
                case .cpu:
                    NotchCompactMetric(
                        icon: "memorychip",
                        value: Int(systemService.memoryInfo.usagePercentage),
                        color: memoryColor,
                        isPrimary: true
                    )
                case .memory:
                    NotchCompactMetric(
                        icon: "cpu",
                        value: Int(systemService.cpuUsage),
                        color: cpuColor,
                        isPrimary: true
                    )
                }
    
                Circle()
                    .fill(.white.opacity(MicroverseDesign.Notch.Materials.separatorOpacity))
                    .frame(width: 2, height: 2)
    
                MicroverseWeatherGlyph(
                    bucket: weatherStore.current?.bucket ?? .unknown,
                    isDaylight: weatherStore.current?.isDaylight ?? true,
                    renderMode: compactWeatherGlyphMode
                    )
                    .font(MicroverseDesign.Notch.Typography.compactIcon)
                    .foregroundColor(.white.opacity(0.85))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: MicroverseDesign.Layout.iconSizeSmall, height: MicroverseDesign.Layout.iconSizeSmall, alignment: .center)
    
                Text(compactTemperatureText)
                    .font(MicroverseDesign.Notch.Typography.compactValue)
                    .foregroundColor(MicroverseDesign.Colors.accent)
                    .monospacedDigit()
    
                if let e = compactUpcomingEvent {
                    Circle()
                        .fill(.white.opacity(MicroverseDesign.Notch.Materials.separatorOpacity))
                        .frame(width: 2, height: 2)
    
                        Image(systemName: MicroverseWeatherAnnouncement.symbolName(for: e, isDaylight: weatherStore.current?.isDaylight ?? true))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.55))
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 10, alignment: .center)
    
                    TimelineView(.periodic(from: .now, by: 60)) { tl in
                        Text(MicroverseWeatherAnnouncement.relativeTimeShort(from: tl.date, to: e.startTime))
                            .font(MicroverseDesign.Notch.Typography.statusText)
                            .foregroundColor(.white.opacity(0.55))
                            .monospacedDigit()
                    }
                } else if weatherStore.nextEvent != nil {
                    Circle()
                        .fill(.white.opacity(MicroverseDesign.Notch.Materials.separatorOpacity))
                        .frame(width: 2, height: 2)
                }
            }
        }

        private var compactUpcomingEvent: WeatherEvent? {
            guard pinnedInNotch || showWeather else { return nil }
            guard let e = weatherStore.nextEvent else { return nil }
            let now = Date()
            guard e.startTime >= now else { return nil }
            guard e.startTime.timeIntervalSince(now) <= MicroverseWeatherAnnouncement.leadTime else { return nil }
        return e
    }

        private var compactTemperatureText: String {
            guard let c = weatherStore.current?.temperatureC else { return "—" }
            return weatherSettings.weatherUnits.formatTemperatureShort(celsius: c)
        }
    
        private var compactWeatherGlyphMode: WeatherRenderMode {
            weatherAnimationBudget.renderMode(for: .compactNotch, isVisible: pinnedInNotch || showWeather, reduceMotion: reduceMotion)
        }

    private func growNonPinnedWidth(_ width: CGFloat) {
        let maxSaneWidth: CGFloat = 200
        guard width > 0 else { return }
        let next = max(stableNonPinnedWidth ?? 0, min(width, maxSaneWidth))
        guard stableNonPinnedWidth == nil || next > (stableNonPinnedWidth ?? 0) + 0.5 else { return }

        var t = Transaction()
        t.animation = nil
        withTransaction(t) {
            stableNonPinnedWidth = next
        }
    }

    private func growPinnedWidth(_ width: CGFloat) {
        let maxSaneWidth: CGFloat = 200
        guard width > 0 else { return }
        let next = max(stablePinnedWidth ?? 0, min(width, maxSaneWidth))
        guard stablePinnedWidth == nil || next > (stablePinnedWidth ?? 0) + 0.5 else { return }

        var t = Transaction()
        t.animation = nil
        withTransaction(t) {
            stablePinnedWidth = next
        }
    }
    
    private var cpuColor: Color {
        if systemService.cpuUsage > 80 {
            return MicroverseDesign.Colors.critical
        } else if systemService.cpuUsage > 60 {
            return MicroverseDesign.Colors.warning
        } else {
            return MicroverseDesign.Colors.processor
        }
    }
    
    private var memoryColor: Color {
        switch systemService.memoryInfo.pressure {
        case .critical:
            return MicroverseDesign.Colors.critical
        case .warning:
            return MicroverseDesign.Colors.warning
        case .normal:
            return MicroverseDesign.Colors.memory
        }
    }
}

// MARK: - Reusable Compact Metric Component
// "The goal is not to make something look new, but to make it look right." - Jonathan Ive

/// Reusable metric display component with hierarchical typography
/// Supports both primary and secondary metric presentations
// MARK: - DEPRECATED: Use NotchCompactMetric instead
// This exists for backward compatibility only
struct CompactMetric: View {
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
        NotchCompactMetric(icon: icon, value: value, color: color, isPrimary: isPrimary)
    }
}

// MARK: - Expanded View (Full System Overview)
// "We believe in the simple, not the simplistic." - Jonathan Ive

/// Full-featured expanded notch view showing comprehensive system status
/// Includes battery, CPU, memory metrics with elegant typography and materials
    struct MicroverseExpandedNotchView: View {
        @EnvironmentObject var viewModel: BatteryViewModel
        @EnvironmentObject private var weatherSettings: WeatherSettingsStore
        @EnvironmentObject private var weatherStore: WeatherStore
        @EnvironmentObject private var weatherAnimationBudget: WeatherAnimationBudget
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @StateObject private var systemService = SystemMonitoringService.shared
        @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: MicroverseDesign.Layout.space1) {
            // Refined header - Perfect proportions and hierarchy
            headerSection
            
            // Elegant divider with breathing space
            HStack {
                Capsule()
                    .fill(.white.opacity(MicroverseDesign.Notch.Materials.dividerOpacity))
                    .frame(height: MicroverseDesign.Layout.space1 / 4)
                    .padding(.horizontal, MicroverseDesign.Notch.Spacing.expandedContainer - 4)
            }
            .padding(.vertical, MicroverseDesign.Notch.Spacing.expandedDivider)
            
            // Primary metrics with perfect spacing
            metricsSection

            // Optional weather module (polish lives in expanded notch, not compact).
            weatherSection
            
            // Subtle system status indicator
            statusSection
        }
        .padding(.horizontal, MicroverseDesign.Notch.Spacing.expandedContainer - 4)
        .padding(.vertical, MicroverseDesign.Notch.Spacing.expandedContainer - 8)
        .frame(width: MicroverseDesign.Notch.Dimensions.expandedWidth)
        .background(
            // Unified material depth system
            RoundedRectangle(cornerRadius: MicroverseDesign.Notch.Dimensions.expandedCornerRadius)
                .fill(MicroverseDesign.Notch.Materials.expandedBackground)
                .opacity(MicroverseDesign.Notch.Materials.expandedOpacity)
                .background(
                    RoundedRectangle(cornerRadius: MicroverseDesign.Notch.Dimensions.expandedCornerRadius)
                        .fill(MicroverseDesign.Notch.Materials.expandedBackdrop)
                        .overlay(
                            RoundedRectangle(cornerRadius: MicroverseDesign.Notch.Dimensions.expandedCornerRadius)
                                .stroke(.white.opacity(MicroverseDesign.Notch.Materials.expandedStrokeOpacity), lineWidth: MicroverseDesign.Notch.Materials.expandedStrokeWidth)
                        )
                )
        )
        .microverseNotchTapToToggleExpanded(enabled: viewModel.notchClickToToggleExpanded)
        .contextMenu {
            MicroverseNotchContextMenu()
        }
        .onAppear {
            withAnimation(MicroverseDesign.Animation.notchExpansion) {
                animationOffset = 0
            }
            weatherStore.triggerRefresh(reason: "notch-expanded")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            // Clear but humble branding
            HStack(spacing: MicroverseDesign.Notch.Spacing.brandSpacing) {
                Circle()
                    .fill(.white.opacity(MicroverseDesign.Notch.Opacity.brandIndicator))
                    .frame(width: MicroverseDesign.Notch.Dimensions.brandIndicatorSize, height: MicroverseDesign.Notch.Dimensions.brandIndicatorSize)
                
                Text("microverse")
                    .font(MicroverseDesign.Notch.Typography.brandLabel)
                    .foregroundColor(.white.opacity(MicroverseDesign.Notch.Opacity.brandText))
                    .tracking(0.8)
                    .textCase(.lowercase)
            }
            
            Spacer()
            
            // Time display with clear hierarchy
            Text(DateFormatter.elegantTimeFormatter.string(from: Date()))
                .font(MicroverseDesign.Notch.Typography.timeDisplay)
                .foregroundColor(.white.opacity(MicroverseDesign.Notch.Opacity.timeText))
                .monospacedDigit()
        }
        .padding(.top, MicroverseDesign.Layout.space1)
    }
    
    // MARK: - Metrics Section
    private var metricsSection: some View {
        HStack(spacing: MicroverseDesign.Notch.Spacing.expandedSection - 8) {
            // Battery - Primary metric
            NotchExpandedMetric(
                icon: batteryIcon,
                label: "Battery",
                value: "\(viewModel.batteryInfo.currentCharge)%",
                detail: batteryDetail,
                color: batteryColor,
                isPrimary: true
            )
            
            // CPU - Secondary metric
            NotchExpandedMetric(
                icon: "cpu",
                label: "CPU",
                value: "\(Int(systemService.cpuUsage))%",
                detail: cpuStatusText,
                color: cpuColor
            )
            
            // Memory - Secondary metric
            NotchExpandedMetric(
                icon: "memorychip",
                label: "Memory", 
                value: "\(Int(systemService.memoryInfo.usagePercentage))%",
                detail: "\(String(format: "%.1f", systemService.memoryInfo.usedMemory))GB",
                color: memoryColor
            )
        }
        .padding(.vertical, MicroverseDesign.Layout.space3)
    }
    
    // MARK: - Status Section
    private var statusSection: some View {
        HStack {
            // System health indicator with subtle animation
            HStack(spacing: MicroverseDesign.Notch.Spacing.statusSpacing) {
                Circle()
                    .fill(systemHealthColor)
                    .frame(width: MicroverseDesign.Notch.Dimensions.statusIndicatorSize, height: MicroverseDesign.Notch.Dimensions.statusIndicatorSize)
                    .scaleEffect(systemHealthColor == MicroverseDesign.Colors.success ? 1.0 : 0.8)
                    .animation(MicroverseDesign.Animation.statusPulse, value: systemHealthColor)
                
                Text(systemHealthText)
                    .font(MicroverseDesign.Notch.Typography.statusText)
                    .foregroundColor(.white.opacity(MicroverseDesign.Notch.Opacity.statusText))
            }
            
            Spacer()
            
            // Subtle update indicator
            Text("live")
                .font(MicroverseDesign.Notch.Typography.liveIndicator)
                .foregroundColor(.white.opacity(MicroverseDesign.Notch.Opacity.liveText))
                .textCase(.lowercase)
        }
        .padding(.bottom, MicroverseDesign.Layout.space1)
    }

        private var weatherSection: some View {
            Group {
                if weatherSettings.weatherEnabled, weatherSettings.weatherShowInNotch, weatherSettings.weatherLocation != nil {
                    HStack(spacing: MicroverseDesign.Notch.Spacing.statusSpacing) {
                        MicroverseWeatherGlyph(
                            bucket: weatherStore.current?.bucket ?? .unknown,
                            isDaylight: weatherStore.current?.isDaylight ?? true,
                            renderMode: weatherAnimationBudget.renderMode(for: .expandedNotch, isVisible: true, reduceMotion: reduceMotion)
                            )
                            .font(MicroverseDesign.Notch.Typography.expandedIcon)
                            .foregroundColor(.white.opacity(0.85))
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: MicroverseDesign.Layout.iconSize + 4, height: MicroverseDesign.Layout.iconSize + 4)
                            .clipped()

                            VStack(alignment: .leading, spacing: 1) {
                            Text(expandedWeatherTitle)
                                .font(MicroverseDesign.Notch.Typography.expandedLabel)
                            .foregroundColor(MicroverseDesign.Colors.accentSubtle)
                            .tracking(0.8)
                            .lineLimit(1)

                        Text(expandedWeatherValue)
                            .font(MicroverseDesign.Notch.Typography.statusText)
                            .foregroundColor(.white.opacity(MicroverseDesign.Notch.Opacity.statusText))
                            .monospacedDigit()
                            .lineLimit(1)
                    }

                    Spacer()

                    if let e = weatherStore.nextEvent {
                        TimelineView(.periodic(from: .now, by: 60)) { tl in
                            HStack(spacing: 4) {
                                Text(e.title.lowercased())
                                    .font(MicroverseDesign.Notch.Typography.statusText)
                                    .foregroundColor(.white.opacity(0.55))
                                    .lineLimit(1)

                                Text(relativeTime(from: tl.date, to: e.startTime))
                                    .font(MicroverseDesign.Notch.Typography.statusText)
                                    .foregroundColor(.white.opacity(0.55))
                                    .monospacedDigit()
                            }
                        }
                    } else {
                        Text("steady")
                            .font(MicroverseDesign.Notch.Typography.statusText)
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
                .padding(.horizontal, MicroverseDesign.Layout.space2)
                .padding(.vertical, MicroverseDesign.Layout.space2)
                .background(
                    RoundedRectangle(cornerRadius: MicroverseDesign.Notch.Dimensions.compactCornerRadius)
                        .fill(.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: MicroverseDesign.Notch.Dimensions.compactCornerRadius)
                                .stroke(.white.opacity(0.08), lineWidth: 0.5)
                        )
                )
                .padding(.bottom, MicroverseDesign.Layout.space2)
            }
        }
    }

        private var expandedWeatherValue: String {
            guard let current = weatherStore.current else { return "—" }
            return weatherSettings.weatherUnits.formatTemperature(celsius: current.temperatureC)
        }

        private var expandedWeatherTitle: String {
            let displayName = weatherSettings.weatherLocation?.displayName ?? "—"
            let city = displayName.split(separator: ",").first.map(String.init) ?? displayName
            return city
        }

    private func relativeTime(from now: Date, to target: Date) -> String {
        let delta = target.timeIntervalSince(now)
        if abs(delta) < 60 { return "now" }

        let minutes = Int((delta / 60).rounded())
        if minutes < 0 {
            return "\(-minutes)m ago"
        }
        if minutes < 60 {
            return "in \(minutes)m"
        }
        let hours = Int((Double(minutes) / 60.0).rounded(.down))
        return "in \(hours)h"
    }
    
    // MARK: - Computed Properties with Steve Jobs' attention to language
    private var batteryIcon: String {
        if viewModel.batteryInfo.isCharging {
            return "bolt.fill"
        } else if viewModel.batteryInfo.currentCharge <= MicroverseDesign.Notch.Performance.batteryThresholdLow {
            return "battery.25percent"
        } else {
            return "battery.100percent"
        }
    }
    
    private var batteryColor: Color {
        if viewModel.batteryInfo.isCharging {
            return MicroverseDesign.Colors.battery
        } else if viewModel.batteryInfo.currentCharge <= MicroverseDesign.Notch.Performance.batteryThresholdLow {
            return MicroverseDesign.Colors.critical
        } else if viewModel.batteryInfo.currentCharge <= MicroverseDesign.Notch.Performance.batteryThresholdMedium {
            return MicroverseDesign.Colors.warning
        } else {
            return MicroverseDesign.Colors.accent
        }
    }
    
    private var batteryDetail: String {
        if let timeString = viewModel.batteryInfo.timeRemainingFormatted {
            return timeString
        } else if viewModel.batteryInfo.isCharging {
            return "charging"
        } else {
            return "calculating"
        }
    }
    
    private var cpuColor: Color {
        if systemService.cpuUsage > 80 { return MicroverseDesign.Colors.critical }
        else if systemService.cpuUsage > 60 { return MicroverseDesign.Colors.warning }
        else { return MicroverseDesign.Colors.processor }
    }
    
    private var memoryColor: Color {
        switch systemService.memoryInfo.pressure {
        case .critical: return MicroverseDesign.Colors.critical
        case .warning: return MicroverseDesign.Colors.warning
        case .normal: return MicroverseDesign.Colors.memory
        }
    }
    
    private var cpuStatusText: String {
        if systemService.cpuUsage > MicroverseDesign.Notch.Performance.cpuThresholdCritical { return "intense" }
        else if systemService.cpuUsage > MicroverseDesign.Notch.Performance.cpuThresholdWarning { return "active" }
        else { return "calm" }
    }
    
    private var systemHealthColor: Color {
        if systemService.cpuUsage > MicroverseDesign.Notch.Performance.cpuThresholdCritical || systemService.memoryInfo.pressure == .critical || viewModel.batteryInfo.currentCharge < MicroverseDesign.Notch.Performance.systemHealthThresholdLow {
            return MicroverseDesign.Colors.critical
        } else if systemService.cpuUsage > MicroverseDesign.Notch.Performance.cpuThresholdWarning || systemService.memoryInfo.pressure == .warning || viewModel.batteryInfo.currentCharge < MicroverseDesign.Notch.Performance.systemHealthThresholdMedium {
            return MicroverseDesign.Colors.warning
        } else {
            return MicroverseDesign.Colors.success
        }
    }
    
    private var systemHealthText: String {
        if systemService.cpuUsage > MicroverseDesign.Notch.Performance.cpuThresholdCritical || systemService.memoryInfo.pressure == .critical {
            return "system under pressure"
        } else if systemService.cpuUsage > MicroverseDesign.Notch.Performance.cpuThresholdWarning || systemService.memoryInfo.pressure == .warning {
            return "system active"
        } else {
            return "system optimal"
        }
    }
}

// MARK: - Expanded Metric Component
// "Every element should serve a purpose." - Steve Jobs

struct ExpandedMetric: View {
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
        VStack(spacing: 6) {
            // Icon with subtle hierarchy
            Image(systemName: icon)
                .font(.system(size: isPrimary ? 14 : 12, weight: .medium))
                .foregroundColor(color)
                .symbolRenderingMode(.monochrome)
            
            // Primary value with perfect weight
            Text(value)
                .font(.system(size: isPrimary ? 20 : 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            
            // Label with refined typography
            Text(label.lowercased())
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .tracking(0.8)
            
            // Detail with subtle presence
            Text(detail.lowercased())
                .font(.system(size: 7, weight: .regular))
                .foregroundColor(.white.opacity(0.4))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Context Menu
// "The details are not the details. They make the design." - Charles Eames

struct MicroverseNotchContextMenu: View {
    var body: some View {
        Group {
            // Primary actions with thoughtful language
            Button("Collapse") {
                Task { @MainActor in
                    // Access through environment or dependency injection
                    if let notchService = NotchServiceLocator.current {
                        do {
                            try await notchService.compactNotch()
                        } catch {
                            print("Failed to collapse notch: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            Button("Hide") {
                Task { @MainActor in
                    if let notchService = NotchServiceLocator.current {
                        do {
                            try await notchService.hideNotch()
                        } catch {
                            print("Failed to hide notch: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            Divider()
            
            // Display selection with elegant presentation
            Menu("Display") {
                let availableScreens = NotchServiceLocator.current?.availableScreens ?? []
                ForEach(0..<min(NSScreen.screens.count, availableScreens.count), id: \.self) { index in
                    let screenName = availableScreens[index]
                    Button(action: {
                        do {
                            try NotchServiceLocator.current?.setScreen(index)
                        } catch {
                            print("Failed to set screen: \(error.localizedDescription)")
                        }
                    }) {
                        Label(screenName, systemImage: index == 0 ? "laptopcomputer" : "display")
                    }
                }
            }
            
            Divider()
            
            // Secondary actions
            Button("Preferences...") {
                // TODO: Implement settings panel opening
                // Could open main Microverse interface
            }
            
            Divider()
            
            Button("Quit Microverse") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

// MARK: - Date Formatter Extension
// "Even things you never see should be beautiful." - Jonathan Ive

extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let elegantTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter
    }()
}

// MARK: - Service Locator (Temporary Bridge)

/// Temporary service locator for notch service dependency injection
/// TODO: Replace with proper DI container in future architecture improvements
@MainActor
class NotchServiceLocator {
    static var current: NotchServiceProtocol?
    
    static func register(_ service: NotchServiceProtocol) {
        current = service
    }
    
    static func unregister() {
        current = nil
    }
}
