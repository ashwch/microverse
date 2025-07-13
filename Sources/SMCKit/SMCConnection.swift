import Foundation
import IOKit
import os.log

/// Low-level SMC connection handler
public class SMCConnection {
    private let logger = Logger(subsystem: "com.microverse.app", category: "SMCConnection")
    private var connection: io_connect_t = 0
    private var connected = false
    
    // SMC service name
    private let serviceName = "AppleSMC"
    
    public init() {}
    
    deinit {
        disconnect()
    }
    
    /// Connect to the SMC service
    public func connect() -> Bool {
        guard !connected else { return true }
        
        // Find the SMC service
        let service = IOServiceGetMatchingService(
            kIOMasterPortDefault,
            IOServiceMatching(serviceName)
        )
        
        guard service != 0 else {
            logger.error("Failed to find SMC service")
            return false
        }
        
        defer { IOObjectRelease(service) }
        
        // Open connection
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard result == kIOReturnSuccess else {
            logger.error("Failed to open SMC connection: \(String(format: "0x%08x", result))")
            return false
        }
        
        connected = true
        logger.info("Successfully connected to SMC")
        return true
    }
    
    /// Disconnect from SMC service
    public func disconnect() {
        guard connected else { return }
        
        let result = IOServiceClose(connection)
        if result != kIOReturnSuccess {
            logger.error("Failed to close SMC connection: \(String(format: "0x%08x", result))")
        }
        
        connection = 0
        connected = false
        logger.info("Disconnected from SMC")
    }
    
    /// Call SMC with input and output structures
    public func call(selector: SMCSelector, 
                    input: inout SMCParamStruct, 
                    output: inout SMCParamStruct) -> IOReturn {
        guard connected else {
            logger.error("Not connected to SMC")
            return kIOReturnNotOpen
        }
        
        let inputSize = MemoryLayout<SMCParamStruct>.size
        var outputSize = MemoryLayout<SMCParamStruct>.size
        
        return IOConnectCallStructMethod(
            connection,
            selector.rawValue,
            &input,
            inputSize,
            &output,
            &outputSize
        )
    }
}

// SMC parameter struct for communication with kernel
public struct SMCParamStruct {
    var key: FourCharCode = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (0, 0, 0, 0, 0, 0, 0, 0,
                          0, 0, 0, 0, 0, 0, 0, 0,
                          0, 0, 0, 0, 0, 0, 0, 0,
                          0, 0, 0, 0, 0, 0, 0, 0)
}

public struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}