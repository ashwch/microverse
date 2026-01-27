import AppKit
import CoreLocation
import SwiftUI

struct WeatherSettingsSection: View {
    enum Style {
        case settings
        case card
    }

    var style: Style = .settings

    @EnvironmentObject private var viewModel: BatteryViewModel
    @EnvironmentObject private var settings: WeatherSettingsStore
    @EnvironmentObject private var weatherStore: WeatherStore
    @EnvironmentObject private var displayOrchestrator: DisplayOrchestrator

    @State private var query = ""
    @State private var results: [CLPlacemark] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var hoveredLocationID: String?
    #if DEBUG
    @State private var isShowingIconGallery = false
    #endif

    private var selectedLocation: WeatherLocation? {
        settings.selectedLocation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MicroverseDesign.Layout.space3) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weather")
                        .font(MicroverseDesign.Typography.body)
                        .foregroundColor(.white)
                    Text("Current temperature and upcoming changes")
                        .font(MicroverseDesign.Typography.caption)
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Toggle("", isOn: $settings.weatherEnabled)
                    .labelsHidden()
                    .toggleStyle(ElegantToggleStyle())
            }

            if settings.weatherEnabled {
                unitsRow
                refreshRow
                animationRows
                notchRows
                locationRow
                smartNotchHint
                #if DEBUG
                debugTestingSection
                #endif

                if let message = errorMessage {
                    Text(message)
                        .font(MicroverseDesign.Typography.caption)
                        .foregroundColor(MicroverseDesign.Colors.warning)
                }
            }
        }
        .padding(.horizontal, style == .settings ? MicroverseDesign.Layout.space5 : 12)
        .padding(.vertical, style == .settings ? MicroverseDesign.Layout.space4 : 12)
        .background {
            if style == .card {
                MicroverseDesign.cardBackground()
            }
        }
        .onDisappear {
            searchTask?.cancel()
            searchTask = nil
        }
    }

    private var unitsRow: some View {
        HStack {
            Text("Units")
                .font(MicroverseDesign.Typography.caption)
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            unitsControl
        }
        .padding(.top, MicroverseDesign.Layout.space2)
    }

    private var refreshRow: some View {
        HStack {
            Text("Refresh")
                .font(MicroverseDesign.Typography.caption)
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            refreshIntervalControl
        }
    }

    private var animationRows: some View {
        VStack(alignment: .leading, spacing: MicroverseDesign.Layout.space2) {
            HStack {
                Text("Animated icons")
                    .font(MicroverseDesign.Typography.caption)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                animatedIconsModeControl
            }

            if settings.weatherShowInNotch, settings.weatherAnimatedIconsMode != .off {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Animate in compact notch")
                            .font(MicroverseDesign.Typography.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text("Micro-motion only")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    Toggle("", isOn: $settings.weatherAnimateInCompactNotch)
                        .labelsHidden()
                        .toggleStyle(ElegantToggleStyle())
                }
                .padding(.leading, MicroverseDesign.Layout.space3)
            }
        }
        .padding(.top, MicroverseDesign.Layout.space1)
    }

    private var notchRows: some View {
        VStack(alignment: .leading, spacing: MicroverseDesign.Layout.space2) {
            HStack {
                Text("Show in Smart Notch")
                    .font(MicroverseDesign.Typography.caption)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Toggle("", isOn: $settings.weatherShowInNotch)
                    .labelsHidden()
                    .toggleStyle(ElegantToggleStyle())
            }

            if settings.weatherShowInNotch, viewModel.isNotchAvailable, viewModel.notchLayoutMode != .off {
                HStack {
                    Text("Preview in notch")
                        .font(MicroverseDesign.Typography.caption)
                        .foregroundColor(.white.opacity(0.55))

                    Spacer()

                    Button("Show now") {
                        displayOrchestrator.previewWeatherInNotch()
                    }
                    .buttonStyle(FlatButtonStyle())
                }
                .padding(.leading, MicroverseDesign.Layout.space3)

                #if DEBUG
                let notchMode = settings.weatherPinInNotch ? "Pinned" : (displayOrchestrator.compactTrailing == .weather ? "Weather" : "System")
                Text("Notch: \(notchMode) (\(displayOrchestrator.debugReason))")
                    .font(MicroverseDesign.Typography.caption)
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.leading, MicroverseDesign.Layout.space3)

                Text(displayOrchestrator.debugCompactScheduleDescription())
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.leading, MicroverseDesign.Layout.space3)
                #endif
            }

            HStack {
                Text("Show in Desktop Widget")
                    .font(MicroverseDesign.Typography.caption)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Toggle("", isOn: $settings.weatherShowInWidget)
                    .labelsHidden()
                    .toggleStyle(ElegantToggleStyle())
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show in Menu Bar")
                        .font(MicroverseDesign.Typography.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("Adds temperature next to the Microverse icon")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Toggle("", isOn: $settings.weatherShowInMenuBar)
                    .labelsHidden()
                    .toggleStyle(ElegantToggleStyle())
            }

            if settings.weatherShowInNotch {
                if viewModel.isNotchAvailable, viewModel.notchLayoutMode != .off {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pinned temperature")
                                .font(MicroverseDesign.Typography.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Text("Always show temperature in compact notch")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(.white.opacity(0.5))
                        }

                        Spacer()

                        Toggle("", isOn: $settings.weatherPinInNotch)
                            .labelsHidden()
                            .toggleStyle(ElegantToggleStyle())
                    }

                    if settings.weatherPinInNotch {
                        HStack {
                            Text("Replaces")
                                .font(MicroverseDesign.Typography.caption)
                                .foregroundColor(.white.opacity(0.7))

                            Spacer()

                            pinnedReplacementControl
                        }
                        .padding(.leading, MicroverseDesign.Layout.space3)

                        let canCycleLocations =
                            settings.weatherLocations.count > 1
                            || (settings.weatherUseCurrentLocation && !settings.weatherLocations.isEmpty)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Show all locations")
                                    .font(MicroverseDesign.Typography.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                Text(
                                    canCycleLocations
                                        ? (settings.weatherUseCurrentLocation
                                            ? "Cycles through current + saved locations in compact notch"
                                            : "Cycles through saved locations in compact notch")
                                        : "Add another location to enable cycling"
                                )
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(.white.opacity(0.5))
                            }

                            Spacer()

                            Toggle("", isOn: $settings.weatherShowAllLocationsInNotch)
                                .labelsHidden()
                                .toggleStyle(ElegantToggleStyle())
                                .disabled(!canCycleLocations)
                        }
                        .padding(.leading, MicroverseDesign.Layout.space3)
                    }
                }

                HStack {
                    Text("Weather highlights")
                        .font(MicroverseDesign.Typography.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    Toggle("", isOn: $settings.weatherSmartSwitchingEnabled)
                        .labelsHidden()
                        .toggleStyle(ElegantToggleStyle())
                }

                HStack {
                    Text("Occasional temperature peek")
                        .font(MicroverseDesign.Typography.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    Toggle("", isOn: $settings.weatherRotationEnabled)
                        .labelsHidden()
                        .toggleStyle(ElegantToggleStyle())
                }

                if settings.weatherRotationEnabled {
                    HStack {
                        Text("Peek interval")
                            .font(MicroverseDesign.Typography.caption)
                            .foregroundColor(.white.opacity(0.7))

                        Spacer()

                        peekIntervalControl
                    }
                    .padding(.leading, MicroverseDesign.Layout.space3)
                }
            }
        }
    }

    private var unitsControl: some View {
        HStack(spacing: 0) {
            unitsButton(.celsius, title: "°C")
            unitsButton(.fahrenheit, title: "°F")
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func unitsButton(_ units: WeatherUnits, title: String) -> some View {
        let isSelected = settings.weatherUnits == units

        return Button {
            settings.weatherUnits = units
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .frame(height: 24)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.white.opacity(0.14) : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Units \(title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private static let refreshIntervals: [(title: String, value: TimeInterval)] = [
        ("15m", 15 * 60),
        ("30m", 30 * 60),
        ("60m", 60 * 60),
    ]

    private var refreshIntervalControl: some View {
        HStack(spacing: 0) {
            ForEach(Self.refreshIntervals, id: \.value) { option in
                refreshIntervalButton(option)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func refreshIntervalButton(_ option: (title: String, value: TimeInterval)) -> some View {
        let isSelected = abs(settings.weatherRefreshInterval - option.value) < 0.5

        return Button {
            settings.weatherRefreshInterval = option.value
        } label: {
            Text(option.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .frame(height: 24)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.white.opacity(0.14) : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Refresh \(option.title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var animatedIconsModeControl: some View {
        HStack(spacing: 0) {
            animatedIconsModeButton(.off, title: "Off")
            animatedIconsModeButton(.subtle, title: "Subtle")
            animatedIconsModeButton(.full, title: "Full")
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func animatedIconsModeButton(_ mode: WeatherSettingsStore.AnimatedIconsMode, title: String) -> some View {
        let isSelected = settings.weatherAnimatedIconsMode == mode

        return Button {
            settings.weatherAnimatedIconsMode = mode
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .frame(height: 24)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.white.opacity(0.14) : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Animated icons \(title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var pinnedReplacementControl: some View {
        HStack(spacing: 2) {
            pinnedReplacementButton(.auto, title: "Auto", systemIcon: "sparkles")
            pinnedReplacementButton(.cpu, title: "CPU", systemIcon: "cpu")
            pinnedReplacementButton(.memory, title: "Memory", systemIcon: "memorychip")
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func pinnedReplacementButton(
        _ replacement: WeatherSettingsStore.PinnedNotchReplacement,
        title: String,
        systemIcon: String
    ) -> some View {
        let isSelected = settings.weatherPinnedNotchReplaces == replacement

        return Button {
            settings.weatherPinnedNotchReplaces = replacement
        } label: {
            HStack(spacing: 5) {
                Image(systemName: systemIcon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .frame(height: 24)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.white.opacity(0.14) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Replace \(title)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private static let peekIntervals: [TimeInterval] = [
        10, 20, 30,
        60, 2 * 60,
        5 * 60, 10 * 60, 15 * 60,
    ]

    private var peekIntervalControl: some View {
        let options = Self.peekIntervals
        let idx = options.firstIndex(where: { abs($0 - settings.weatherRotationInterval) < 0.5 }) ?? 0

        return HStack(spacing: 8) {
            Button {
                let next = max(0, idx - 1)
                settings.weatherRotationInterval = options[next]
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(idx == 0 ? 0.25 : 0.75))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(idx == 0)
            .accessibilityLabel("Decrease interval")

            Text(formatPeekInterval(options[idx]))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .monospacedDigit()
                .frame(minWidth: 42, alignment: .center)

            Button {
                let next = min(options.count - 1, idx + 1)
                settings.weatherRotationInterval = options[next]
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(idx == options.count - 1 ? 0.25 : 0.75))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(idx == options.count - 1)
            .accessibilityLabel("Increase interval")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .accessibilityLabel("Peek interval")
        .accessibilityValue(formatPeekInterval(options[idx]))
    }

    private func formatPeekInterval(_ interval: TimeInterval) -> String {
        let seconds = Int(interval.rounded())
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        return "\(minutes)m"
    }

    private var smartNotchHint: some View {
        Group {
            if viewModel.isNotchAvailable, settings.weatherShowInNotch, viewModel.notchLayoutMode == .off {
                HStack(spacing: 8) {
                    Text("Smart Notch is off.")
                        .font(MicroverseDesign.Typography.caption)
                        .foregroundColor(.white.opacity(0.6))

                    Spacer()

                    Button("Enable") {
                        viewModel.notchLayoutMode = .split
                    }
                    .buttonStyle(FlatButtonStyle())
                }
                .padding(.top, MicroverseDesign.Layout.space1)
            }
        }
    }

    #if DEBUG
    private var debugTestingSection: some View {
        VStack(alignment: .leading, spacing: MicroverseDesign.Layout.space2) {
            Text("TEST WEATHER")
                .font(MicroverseDesign.Typography.label)
                .foregroundColor(.white.opacity(0.5))
                .tracking(0.8)

            if selectedLocation == nil {
                Text("Set a location to test scenarios.")
                    .font(MicroverseDesign.Typography.caption)
                    .foregroundColor(.white.opacity(0.55))
            }

            HStack {
                Button("Icon gallery") {
                    isShowingIconGallery = true
                }
                .buttonStyle(FlatButtonStyle())

                Spacer()

                Button("Run demo") {
                    Task { @MainActor in
                        await runWeatherDebugDemo()
                    }
                }
                .buttonStyle(FlatButtonStyle())
                .disabled(selectedLocation == nil)
            }

            HStack(spacing: MicroverseDesign.Layout.space2) {
                debugScenarioButton("Clear", scenario: .clear)
                debugScenarioButton("Rain", scenario: .rainIn25m)
                debugScenarioButton("Clearing", scenario: .clearingIn20m)
            }

            HStack(spacing: MicroverseDesign.Layout.space2) {
                debugScenarioButton("Thunder", scenario: .thunderIn2h)
                debugScenarioButton("Temp drop", scenario: .tempDropIn2h)

                if viewModel.isNotchAvailable, viewModel.notchLayoutMode != .off {
                    Button("Expand") {
                        Task { @MainActor in
                            try? await NotchServiceLocator.current?.expandNotch()
                        }
                    }
                    .buttonStyle(FlatButtonStyle())
                }
            }
        }
        .padding(.top, MicroverseDesign.Layout.space2)
        .sheet(isPresented: $isShowingIconGallery) {
            WeatherIconGallery()
        }
    }

    private func debugScenarioButton(_ title: String, scenario: WeatherDebugScenarioProvider.Scenario) -> some View {
        Button(title) {
            weatherStore.debugApplyScenario(scenario)
            displayOrchestrator.previewWeatherInNotch(duration: 20)
        }
        .buttonStyle(FlatButtonStyle())
        .disabled(selectedLocation == nil)
    }

    @MainActor
    private func runWeatherDebugDemo() async {
        guard selectedLocation != nil else { return }

        let previous = DebugWeatherSettingsSnapshot.capture(settings: settings)
        defer { previous.restore(settings: settings) }

        settings.weatherEnabled = true
        settings.weatherShowInNotch = true
        settings.weatherShowInWidget = true
        settings.weatherSmartSwitchingEnabled = true

        let scenarios: [WeatherDebugScenarioProvider.Scenario] = [
            .clear,
            .rainIn25m,
            .clearingIn20m,
            .thunderIn2h,
            .tempDropIn2h,
        ]

        for scenario in scenarios {
            weatherStore.debugApplyScenario(scenario)
            displayOrchestrator.previewWeatherInNotch(duration: 20)

            if viewModel.isNotchAvailable, viewModel.notchLayoutMode != .off {
                try? await NotchServiceLocator.current?.expandNotch()
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                try? await NotchServiceLocator.current?.compactNotch()
            }

            try? await Task.sleep(nanoseconds: 1_200_000_000)
        }
    }

    @MainActor
    private struct DebugWeatherSettingsSnapshot {
        var weatherEnabled: Bool
        var weatherShowInNotch: Bool
        var weatherShowInWidget: Bool
        var weatherSmartSwitchingEnabled: Bool

        static func capture(settings: WeatherSettingsStore) -> DebugWeatherSettingsSnapshot {
            DebugWeatherSettingsSnapshot(
                weatherEnabled: settings.weatherEnabled,
                weatherShowInNotch: settings.weatherShowInNotch,
                weatherShowInWidget: settings.weatherShowInWidget,
                weatherSmartSwitchingEnabled: settings.weatherSmartSwitchingEnabled
            )
        }

        func restore(settings: WeatherSettingsStore) {
            settings.weatherEnabled = weatherEnabled
            settings.weatherShowInNotch = weatherShowInNotch
            settings.weatherShowInWidget = weatherShowInWidget
            settings.weatherSmartSwitchingEnabled = weatherSmartSwitchingEnabled
        }
    }
    #endif

    private var locationRow: some View {
        VStack(alignment: .leading, spacing: MicroverseDesign.Layout.space2) {
            HStack {
                Text("Locations")
                    .font(MicroverseDesign.Typography.caption)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                if !settings.weatherLocations.isEmpty {
                    Text("\(settings.weatherLocations.count) saved")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                        .monospacedDigit()
                }
            }

            currentLocationRow

            if settings.weatherLocations.isEmpty {
                Text("No saved locations.")
                    .font(MicroverseDesign.Typography.caption)
                    .foregroundColor(.white.opacity(0.55))
            } else {
                VStack(spacing: 0) {
                    ForEach(settings.weatherLocations) { location in
                        locationRowItem(location)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
            }

            HStack(spacing: 8) {
                TextField("Search city…", text: $query)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(MicroverseDesign.Typography.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .onSubmit { startSearch() }

                Button(action: startSearch) {
                    if isSearching {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white.opacity(0.7))
                    } else {
                        Text("Search")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(FlatButtonStyle())
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
            }

            if !results.isEmpty {
                let limitedCount = min(results.count, 6)
                VStack(spacing: 0) {
                    ForEach(Array(results.prefix(6).enumerated()), id: \.offset) { idx, placemark in
                        Button(action: { select(placemark) }) {
                            let displayName = WeatherPlacemarkNameFormatter.displayName(for: placemark)
                            let parts = displayName
                                .split(separator: ",")
                                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                            let primary = parts.first ?? displayName
                            let secondary = parts.dropFirst().joined(separator: " · ")

                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(primary)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    if !secondary.isEmpty {
                                        Text(secondary)
                                            .font(.system(size: 9, weight: .regular))
                                            .foregroundColor(.white.opacity(0.55))
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                                    .frame(width: 18, height: 18)
                                    .padding(4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 7)
                                            .fill(Color.white.opacity(0.06))
                                    )
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(PlainButtonStyle())

                        if idx < limitedCount - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 1)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
            }
        }
    }

    private func locationRowItem(_ location: WeatherLocation) -> some View {
        let isSelected = !settings.weatherUseCurrentLocation && location.id == settings.weatherSelectedLocationID
        let isHovered = hoveredLocationID == location.id
        let primary = location.microversePrimaryName()
        let secondary = location.microverseSecondaryName()

        return ZStack(alignment: .trailing) {
            Button {
                settings.selectLocation(id: location.id)
                results = []
                errorMessage = nil
            } label: {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(primary)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(isSelected ? 1.0 : 0.85))
                            .lineLimit(1)

                        if let secondary {
                            Text(secondary)
                                .font(.system(size: 9, weight: .regular))
                                .foregroundColor(.white.opacity(0.45))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(MicroverseDesign.Colors.accent)
                    }

                    // Reserve space so the row doesn't jump when the hover action appears.
                    Color.clear
                        .frame(width: 22, height: 22)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(isSelected ? 0.08 : (isHovered ? 0.04 : 0.0)))
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if isHovered || isSelected {
                Button {
                    settings.removeLocation(id: location.id)
                    results = []
                    errorMessage = nil
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Remove")
                .padding(.trailing, 10)
            }
        }
        .onHover { hovering in
            if hovering {
                hoveredLocationID = location.id
            } else if hoveredLocationID == location.id {
                hoveredLocationID = nil
            }
        }
    }

    private func startSearch() {
        errorMessage = nil
        results = []

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }

        searchTask?.cancel()
        searchTask = Task {
            await performSearch(query: q)
        }
    }

    @MainActor
    private func performSearch(query: String) async {
        isSearching = true
        defer { isSearching = false }

        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            results = placemarks.filter { $0.location != nil }
            if results.isEmpty {
                errorMessage = "No matches found."
            }
        } catch is CancellationError {
            // Ignore cancellation (user typed a new query or navigated away).
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func select(_ placemark: CLPlacemark) {
        guard let loc = placemark.location else { return }

        let tz = placemark.timeZone?.identifier ?? TimeZone.current.identifier
        let name = WeatherPlacemarkNameFormatter.displayName(for: placemark)

        guard let location = WeatherLocation(
            displayName: name,
            latitude: loc.coordinate.latitude,
            longitude: loc.coordinate.longitude,
            timezoneIdentifier: tz
        ) else {
            errorMessage = "Selected location had invalid coordinates."
            return
        }

        settings.addOrSelectLocation(location)

        query = ""
        results = []
        errorMessage = nil
    }

    private var currentLocationRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(settings.weatherUseCurrentLocation ? MicroverseDesign.Colors.accent : .white.opacity(0.7))
                    .frame(width: 16, height: 16, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Current location")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))

                    Text(currentLocationSubtitle)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer()

                if settings.weatherUseCurrentLocation, settings.weatherCurrentLocationIsUpdating, settings.weatherCurrentLocation == nil {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white.opacity(0.65))
                }

                Toggle("", isOn: $settings.weatherUseCurrentLocation)
                    .labelsHidden()
                    .toggleStyle(ElegantToggleStyle())
                    .onChange(of: settings.weatherUseCurrentLocation) { enabled in
                        guard enabled else { return }
                        settings.requestCurrentLocationAuthorization()
                    }
            }

            if settings.weatherUseCurrentLocation {
                if let error = settings.weatherCurrentLocationErrorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(MicroverseDesign.Colors.warning.opacity(0.9))
                        Text(error)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                } else if shouldShowLocationPermissionCTA {
                    HStack {
                        Text("Allow Microverse to use your location for local weather.")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.white.opacity(0.55))

                        Spacer()

                        Button("Allow") {
                            settings.requestCurrentLocationAuthorization()
                        }
                        .buttonStyle(FlatButtonStyle())
                    }
                } else if shouldShowLocationSettingsCTA {
                    HStack {
                        Text("Enable Location Services for Microverse in System Settings.")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.white.opacity(0.55))

                        Spacer()

                        Button("Open Settings") {
                            openLocationSystemSettings()
                        }
                        .buttonStyle(FlatButtonStyle())
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private var currentLocationSubtitle: String {
        guard settings.weatherUseCurrentLocation else {
            return "Use your Mac’s location for Weather"
        }

        if let location = settings.weatherCurrentLocation {
            let name = location.microverseDisplayName()
            return name.isEmpty ? "Using current location" : "Using \(name)"
        }

        let status = settings.weatherCurrentLocationAuthorizationStatus
        if !CLLocationManager.locationServicesEnabled() {
            return "Location Services are off"
        }

        switch status {
        case .notDetermined:
            return "Needs permission"
        case .restricted, .denied:
            return "No access"
        case .authorizedAlways, .authorized:
            return "Locating…"
        @unknown default:
            return "Locating…"
        }
    }

    private var shouldShowLocationPermissionCTA: Bool {
        guard settings.weatherUseCurrentLocation else { return false }
        guard CLLocationManager.locationServicesEnabled() else { return false }
        return settings.weatherCurrentLocationAuthorizationStatus == .notDetermined
    }

    private var shouldShowLocationSettingsCTA: Bool {
        guard settings.weatherUseCurrentLocation else { return false }
        guard CLLocationManager.locationServicesEnabled() else { return true }
        switch settings.weatherCurrentLocationAuthorizationStatus {
        case .restricted, .denied:
            return true
        default:
            return false
        }
    }

    private func openLocationSystemSettings() {
        // Best-effort deep link; falls back to opening System Settings if the URL isn't supported.
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
            return
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }
}
