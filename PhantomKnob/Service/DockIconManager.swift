import AppKit
import Combine

class DockIconManager {
    static let shared = DockIconManager()
    private var cancellable: AnyCancellable?
    
    private init() {
        cancellable = NotificationCenter.default
            .publisher(for: NSNotification.Name("LicenseStateDidChange"))
            .sink { [weak self] _ in
                self?.updateDockIcon()
            }
    }
    
    func start() {
        updateDockIcon()
    }
    
    func updateDockIcon() {
        let licenseState = LicenseManager.shared.currentState
        switch licenseState {
        case .free:
            if let freeImage = NSImage(named: "AppIconFree") {
                NSApp.applicationIconImage = freeImage
                PKLogger.app.info("Dock icon successfully updated to AppIconFree (Free Edition)")
            } else {
                PKLogger.app.error("Failed to load AppIconFree image from assets")
            }
        default:
            NSApp.applicationIconImage = nil // Restore default AppIcon from plist
            PKLogger.app.info("Dock icon restored to default")
        }
    }
}
