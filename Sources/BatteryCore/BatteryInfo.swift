import Foundation

/// Real battery information that can be read without elevated privileges
public struct BatteryInfo: Equatable {
    // Basic battery stats (always available)
    public let currentCharge: Int        // 0-100%
    public let isCharging: Bool
    public let isPluggedIn: Bool
    public let cycleCount: Int
    public let maxCapacity: Int          // Design capacity percentage
    public let timeRemaining: Int?       // Minutes, nil if plugged in
    
    // Power adapter info (when plugged in)
    public let adapterWattage: Int?      // Watts
    public let powerSourceType: String   // "AC Power" or "Battery Power"
    
    // Health metrics
    public let health: Double            // 0.0-1.0 (maxCapacity/designCapacity)
    public let voltage: Double?          // mV
    public let amperage: Int?            // mA
    
    // System info
    public let hardwareModel: String     // Mac model
    public let isAppleSilicon: Bool
    
    public init(
        currentCharge: Int = 0,
        isCharging: Bool = false,
        isPluggedIn: Bool = false,
        cycleCount: Int = 0,
        maxCapacity: Int = 100,
        timeRemaining: Int? = nil,
        adapterWattage: Int? = nil,
        powerSourceType: String = "Battery Power",
        health: Double = 1.0,
        voltage: Double? = nil,
        amperage: Int? = nil,
        hardwareModel: String = "Unknown",
        isAppleSilicon: Bool = false
    ) {
        self.currentCharge = currentCharge
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.cycleCount = cycleCount
        self.maxCapacity = maxCapacity
        self.timeRemaining = timeRemaining
        self.adapterWattage = adapterWattage
        self.powerSourceType = powerSourceType
        self.health = health
        self.voltage = voltage
        self.amperage = amperage
        self.hardwareModel = hardwareModel
        self.isAppleSilicon = isAppleSilicon
    }
}

/// Features that require admin/root access
public struct BatteryControlCapabilities {
    public let canSetChargeLimit: Bool
    public let canDisableCharging: Bool
    public let canReadSMC: Bool
    public let supportedChargeLimits: [Int]  // e.g., [80, 100] for Apple Silicon
    
    public init(
        canSetChargeLimit: Bool = false,
        canDisableCharging: Bool = false,
        canReadSMC: Bool = false,
        supportedChargeLimits: [Int] = []
    ) {
        self.canSetChargeLimit = canSetChargeLimit
        self.canDisableCharging = canDisableCharging
        self.canReadSMC = canReadSMC
        self.supportedChargeLimits = supportedChargeLimits
    }
}

/// Result of attempting privileged operations
public enum BatteryControlResult {
    case success
    case requiresAuthentication
    case notSupported(reason: String)
    case failed(error: Error)
}