import Foundation
import SwiftUI
import Sparkle
import os.log

@MainActor
class SecureUpdateService: NSObject, ObservableObject {
    @Published var updateAvailable = false
    @Published var isCheckingForUpdates = false
    @Published var currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    @Published var latestVersion: String?
    @Published var lastUpdateCheck: Date?
    
    private let logger = Logger(subsystem: "com.microverse.app", category: "SecureUpdateService")
    private var updater: SPUUpdater!
    
    static let shared = SecureUpdateService()
    
    override init() {
        super.init()
        
        // Create user driver first 
        let userDriver = SPUStandardUserDriver(hostBundle: Bundle.main, delegate: nil)
        
        // Initialize updater with proper delegate reference
        self.updater = SPUUpdater(hostBundle: Bundle.main, applicationBundle: Bundle.main, userDriver: userDriver, delegate: self)
        
        do {
            try updater.start()
        } catch {
            logger.error("Sparkle failed to start: \(error)")
            return
        }
        
        setupUpdater()
        loadLastUpdateCheck()
        
        logger.info("SecureUpdateService initialized successfully")
    }
    
    
    private func setupUpdater() {
        // Configure Sparkle for security and user experience
        // Disable automatic checking by default - user controls this through settings
        updater.automaticallyChecksForUpdates = false
        
        // Check every 24 hours when enabled by user
        updater.updateCheckInterval = 24 * 60 * 60
        
        // EdDSA signature verification enabled via SUPublicEDKey in Info.plist
        
        logger.info("Secure update service initialized with Sparkle framework (manual mode)")
    }
    
    func checkForUpdates() {
        guard !isCheckingForUpdates else { return }
        
        isCheckingForUpdates = true
        lastUpdateCheck = Date()
        saveLastUpdateCheck()
        
        updater.checkForUpdateInformation()
    }
    
    func installUpdate() {
        // Use Sparkle's standard user-driven update flow
        updater.checkForUpdates()
    }
    
    @MainActor
    private func checkForUpdatesManually() async {
        do {
            // Fetch appcast directly
            guard let url = URL(string: "https://microverse.ashwch.com/appcast.xml") else {
                isCheckingForUpdates = false
                return
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let xmlString = String(data: data, encoding: .utf8) ?? ""
            
            // Parse latest version from appcast
            if let latestVersion = parseLatestVersionFromAppcast(xmlString) {
                let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.1"
                
                // Compare versions
                let comparison = currentVersion.compare(latestVersion, options: .numeric)
                
                if comparison == .orderedAscending {
                    // Update available!
                    self.updateAvailable = true
                    self.latestVersion = latestVersion
                    logger.info("Update found: \(currentVersion) → \(latestVersion)")
                } else {
                    // Up to date
                    self.updateAvailable = false
                    logger.info("Up to date: \(currentVersion)")
                }
            }
            
        } catch {
            logger.error("Update check failed: \(error)")
        }
        
        isCheckingForUpdates = false
    }
    
    private func parseLatestVersionFromAppcast(_ xml: String) -> String? {
        // Simple regex to find first sparkle:version
        let pattern = #"sparkle:version="([^"]+)""#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)),
           let range = Range(match.range(at: 1), in: xml) {
            return String(xml[range])
        }
        return nil
    }
    
    func setAutomaticUpdateChecking(enabled: Bool) {
        updater.automaticallyChecksForUpdates = enabled
        logger.info("Automatic update checking set to: \(enabled)")
    }
    
    private func loadLastUpdateCheck() {
        if let timestamp = UserDefaults.standard.object(forKey: "lastUpdateCheck") as? Date {
            lastUpdateCheck = timestamp
        }
    }
    
    private func saveLastUpdateCheck() {
        UserDefaults.standard.set(lastUpdateCheck, forKey: "lastUpdateCheck")
    }
    
    func resetUpdateState() {
        isCheckingForUpdates = false
        updateAvailable = false
        logger.info("Update state reset")
    }
}

// MARK: - SPUUpdaterDelegate

extension SecureUpdateService: SPUUpdaterDelegate {
    nonisolated func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        Task { @MainActor in
            isCheckingForUpdates = false
            
            if let error = error {
                logger.error("Update cycle failed: \(error)")
                updateAvailable = false
            }
        }
    }
    
    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        
        let version = item.versionString
        
        Task { @MainActor in
            updateAvailable = true
            latestVersion = version
            logger.info("Update available: \(version)")
        }
    }
    
    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        Task { @MainActor in
            updateAvailable = false
            isCheckingForUpdates = false
        }
    }
    
    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        Task { @MainActor in
            updateAvailable = false
            isCheckingForUpdates = false
        }
    }
    
    nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        Task { @MainActor in
            isCheckingForUpdates = false
        }
    }
    
    nonisolated func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        logger.info("Will install update: \(item.versionString)")
    }
    
    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        return "https://microverse.ashwch.com/appcast.xml"
    }
}
