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
        
        NSLog("[AppState] Initialized, statusBarController retained")
    }
    
    func toggleKnobMode() {
        NSLog("[AppState] toggleKnobMode called from UI")
        knobStateManager.toggleMode()
    }
}

#if !TESTING
@main
struct PhantomKnobApp: App {
    @StateObject private var appViewModel = AppViewModel(cache: DetectionCache())
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            VStack {
                ContentView(appViewModel: appViewModel)
            }
            .onAppear {
                appState.knobStateManager.start()
                
                let skipGuide = UserDefaults.standard.bool(forKey: "skipUserGuideOnStartup")
                if !skipGuide {
                    UserGuideWindowController.shared.show()
                } else {
                    let tutorialCompleted = UserDefaults.standard.bool(forKey: "firstRunTutorialCompleted")
                    if !tutorialCompleted {
                        KnobPanelWindowController.shared.show()
                    }
                }
            }
            .toolbar {
                ToolbarItem {
                    Button(action: {
                        appState.toggleKnobMode()
                    }) {
                        Text("切换 Knob 模式")
                    }
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        
        Settings {
            SettingsView()
        }
    }
}
#endif

struct ContentView: View {
    @ObservedObject var appViewModel: AppViewModel
    
    var body: some View {
        switch appViewModel.currentScreen {
        case .welcome:
            WelcomeView()
                .environmentObject(appViewModel)
        case .detection:
            DetectionView()
                .environmentObject(appViewModel)
        case .result(let result):
            ResultView(result: result)
                .environmentObject(appViewModel)
        case .demo:
            DemoView()
                .environmentObject(appViewModel)
        }
    }
}
