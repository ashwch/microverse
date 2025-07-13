import Foundation
import os.log
import SMCKit

/// Privileged helper tool for Microverse battery control
/// This runs with root privileges and handles SMC operations
class HelperTool: NSObject, NSXPCListenerDelegate {
    private let listener: NSXPCListener
    private let logger = Logger(subsystem: "com.diversio.microverse.helper", category: "HelperTool")
    
    override init() {
        // Create listener for the helper service
        self.listener = NSXPCListener(machServiceName: "com.diversio.microverse.helper")
        super.init()
        
        self.listener.delegate = self
    }
    
    func run() {
        logger.info("Microverse Helper Tool starting...")
        
        // Start listening for connections
        listener.resume()
        
        // Keep the tool running
        RunLoop.current.run()
    }
    
    // MARK: - NSXPCListenerDelegate
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        logger.info("Helper: Received connection request")
        
        // Verify the connection is from our main app
        guard isValidConnection(newConnection) else {
            logger.error("Helper: Rejected invalid connection")
            return false
        }
        
        // Configure the connection
        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        newConnection.exportedObject = HelperService()
        
        newConnection.invalidationHandler = {
            self.logger.info("Helper: Connection invalidated")
        }
        
        newConnection.interruptionHandler = {
            self.logger.warning("Helper: Connection interrupted")
        }
        
        newConnection.resume()
        logger.info("Helper: Connection accepted and configured")
        
        return true
    }
    
    private func isValidConnection(_ connection: NSXPCConnection) -> Bool {
        // In production, verify the code signature of the connecting process
        // For development, we'll accept any connection
        return true
    }
}

/// Protocol for helper communication
@objc protocol HelperProtocol {
    func getVersion(reply: @escaping (String) -> Void)
    func setChargeLimit(_ limit: Int, reply: @escaping (Bool, String?) -> Void)
    func setChargingEnabled(_ enabled: Bool, reply: @escaping (Bool, String?) -> Void)
    func getChargingStatus(reply: @escaping ([String: Any]) -> Void)
}

/// Helper service implementation
class HelperService: NSObject, HelperProtocol {
    private let logger = Logger(subsystem: "com.diversio.microverse.helper", category: "HelperService")
    
    func getVersion(reply: @escaping (String) -> Void) {
        reply("1.0.0")
    }
    
    func setChargeLimit(_ limit: Int, reply: @escaping (Bool, String?) -> Void) {
        logger.info("Helper: Setting charge limit to \(limit)%")
        
        // Verify we're running as root
        guard geteuid() == 0 else {
            reply(false, "Helper must run as root")
            return
        }
        
        // Use our SMC implementation
        let smcController = createSMCController()
        let result = smcController.setChargeLimit(limit)
        
        switch result {
        case .success:
            logger.info("Helper: Successfully set charge limit")
            reply(true, nil)
        case .failed(let error):
            logger.error("Helper: Failed to set charge limit: \(error)")
            reply(false, error)
        case .requiresRoot:
            reply(false, "Root access required")
        case .notSupported:
            reply(false, "Not supported on this system")
        }
    }
    
    func setChargingEnabled(_ enabled: Bool, reply: @escaping (Bool, String?) -> Void) {
        logger.info("Helper: Setting charging enabled to \(enabled)")
        
        // Verify we're running as root
        guard geteuid() == 0 else {
            reply(false, "Helper must run as root")
            return
        }
        
        let smcController = createSMCController()
        let result = smcController.setChargingEnabled(enabled)
        
        switch result {
        case .success:
            logger.info("Helper: Successfully set charging state")
            reply(true, nil)
        case .failed(let error):
            logger.error("Helper: Failed to set charging state: \(error)")
            reply(false, error)
        case .requiresRoot:
            reply(false, "Root access required")
        case .notSupported:
            reply(false, "Not supported on this system")
        }
    }
    
    func getChargingStatus(reply: @escaping ([String: Any]) -> Void) {
        logger.info("Helper: Getting charging status")
        
        let smcController = createSMCController()
        var status: [String: Any] = [:]
        
        if let chargeLimit = smcController.getChargeLimit() {
            status["chargeLimit"] = chargeLimit
        }
        
        if let chargingEnabled = smcController.isChargingEnabled() {
            status["chargingEnabled"] = chargingEnabled
        }
        
        if let temperature = smcController.getBatteryTemperature() {
            status["temperature"] = temperature
        }
        
        status["availableKeys"] = smcController.listAvailableBatteryKeys()
        
        reply(status)
    }
    
    private func createSMCController() -> SMCBatteryController {
        // This would normally import from our SMC framework
        // For now, we'll create a basic implementation
        return SMCBatteryController()
    }
}

// MARK: - Main Entry Point

let tool = HelperTool()
tool.run()