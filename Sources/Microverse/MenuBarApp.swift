import SwiftUI
import AppKit
import os.log
import Combine

@main
struct MicroverseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Empty scene - we handle everything through AppDelegate
        // This prevents SwiftUI from creating unwanted windows
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var viewModel: BatteryViewModel!
    var weatherSettings: WeatherSettingsStore!
    var weatherStore: WeatherStore!
    var weatherLocationsStore: WeatherLocationsStore!
    var displayOrchestrator: DisplayOrchestrator!
    var weatherAnimationBudget: WeatherAnimationBudget!
    var weatherAlertEngine: WeatherAlertEngine!
    var networkStore: NetworkStore!
    var popoverContentViewController: NSViewController?
    private var cancellables = Set<AnyCancellable>()
    
    private let logger = Logger(subsystem: "com.microverse.app", category: "AppDelegate")
    
    // Constants
    private static let menuBarIconSize: CGFloat = 22
    private static let welcomeDelay: TimeInterval = 0.5
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Close any default windows that SwiftUI might create
        for window in NSApp.windows {
            window.close()
        }
        
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Use the actual Microverse app icon (alien face)
            if let appIcon = getAppIcon() {
                button.image = appIcon
                button.imagePosition = .imageOnly
                button.title = ""
            } else {
                // Fallback to system icon
                button.image = createMicroverseIcon()
            }
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Initialize battery manager
        setupBatteryManager()
        
        // Show first-run welcome if needed
        showFirstRunWelcomeIfNeeded()
    }
    
    private func showFirstRunWelcomeIfNeeded() {
        let hasShownWelcome = UserDefaults.standard.bool(forKey: "hasShownFirstRunWelcome")
        
        if !hasShownWelcome {
            Task { @MainActor [weak self] in
                // Delay to ensure menu bar icon is visible, then show welcome
                try? await Task.sleep(nanoseconds: UInt64(Self.welcomeDelay * 1_000_000_000))
                guard let self else { return }
                self.showWelcomeMessage()
                // Only mark as shown after successfully showing the dialog
                UserDefaults.standard.set(true, forKey: "hasShownFirstRunWelcome")
            }
        }
    }
    
    private func showWelcomeMessage() {
        let alert = NSAlert()
        alert.messageText = "Welcome to Microverse! 🚀"
        
        // Clean, well-formatted text with better spacing
        alert.informativeText = """
Microverse is now running in your menu bar!

Look for the alien icon 👽 in the top-right corner of your screen.

Click it to access system monitoring, settings, and desktop widgets.

✨ Tip: Enable desktop widgets from the settings panel for continuous monitoring.
"""
        
        alert.addButton(withTitle: "Got it!")
        alert.addButton(withTitle: "Show me Microverse")
        alert.alertStyle = .informational
        
        // Use high quality app icon for dialog
        if let appIcon = getDialogAppIcon() {
            alert.icon = appIcon
        }
        
        let response = alert.runModal()
        
        if response == .alertSecondButtonReturn {
            // User clicked "Show me Microverse"
            if let button = statusItem.button {
                togglePopover(button)
            }
        }
    }
    
    @MainActor func setupBatteryManager() {
        logger.info("Setting up battery manager...")
        
        // Construct shared services first, then the view model (so notch can render weather safely).
        weatherSettings = WeatherSettingsStore()
        weatherStore = WeatherStore(provider: makeWeatherProvider(), settings: weatherSettings)
        weatherLocationsStore = WeatherLocationsStore(provider: makeWeatherSummaryProvider(), settings: weatherSettings)
        weatherAnimationBudget = WeatherAnimationBudget(settings: weatherSettings)

        // Create battery view model.
        viewModel = BatteryViewModel()

        // Display orchestration (system ↔ weather swapping) for notch/widget surfaces.
        displayOrchestrator = DisplayOrchestrator(settings: weatherSettings, weatherStore: weatherStore, batteryViewModel: viewModel)

        viewModel.setWeatherEnvironment(
            settings: weatherSettings,
            store: weatherStore,
            locationsStore: weatherLocationsStore,
            orchestrator: displayOrchestrator,
            animationBudget: weatherAnimationBudget
        )

        weatherStore.start()
        weatherAlertEngine = WeatherAlertEngine(settings: weatherSettings, weather: weatherStore, battery: viewModel)
        viewModel.handleAppLaunchCompleted()

        networkStore = NetworkStore()
        
        // Update menu bar
        updateMenuBarDisplay()
        
        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 500)
        popover.behavior = .applicationDefined
        popover.delegate = self
        
        let tabbedMainView = TabbedMainView()
            .environmentObject(viewModel)
            .environmentObject(weatherSettings)
            .environmentObject(weatherStore)
            .environmentObject(weatherLocationsStore)
            .environmentObject(displayOrchestrator)
            .environmentObject(weatherAnimationBudget)
            .environmentObject(networkStore)
            .environmentObject(viewModel.wifiStore)
            .environmentObject(viewModel.audioDevicesStore)
        
        popoverContentViewController = NSHostingController(rootView: tabbedMainView)
        popover.contentViewController = popoverContentViewController
        
        // Update menu bar display when battery info changes
        // Use Combine to observe changes instead of polling
        viewModel.$batteryInfo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarDisplay()
            }
            .store(in: &cancellables)
        
        // Also update when showPercentageInMenuBar changes
        viewModel.$showPercentageInMenuBar
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarDisplay()
            }
            .store(in: &cancellables)

        Publishers.MergeMany([
            weatherStore.$current
                .removeDuplicates()
                .map { _ in () }
                .eraseToAnyPublisher(),
            weatherSettings.$weatherShowInMenuBar
                .removeDuplicates()
                .map { _ in () }
                .eraseToAnyPublisher(),
            weatherSettings.$weatherEnabled
                .removeDuplicates()
                .map { _ in () }
                .eraseToAnyPublisher(),
            weatherSettings.$weatherUnits
                .removeDuplicates()
                .map { _ in () }
                .eraseToAnyPublisher(),
            weatherSettings.$weatherSelectedLocationID
                .removeDuplicates()
                .map { _ in () }
                .eraseToAnyPublisher(),
            weatherSettings.$weatherLocations
                .removeDuplicates()
                .map { _ in () }
                .eraseToAnyPublisher()
        ])
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.updateMenuBarDisplay()
        }
        .store(in: &cancellables)

        // Coalesced refresh after sleep/wake (prevents stale “in 25m” becoming “8m ago”).
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.weatherSettings.requestCurrentLocationUpdate()
                self?.weatherStore.triggerRefresh(reason: "wake")
                self?.displayOrchestrator.refresh(reason: "wake")
            }
            .store(in: &cancellables)
        
        logger.info("Battery manager setup complete")

        #if DEBUG
        maybeShowNotchGlowDebugIfRequested()
        maybeOpenPopoverDebugIfRequested()
        maybeOpenSettingsDebugIfRequested()
        maybePrintWeatherDebugHelpIfRequested()
        maybeFetchWeatherDebugIfRequested()
        maybeRunWeatherDemoDebugIfRequested()
        #endif
    }

    #if DEBUG
    private func maybeShowNotchGlowDebugIfRequested() {
        guard let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--debug-notch-glow") }) else {
            return
        }

        let typeString: String = {
            let parts = arg.split(separator: "=", maxSplits: 1).map(String.init)
            return parts.count == 2 ? parts[1].lowercased() : "info"
        }()

        let type: NotchAlertType = {
            switch typeString {
            case "success": return .success
            case "warning": return .warning
            case let s where s.hasPrefix("crit"): return .critical
            default: return .info
            }
        }()

        Task { @MainActor in
            // Give the menu bar / run loop a moment to settle.
            try? await Task.sleep(nanoseconds: 700_000_000)
            NotchGlowManager.shared.showAlert(type: type, duration: 4.0, pulseCount: 3)
        }
    }

    private func maybeOpenSettingsDebugIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--debug-open-settings") }) else {
            return
        }
        guard let button = statusItem.button else { return }

        Task { @MainActor [weak self] in
            // Give the menu bar / run loop a moment to settle.
            try? await Task.sleep(nanoseconds: 600_000_000)
            self?.togglePopover(button)
        }
    }

    private func maybeOpenPopoverDebugIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        let shouldOpen =
          args.contains("--debug-open-popover")
          || args.contains("--debug-open-weather")
          || args.contains("--debug-open-alerts")
          || args.contains("--debug-open-system-network")
          || args.contains("--debug-open-system-audio")

        guard shouldOpen else {
            return
        }

        let hasOpenSettings = args.contains(where: { $0.hasPrefix("--debug-open-settings") })
        // Avoid double-open if settings or demo is requested.
        guard !hasOpenSettings,
              !args.contains("--debug-weather-demo") else {
            return
        }
        guard let button = statusItem.button else { return }

        Task { @MainActor [weak self] in
            // Give the menu bar / run loop a moment to settle.
            try? await Task.sleep(nanoseconds: 600_000_000)
            self?.togglePopover(button)
        }
    }

    private func maybeFetchWeatherDebugIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--debug-weather-fetch") else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }

            if self.weatherSettings.selectedLocation == nil,
               let location = WeatherLocation(
                    displayName: "San Francisco, CA, USA",
                    latitude: 37.7749,
                    longitude: -122.4194,
                    timezoneIdentifier: "America/Los_Angeles"
                )
            {
                self.weatherSettings.addOrSelectLocation(location)
            }

            self.weatherSettings.weatherEnabled = true
            await self.weatherStore.refreshNow(reason: "debug-weather-fetch")

            if let current = self.weatherStore.current {
                print("WEATHER_OK tempC=\(current.temperatureC) bucket=\(current.bucket.rawValue) state=\(self.describeWeatherFetchState(self.weatherStore.fetchState))")
            } else {
                print("WEATHER_FAIL state=\(self.describeWeatherFetchState(self.weatherStore.fetchState))")
            }

            NSApplication.shared.terminate(nil)
        }
    }

    private func describeWeatherFetchState(_ state: WeatherFetchState) -> String {
        switch state {
        case .idle: return "idle"
        case .loading: return "loading"
        case .loaded: return "loaded"
        case .stale: return "stale"
        case .failed(let message): return "failed(\(message))"
        }
    }

    private func printWeatherDebugHelp() {
        let scenarios = WeatherDebugScenarioProvider.Scenario.allCases.map(\.rawValue).joined(separator: ", ")
        print(
            """
            WEATHER_DEBUG_HELP
            Commands:
              --debug-weather-fetch
              --debug-weather-demo
              --debug-weather-scenario=<scenario>
                scenarios: \(scenarios)
              --debug-open-popover
              --debug-open-alerts
              --debug-open-system-network
              --debug-open-system-audio
              --debug-open-settings[=<general|weather|notch|alerts|updates>]
              --debug-open-weather

            Notes:
              - Microverse uses WeatherKit when available and falls back to Open‑Meteo if WeatherKit isn’t authorized.
              - --debug-weather-demo temporarily forces notch+widget on, then restores settings and quits.
            """
        )
    }

    private func maybePrintWeatherDebugHelpIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--debug-weather-help") else { return }
        printWeatherDebugHelp()
        NSApplication.shared.terminate(nil)
    }

    private func maybeRunWeatherDemoDebugIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--debug-weather-demo") else { return }
        // Mutually exclusive with the one-shot fetch command (which exits immediately).
        guard !ProcessInfo.processInfo.arguments.contains("--debug-weather-fetch") else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }

            let previous = DebugWeatherDemoSnapshot.capture(viewModel: viewModel, settings: weatherSettings)

            // Ensure weather has a location and is enabled.
            if self.weatherSettings.selectedLocation == nil,
               let location = WeatherLocation(
                    displayName: "San Francisco, CA, USA",
                    latitude: 37.7749,
                    longitude: -122.4194,
                    timezoneIdentifier: "America/Los_Angeles"
                )
            {
                self.weatherSettings.addOrSelectLocation(location)
            }

            self.weatherSettings.weatherEnabled = true
            self.weatherSettings.weatherShowInNotch = true
            self.weatherSettings.weatherShowInWidget = true
            self.weatherSettings.weatherSmartSwitchingEnabled = true

            // Ensure notch is enabled if available.
            if self.viewModel.isNotchAvailable, self.viewModel.notchLayoutMode == .off {
                self.viewModel.notchLayoutMode = .split
            }

            // Ensure widget is visible (System Glance is the v1 swap surface).
            self.viewModel.widgetStyle = .systemGlance
            self.viewModel.showDesktopWidget = true

            // Open the popover so the Weather tab is visible during the demo.
            if let button = self.statusItem.button {
                self.togglePopover(button)
            }

            // Give the UI time to mount, then fetch + preview.
            try? await Task.sleep(nanoseconds: 900_000_000)
            self.weatherStore.triggerRefresh(reason: "debug-weather-demo")
            self.displayOrchestrator.previewWeatherInNotch(duration: 20)

            // Expand the notch briefly to show the expanded weather row (if available).
            if self.viewModel.isNotchAvailable {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                try? await NotchServiceLocator.current?.expandNotch()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                try? await NotchServiceLocator.current?.compactNotch()
            }

            // Keep the demo running briefly, then quit to avoid leaving debug state behind.
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            previous.restore(viewModel: viewModel, settings: weatherSettings)
            NSApplication.shared.terminate(nil)
        }
    }

    @MainActor
    private struct DebugWeatherDemoSnapshot {
        var showDesktopWidget: Bool
        var widgetStyle: WidgetStyle
        var notchLayoutMode: MicroverseNotchViewModel.NotchLayoutMode

        var weatherEnabled: Bool
        var weatherShowInNotch: Bool
        var weatherShowInWidget: Bool
        var weatherSmartSwitchingEnabled: Bool
        var weatherLocations: [WeatherLocation]
        var weatherSelectedLocationID: String?

        static func capture(viewModel: BatteryViewModel, settings: WeatherSettingsStore) -> DebugWeatherDemoSnapshot {
            DebugWeatherDemoSnapshot(
                showDesktopWidget: viewModel.showDesktopWidget,
                widgetStyle: viewModel.widgetStyle,
                notchLayoutMode: viewModel.notchLayoutMode,
                weatherEnabled: settings.weatherEnabled,
                weatherShowInNotch: settings.weatherShowInNotch,
                weatherShowInWidget: settings.weatherShowInWidget,
                weatherSmartSwitchingEnabled: settings.weatherSmartSwitchingEnabled,
                weatherLocations: settings.weatherLocations,
                weatherSelectedLocationID: settings.weatherSelectedLocationID
            )
        }

        func restore(viewModel: BatteryViewModel, settings: WeatherSettingsStore) {
            // Restore Weather settings first (so surfaces gate correctly).
            settings.weatherEnabled = weatherEnabled
            settings.weatherShowInNotch = weatherShowInNotch
            settings.weatherShowInWidget = weatherShowInWidget
            settings.weatherSmartSwitchingEnabled = weatherSmartSwitchingEnabled
            settings.weatherLocations = weatherLocations
            settings.weatherSelectedLocationID = weatherSelectedLocationID

            // Restore UI surface settings.
            viewModel.widgetStyle = widgetStyle
            viewModel.showDesktopWidget = showDesktopWidget
            viewModel.notchLayoutMode = notchLayoutMode
        }
    }
    #endif
    
    @MainActor func updateMenuBarDisplay() {
        guard let button = statusItem.button else { return }
        
        let info = viewModel.batteryInfo

        // Icon
        if let alienIcon = getAppIcon() {
            button.image = alienIcon
        } else {
            button.image = createMicroverseIcon(
                batteryLevel: info.currentCharge,
                isCharging: info.isCharging,
                showHealth: viewModel.showPercentageInMenuBar
            )
        }

        // Title (battery % and/or temperature)
        var parts: [String] = []
        if viewModel.showPercentageInMenuBar {
            parts.append("\(info.currentCharge)%")
        }
        if let t = menuBarWeatherText() {
            parts.append(t)
        }

        let title = parts.isEmpty ? "" : " " + parts.joined(separator: " • ")
        button.title = title
        button.imagePosition = title.isEmpty ? .imageOnly : .imageLeft
    }

    private func menuBarWeatherText() -> String? {
        guard weatherSettings.weatherEnabled else { return nil }
        guard weatherSettings.weatherShowInMenuBar else { return nil }
        guard weatherSettings.selectedLocation != nil else { return nil }

        guard let c = weatherStore.current?.temperatureC else {
            return "—°"
        }
        return weatherSettings.weatherUnits.formatTemperatureShort(celsius: c)
    }
    
    func createBatteryIcon(charge: Int, isCharging: Bool) -> NSImage? {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Draw battery outline
        let batteryRect = NSRect(x: 1, y: 6, width: 16, height: 10)
        let batteryPath = NSBezierPath(roundedRect: batteryRect, xRadius: 1, yRadius: 1)
        
        NSColor.labelColor.setStroke()
        batteryPath.lineWidth = 1.5
        batteryPath.stroke()
        
        // Battery terminal
        let terminalRect = NSRect(x: 17, y: 9, width: 3, height: 4)
        let terminalPath = NSBezierPath(roundedRect: terminalRect, xRadius: 1, yRadius: 1)
        NSColor.labelColor.setFill()
        terminalPath.fill()
        
        // Fill based on charge level
        let fillWidth = (batteryRect.width - 3) * CGFloat(charge) / 100.0
        let fillRect = NSRect(
            x: batteryRect.minX + 1.5,
            y: batteryRect.minY + 1.5,
            width: fillWidth,
            height: batteryRect.height - 3
        )
        
        // Color based on charge
        let fillColor: NSColor
        if charge <= 20 {
            fillColor = .systemRed
        } else if charge <= 50 {
            fillColor = .systemYellow
        } else {
            fillColor = .systemGreen
        }
        
        fillColor.setFill()
        NSBezierPath(roundedRect: fillRect, xRadius: 0.5, yRadius: 0.5).fill()
        
        // Add lightning bolt if charging
        if isCharging {
            let boltPath = NSBezierPath()
            boltPath.move(to: NSPoint(x: 8, y: 14))
            boltPath.line(to: NSPoint(x: 10, y: 10))
            boltPath.line(to: NSPoint(x: 9, y: 10))
            boltPath.line(to: NSPoint(x: 11, y: 6))
            boltPath.line(to: NSPoint(x: 9, y: 10.5))
            boltPath.line(to: NSPoint(x: 10, y: 10.5))
            boltPath.close()
            
            NSColor.white.setFill()
            boltPath.fill()
            NSColor.labelColor.setStroke()
            boltPath.lineWidth = 0.5
            boltPath.stroke()
        }
        
        image.unlockFocus()
        return image
    }
    
    /// Create elegant Microverse system monitoring icon
    func createMicroverseIcon(batteryLevel: Int? = nil, isCharging: Bool = false, showHealth: Bool = false) -> NSImage? {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Use clean system monitoring icon instead of battery
        let iconName = "circle.grid.2x2.fill"
        let systemImage = NSImage(systemSymbolName: iconName, accessibilityDescription: "Microverse")
        
        if let systemImage = systemImage {
            // Base icon color
            var iconColor = NSColor.controlAccentColor
            
            // Adjust color based on system health if requested
            if showHealth, let battery = batteryLevel {
                if battery <= 10 {
                    iconColor = NSColor.systemRed
                } else if battery <= 20 {
                    iconColor = NSColor.systemOrange
                } else if isCharging {
                    iconColor = NSColor.systemGreen
                } else {
                    iconColor = NSColor.controlAccentColor
                }
            }
            
            // Draw the icon
            iconColor.set()
            let iconRect = NSRect(x: 3, y: 3, width: 16, height: 16)
            systemImage.draw(in: iconRect)
            
            // Add subtle charging indicator if needed
            if isCharging && showHealth {
                let boltImage = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Charging")
                if let boltImage = boltImage {
                    NSColor.systemYellow.set()
                    let boltRect = NSRect(x: 13, y: 2, width: 8, height: 8)
                    boltImage.draw(in: boltRect)
                }
            }
        }
        
        image.unlockFocus()
        return image
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                // Ensure the popover is interactive immediately (scroll, clicks, keyboard focus).
                NSApp.activate(ignoringOtherApps: true)

                // Recreate the content view to ensure fresh state
                let tabbedMainView = TabbedMainView()
                    .environmentObject(viewModel)
                    .environmentObject(weatherSettings)
                    .environmentObject(weatherStore)
                    .environmentObject(weatherLocationsStore)
                    .environmentObject(displayOrchestrator)
                    .environmentObject(weatherAnimationBudget)
                    .environmentObject(networkStore)
                    .environmentObject(viewModel.wifiStore)
                    .environmentObject(viewModel.audioDevicesStore)
                
                popoverContentViewController = NSHostingController(rootView: tabbedMainView)
                popover.contentViewController = popoverContentViewController
                
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                DispatchQueue.main.async { [weak self] in
                    self?.popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
                }
            }
        }
    }

    private func makeWeatherProvider() -> WeatherProvider {
        #if DEBUG
        if let scenario = debugWeatherScenarioFromArgs() {
            return WeatherDebugScenarioProvider(scenario: scenario)
        }
        #endif

        #if canImport(WeatherKit)
        return WeatherProviderFallback(primary: WeatherKitProvider(), fallback: OpenMeteoProvider())
        #else
        return OpenMeteoProvider()
        #endif
    }

    private func makeWeatherSummaryProvider() -> WeatherProvider {
        #if DEBUG
        if let scenario = debugWeatherScenarioFromArgs() {
            return WeatherDebugScenarioProvider(scenario: scenario)
        }
        #endif

        #if canImport(WeatherKit)
        return WeatherProviderFallback(primary: WeatherKitProvider(), fallback: OpenMeteoProvider(mode: .currentOnly))
        #else
        return OpenMeteoProvider(mode: .currentOnly)
        #endif
    }

    #if DEBUG
    private func debugWeatherScenarioFromArgs() -> WeatherDebugScenarioProvider.Scenario? {
        guard let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--debug-weather-scenario=") }) else {
            return nil
        }

        let raw = arg.split(separator: "=", maxSplits: 1).last.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return WeatherDebugScenarioProvider.Scenario(rawValue: raw)
    }
    #endif
    
    // MARK: - NSPopoverDelegate
    
    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        return false
    }
    
    func popoverDidShow(_ notification: Notification) {
        // Set up event monitor for clicks outside
        if eventMonitor == nil {
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                if let strongSelf = self, strongSelf.popover.isShown {
                    if let contentView = strongSelf.popover.contentViewController?.view,
                       let window = contentView.window
                    {
                        // Global monitor events report screen coordinates; use the current mouse location to
                        // avoid mixing coordinate spaces and accidentally treating inside clicks as outside.
                        let screenLocation = NSEvent.mouseLocation
                        if window.frame.contains(screenLocation) {
                            return
                        }
                    }

                    strongSelf.closePopover()
                }
            }
        }
    }
    
    func popoverDidClose(_ notification: Notification) {
        // Remove event monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    func closePopover() {
        popover.performClose(nil)
    }
    
    // Event monitor for clicks outside popover
    var eventMonitor: Any?
    
    // Helper function to get the app icon for consistent use
    private func getAppIcon() -> NSImage? {
        // First try to get the app icon from bundle resources
        if let resourcePath = Bundle.main.resourcePath {
            let iconPath = "\(resourcePath)/AppIcon.icns"
            
            if let appIcon = NSImage(contentsOfFile: iconPath) {
                return createResizedIcon(from: appIcon)
            }
        }
        
        // Fallback to application icon
        if let appIcon = NSApp.applicationIconImage {
            return createResizedIcon(from: appIcon)
        }
        
        return nil
    }
    
    // Helper to safely create resized icons
    private func createResizedIcon(from sourceIcon: NSImage) -> NSImage? {
        let iconSize = Self.menuBarIconSize
        let menuBarIcon = NSImage(size: NSSize(width: iconSize, height: iconSize))
        
        menuBarIcon.lockFocus()
        defer { menuBarIcon.unlockFocus() } // Ensure context is always unlocked
        
        sourceIcon.draw(in: NSRect(x: 0, y: 0, width: iconSize, height: iconSize), 
                       from: NSRect.zero, 
                       operation: .sourceOver, 
                       fraction: 1.0)
        
        menuBarIcon.isTemplate = false  // Don't make it a template (keep colors)
        return menuBarIcon
    }
    
    // Helper function to get high-quality app icon for dialogs (not resized)
    private func getDialogAppIcon() -> NSImage? {
        // Load the original high-quality icon without resizing
        if let resourcePath = Bundle.main.resourcePath {
            let iconPath = "\(resourcePath)/AppIcon.icns"
            
            if let appIcon = NSImage(contentsOfFile: iconPath) {
                // Return original size for crisp dialog display
                return appIcon
            }
        }
        
        // Fallback to application icon (original size)
        if let appIcon = NSApp.applicationIconImage {
            return appIcon
        }
        
        return nil
    }
}
