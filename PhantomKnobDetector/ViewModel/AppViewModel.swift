import Foundation
import SwiftUI

enum AppScreen {
    case welcome
    case detection
    case result(DetectionResult)
    case demo
}

class AppViewModel: ObservableObject {
    @Published var currentScreen: AppScreen = .welcome
    @Published var detectionResult: DetectionResult?
    
    private let cache: DetectionCache
    
    init(cache: DetectionCache) {
        self.cache = cache
        
        if let cachedResult = cache.load(), cachedResult.isSupported {
            self.detectionResult = cachedResult
            self.currentScreen = .demo
        }
    }
    
    func startDetection() {
        currentScreen = .detection
    }
    
    func completeDetection(_ result: DetectionResult) {
        detectionResult = result
        cache.save(result)
        
        if result.isSupported {
            currentScreen = .demo
        } else {
            currentScreen = .result(result)
        }
    }
    
    func reset() {
        cache.clear()
        detectionResult = nil
        currentScreen = .welcome
    }
    
    func goToWelcome() {
        currentScreen = .welcome
    }
}