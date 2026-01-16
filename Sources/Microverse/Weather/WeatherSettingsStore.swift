import Combine
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

@MainActor
final class WeatherSettingsStore: ObservableObject {
    enum AnimatedIconsMode: String, CaseIterable, Codable, Sendable {
        case off
        case subtle
        case full
    }

    enum PinnedNotchReplacement: String, CaseIterable, Codable, Sendable {
        case cpu
        case memory
    }

    private enum Keys {
        static let weatherEnabled = "weatherEnabled"
        static let weatherUnits = "weatherUnits"
        static let weatherLocation = "weatherLocation"
        static let weatherRefreshInterval = "weatherRefreshInterval"

        static let weatherShowInNotch = "weatherShowInNotch"
        static let weatherShowInWidget = "weatherShowInWidget"
        static let weatherShowInMenuBar = "weatherShowInMenuBar"

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

    @Published var weatherEnabled: Bool { didSet { defaults.set(weatherEnabled, forKey: Keys.weatherEnabled) } }
    @Published var weatherUnits: WeatherUnits { didSet { defaults.set(weatherUnits.rawValue, forKey: Keys.weatherUnits) } }
    @Published var weatherLocation: WeatherLocation? { didSet { saveCodable(weatherLocation, key: Keys.weatherLocation) } }
    @Published var weatherRefreshInterval: TimeInterval { didSet { defaults.set(weatherRefreshInterval, forKey: Keys.weatherRefreshInterval) } }

    @Published var weatherShowInNotch: Bool { didSet { defaults.set(weatherShowInNotch, forKey: Keys.weatherShowInNotch) } }
    @Published var weatherShowInWidget: Bool { didSet { defaults.set(weatherShowInWidget, forKey: Keys.weatherShowInWidget) } }
    @Published var weatherShowInMenuBar: Bool { didSet { defaults.set(weatherShowInMenuBar, forKey: Keys.weatherShowInMenuBar) } }

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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let defaultUnits: WeatherUnits = Locale.current.measurementSystem == .metric ? .celsius : .fahrenheit

        defaults.register(defaults: [
            Keys.weatherEnabled: false,
            Keys.weatherUnits: defaultUnits.rawValue,
            Keys.weatherRefreshInterval: 30 * 60,

            Keys.weatherShowInNotch: true,
            Keys.weatherShowInWidget: true,
            Keys.weatherShowInMenuBar: false,

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
        weatherLocation = Self.loadCodable(WeatherLocation.self, defaults: defaults, key: Keys.weatherLocation)
        weatherRefreshInterval = defaults.double(forKey: Keys.weatherRefreshInterval)

        weatherShowInNotch = defaults.bool(forKey: Keys.weatherShowInNotch)
        weatherShowInWidget = defaults.bool(forKey: Keys.weatherShowInWidget)
        weatherShowInMenuBar = defaults.bool(forKey: Keys.weatherShowInMenuBar)

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
    }

    func snapshot() -> WeatherSettingsSnapshot {
        WeatherSettingsSnapshot(
            enabled: weatherEnabled,
            units: weatherUnits,
            location: weatherLocation,
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
