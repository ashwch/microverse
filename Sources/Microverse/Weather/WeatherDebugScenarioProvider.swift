#if DEBUG
import Foundation

/// Debug-only provider to make it easy to test UI + switching + event detection without relying on live weather.
struct WeatherDebugScenarioProvider: WeatherProvider {
    enum Scenario: String, CaseIterable, Sendable {
        case clear
        case rainIn25m
        case clearingIn20m
        case thunderIn2h
        case tempDropIn2h
    }

    let scenario: Scenario

    func fetch(location: WeatherLocation) async throws -> WeatherPayload {
        let now = Date()
        let isDaylight = true

        switch scenario {
        case .clear:
            return WeatherPayload(
                provider: .openMeteo,
                location: location,
                current: WeatherSnapshot(
                    temperatureC: 12.0,
                    feelsLikeC: 12.0,
                    bucket: .clear,
                    isDaylight: isDaylight,
                    precipChance: 0.0,
                    windKph: 8.0,
                    asOf: now,
                    expiration: nil
                ),
                hourly: makeHourly(
                    now: now,
                    baseTempC: 12.0,
                    buckets: Array(repeating: .clear, count: 24),
                    precipChance: Array(repeating: 0.0, count: 24)
                ),
                minutely: makeMinutely(now: now, chance: { _ in 0.0 }, intensity: { _ in 0.0 }),
                fetchedAt: now
            )

        case .rainIn25m:
            return WeatherPayload(
                provider: .openMeteo,
                location: location,
                current: WeatherSnapshot(
                    temperatureC: 10.0,
                    feelsLikeC: 9.0,
                    bucket: .cloudy,
                    isDaylight: isDaylight,
                    precipChance: 0.1,
                    windKph: 10.0,
                    asOf: now,
                    expiration: nil
                ),
                hourly: makeHourly(
                    now: now,
                    baseTempC: 10.0,
                    buckets: ([.cloudy] * 2) + ([.rain] * 6) + ([.cloudy] * 16),
                    precipChance: ([0.10, 0.20] + [0.80, 0.85, 0.70, 0.60, 0.40, 0.25] + Array(repeating: 0.10, count: 16))
                ),
                minutely: makeMinutely(
                    now: now,
                    chance: { minute in
                        // Dry for 25m, then wet for ~20m.
                        if minute < 25 { return 0.05 }
                        if minute < 45 { return 0.85 }
                        return 0.15
                    },
                    intensity: { minute in
                        if minute < 25 { return 0.0 }
                        if minute < 45 { return 0.6 }
                        return 0.05
                    }
                ),
                fetchedAt: now
            )

        case .clearingIn20m:
            return WeatherPayload(
                provider: .openMeteo,
                location: location,
                current: WeatherSnapshot(
                    temperatureC: 9.0,
                    feelsLikeC: 8.0,
                    bucket: .rain,
                    isDaylight: isDaylight,
                    precipChance: 0.85,
                    windKph: 12.0,
                    asOf: now,
                    expiration: nil
                ),
                hourly: makeHourly(
                    now: now,
                    baseTempC: 9.0,
                    buckets: ([.rain] * 1) + ([.cloudy] * 23),
                    precipChance: ([0.85] + Array(repeating: 0.10, count: 23))
                ),
                minutely: makeMinutely(
                    now: now,
                    chance: { minute in
                        if minute < 20 { return 0.85 }
                        return 0.05
                    },
                    intensity: { minute in
                        if minute < 20 { return 0.7 }
                        return 0.0
                    }
                ),
                fetchedAt: now
            )

        case .thunderIn2h:
            return WeatherPayload(
                provider: .openMeteo,
                location: location,
                current: WeatherSnapshot(
                    temperatureC: 14.0,
                    feelsLikeC: 14.0,
                    bucket: .cloudy,
                    isDaylight: isDaylight,
                    precipChance: 0.15,
                    windKph: 6.0,
                    asOf: now,
                    expiration: nil
                ),
                hourly: makeHourly(
                    now: now,
                    baseTempC: 14.0,
                    buckets: ([.cloudy] * 2) + ([.thunder] * 3) + ([.cloudy] * 19),
                    precipChance: ([0.15, 0.20] + [0.55, 0.60, 0.50] + Array(repeating: 0.15, count: 19))
                ),
                minutely: makeMinutely(now: now, chance: { _ in 0.05 }, intensity: { _ in 0.0 }),
                fetchedAt: now
            )

        case .tempDropIn2h:
            let temps: [Double] = [18.0, 16.0, 12.5, 11.0] + Array(repeating: 11.0, count: 20)
            return WeatherPayload(
                provider: .openMeteo,
                location: location,
                current: WeatherSnapshot(
                    temperatureC: temps[0],
                    feelsLikeC: temps[0] - 0.5,
                    bucket: .clear,
                    isDaylight: isDaylight,
                    precipChance: 0.0,
                    windKph: 5.0,
                    asOf: now,
                    expiration: nil
                ),
                hourly: makeHourly(now: now, temperaturesC: temps, bucket: .clear, precipChance: 0.0),
                minutely: makeMinutely(now: now, chance: { _ in 0.0 }, intensity: { _ in 0.0 }),
                fetchedAt: now
            )
        }
    }

    // MARK: - Helpers

    private func makeMinutely(now: Date, chance: (Int) -> Double, intensity: (Int) -> Double) -> [MinutelyPrecipPoint] {
        (0..<60).map { minute in
            MinutelyPrecipPoint(
                date: now.addingTimeInterval(TimeInterval(minute) * 60),
                precipChance: chance(minute),
                intensityMmPerHr: intensity(minute)
            )
        }
    }

    private func makeHourly(now: Date, baseTempC: Double, buckets: [WeatherConditionBucket], precipChance: [Double]) -> [HourlyForecastPoint] {
        let count = min(24, buckets.count, precipChance.count)
        return (0..<count).map { idx in
            HourlyForecastPoint(
                date: now.addingTimeInterval(TimeInterval(idx) * 3600),
                temperatureC: baseTempC - Double(idx) * 0.1,
                bucket: buckets[idx],
                precipChance: precipChance[idx],
                windKph: nil,
                isDaylight: nil
            )
        }
    }

    private func makeHourly(now: Date, temperaturesC: [Double], bucket: WeatherConditionBucket, precipChance: Double) -> [HourlyForecastPoint] {
        let count = min(24, temperaturesC.count)
        return (0..<count).map { idx in
            HourlyForecastPoint(
                date: now.addingTimeInterval(TimeInterval(idx) * 3600),
                temperatureC: temperaturesC[idx],
                bucket: bucket,
                precipChance: precipChance,
                windKph: nil,
                isDaylight: nil
            )
        }
    }
}

private extension Array where Element == WeatherConditionBucket {
    static func * (lhs: [WeatherConditionBucket], rhs: Int) -> [WeatherConditionBucket] {
        guard rhs > 0 else { return [] }
        return (0..<rhs).flatMap { _ in lhs }
    }
}
#endif
