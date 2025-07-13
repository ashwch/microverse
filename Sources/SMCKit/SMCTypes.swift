import Foundation

// SMC data types based on AppleSMC kernel extension
public typealias SMCBytes = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                             UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                             UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                             UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

// SMC key type
public struct SMCKey {
    let code: FourCharCode
    
    public init(_ key: String) {
        precondition(key.count == 4, "SMC key must be 4 characters")
        
        let chars = key.utf8
        var code: FourCharCode = 0
        
        for (index, char) in chars.enumerated() {
            code |= FourCharCode(char) << (24 - (index * 8))
        }
        
        self.code = code
    }
    
    public var string: String {
        let bytes = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF)
        ]
        return String(bytes: bytes, encoding: .utf8) ?? "????"
    }
}

// SMC data types
public enum SMCDataType: String {
    case flt = "flt "  // Floating point
    case ui8 = "ui8 "  // Unsigned int 8
    case ui16 = "ui16" // Unsigned int 16
    case ui32 = "ui32" // Unsigned int 32
    case si8 = "si8 "  // Signed int 8
    case hex = "hex_" // Hexadecimal
    case ch8 = "ch8*" // Character string
    case flag = "flag" // Boolean flag
    
    var size: Int {
        switch self {
        case .flt: return 4
        case .ui8, .si8: return 1
        case .ui16: return 2
        case .ui32: return 4
        case .hex: return 1
        case .ch8: return 1
        case .flag: return 1
        }
    }
}

// SMC version struct
public struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

// SMC key info struct
public struct SMCKeyInfo {
    var dataSize: IOByteCount = 0
    var dataType: FourCharCode = 0
    var dataAttributes: UInt8 = 0
    
    var dataTypeString: String {
        let bytes = [
            UInt8((dataType >> 24) & 0xFF),
            UInt8((dataType >> 16) & 0xFF),
            UInt8((dataType >> 8) & 0xFF),
            UInt8(dataType & 0xFF)
        ]
        return String(bytes: bytes, encoding: .utf8) ?? "????"
    }
}

// Battery-specific SMC keys
public struct BatterySMCKeys {
    // Charge control keys
    public static let chargeControl = SMCKey("CH0B")          // Intel charging control
    public static let chargeControlM1 = SMCKey("CH0C")        // M1 charging control
    public static let chargeLimit = SMCKey("BCLM")            // Intel charge limit
    public static let chargeLimitM1 = SMCKey("CHWA")          // M1 charge limit
    
    // Battery info keys
    public static let batteryPowered = SMCKey("BATP")         // Battery powered status
    public static let batteryCount = SMCKey("BNum")           // Number of batteries
    public static let batteryInfo = SMCKey("BSIn")            // Battery info
    
    // Temperature keys
    public static let batteryTemp0 = SMCKey("TB0T")           // Battery temp sensor 0
    public static let batteryTemp1 = SMCKey("TB1T")           // Battery temp sensor 1
    public static let batteryTemp2 = SMCKey("TB2T")           // Battery temp sensor 2
    public static let batteryTemp3 = SMCKey("TB3T")           // Battery temp sensor 3
    
    // Cycle count key
    public static let cycleCount = SMCKey("B0CT")             // Battery cycle count
}

// SMC selectors for IOConnectCallStructMethod
public enum SMCSelector: UInt32 {
    case readKey = 5
    case writeKey = 6
    case getKeyCount = 7
    case getKeyFromIndex = 8
    case getKeyInfo = 9
}