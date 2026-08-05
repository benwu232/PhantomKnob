import Foundation
import Sparkle
import os

final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateManager()
    
    private var updaterController: SPUStandardUpdaterController!
    
    @Published var automaticallyChecksForUpdates: Bool {
        didSet {
            updaterController.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }
    
    @Published var automaticallyDownloadsUpdates: Bool {
        didSet {
            updaterController.updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
        }
    }
    
    @Published var lastUpdateCheckDate: Date?
    
    private override init() {
        let autoCheck = UserDefaults.standard.object(forKey: "SUEnableAutomaticChecks") as? Bool ?? true
        let autoDownload = UserDefaults.standard.object(forKey: "SUAutomaticallyUpdate") as? Bool ?? true
        
        self.automaticallyChecksForUpdates = autoCheck
        self.automaticallyDownloadsUpdates = autoDownload
        
        super.init()
        
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        
        self.lastUpdateCheckDate = updaterController.updater.lastUpdateCheckDate
    }
    
    func checkForUpdates() {
        PKLogger.updater.info("User initiated check for updates")
        AnalyticsManager.shared.trackEvent("check_for_updates_clicked")
        updaterController.checkForUpdates(nil)
    }
    
    func checkForUpdatesInBackground() {
        PKLogger.updater.info("Background silent check for updates started")
        updaterController.updater.checkForUpdatesInBackground()
    }
    
    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }
    
    // MARK: - SPUUpdaterDelegate
    
    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        PKLogger.updater.info("Successfully loaded appcast with \(appcast.items.count) items")
        DispatchQueue.main.async {
            self.lastUpdateCheckDate = updater.lastUpdateCheckDate
        }
    }
    
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        PKLogger.updater.info("Found valid update item: \(item.versionString)")
        AnalyticsManager.shared.trackEvent("update_found", parameters: ["version": item.versionString])
    }
    
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        PKLogger.updater.error("Update aborted with error: \(error.localizedDescription)")
        AnalyticsManager.shared.trackEvent("update_failed", parameters: ["error": error.localizedDescription])
    }
}
