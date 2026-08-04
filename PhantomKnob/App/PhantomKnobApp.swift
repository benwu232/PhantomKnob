import SwiftUI
import AppKit
import os
#if canImport(Sentry)
import Sentry
#endif

class AppState: ObservableObject {
    let knobStateManager: KnobStateManager
    let statusBarController: StatusBarController
    
    init() {

        SentryManager.start()
        
        AnalyticsManager.shared.initialize()
        URLSchemeHandler.shared.startListening()
        
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
        
        // 启动 Dock 图标版本切换管理
        DockIconManager.shared.start()
        
        // 挂载云同步服务（当前仅保留本地持久化，已停用 iCloud KVS 同步）
        // CloudSyncManager.shared.start()
        
        let skipGuide = UserDefaults.app.bool(forKey: "skipUserGuideOnStartup")
        if !skipGuide {
            UserGuideWindowController.shared.show()
        } else {
            let tutorialCompleted = UserDefaults.app.bool(forKey: "firstRunTutorialCompleted")
            if !tutorialCompleted {
                KnobPanelWindowController.shared.show()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ReleaseNotesController.shared.showIfNeeded()
        }
        
        PKLogger.app.info("Initialized and touch monitoring started")
    }
    
    func toggleKnobMode() {
        PKLogger.app.info("toggleKnobMode called from UI")
        knobStateManager.toggleMode()
    }
}

#if !TESTING
class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            URLSchemeHandler.shared.parseAndTriggerActivation(url: url)
        }
    }
}

@main
struct PhantomKnobApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    
    init() {
        if NSClassFromString("XCTestCase") == nil {
            HardwareDetector.checkTrackpadWithRetry(maxAttempts: 5, interval: 2.0) { connected in
                if !connected {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = String(localized: "startup.noTrackpad.title", defaultValue: "No Trackpad Detected")
                        alert.informativeText = String(localized: "startup.noTrackpad.message", defaultValue: "PhantomKnob requires a trackpad (MacBook trackpad or Magic Trackpad) to perform knob gestures. The application will now exit.")
                        alert.alertStyle = .critical
                        alert.addButton(withTitle: String(localized: "startup.noTrackpad.quit", defaultValue: "Quit"))
                        alert.runModal()
                        exit(0)
                    }
                }
            }
        }
        AppLanguageManager.shared.applyLanguageOverrideOnStartup()
    }
    
    var body: some Scene {
        Settings {
            SettingsView()
                .onOpenURL { url in
                    URLSchemeHandler.shared.parseAndTriggerActivation(url: url)
                }
        }
    }
}
#endif
