import CoreLocation
import Foundation

enum WeatherUnits: String, Codable, CaseIterable, Sendable {
    case celsius
    case fahrenheit
}

extension WeatherUnits {
    func formatTemperature(celsius: Double, roundedTo places: Int = 0) -> String {
        let value: Double = switch self {
        case .celsius:
            celsius
        case .fahrenheit:
            (celsius * 9.0 / 5.0) + 32.0
        }

        let rounded = value.rounded(toPlaces: places)
        let unitSymbol = self == .celsius ? "°C" : "°F"
        return "\(Int(rounded))\(unitSymbol)"
    }

    func formatTemperatureShort(celsius: Double, roundedTo places: Int = 0) -> String {
        let value: Double = switch self {
        case .celsius:
            celsius
        case .fahrenheit:
            (celsius * 9.0 / 5.0) + 32.0
        }

        let rounded = value.rounded(toPlaces: places)
        return "\(Int(rounded))°"
    }
}

struct WeatherLocation: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: String
    var displayName: String
    var latitude: Double
    var longitude: Double
    var timezoneIdentifier: String

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case latitude
        case longitude
        case timezoneIdentifier
    }

    init?(
        displayName: String,
        latitude: Double,
        longitude: Double,
        timezoneIdentifier: String
    ) {
        guard Self.isValidCoordinate(latitude: latitude, longitude: longitude) else {
            return nil
        }

        self.displayName = displayName
        self.latitude = latitude
        self.longitude = longitude
        self.timezoneIdentifier = timezoneIdentifier
        self.id = WeatherLocation.makeID(latitude: latitude, longitude: longitude, timezoneIdentifier: timezoneIdentifier)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let displayName = try container.decode(String.self, forKey: .displayName)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        let timezoneIdentifier = try container.decode(String.self, forKey: .timezoneIdentifier)

        guard Self.isValidCoordinate(latitude: latitude, longitude: longitude) else {
            throw DecodingError.dataCorruptedError(
                forKey: .latitude,
                in: container,
                debugDescription: "Invalid coordinates (lat=\(latitude), lon=\(longitude))"
            )
        }

        guard let validated = WeatherLocation(
            displayName: displayName,
            latitude: latitude,
            longitude: longitude,
            timezoneIdentifier: timezoneIdentifier
        ) else {
            throw DecodingError.dataCorruptedError(
                forKey: .latitude,
                in: container,
                debugDescription: "Invalid coordinates (lat=\(latitude), lon=\(longitude))"
            )
        }

        self = validated
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(timezoneIdentifier, forKey: .timezoneIdentifier)
    }

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timezoneIdentifier) ?? .current
    }

    static func makeID(latitude: Double, longitude: Double, timezoneIdentifier: String) -> String {
        "\(latitude.rounded(toPlaces: 4)):\(longitude.rounded(toPlaces: 4)):\(timezoneIdentifier)"
    }

    private static func isValidCoordinate(latitude: Double, longitude: Double) -> Bool {
        latitude.isFinite && longitude.isFinite
            && (-90.0...90.0).contains(latitude)
            && (-180.0...180.0).contains(longitude)
    }
}

extension WeatherLocation {
    func microversePrimaryName() -> String {
        microverseDisplayParts().first ?? displayName
    }

    func microverseSecondaryName() -> String? {
        let parts = microverseDisplayParts()
        guard parts.count > 1 else { return nil }
        return parts.dropFirst().joined(separator: " · ")
    }

    func microverseDisplayName() -> String {
        let parts = microverseDisplayParts()
        if parts.isEmpty { return displayName }
        return parts.joined(separator: ", ")
    }

    private func microverseDisplayParts() -> [String] {
        func trimmed(_ value: Substring) -> String? {
            let next = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return next.isEmpty ? nil : next
        }

        let components = displayName
            .split(separator: ",")
            .compactMap(trimmed)

        guard let primary = components.first else {
            return [displayName]
        }

        let secondary = components.dropFirst().compactMap { part in
            microverseNormalizeLocationPart(part)
        }

        return [primary] + secondary
    }

    private func microverseNormalizeLocationPart(_ part: String) -> String? {
        let value = part.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        let upper = value.uppercased()
        let isCompactCode = upper.count <= 4 && upper == value && upper.allSatisfy { $0.isLetter || $0.isNumber }

        guard isCompactCode, let countryName = Locale.current.localizedString(forRegionCode: upper) else {
            return value
        }

        let ambiguousUSStateCodes: Set<String> = [
            "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
            "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
            "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
            "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
            "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY",
            "DC",
        ]

        if ambiguousUSStateCodes.contains(upper) {
            let looksAmerican = timezoneIdentifier.hasPrefix("America/") && longitude < 0
            if looksAmerican {
                return value
            }
        }

        return countryName
    }
}

enum WeatherConditionBucket: String, Codable, Equatable, Sendable, CaseIterable {
    case clear
    case cloudy
    case rain
    case snow
    case fog
    case thunder
    case wind
    case unknown

    var isPrecipitation: Bool {
        self == .rain || self == .snow
    }
}

extension WeatherConditionBucket {
    var displayName: String {
        switch self {
        case .clear: return "Clear"
        case .cloudy: return "Cloudy"
        case .rain: return "Rain"
        case .snow: return "Snow"
        case .fog: return "Fog"
        case .thunder: return "Thunder"
        case .wind: return "Wind"
        case .unknown: return "Unknown"
        }
    }

    func symbolName(isDaylight: Bool) -> String {
        switch self {
        case .clear:
            return isDaylight ? "sun.max.fill" : "moon.fill"
        case .cloudy:
            // Strong silhouette at tiny sizes (avoid mixing in sun/moon details).
            return "cloud.fill"
        case .rain:
            return "cloud.rain.fill"
        case .snow:
            return "cloud.snow.fill"
        case .fog:
            return "cloud.fog.fill"
        case .thunder:
            // Distinguish thunder from generic rain at tiny sizes.
            return "cloud.bolt.fill"
        case .wind:
            return "wind"
        case .unknown:
            return "cloud"
        }
    }
}

struct WeatherSnapshot: Codable, Equatable, Sendable {
    var temperatureC: Double
    var feelsLikeC: Double?
    var bucket: WeatherConditionBucket
    var isDaylight: Bool
    var precipChance: Double?
    var windKph: Double?
    var asOf: Date
    var expiration: Date?
}

struct HourlyForecastPoint: Codable, Equatable, Sendable {
    var date: Date
    var temperatureC: Double
    var bucket: WeatherConditionBucket
    var precipChance: Double?
    var windKph: Double?
    var isDaylight: Bool?
}

struct MinutelyPrecipPoint: Codable, Equatable, Sendable {
    var date: Date
    var precipChance: Double?
    var intensityMmPerHr: Double?
}

struct WeatherPayload: Codable, Equatable, Sendable {
    enum Provider: String, Codable, Sendable {
        case weatherKit
        case openMeteo
    }

    var provider: Provider
    var location: WeatherLocation
    var current: WeatherSnapshot
    var hourly: [HourlyForecastPoint]
    var minutely: [MinutelyPrecipPoint]?
    var fetchedAt: Date
}
