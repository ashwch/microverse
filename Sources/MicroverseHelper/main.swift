import Foundation
import os.log
import SMCKit
import BatteryCore

// MARK: - Helper Protocol
@objc protocol MicroverseHelperProtocol {
    func setChargeLimit(_ limit: Int, reply: @escaping (Bool, String?) -> Void)
    func setChargingEnabled(_ enabled: Bool, reply: @escaping (Bool, String?) -> Void)
    func getChargingStatus(reply: @escaping (Bool, Int?, Bool?, String?) -> Void)
    func runSMCDiagnostics(reply: @escaping (String) -> Void)
}

// MARK: - Helper Implementation
class MicroverseHelper: NSObject, MicroverseHelperProtocol, NSXPCListenerDelegate {
    private let logger = Logger(subsystem: "com.diversio.microverse.helper", category: "Helper")
    private lazy var smcController: SMCBatteryController = {
        // We'll need to copy SMC classes here or create a shared framework
        return SMCBatteryController()
    }()
    
    func setChargeLimit(_ limit: Int, reply: @escaping (Bool, String?) -> Void) {
        logger.info("Helper: Setting charge limit to \(limit)%")
        
        let result = smcController.setChargeLimit(limit)
        
        switch result {
        case .success:
            reply(true, nil)
        case .failed(let error):
            reply(false, error)
        case .requiresRoot:
            reply(false, "Root access required")
        case .notSupported:
            reply(false, "Not supported on this Mac")
        }
    }
    
    func setChargingEnabled(_ enabled: Bool, reply: @escaping (Bool, String?) -> Void) {
        logger.info("Helper: Setting charging enabled to \(enabled)")
        
        let result = smcController.setChargingEnabled(enabled)
        
        switch result {
        case .success:
            reply(true, nil)
        case .failed(let error):
            reply(false, error)
        case .requiresRoot:
            reply(false, "Root access required")
        case .notSupported:
            reply(false, "Not supported on this Mac")
        }
    }
    
    func getChargingStatus(reply: @escaping (Bool, Int?, Bool?, String?) -> Void) {
        logger.info("Helper: Getting charging status")
        
        let chargeLimit = smcController.getChargeLimit()
        let chargingEnabled = smcController.isChargingEnabled()
        
        if chargeLimit != nil || chargingEnabled != nil {
            reply(true, chargeLimit, chargingEnabled, nil)
        } else {
            reply(false, nil, nil, "Failed to read SMC values")
        }
    }
    
    func runSMCDiagnostics(reply: @escaping (String) -> Void) {
        logger.info("Helper: Running SMC diagnostics")
        
        let tester = SMCTester()
        let report = tester.getDiagnosticReport()
        reply(report)
    }
    
    // MARK: - NSXPCListenerDelegate
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Verify the connection is from our main app
        let connectionIsValid = verifyConnection(newConnection)
        
        guard connectionIsValid else {
            logger.error("Rejected connection from unauthorized client")
            return false
        }
        
        newConnection.exportedInterface = NSXPCInterface(with: MicroverseHelperProtocol.self)
        newConnection.exportedObject = self
        
        newConnection.invalidationHandler = {
            self.logger.info("Client disconnected")
        }
        
        newConnection.interruptionHandler = {
            self.logger.info("Client connection interrupted")
        }
        
        newConnection.resume()
        
        logger.info("Accepted connection from client")
        return true
    }
    
    private func verifyConnection(_ connection: NSXPCConnection) -> Bool {
        // In production, verify the code signature of the connecting process
        // For now, we'll accept all connections
        return true
    }
}

// MARK: - Main Entry Point
let logger = Logger(subsystem: "com.diversio.microverse.helper", category: "Main")
logger.info("Microverse Helper starting...")

// Create the listener
let listener = NSXPCListener(machServiceName: "com.diversio.microverse.helper")
let helper = MicroverseHelper()
listener.delegate = helper

// Start listening
listener.resume()

logger.info("Helper listening for connections...")

// Run the run loop
RunLoop.current.run()