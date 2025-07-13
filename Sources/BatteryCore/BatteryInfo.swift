import Foundation

/// Real battery information that can be read without elevated privileges
public struct BatteryInfo: Equatable {
    // Basic battery stats (always available)
    public let currentCharge: Int        // 0-100%
    public let isCharging: Bool
    public let isPluggedIn: Bool
    public let cycleCount: Int
    public let maxCapacity: Int          // Design capacity percentage
    public let timeRemaining: Int?       // Minutes until empty/full
    
    // Health metrics
    public let health: Double            // 0.0-1.0 (maxCapacity/designCapacity)
    
    public init(
        currentCharge: Int = 0,
        isCharging: Bool = false,
        isPluggedIn: Bool = false,
        cycleCount: Int = 0,
        maxCapacity: Int = 100,
        timeRemaining: Int? = nil,
        health: Double = 1.0
    ) {
        self.currentCharge = currentCharge
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.cycleCount = cycleCount
        self.maxCapacity = maxCapacity
        self.timeRemaining = timeRemaining
        self.health = health
    }
}

// MARK: - Extensions

extension BatteryInfo {
    /// Formatted time remaining string (e.g., "2:34" or "10:15")
    public var timeRemainingFormatted: String? {
        guard let minutes = timeRemaining, minutes > 0 else { return nil }
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
}