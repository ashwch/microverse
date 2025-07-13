import Foundation
import Security
import os.log

/// Helper for managing authorization and privileged operations
public class AuthorizationHelper {
    private let logger = Logger(subsystem: "com.microverse.app", category: "AuthorizationHelper")
    private var authRef: AuthorizationRef?
    
    public init() {}
    
    deinit {
        if let auth = authRef {
            AuthorizationFree(auth, [])
        }
    }
    
    /// Request authorization from the user
    public func requestAuthorization() -> Bool {
        logger.info("Requesting authorization...")
        
        // Use com.apple.ServiceManagement.daemons.modify for modern Touch ID prompt
        // This is the same right used by system preference panes
        let rightName = "com.apple.ServiceManagement.daemons.modify"
        
        return rightName.withCString { rightNameCStr in
            // Define the rights we need
            var authItem = AuthorizationItem(
                name: rightNameCStr,
                valueLength: 0,
                value: nil,
                flags: 0
            )
            
            return withUnsafeMutablePointer(to: &authItem) { authItemPtr in
                var authRights = AuthorizationRights(
                    count: 1,
                    items: authItemPtr
                )
                
                let authFlags: AuthorizationFlags = [
                    .interactionAllowed,    // Allow user interaction
                    .extendRights          // Extend rights if needed
                ]
                
                // Create authorization reference
                var authRef: AuthorizationRef?
                
                // First create an empty auth ref
                var status = AuthorizationCreate(
                    nil,
                    nil,
                    [],
                    &authRef
                )
                
                guard status == errAuthorizationSuccess else {
                    logger.error("Failed to create authorization reference: \(status)")
                    return false
                }
                
                // Now request the specific rights with the modern dialog
                status = AuthorizationCopyRights(
                    authRef!,
                    &authRights,
                    nil,  // Use default environment
                    authFlags,
                    nil   // We don't need to copy the rights
                )
                
                if status == errAuthorizationSuccess {
                    self.authRef = authRef
                    logger.info("Authorization granted")
                    return true
                } else if status == errAuthorizationCanceled {
                    logger.info("Authorization cancelled by user")
                    if let auth = authRef {
                        AuthorizationFree(auth, [])
                    }
                    return false
                } else {
                    logger.error("Authorization failed with status: \(status)")
                    if let auth = authRef {
                        AuthorizationFree(auth, [])
                    }
                    return false
                }
            }
        }
    }
    
    /// Execute a privileged command
    public func executePrivilegedCommand(_ command: String, arguments: [String]) -> (success: Bool, output: String?) {
        guard authRef != nil else {
            logger.error("No authorization reference")
            return (false, nil)
        }
        
        logger.info("Executing privileged command: \(command)")
        
        // This is a simplified version - in production, you'd use a privileged helper tool
        let task = Process()
        task.launchPath = command
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)
            
            return (task.terminationStatus == 0, output)
        } catch {
            logger.error("Failed to execute command: \(error)")
            return (false, nil)
        }
    }
    
    /// Check if we have existing authorization
    public func hasAuthorization() -> Bool {
        return authRef != nil
    }
}