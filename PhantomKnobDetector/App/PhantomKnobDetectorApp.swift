import SwiftUI

class AppState: ObservableObject {
    let knobStateManager: KnobStateManager
    
    init() {
        let targetDetector = TargetDetector()
        let gestureClassifier = GestureClassifier()
        let overlayController = OverlayController()
        let statusBarController = StatusBarController()
        let touchHandler = GlobalTouchHandler()
        
        self.knobStateManager = KnobStateManager(
            targetDetector: targetDetector,
            gestureClassifier: gestureClassifier,
            overlayController: overlayController,
            statusBarController: statusBarController,
            touchHandler: touchHandler
        )
    }
}

@main
struct PhantomKnobDetectorApp: App {
    @StateObject private var appViewModel = AppViewModel(cache: DetectionCache())
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView(appViewModel: appViewModel)
                .onAppear {
                    appState.knobStateManager.start()
                }
        }
        .windowStyle(.hiddenTitleBar)
        
        Settings {
            SettingsView()
        }
    }
}

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
