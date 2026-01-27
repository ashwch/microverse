import Combine
import CoreLocation
import Foundation

struct WeatherSettingsSnapshot: Sendable, Equatable {
    var enabled: Bool
    var units: WeatherUnits
    var location: WeatherLocation?
    var refreshInterval: TimeInterval

    var precipStartThreshold: Double
    var precipStopThreshold: Double
    var tempDeltaThresholdC: Double
    var tempDeltaWindowHours: Int

    var smartSwitchingEnabled: Bool
    var rotationEnabled: Bool
    var rotationInterval: TimeInterval
    var minDwell: TimeInterval
    var eventBoostDuration: TimeInterval
    var cooldown: TimeInterval

    var showInNotch: Bool
    var showInWidget: Bool
    var showInMenuBar: Bool

    var pinInNotch: Bool
    var pinnedNotchReplaces: WeatherSettingsStore.PinnedNotchReplacement

    var animatedIconsMode: WeatherSettingsStore.AnimatedIconsMode
    var animateInCompactNotch: Bool
}

/// UserDefaults-backed settings and small bits of state for the Weather feature.
///
/// ## First principles
/// - **Single source of truth:** multiple UI surfaces (popover, notch, widget, menu bar) read the same settings.
/// - **Predictable persistence:** UserDefaults keys are centralized here to avoid “magic strings” spread across views.
/// - **Energy-aware current location:** when enabled, we request **When In Use** and use coarse location updates.
///
/// ## Multi-location + migration
/// v0.7.0 stored a single `WeatherLocation` under `weatherLocation`.
/// Newer versions store `weatherLocations` + `weatherSelectedLocationID` and migrate the legacy key on first run.
@MainActor
final class WeatherSettingsStore: ObservableObject {
    enum AnimatedIconsMode: String, CaseIterable, Codable, Sendable {
        case off
        case subtle
        case full
    }

    enum PinnedNotchReplacement: String, CaseIterable, Codable, Sendable {
        case auto
        case cpu
        case memory
    }

    private enum Keys {
        static let weatherEnabled = "weatherEnabled"
        static let weatherUnits = "weatherUnits"
        static let weatherLocation = "weatherLocation" // legacy (v0.7.0)
        static let weatherLocations = "weatherLocations"
        static let weatherSelectedLocationID = "weatherSelectedLocationID"
        static let weatherRefreshInterval = "weatherRefreshInterval"
        static let weatherUseCurrentLocation = "weatherUseCurrentLocation"

        static let weatherShowInNotch = "weatherShowInNotch"
        static let weatherShowInWidget = "weatherShowInWidget"
        static let weatherShowInMenuBar = "weatherShowInMenuBar"
        static let weatherShowAllLocationsInNotch = "weatherShowAllLocationsInNotch"

        static let weatherAlertsEnabled = "weatherAlertsEnabled"
        static let weatherAlertLeadTime = "weatherAlertLeadTime"
        static let weatherAlertCooldown = "weatherAlertCooldown"
        static let weatherAlertPrecipitation = "weatherAlertPrecipitation"
        static let weatherAlertStorm = "weatherAlertStorm"
        static let weatherAlertTempChange = "weatherAlertTempChange"

        static let weatherSmartSwitchingEnabled = "weatherSmartSwitchingEnabled"
        static let weatherRotationEnabled = "weatherRotationEnabled"
        static let weatherRotationInterval = "weatherRotationInterval"
        static let weatherMinDwell = "weatherMinDwell"
        static let weatherEventBoostDuration = "weatherEventBoostDuration"
        static let weatherCooldown = "weatherCooldown"

        static let weatherPrecipStartThreshold = "weatherPrecipStartThreshold"
        static let weatherPrecipStopThreshold = "weatherPrecipStopThreshold"
        static let weatherTempDeltaThresholdC = "weatherTempDeltaThresholdC"
        static let weatherTempDeltaWindowHours = "weatherTempDeltaWindowHours"

        static let weatherPinInNotch = "weatherPinInNotch"
        static let weatherPinnedNotchReplaces = "weatherPinnedNotchReplaces"

        static let weatherAnimatedIconsMode = "weatherAnimatedIconsMode"
        static let weatherAnimateInCompactNotch = "weatherAnimateInCompactNotch"
    }

    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    @Published var weatherEnabled: Bool {
        didSet {
            defaults.set(weatherEnabled, forKey: Keys.weatherEnabled)
            updateCurrentLocationTracking(reason: "weather_enabled_changed")
        }
    }
    @Published var weatherUnits: WeatherUnits { didSet { defaults.set(weatherUnits.rawValue, forKey: Keys.weatherUnits) } }
    @Published var weatherLocations: [WeatherLocation] {
        didSet {
            saveCodable(weatherLocations, key: Keys.weatherLocations)
            ensureSelectedLocationValid()
        }
    }

    @Published var weatherSelectedLocationID: String? {
        didSet {
            defaults.set(weatherSelectedLocationID, forKey: Keys.weatherSelectedLocationID)
            ensureSelectedLocationValid()
        }
    }
    @Published var weatherRefreshInterval: TimeInterval { didSet { defaults.set(weatherRefreshInterval, forKey: Keys.weatherRefreshInterval) } }

    @Published var weatherUseCurrentLocation: Bool {
        didSet {
            defaults.set(weatherUseCurrentLocation, forKey: Keys.weatherUseCurrentLocation)
            updateCurrentLocationTracking(reason: "current_location_toggled")
        }
    }

    @Published private(set) var weatherCurrentLocationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var weatherCurrentLocationIsUpdating: Bool = false
    @Published private(set) var weatherCurrentLocation: WeatherLocation?
    @Published private(set) var weatherCurrentLocationLastUpdated: Date?
    @Published private(set) var weatherCurrentLocationErrorMessage: String?

    @Published var weatherShowInNotch: Bool { didSet { defaults.set(weatherShowInNotch, forKey: Keys.weatherShowInNotch) } }
    @Published var weatherShowInWidget: Bool { didSet { defaults.set(weatherShowInWidget, forKey: Keys.weatherShowInWidget) } }
    @Published var weatherShowInMenuBar: Bool { didSet { defaults.set(weatherShowInMenuBar, forKey: Keys.weatherShowInMenuBar) } }
    @Published var weatherShowAllLocationsInNotch: Bool { didSet { defaults.set(weatherShowAllLocationsInNotch, forKey: Keys.weatherShowAllLocationsInNotch) } }

    @Published var weatherAlertsEnabled: Bool { didSet { defaults.set(weatherAlertsEnabled, forKey: Keys.weatherAlertsEnabled) } }
    @Published var weatherAlertLeadTime: TimeInterval { didSet { defaults.set(weatherAlertLeadTime, forKey: Keys.weatherAlertLeadTime) } }
    @Published var weatherAlertCooldown: TimeInterval { didSet { defaults.set(weatherAlertCooldown, forKey: Keys.weatherAlertCooldown) } }
    @Published var weatherAlertPrecipitation: Bool { didSet { defaults.set(weatherAlertPrecipitation, forKey: Keys.weatherAlertPrecipitation) } }
    @Published var weatherAlertStorm: Bool { didSet { defaults.set(weatherAlertStorm, forKey: Keys.weatherAlertStorm) } }
    @Published var weatherAlertTempChange: Bool { didSet { defaults.set(weatherAlertTempChange, forKey: Keys.weatherAlertTempChange) } }

    @Published var weatherPinInNotch: Bool { didSet { defaults.set(weatherPinInNotch, forKey: Keys.weatherPinInNotch) } }
    @Published var weatherPinnedNotchReplaces: PinnedNotchReplacement {
        didSet { defaults.set(weatherPinnedNotchReplaces.rawValue, forKey: Keys.weatherPinnedNotchReplaces) }
    }

    @Published var weatherSmartSwitchingEnabled: Bool { didSet { defaults.set(weatherSmartSwitchingEnabled, forKey: Keys.weatherSmartSwitchingEnabled) } }
    @Published var weatherRotationEnabled: Bool { didSet { defaults.set(weatherRotationEnabled, forKey: Keys.weatherRotationEnabled) } }
    @Published var weatherRotationInterval: TimeInterval { didSet { defaults.set(weatherRotationInterval, forKey: Keys.weatherRotationInterval) } }
    @Published var weatherMinDwell: TimeInterval { didSet { defaults.set(weatherMinDwell, forKey: Keys.weatherMinDwell) } }
    @Published var weatherEventBoostDuration: TimeInterval { didSet { defaults.set(weatherEventBoostDuration, forKey: Keys.weatherEventBoostDuration) } }
    @Published var weatherCooldown: TimeInterval { didSet { defaults.set(weatherCooldown, forKey: Keys.weatherCooldown) } }

    @Published var weatherPrecipStartThreshold: Double
    @Published var weatherPrecipStopThreshold: Double
    @Published var weatherTempDeltaThresholdC: Double
    @Published var weatherTempDeltaWindowHours: Int { didSet { defaults.set(weatherTempDeltaWindowHours, forKey: Keys.weatherTempDeltaWindowHours) } }

    @Published var weatherAnimatedIconsMode: AnimatedIconsMode { didSet { defaults.set(weatherAnimatedIconsMode.rawValue, forKey: Keys.weatherAnimatedIconsMode) } }
    @Published var weatherAnimateInCompactNotch: Bool { didSet { defaults.set(weatherAnimateInCompactNotch, forKey: Keys.weatherAnimateInCompactNotch) } }

    private var currentLocationController: WeatherCurrentLocationController?

    var selectedLocation: WeatherLocation? {
        if weatherUseCurrentLocation {
            return weatherCurrentLocation
        }
        if let id = weatherSelectedLocationID,
           let selected = weatherLocations.first(where: { $0.id == id }) {
            return selected
        }
        return weatherLocations.first
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let defaultUnits: WeatherUnits = Locale.current.measurementSystem == .metric ? .celsius : .fahrenheit

        defaults.register(defaults: [
            Keys.weatherEnabled: false,
            Keys.weatherUnits: defaultUnits.rawValue,
            Keys.weatherRefreshInterval: 30 * 60,
            Keys.weatherUseCurrentLocation: false,

            Keys.weatherShowInNotch: true,
            Keys.weatherShowInWidget: true,
            Keys.weatherShowInMenuBar: false,
            Keys.weatherShowAllLocationsInNotch: true,

            Keys.weatherAlertsEnabled: false,
            Keys.weatherAlertLeadTime: 30 * 60,
            Keys.weatherAlertCooldown: 60 * 60,
            Keys.weatherAlertPrecipitation: true,
            Keys.weatherAlertStorm: true,
            Keys.weatherAlertTempChange: false,

            Keys.weatherPinInNotch: false,
            Keys.weatherPinnedNotchReplaces: PinnedNotchReplacement.memory.rawValue,

            Keys.weatherSmartSwitchingEnabled: true,
            Keys.weatherRotationEnabled: false,
            Keys.weatherRotationInterval: 15 * 60,
            Keys.weatherMinDwell: 8,
            Keys.weatherEventBoostDuration: 12,
            Keys.weatherCooldown: 15 * 60,

            Keys.weatherPrecipStartThreshold: 0.40,
            Keys.weatherPrecipStopThreshold: 0.25,
            Keys.weatherTempDeltaThresholdC: 5.0,
            Keys.weatherTempDeltaWindowHours: 2,

            Keys.weatherAnimatedIconsMode: AnimatedIconsMode.subtle.rawValue,
            Keys.weatherAnimateInCompactNotch: false
        ])

        weatherEnabled = defaults.bool(forKey: Keys.weatherEnabled)
        weatherUnits = WeatherUnits(rawValue: defaults.string(forKey: Keys.weatherUnits) ?? "") ?? .celsius

        weatherRefreshInterval = defaults.double(forKey: Keys.weatherRefreshInterval)
        weatherUseCurrentLocation = defaults.bool(forKey: Keys.weatherUseCurrentLocation)

        weatherShowInNotch = defaults.bool(forKey: Keys.weatherShowInNotch)
        weatherShowInWidget = defaults.bool(forKey: Keys.weatherShowInWidget)
        weatherShowInMenuBar = defaults.bool(forKey: Keys.weatherShowInMenuBar)
        weatherShowAllLocationsInNotch = defaults.bool(forKey: Keys.weatherShowAllLocationsInNotch)

        weatherAlertsEnabled = defaults.bool(forKey: Keys.weatherAlertsEnabled)
        weatherAlertLeadTime = defaults.double(forKey: Keys.weatherAlertLeadTime)
        weatherAlertCooldown = defaults.double(forKey: Keys.weatherAlertCooldown)
        weatherAlertPrecipitation = defaults.bool(forKey: Keys.weatherAlertPrecipitation)
        weatherAlertStorm = defaults.bool(forKey: Keys.weatherAlertStorm)
        weatherAlertTempChange = defaults.bool(forKey: Keys.weatherAlertTempChange)

        weatherPinInNotch = defaults.bool(forKey: Keys.weatherPinInNotch)
        weatherPinnedNotchReplaces =
            PinnedNotchReplacement(rawValue: defaults.string(forKey: Keys.weatherPinnedNotchReplaces) ?? "")
            ?? .memory

        weatherSmartSwitchingEnabled = defaults.bool(forKey: Keys.weatherSmartSwitchingEnabled)
        weatherRotationEnabled = defaults.bool(forKey: Keys.weatherRotationEnabled)
        weatherRotationInterval = defaults.double(forKey: Keys.weatherRotationInterval)
        weatherMinDwell = defaults.double(forKey: Keys.weatherMinDwell)
        weatherEventBoostDuration = defaults.double(forKey: Keys.weatherEventBoostDuration)
        weatherCooldown = defaults.double(forKey: Keys.weatherCooldown)

        weatherPrecipStartThreshold = defaults.double(forKey: Keys.weatherPrecipStartThreshold)
        weatherPrecipStopThreshold = defaults.double(forKey: Keys.weatherPrecipStopThreshold)
        weatherTempDeltaThresholdC = defaults.double(forKey: Keys.weatherTempDeltaThresholdC)
        weatherTempDeltaWindowHours = defaults.integer(forKey: Keys.weatherTempDeltaWindowHours)

        weatherAnimatedIconsMode =
            AnimatedIconsMode(rawValue: defaults.string(forKey: Keys.weatherAnimatedIconsMode) ?? "")
            ?? .subtle
        weatherAnimateInCompactNotch = defaults.bool(forKey: Keys.weatherAnimateInCompactNotch)

        // Load multi-location state (v0.7.1+). If absent, migrate from v0.7.0's single-location key.
        let loadedLocations = Self.loadCodable([WeatherLocation].self, defaults: defaults, key: Keys.weatherLocations) ?? []
        let loadedSelectedID = defaults.string(forKey: Keys.weatherSelectedLocationID)

        if loadedLocations.isEmpty,
           let legacy = Self.loadCodable(WeatherLocation.self, defaults: defaults, key: Keys.weatherLocation)
        {
            weatherLocations = [legacy]
            weatherSelectedLocationID = legacy.id
        } else {
            weatherLocations = loadedLocations
            weatherSelectedLocationID = loadedSelectedID
        }

        normalizeLocationDisplayNamesIfNeeded()
        ensureSelectedLocationValid()

        // Debounce slider-driven persistence so we don't spam UserDefaults.
        $weatherPrecipStartThreshold
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [defaults] v in defaults.set(v, forKey: Keys.weatherPrecipStartThreshold) }
            .store(in: &cancellables)

        $weatherPrecipStopThreshold
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [defaults] v in defaults.set(v, forKey: Keys.weatherPrecipStopThreshold) }
            .store(in: &cancellables)

        $weatherTempDeltaThresholdC
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [defaults] v in defaults.set(v, forKey: Keys.weatherTempDeltaThresholdC) }
            .store(in: &cancellables)

        updateCurrentLocationTracking(reason: "init")
    }

    func addOrSelectLocation(_ location: WeatherLocation) {
        weatherUseCurrentLocation = false

        if let idx = weatherLocations.firstIndex(where: { $0.id == location.id }) {
            // Keep the newest display name/timezone, but preserve ordering.
            weatherLocations[idx] = location
        } else {
            weatherLocations.append(location)
        }

        weatherSelectedLocationID = location.id
    }

    func selectLocation(id: String) {
        weatherUseCurrentLocation = false
        weatherSelectedLocationID = id
    }

    func removeLocation(id: String) {
        weatherLocations.removeAll(where: { $0.id == id })
        if weatherSelectedLocationID == id {
            weatherSelectedLocationID = weatherLocations.first?.id
        }
        ensureSelectedLocationValid()
    }

    func clearLocations() {
        weatherLocations = []
        weatherSelectedLocationID = nil
    }

    func requestCurrentLocationUpdate() {
        guard weatherUseCurrentLocation else { return }
        ensureCurrentLocationController().requestOneShotUpdate()
    }

    func requestCurrentLocationAuthorization() {
        ensureCurrentLocationController().start()
    }

    func snapshot() -> WeatherSettingsSnapshot {
        WeatherSettingsSnapshot(
            enabled: weatherEnabled,
            units: weatherUnits,
            location: selectedLocation,
            refreshInterval: weatherRefreshInterval,
            precipStartThreshold: weatherPrecipStartThreshold,
            precipStopThreshold: weatherPrecipStopThreshold,
            tempDeltaThresholdC: weatherTempDeltaThresholdC,
            tempDeltaWindowHours: weatherTempDeltaWindowHours,
            smartSwitchingEnabled: weatherSmartSwitchingEnabled,
            rotationEnabled: weatherRotationEnabled,
            rotationInterval: weatherRotationInterval,
            minDwell: weatherMinDwell,
            eventBoostDuration: weatherEventBoostDuration,
            cooldown: weatherCooldown,
            showInNotch: weatherShowInNotch,
            showInWidget: weatherShowInWidget,
            showInMenuBar: weatherShowInMenuBar,
            pinInNotch: weatherPinInNotch,
            pinnedNotchReplaces: weatherPinnedNotchReplaces,
            animatedIconsMode: weatherAnimatedIconsMode,
            animateInCompactNotch: weatherAnimateInCompactNotch
        )
    }

    private func ensureCurrentLocationController() -> WeatherCurrentLocationController {
        if let currentLocationController { return currentLocationController }

        let controller = WeatherCurrentLocationController()
        controller.onAuthorizationChanged = { [weak self] status in
            guard let self else { return }
            self.weatherCurrentLocationAuthorizationStatus = status
        }
        controller.onUpdatingChanged = { [weak self] isUpdating in
            guard let self else { return }
            self.weatherCurrentLocationIsUpdating = isUpdating
        }
        controller.onUpdate = { [weak self] update in
            guard let self else { return }
            self.weatherCurrentLocation = update.location
            self.weatherCurrentLocationLastUpdated = Date()
        }
        controller.onError = { [weak self] message in
            guard let self else { return }
            self.weatherCurrentLocationErrorMessage = message
        }

        currentLocationController = controller
        weatherCurrentLocationAuthorizationStatus = controller.authorizationStatus
        return controller
    }

    private func updateCurrentLocationTracking(reason: String) {
        guard weatherEnabled, weatherUseCurrentLocation else {
            currentLocationController?.stop()
            weatherCurrentLocationIsUpdating = false
            return
        }

        let controller = ensureCurrentLocationController()
        weatherCurrentLocationAuthorizationStatus = controller.authorizationStatus
        controller.start()
    }

    private func ensureSelectedLocationValid() {
        let resolvedID = weatherLocations.first(where: { $0.id == weatherSelectedLocationID })?.id ?? weatherLocations.first?.id
        if weatherSelectedLocationID != resolvedID {
            weatherSelectedLocationID = resolvedID
        }
    }

    private func normalizeLocationDisplayNamesIfNeeded() {
        let userRegion = Locale.current.region?.identifier.uppercased()

        let isoToCountryName: [String: String] = {
            var map: [String: String] = [:]
            map.reserveCapacity(Locale.Region.isoRegions.count)
            for region in Locale.Region.isoRegions {
                let code = region.identifier.uppercased()
                if let name = Locale.current.localizedString(forRegionCode: code)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    !name.isEmpty
                {
                    map[code] = name
                }
            }
            return map
        }()

        let countryNameToISO: [String: String] = Dictionary(
            uniqueKeysWithValues: isoToCountryName.map { ($0.value.lowercased(), $0.key) }
        )
        let isoRegions = Set(isoToCountryName.keys)

        let userCountryNameLower = userRegion.flatMap { isoToCountryName[$0] }?.lowercased()

        let ambiguousAdminCodes: Set<String> = [
            // US states (+ DC) that are commonly used as "City, XX"
            "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
            "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
            "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
            "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
            "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY",
            "DC",
        ]

        func isCompactRegionCode(_ s: String) -> Bool {
            let value = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard value.count <= 4 else { return false }
            guard value == value.uppercased() else { return false }
            return value.allSatisfy { $0.isLetter || $0.isNumber }
        }

        func normalizedName(for location: WeatherLocation) -> String {
            let displayName = location.displayName
            let components = displayName
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard !components.isEmpty else { return displayName }

            let base = components[0]
            var admin: String?
            var country: String?

            func isNonLocalCountry(iso: String) -> Bool {
                guard let userRegion else { return true }
                return iso != userRegion
            }

            func countryName(for iso: String) -> String? {
                isoToCountryName[iso.uppercased()]
            }

            func shouldTreatTwoPartCodeAsCountry(code: String) -> Bool {
                let upper = code.uppercased()
                guard isoRegions.contains(upper) else { return false }
                guard isNonLocalCountry(iso: upper) else { return false }

                if !ambiguousAdminCodes.contains(upper) {
                    return true
                }

                // If the code is ambiguous (e.g., "IN" could be Indiana vs India), prefer "country"
                // for locations that are clearly outside the Americas.
                if location.longitude > 0 { return true }
                if !location.timezoneIdentifier.hasPrefix("America/") { return true }
                return false
            }

            if components.count >= 3 {
                // Canonical: "City, Region, Country"
                let candidateAdmin = components[1]
                if isCompactRegionCode(candidateAdmin) {
                    admin = candidateAdmin
                }

                let candidateCountry = components.last ?? ""
                let upper = candidateCountry.uppercased()
                if upper.count == 2, isoRegions.contains(upper), isNonLocalCountry(iso: upper) {
                    country = countryName(for: upper) ?? upper
                } else if let mapped = countryNameToISO[candidateCountry.lowercased()], isNonLocalCountry(iso: mapped) {
                    country = countryName(for: mapped) ?? candidateCountry
                } else if let userCountryNameLower, candidateCountry.lowercased() != userCountryNameLower {
                    country = candidateCountry
                }
            } else if components.count == 2 {
                let candidate = components[1]
                let upper = candidate.uppercased()

                if shouldTreatTwoPartCodeAsCountry(code: candidate) {
                    country = countryName(for: upper) ?? candidate
                } else if let mapped = countryNameToISO[candidate.lowercased()], isNonLocalCountry(iso: mapped) {
                    country = countryName(for: mapped) ?? candidate
                } else if isCompactRegionCode(candidate) {
                    admin = candidate
                } else if let userCountryNameLower, candidate.lowercased() != userCountryNameLower {
                    // "City, Country"
                    country = candidate
                }
            }

            var parts: [String] = [base]
            if let admin { parts.append(admin) }
            if let country { parts.append(country) }
            return parts.joined(separator: ", ")
        }

        var updated: [WeatherLocation] = []
        updated.reserveCapacity(weatherLocations.count)

        var changed = false
        for var location in weatherLocations {
            let nextName = normalizedName(for: location)
            if nextName != location.displayName {
                location.displayName = nextName
                changed = true
            }
            updated.append(location)
        }

        if changed {
            weatherLocations = updated
        }
    }

    private func saveCodable<T: Codable>(_ value: T?, key: String) {
        if let value {
            do {
                defaults.set(try JSONEncoder().encode(value), forKey: key)
            } catch {
                defaults.removeObject(forKey: key)
            }
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private static func loadCodable<T: Codable>(_ type: T.Type, defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
