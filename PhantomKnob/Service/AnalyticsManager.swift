import Foundation
import TelemetryClient

final class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private init() {}
    
    func initialize() {
        guard !UserDefaults.app.bool(forKey: "disableAnalytics") else { return }
        let config = TelemetryManagerConfiguration(appID: "00000000-0000-0000-0000-000000000000")
        TelemetryManager.initialize(with: config)
        
        trackEvent("appLaunched")
    }
    
    func trackEvent(_ name: String, parameters: [String: String] = [:]) {
        guard !UserDefaults.app.bool(forKey: "disableAnalytics") else { return }
        TelemetryManager.send(name, with: parameters)
    }
}
