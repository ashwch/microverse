import Foundation

enum WeatherFetchState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case stale
    case failed(String)
}

protocol WeatherProvider: Sendable {
    func fetch(location: WeatherLocation) async throws -> WeatherPayload
}

struct UnavailableWeatherProvider: WeatherProvider {
    func fetch(location: WeatherLocation) async throws -> WeatherPayload {
        throw WeatherProviderError.providerUnavailable
    }
}

enum WeatherProviderError: LocalizedError, Equatable, Sendable {
    case providerUnavailable
    case invalidLocation
    case notAuthorized
    case setupRequired(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .providerUnavailable:
            "Weather provider unavailable"
        case .invalidLocation:
            "Invalid location"
        case .notAuthorized:
            "Weather access not authorized"
        case .setupRequired(let message):
            message
        case .failed(let message):
            message
        }
    }
}
