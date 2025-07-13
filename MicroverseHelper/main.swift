import Foundation
import ServiceManagement

/// Privileged helper tool for battery management operations
class MicroverseHelper: NSObject, NSXPCListenerDelegate, MicroverseHelperProtocol {
    
    private let listener: NSXPCListener
    private var connections = Set<NSXPCConnection>()
    private let smc = try? SMC()
    
    override init() {
        self.listener = NSXPCListener(machServiceName: "com.microverse.helper")
        super.init()
        self.listener.delegate = self
    }
    
    func run() {
        self.listener.resume()
        RunLoop.current.run()
    }
    
    // MARK: - NSXPCListenerDelegate
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Verify the connection is from our main app
        guard isValidConnection(newConnection) else {
            return false
        }
        
        newConnection.exportedInterface = NSXPCInterface(with: MicroverseHelperProtocol.self)
        newConnection.exportedObject = self
        
        newConnection.invalidationHandler = { [weak self] in
            self?.connections.remove(newConnection)
        }
        
        connections.insert(newConnection)
        newConnection.resume()
        
        return true
    }
    
    private func isValidConnection(_ connection: NSXPCConnection) -> Bool {
        // Verify the connection is from our signed app
        // This would check code signing requirements
        return true // Simplified for example
    }
    
    // MARK: - MicroverseHelperProtocol
    
    func setChargeLimit(_ percentage: Int, reply: @escaping (Bool, Error?) -> Void) {
        do {
            try smc?.setChargeLimit(percentage)
            reply(true, nil)
        } catch {
            reply(false, error)
        }
    }
    
    func setChargingEnabled(_ enabled: Bool, reply: @escaping (Bool, Error?) -> Void) {
        do {
            try smc?.setChargingEnabled(enabled)
            reply(true, nil)
        } catch {
            reply(false, error)
        }
    }
    
    func getBatteryInfo(reply: @escaping ([String: Any]?, Error?) -> Void) {
        do {
            let info: [String: Any] = [
                "temperature": try smc?.getBatteryTemperature() ?? 0,
                "cycleCount": try smc?.getCycleCount() ?? 0,
                "voltage": try smc?.readValue(for: .batteryVoltage) ?? 0,
                "current": try smc?.readValue(for: .batteryCurrent) ?? 0
            ]
            reply(info, nil)
        } catch {
            reply(nil, error)
        }
    }
    
    func installHelper(reply: @escaping (Bool, Error?) -> Void) {
        // Self-installation logic
        do {
            try installPrivilegedHelper()
            reply(true, nil)
        } catch {
            reply(false, error)
        }
    }
    
    private func installPrivilegedHelper() throws {
        // Copy helper to privileged location
        let fileManager = FileManager.default
        let helperPath = "/Library/PrivilegedHelperTools/com.microverse.helper"
        
        if !fileManager.fileExists(atPath: helperPath) {
            // Copy helper binary
            let sourcePath = Bundle.main.executablePath!
            try fileManager.copyItem(atPath: sourcePath, toPath: helperPath)
            
            // Set permissions
            try fileManager.setAttributes([
                .posixPermissions: 0o755,
                .ownerAccountID: 0,
                .groupOwnerAccountID: 0
            ], ofItemAtPath: helperPath)
        }
        
        // Install launchd plist
        installLaunchdPlist()
    }
    
    private func installLaunchdPlist() {
        let plistPath = "/Library/LaunchDaemons/com.microverse.helper.plist"
        let plist: [String: Any] = [
            "Label": "com.microverse.helper",
            "MachServices": [
                "com.microverse.helper": true
            ],
            "Program": "/Library/PrivilegedHelperTools/com.microverse.helper",
            "ProgramArguments": [
                "/Library/PrivilegedHelperTools/com.microverse.helper"
            ]
        ]
        
        if let plistData = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            try? plistData.write(to: URL(fileURLWithPath: plistPath))
            
            // Load the service
            let task = Process()
            task.launchPath = "/bin/launchctl"
            task.arguments = ["load", plistPath]
            task.launch()
            task.waitUntilExit()
        }
    }
}

// MARK: - Helper Protocol

@objc protocol MicroverseHelperProtocol {
    func setChargeLimit(_ percentage: Int, reply: @escaping (Bool, Error?) -> Void)
    func setChargingEnabled(_ enabled: Bool, reply: @escaping (Bool, Error?) -> Void)
    func getBatteryInfo(reply: @escaping ([String: Any]?, Error?) -> Void)
    func installHelper(reply: @escaping (Bool, Error?) -> Void)
}

// MARK: - Main

let helper = MicroverseHelper()
helper.run()