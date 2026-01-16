import CoreLocation
import SwiftUI

struct WeatherSettingsSection: View {
    @EnvironmentObject private var viewModel: BatteryViewModel
    @EnvironmentObject private var settings: WeatherSettingsStore
    @EnvironmentObject private var weatherStore: WeatherStore
    @EnvironmentObject private var displayOrchestrator: DisplayOrchestrator

    @State private var query = ""
    @State private var results: [CLPlacemark] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    #if DEBUG
    @State private var isShowingIconGallery = false
    #endif

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
        .padding(.horizontal, MicroverseDesign.Layout.space5)
        .padding(.vertical, MicroverseDesign.Layout.space4)
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

            Picker("", selection: $settings.weatherUnits) {
                Text("°C").tag(WeatherUnits.celsius)
                Text("°F").tag(WeatherUnits.fahrenheit)
            }
            .labelsHidden()
            .pickerStyle(MenuPickerStyle())
            .frame(width: 120)
        }
        .padding(.top, MicroverseDesign.Layout.space2)
    }

    private var refreshRow: some View {
        HStack {
            Text("Refresh")
                .font(MicroverseDesign.Typography.caption)
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Picker("", selection: $settings.weatherRefreshInterval) {
                Text("15m").tag(15.0 * 60.0)
                Text("30m").tag(30.0 * 60.0)
                Text("60m").tag(60.0 * 60.0)
            }
            .labelsHidden()
            .pickerStyle(MenuPickerStyle())
            .frame(width: 120)
        }
    }

    private var animationRows: some View {
        VStack(alignment: .leading, spacing: MicroverseDesign.Layout.space2) {
            HStack {
                Text("Animated icons")
                    .font(MicroverseDesign.Typography.caption)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Picker("", selection: $settings.weatherAnimatedIconsMode) {
                    Text("Off").tag(WeatherSettingsStore.AnimatedIconsMode.off)
                    Text("Subtle").tag(WeatherSettingsStore.AnimatedIconsMode.subtle)
                    Text("Full").tag(WeatherSettingsStore.AnimatedIconsMode.full)
                }
                .labelsHidden()
                .pickerStyle(MenuPickerStyle())
                .frame(width: 120)
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

                            Picker("", selection: $settings.weatherPinnedNotchReplaces) {
                                Text("CPU").tag(WeatherSettingsStore.PinnedNotchReplacement.cpu)
                                Text("Memory").tag(WeatherSettingsStore.PinnedNotchReplacement.memory)
                            }
                            .labelsHidden()
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 120)
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

                        Picker("", selection: $settings.weatherRotationInterval) {
                            Text("10s").tag(10.0)
                            Text("20s").tag(20.0)
                            Text("30s").tag(30.0)
                            Text("1m").tag(60.0)
                            Text("2m").tag(2.0 * 60.0)
                            Text("5m").tag(5.0 * 60.0)
                            Text("10m").tag(10.0 * 60.0)
                            Text("15m").tag(15.0 * 60.0)
                        }
                        .labelsHidden()
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 120)
                    }
                    .padding(.leading, MicroverseDesign.Layout.space3)
                }
            }
        }
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

            if settings.weatherLocation == nil {
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
                .disabled(settings.weatherLocation == nil)
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
        .disabled(settings.weatherLocation == nil)
    }

    @MainActor
    private func runWeatherDebugDemo() async {
        guard settings.weatherLocation != nil else { return }

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
                Text("Location")
                    .font(MicroverseDesign.Typography.caption)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                if settings.weatherLocation != nil {
                    Button("Clear") {
                        settings.weatherLocation = nil
                        results = []
                        errorMessage = nil
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.white.opacity(0.7))
                }
            }

            if let location = settings.weatherLocation {
                Text(location.displayName)
                    .font(MicroverseDesign.Typography.body)
                    .foregroundColor(.white)
                    .lineLimit(1)
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
                            VStack(alignment: .leading, spacing: 2) {
                                Text(placemarkDisplayName(placemark))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                if let loc = placemark.location {
                                    Text("\(loc.coordinate.latitude, specifier: "%.3f"), \(loc.coordinate.longitude, specifier: "%.3f")")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.55))
                                        .monospacedDigit()
                                }
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
        let name = placemarkDisplayName(placemark)

        guard let location = WeatherLocation(
            displayName: name,
            latitude: loc.coordinate.latitude,
            longitude: loc.coordinate.longitude,
            timezoneIdentifier: tz
        ) else {
            errorMessage = "Selected location had invalid coordinates."
            return
        }

        settings.weatherLocation = location

        results = []
        errorMessage = nil
    }

    private func placemarkDisplayName(_ placemark: CLPlacemark) -> String {
        var parts: [String] = []

        if let locality = placemark.locality, !locality.isEmpty {
            parts.append(locality)
        } else if let name = placemark.name, !name.isEmpty {
            parts.append(name)
        }

        if let admin = placemark.administrativeArea, !admin.isEmpty {
            parts.append(admin)
        }

        if let country = placemark.country, !country.isEmpty {
            parts.append(country)
        }

        if parts.isEmpty {
            return "Selected Location"
        }

        return parts.joined(separator: ", ")
    }
}
