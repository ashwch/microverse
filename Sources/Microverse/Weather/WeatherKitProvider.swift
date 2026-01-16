#if canImport(WeatherKit)
import CoreLocation
import Foundation
import WeatherKit

struct WeatherKitProvider: WeatherProvider {
    func fetch(location: WeatherLocation) async throws -> WeatherPayload {
        let weather: Weather
        do {
            weather = try await WeatherService.shared.weather(for: location.clLocation)
        } catch let e as WeatherError {
            switch e {
            case .permissionDenied:
                throw WeatherProviderError.notAuthorized
            case .unknown:
                let message = e.localizedDescription
                if message.contains("WDSJWT") || message.contains("WeatherDaemon") {
                    let bundleID = Bundle.main.bundleIdentifier ?? "unknown bundle id"
                    throw WeatherProviderError.setupRequired(
                        "WeatherKit auth failed for \(bundleID). Enable WeatherKit for this App ID in the Developer portal and run a properly code-signed build (Xcode automatic signing)."
                    )
                }

                throw WeatherProviderError.failed(message)
            @unknown default:
                throw WeatherProviderError.failed(e.localizedDescription)
            }
        } catch {
            let ns = error as NSError
            if ns.domain.contains("WeatherDaemon") || ns.localizedDescription.contains("WDSJWT") {
                let bundleID = Bundle.main.bundleIdentifier ?? "unknown bundle id"
                throw WeatherProviderError.setupRequired(
                    "WeatherKit auth failed for \(bundleID). Enable WeatherKit for this App ID in the Developer portal and run a properly code-signed build (Xcode automatic signing)."
                )
            }

            throw WeatherProviderError.failed(ns.localizedDescription)
        }

        let precipChance: Double? =
            weather.minuteForecast?.forecast.first?.precipitationChance
            ?? weather.hourlyForecast.forecast.first?.precipitationChance

        let current = WeatherSnapshot(
            temperatureC: weather.currentWeather.temperature.converted(to: .celsius).value,
            feelsLikeC: weather.currentWeather.apparentTemperature.converted(to: .celsius).value,
            bucket: bucket(from: weather.currentWeather.condition),
            isDaylight: weather.currentWeather.isDaylight,
            precipChance: precipChance,
            windKph: weather.currentWeather.wind.speed.converted(to: .kilometersPerHour).value,
            asOf: Date(),
            expiration: weather.currentWeather.metadata.expirationDate
        )

        let hourly: [HourlyForecastPoint] = weather.hourlyForecast.forecast.prefix(24).map { hour in
            HourlyForecastPoint(
                date: hour.date,
                temperatureC: hour.temperature.converted(to: .celsius).value,
                bucket: bucket(from: hour.condition),
                precipChance: hour.precipitationChance,
                windKph: hour.wind.speed.converted(to: .kilometersPerHour).value,
                isDaylight: hour.isDaylight
            )
        }

        let minutely: [MinutelyPrecipPoint]? = weather.minuteForecast?.forecast.prefix(60).map { minute in
            // WeatherKit's precipitationIntensity is a `Measurement<UnitSpeed>` (length / time).
            // We store intensity as millimeters per hour.
            // m/s → mm/h: (1000 mm / 1 m) * (3600 s / 1 h) = 3,600,000
            let intensityMmPerHr: Double = minute.precipitationIntensity.converted(to: .metersPerSecond).value * 1000 * 3600
            return MinutelyPrecipPoint(
                date: minute.date,
                precipChance: minute.precipitationChance,
                intensityMmPerHr: intensityMmPerHr
            )
        }

        return WeatherPayload(
            provider: .weatherKit,
            location: location,
            current: current,
            hourly: hourly,
            minutely: minutely,
            fetchedAt: Date()
        )
    }

    private func bucket(from condition: WeatherCondition) -> WeatherConditionBucket {
        switch condition {
        case .clear, .mostlyClear:
            .clear
        case .partlyCloudy, .mostlyCloudy, .cloudy:
            .cloudy
        case .foggy, .haze, .smoky, .blowingDust:
            .fog
        case .windy, .breezy:
            .wind
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms:
            .thunder
        case .snow, .heavySnow, .flurries, .blizzard, .blowingSnow, .sleet, .wintryMix, .sunFlurries:
            .snow
        case .rain, .heavyRain, .drizzle, .sunShowers, .freezingRain, .freezingDrizzle, .hail:
            .rain
        default:
            // If WeatherKit adds new cases, keep them mapped conservatively.
            .unknown
        }
    }
}
#endif
