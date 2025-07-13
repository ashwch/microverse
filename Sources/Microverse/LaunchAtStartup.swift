import Foundation
import ServiceManagement

class LaunchAtStartup {
    private static let appIdentifier = "com.microverse.app"
    
    static var isEnabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            } else {
                // Fallback for older macOS versions
                return UserDefaults.standard.bool(forKey: "launchAtStartup")
            }
        }
        set {
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("Failed to \(newValue ? "enable" : "disable") launch at startup: \(error)")
                }
            } else {
                // Fallback for older macOS versions
                UserDefaults.standard.set(newValue, forKey: "launchAtStartup")
                print("Launch at startup is not fully supported on macOS < 13.0")
            }
        }
    }
}