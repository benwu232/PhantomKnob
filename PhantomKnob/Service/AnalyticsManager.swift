import Foundation
import TelemetryClient

final class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private init() {}
    
    func initialize() {
        guard !UserDefaults.app.bool(forKey: "disableAnalytics") else { return }
        let config = TelemetryManagerConfiguration(appID: "53C1AC3A-367E-4E3D-9AF3-1B735A5D8C37")
        TelemetryManager.initialize(with: config)
        
        trackEvent("appLaunched")
    }
    
    func trackEvent(_ name: String, parameters: [String: String] = [:]) {
        guard !UserDefaults.app.bool(forKey: "disableAnalytics") else { return }
        TelemetryManager.send(name, with: parameters)
    }
}
