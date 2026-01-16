import Foundation

struct OpenMeteoProvider: WeatherProvider {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(location: WeatherLocation) async throws -> WeatherPayload {
        guard let url = makeURL(location: location) else {
            throw WeatherProviderError.invalidLocation
        }

        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

        let parser = OpenMeteoDateParser(timeZone: location.timeZone)
        let currentDate = parser.parse(decoded.current.time) ?? Date()

        let current = WeatherSnapshot(
            temperatureC: decoded.current.temperature_2m,
            feelsLikeC: nil,
            bucket: bucket(from: decoded.current.weather_code),
            isDaylight: decoded.current.is_day == 1,
            precipChance: nil,
            windKph: nil,
            asOf: currentDate,
            expiration: nil
        )

        let hourly = makeHourly(decoded.hourly, parser: parser)

        return WeatherPayload(
            provider: .openMeteo,
            location: location,
            current: current,
            hourly: hourly,
            minutely: nil,
            fetchedAt: Date()
        )
    }

    private func makeURL(location: WeatherLocation) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "timezone", value: location.timezoneIdentifier),
            URLQueryItem(name: "current", value: "temperature_2m,is_day,weather_code"),
            URLQueryItem(name: "hourly", value: "temperature_2m,is_day,precipitation_probability,weather_code,wind_speed_10m"),
            URLQueryItem(name: "forecast_hours", value: "24"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh")
        ]
        return components?.url
    }

    private func makeHourly(_ hourly: OpenMeteoResponse.Hourly, parser: OpenMeteoDateParser) -> [HourlyForecastPoint] {
        let count = min(hourly.time.count, hourly.temperature_2m.count, hourly.weather_code.count)
        var points: [HourlyForecastPoint] = []
        points.reserveCapacity(count)

        for idx in 0..<count {
            guard let date = parser.parse(hourly.time[idx]) else { continue }
            let bucket = bucket(from: hourly.weather_code[idx])
            let precipChance: Double? = hourly.precipitation_probability?[safe: idx].map { min(1, max(0, $0 / 100.0)) }
            let windKph: Double? = hourly.wind_speed_10m?[safe: idx]
            let isDaylight: Bool? = hourly.is_day?[safe: idx].map { $0 == 1 }
            points.append(
                HourlyForecastPoint(
                    date: date,
                    temperatureC: hourly.temperature_2m[idx],
                    bucket: bucket,
                    precipChance: precipChance,
                    windKph: windKph,
                    isDaylight: isDaylight
                )
            )
        }

        return points
    }

    private func bucket(from code: Int) -> WeatherConditionBucket {
        switch code {
        case 0:
            return .clear
        case 1, 2, 3:
            return .cloudy
        case 45, 48:
            return .fog
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82:
            return .rain
        case 71, 73, 75, 77, 85, 86:
            return .snow
        case 95, 96, 99:
            return .thunder
        default:
            return .unknown
        }
    }
}

private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        var time: String
        var temperature_2m: Double
        var is_day: Int
        var weather_code: Int
    }

    struct Hourly: Decodable {
        var time: [String]
        var temperature_2m: [Double]
        var is_day: [Int]?
        var precipitation_probability: [Double]?
        var weather_code: [Int]
        var wind_speed_10m: [Double]?
    }

    var current: Current
    var hourly: Hourly
}

private final class OpenMeteoDateParser {
    private let formatter: ISO8601DateFormatter
    private let localNoSeconds: DateFormatter
    private let localWithSeconds: DateFormatter

    init(timeZone: TimeZone) {
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Open‑Meteo returns local times (timezone is controlled via request params) without offsets, e.g.:
        // "2026-01-14T05:00"
        // `ISO8601DateFormatter` with `.withInternetDateTime` will fail without an explicit offset.
        localNoSeconds = DateFormatter()
        localNoSeconds.locale = Locale(identifier: "en_US_POSIX")
        localNoSeconds.timeZone = timeZone
        localNoSeconds.dateFormat = "yyyy-MM-dd'T'HH:mm"

        localWithSeconds = DateFormatter()
        localWithSeconds.locale = Locale(identifier: "en_US_POSIX")
        localWithSeconds.timeZone = timeZone
        localWithSeconds.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    }

    func parse(_ string: String) -> Date? {
        if let date = formatter.date(from: string) { return date }
        // Open-Meteo sometimes omits fractional seconds.
        formatter.formatOptions = [.withInternetDateTime]
        defer { formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds] }
        if let date = formatter.date(from: string) { return date }

        // Local time fallback (no timezone designator).
        if let date = localWithSeconds.date(from: string) { return date }
        if let date = localNoSeconds.date(from: string) { return date }
        return nil
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
