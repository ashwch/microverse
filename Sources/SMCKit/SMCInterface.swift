import Foundation
import IOKit
import os.log

/// High-level SMC interface for battery control
public class SMCInterface {
    private let logger = Logger(subsystem: "com.microverse.app", category: "SMCInterface")
    private let connection = SMCConnection()
    
    public init() {}
    
    /// Read a value from SMC
    public func readValue(key: SMCKey) -> SMCReadResult? {
        guard connection.connect() else {
            logger.error("Failed to connect to SMC")
            return nil
        }
        
        // First get key info
        guard let keyInfo = getKeyInfo(key: key) else {
            logger.error("Failed to get key info for \(key.string)")
            return nil
        }
        
        // Prepare read parameters
        var input = SMCParamStruct()
        var output = SMCParamStruct()
        
        input.key = key.code
        input.data8 = UInt8(SMCSelector.readKey.rawValue)
        input.keyInfo.dataSize = keyInfo.dataSize
        
        let result = connection.call(selector: .readKey, input: &input, output: &output)
        guard result == kIOReturnSuccess else {
            logger.error("Failed to read key \(key.string): \(String(format: "0x%08x", result))")
            return nil
        }
        
        return SMCReadResult(
            key: key,
            dataType: keyInfo.dataTypeString,
            dataSize: Int(keyInfo.dataSize),
            bytes: output.bytes
        )
    }
    
    /// Write a value to SMC (requires root)
    public func writeValue(key: SMCKey, value: SMCWriteValue) -> Bool {
        guard connection.connect() else {
            logger.error("Failed to connect to SMC")
            return false
        }
        
        // Get key info first
        guard let keyInfo = getKeyInfo(key: key) else {
            logger.error("Failed to get key info for \(key.string)")
            return false
        }
        
        // Verify data type matches
        guard keyInfo.dataTypeString == value.dataType else {
            logger.error("Data type mismatch for key \(key.string): expected \(keyInfo.dataTypeString), got \(value.dataType)")
            return false
        }
        
        // Prepare write parameters
        var input = SMCParamStruct()
        var output = SMCParamStruct()
        
        input.key = key.code
        input.data8 = UInt8(SMCSelector.writeKey.rawValue)
        input.keyInfo.dataSize = IOByteCount(value.bytes.count)
        input.bytes = value.toSMCBytes()
        
        let result = connection.call(selector: .writeKey, input: &input, output: &output)
        guard result == kIOReturnSuccess else {
            logger.error("Failed to write key \(key.string): \(String(format: "0x%08x", result))")
            return false
        }
        
        logger.info("Successfully wrote value to key \(key.string)")
        return true
    }
    
    /// Get info about a specific key
    private func getKeyInfo(key: SMCKey) -> SMCKeyInfo? {
        var input = SMCParamStruct()
        var output = SMCParamStruct()
        
        input.key = key.code
        input.data8 = UInt8(SMCSelector.getKeyInfo.rawValue)
        
        let result = connection.call(selector: .getKeyInfo, input: &input, output: &output)
        guard result == kIOReturnSuccess else {
            return nil
        }
        
        return output.keyInfo
    }
    
    /// Check if a key exists
    public func keyExists(key: SMCKey) -> Bool {
        return getKeyInfo(key: key) != nil
    }
    
    /// Disconnect from SMC
    public func disconnect() {
        connection.disconnect()
    }
}

/// Result of SMC read operation
public struct SMCReadResult {
    public let key: SMCKey
    public let dataType: String
    public let dataSize: Int
    public let bytes: SMCBytes
    
    /// Get value as UInt8
    public var ui8Value: UInt8? {
        guard dataType == "ui8 " && dataSize == 1 else { return nil }
        return bytes.0
    }
    
    /// Get value as UInt16
    public var ui16Value: UInt16? {
        guard dataType == "ui16" && dataSize == 2 else { return nil }
        return UInt16(bytes.0) << 8 | UInt16(bytes.1)
    }
    
    /// Get value as UInt32
    public var ui32Value: UInt32? {
        guard dataType == "ui32" && dataSize == 4 else { return nil }
        return UInt32(bytes.0) << 24 | UInt32(bytes.1) << 16 | 
               UInt32(bytes.2) << 8 | UInt32(bytes.3)
    }
    
    /// Get value as Float
    public var floatValue: Float? {
        guard dataType == "flt " && dataSize == 4 else { return nil }
        let bits = ui32Value ?? 0
        return Float(bitPattern: bits)
    }
    
    /// Get temperature value (special decoding)
    public var temperatureValue: Double? {
        guard dataType == "sp78" && dataSize == 2 else { return nil }
        let raw = Int16(bitPattern: ui16Value ?? 0)
        return Double(raw) / 256.0
    }
}

/// Value to write to SMC
public struct SMCWriteValue {
    public let dataType: String
    public let bytes: [UInt8]
    
    /// Create from UInt8
    public static func ui8(_ value: UInt8) -> SMCWriteValue {
        return SMCWriteValue(dataType: "ui8 ", bytes: [value])
    }
    
    /// Create from UInt16
    public static func ui16(_ value: UInt16) -> SMCWriteValue {
        return SMCWriteValue(dataType: "ui16", bytes: [
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ])
    }
    
    /// Create from UInt32
    public static func ui32(_ value: UInt32) -> SMCWriteValue {
        return SMCWriteValue(dataType: "ui32", bytes: [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ])
    }
    
    /// Create from hex string
    public static func hex(_ value: UInt8) -> SMCWriteValue {
        return SMCWriteValue(dataType: "hex_", bytes: [value])
    }
    
    /// Convert to SMCBytes tuple
    func toSMCBytes() -> SMCBytes {
        var result: SMCBytes = (0, 0, 0, 0, 0, 0, 0, 0,
                               0, 0, 0, 0, 0, 0, 0, 0,
                               0, 0, 0, 0, 0, 0, 0, 0,
                               0, 0, 0, 0, 0, 0, 0, 0)
        
        for (index, byte) in bytes.prefix(32).enumerated() {
            switch index {
            case 0: result.0 = byte
            case 1: result.1 = byte
            case 2: result.2 = byte
            case 3: result.3 = byte
            case 4: result.4 = byte
            case 5: result.5 = byte
            case 6: result.6 = byte
            case 7: result.7 = byte
            case 8: result.8 = byte
            case 9: result.9 = byte
            case 10: result.10 = byte
            case 11: result.11 = byte
            case 12: result.12 = byte
            case 13: result.13 = byte
            case 14: result.14 = byte
            case 15: result.15 = byte
            case 16: result.16 = byte
            case 17: result.17 = byte
            case 18: result.18 = byte
            case 19: result.19 = byte
            case 20: result.20 = byte
            case 21: result.21 = byte
            case 22: result.22 = byte
            case 23: result.23 = byte
            case 24: result.24 = byte
            case 25: result.25 = byte
            case 26: result.26 = byte
            case 27: result.27 = byte
            case 28: result.28 = byte
            case 29: result.29 = byte
            case 30: result.30 = byte
            case 31: result.31 = byte
            default: break
            }
        }
        
        return result
    }
}