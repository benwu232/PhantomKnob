import SwiftUI
import os
#if canImport(Sentry)
import Sentry
#endif

class AppState: ObservableObject {
    let knobStateManager: KnobStateManager
    let statusBarController: StatusBarController
    
    init() {
        #if canImport(Sentry)
        SentrySDK.start { options in
            options.dsn = "YOUR_SENTRY_DSN"
            options.environment = "production"
            options.sampleRate = 1.0
            options.enableAutoSessionTracking = true
            options.attachStacktrace = true
            options.beforeSend = { event in
                let optOut = UserDefaults.standard.bool(forKey: "disableCrashReporting")
                return optOut ? nil : event
            }
        }
        #endif
        
        AnalyticsManager.shared.initialize()
        
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
        
        PKLogger.app.info("Initialized and touch monitoring started")
    }
    
    func toggleKnobMode() {
        PKLogger.app.info("toggleKnobMode called from UI")
        knobStateManager.toggleMode()
    }
}

#if !TESTING
@main
struct PhantomKnobApp: App {
    @StateObject private var appState = AppState()
    
    init() {
        AppLanguageManager.shared.applyLanguageOverrideOnStartup()
    }
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
#endif
