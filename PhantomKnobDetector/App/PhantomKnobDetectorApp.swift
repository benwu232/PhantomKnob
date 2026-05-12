import SwiftUI

@main
struct PhantomKnobDetectorApp: App {
    @StateObject private var appViewModel = AppViewModel(cache: DetectionCache())
    
    var body: some Scene {
        WindowGroup {
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
        .windowStyle(.hiddenTitleBar)
    }
}
