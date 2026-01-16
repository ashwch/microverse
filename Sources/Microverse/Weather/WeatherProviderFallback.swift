import Foundation

struct WeatherProviderFallback: WeatherProvider {
    let primary: WeatherProvider
    let fallback: WeatherProvider

    func fetch(location: WeatherLocation) async throws -> WeatherPayload {
        do {
            return try await primary.fetch(location: location)
        } catch let e as WeatherProviderError {
            switch e {
            case .notAuthorized, .setupRequired:
                return try await fallback.fetch(location: location)
            default:
                throw e
            }
        } catch {
            throw error
        }
    }
}

