import Foundation
import Sparkle

final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    
    private let updaterController: SPUStandardUpdaterController
    
    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }
    
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
    
    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }
}
