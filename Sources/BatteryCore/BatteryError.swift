import Foundation

/// Errors that can occur during battery monitoring
public enum BatteryError: LocalizedError {
    case noPowerSource
    case invalidPowerSourceData
    case iokitServiceNotFound
    case iokitPropertyMissing(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .noPowerSource:
            return "No battery found. This may occur on desktop Macs."
        case .invalidPowerSourceData:
            return "Unable to read battery information. Please try again."
        case .iokitServiceNotFound:
            return "Battery service unavailable. Please restart the app."
        case .iokitPropertyMissing(let property):
            return "Missing battery property: \(property)"
        case .unknown(let message):
            return message
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .noPowerSource:
            return "Microverse requires a Mac with a battery."
        case .invalidPowerSourceData, .iokitServiceNotFound:
            return "Try restarting the app. If the problem persists, restart your Mac."
        case .iokitPropertyMissing:
            return "Your Mac may have limited battery information available."
        case .unknown:
            return "Please check Console.app for more details."
        }
    }
    
    /// User-friendly message for display in UI
    public var userMessage: String {
        if let description = errorDescription,
           let recovery = recoverySuggestion {
            return "\(description)\n\n\(recovery)"
        }
        return errorDescription ?? "An unknown error occurred"
    }
}