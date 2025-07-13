import Foundation
import LocalAuthentication
import os.log

/// Modern authentication helper using LocalAuthentication for Touch ID
public class ModernAuthHelper {
    private let logger = Logger(subsystem: "com.microverse.app", category: "ModernAuthHelper")
    
    public init() {}
    
    /// Request authentication using Touch ID or password
    public func requestAuthentication(reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is available
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            logger.info("Requesting authentication with Touch ID/password")
            
            // Set the reason for authentication
            context.localizedReason = reason
            
            // Evaluate the policy
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            ) { [weak self] success, authError in
                DispatchQueue.main.async {
                    if success {
                        self?.logger.info("Authentication successful")
                        completion(true)
                    } else {
                        if let error = authError {
                            self?.logger.error("Authentication failed: \(error.localizedDescription)")
                        }
                        completion(false)
                    }
                }
            }
        } else {
            logger.error("Authentication not available: \(error?.localizedDescription ?? "Unknown error")")
            completion(false)
        }
    }
    
    /// Check if Touch ID is available
    public func isBiometricAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        
        // Check specifically for biometrics (Touch ID)
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
}