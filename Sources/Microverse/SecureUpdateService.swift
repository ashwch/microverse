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
    private var updaterController: SPUStandardUpdaterController!
    
    static let shared = SecureUpdateService()
    
    override init() {
        super.init()
        
        // Initialize the updater controller with self as delegate
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        
        setupUpdater()
        loadLastUpdateCheck()
    }
    
    private func setupUpdater() {
        // Configure Sparkle for security and user experience
        let updater = updaterController.updater
        
        // Disable automatic checking by default - user controls this through settings
        updater.automaticallyChecksForUpdates = false
        
        // Check every 24 hours when enabled by user
        updater.updateCheckInterval = 24 * 60 * 60
        
        logger.info("Secure update service initialized with Sparkle framework (manual mode)")
    }
    
    func checkForUpdates() {
        guard !isCheckingForUpdates else { return }
        
        isCheckingForUpdates = true
        lastUpdateCheck = Date()
        saveLastUpdateCheck()
        
        // Add timeout to prevent stuck state
        Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            if isCheckingForUpdates {
                await MainActor.run {
                    isCheckingForUpdates = false
                    logger.warning("Update check timed out after 30 seconds")
                }
            }
        }
        
        updaterController.checkForUpdates(nil)
        logger.info("Manual update check initiated")
    }
    
    func setAutomaticUpdateChecking(enabled: Bool) {
        updaterController.updater.automaticallyChecksForUpdates = enabled
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
                logger.error("Update check failed: \(error.localizedDescription)")
                logger.error("Error details: \(error)")
                updateAvailable = false
            } else {
                logger.info("Update check completed successfully")
            }
        }
    }
    
    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Task { @MainActor in
            updateAvailable = true
            latestVersion = item.versionString
            logger.info("Update available: \(item.versionString)")
        }
    }
    
    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        Task { @MainActor in
            updateAvailable = false
            logger.info("No updates available")
        }
    }
    
    nonisolated func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        logger.info("Will install update: \(item.versionString)")
    }
    
    nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        Task { @MainActor in
            isCheckingForUpdates = false
            updateAvailable = false
            logger.error("Update aborted with error: \(error.localizedDescription)")
        }
    }
    
    // Provide feed URL programmatically since we don't have it in Info.plist
    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        // Return the proper appcast XML feed URL
        return "https://microverse.ashwch.com/appcast.xml"
    }
}

