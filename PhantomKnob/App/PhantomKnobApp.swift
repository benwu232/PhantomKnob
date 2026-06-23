import SwiftUI

class AppState: ObservableObject {
    let knobStateManager: KnobStateManager
    let statusBarController: StatusBarController
    
    init() {
        let targetDetector = TargetDetector()
        let gestureClassifier = GestureClassifier()
        let overlayController = OverlayController()
        let statusBarController = StatusBarController()
        let touchHandler = GlobalTouchHandler()
        
        self.statusBarController = statusBarController
        self.knobStateManager = KnobStateManager(
            targetDetector: targetDetector,
            gestureClassifier: gestureClassifier,
            overlayController: overlayController,
            statusBarController: statusBarController,
            touchHandler: touchHandler
        )
        
        self.knobStateManager.start()
        
        // 挂载云同步服务（当前仅保留本地持久化，已停用 iCloud KVS 同步）
        // CloudSyncManager.shared.start()
        
        let skipGuide = UserDefaults.standard.bool(forKey: "skipUserGuideOnStartup")
        if !skipGuide {
            UserGuideWindowController.shared.show()
        } else {
            let tutorialCompleted = UserDefaults.standard.bool(forKey: "firstRunTutorialCompleted")
            if !tutorialCompleted {
                KnobPanelWindowController.shared.show()
            }
        }
        
        NSLog("[AppState] Initialized and touch monitoring started")
    }
    
    func toggleKnobMode() {
        NSLog("[AppState] toggleKnobMode called from UI")
        knobStateManager.toggleMode()
    }
}

#if !TESTING
@main
struct PhantomKnobApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
#endif
