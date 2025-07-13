import Foundation
import ServiceManagement
import Security
import os.log

/// Manages the privileged helper tool installation and communication
public class HelperManager: NSObject {
    private let logger = Logger(subsystem: "com.microverse.app", category: "HelperManager")
    private let helperMachServiceName = "com.diversio.microverse.helper"
    private var helperConnection: NSXPCConnection?
    
    public override init() {
        super.init()
    }
    
    // MARK: - Helper Installation
    
    /// Check if the helper tool is installed
    public func isHelperInstalled() -> Bool {
        let helperURL = helperToolURL()
        let installed = FileManager.default.fileExists(atPath: helperURL.path)
        logger.info("Helper installed: \(installed)")
        return installed
    }
    
    /// Install the helper tool with user authentication
    public func installHelper(completion: @escaping (Bool, Error?) -> Void) {
        logger.info("Installing helper tool...")
        
        // For now, just return not implemented
        // This would require proper SMJobBless implementation
        completion(false, HelperError.notImplemented)
    }
    
    /// Remove the helper tool
    public func removeHelper(completion: @escaping (Bool, Error?) -> Void) {
        logger.info("Removing helper tool...")
        
        // Create authorization
        var authRef: AuthorizationRef?
        let authStatus = AuthorizationCreate(nil, nil, [], &authRef)
        
        guard authStatus == errAuthorizationSuccess else {
            completion(false, HelperError.authorizationFailed)
            return
        }
        
        defer {
            if let authRef = authRef {
                AuthorizationFree(authRef, [])
            }
        }
        
        // Use SMJobRemove to uninstall the helper
        var cfError: Unmanaged<CFError>?
        let success = SMJobRemove(
            kSMDomainSystemLaunchd,
            helperMachServiceName as CFString,
            authRef,
            true, // wait for removal
            &cfError
        )
        
        if success {
            logger.info("Helper tool removed successfully")
            completion(true, nil)
        } else {
            let error = cfError?.takeRetainedValue()
            logger.error("Failed to remove helper: \(String(describing: error))")
            completion(false, error ?? HelperError.removalFailed)
        }
    }
    
    // MARK: - Helper Communication
    
    /// Get connection to the helper tool
    private func createHelperConnection() -> NSXPCConnection? {
        if let existingConnection = helperConnection {
            return existingConnection
        }
        
        let connection = NSXPCConnection(machServiceName: helperMachServiceName, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        
        connection.invalidationHandler = { [weak self] in
            self?.logger.info("Helper connection invalidated")
            self?.helperConnection = nil
        }
        
        connection.interruptionHandler = { [weak self] in
            self?.logger.warning("Helper connection interrupted")
        }
        
        connection.resume()
        helperConnection = connection
        
        return connection
    }
    
    /// Test connection to helper
    public func testHelper(completion: @escaping (Bool, String?) -> Void) {
        guard let connection = createHelperConnection() else {
            completion(false, "Failed to create connection")
            return
        }
        
        let helper = connection.remoteObjectProxyWithErrorHandler { error in
            self.logger.error("Helper connection error: \(error)")
            completion(false, "Connection error: \(error.localizedDescription)")
        } as? HelperProtocol
        
        helper?.getVersion { version in
            self.logger.info("Helper version: \(version)")
            completion(true, version)
        }
    }
    
    // MARK: - Battery Control via Helper
    
    public func setChargeLimit(_ limit: Int, completion: @escaping (Bool, String?) -> Void) {
        guard let connection = createHelperConnection() else {
            completion(false, "Helper not connected")
            return
        }
        
        let helper = connection.remoteObjectProxyWithErrorHandler { error in
            completion(false, "Connection error: \(error.localizedDescription)")
        } as? HelperProtocol
        
        helper?.setChargeLimit(limit, reply: completion)
    }
    
    public func setChargingEnabled(_ enabled: Bool, completion: @escaping (Bool, String?) -> Void) {
        guard let connection = createHelperConnection() else {
            completion(false, "Helper not connected")
            return
        }
        
        let helper = connection.remoteObjectProxyWithErrorHandler { error in
            completion(false, "Connection error: \(error.localizedDescription)")
        } as? HelperProtocol
        
        helper?.setChargingEnabled(enabled, reply: completion)
    }
    
    public func getChargingStatus(completion: @escaping ([String: Any]?) -> Void) {
        guard let connection = createHelperConnection() else {
            completion(nil)
            return
        }
        
        let helper = connection.remoteObjectProxyWithErrorHandler { error in
            self.logger.error("Helper status error: \(error)")
            completion(nil)
        } as? HelperProtocol
        
        helper?.getChargingStatus { status in
            completion(status)
        }
    }
    
    // MARK: - Helper Utilities
    
    private func helperToolURL() -> URL {
        return URL(fileURLWithPath: "/Library/PrivilegedHelperTools/\(helperMachServiceName)")
    }
}

// MARK: - Helper Protocol (shared)

@objc protocol HelperProtocol {
    func getVersion(reply: @escaping (String) -> Void)
    func setChargeLimit(_ limit: Int, reply: @escaping (Bool, String?) -> Void)
    func setChargingEnabled(_ enabled: Bool, reply: @escaping (Bool, String?) -> Void)
    func getChargingStatus(reply: @escaping ([String: Any]) -> Void)
}

// MARK: - Helper Errors

public enum HelperError: LocalizedError {
    case authorizationFailed
    case installationFailed
    case removalFailed
    case connectionFailed
    case notInstalled
    case notImplemented
    
    public var errorDescription: String? {
        switch self {
        case .authorizationFailed:
            return "Failed to get authorization for helper installation"
        case .installationFailed:
            return "Failed to install helper tool"
        case .removalFailed:
            return "Failed to remove helper tool"
        case .connectionFailed:
            return "Failed to connect to helper tool"
        case .notInstalled:
            return "Helper tool is not installed"
        case .notImplemented:
            return "Helper tool installation not yet implemented"
        }
    }
}