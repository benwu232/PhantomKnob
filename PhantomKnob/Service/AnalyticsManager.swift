import Foundation
import TelemetryClient

final class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private init() {}
    
    func initialize() {
        guard !UserDefaults.standard.bool(forKey: "disableAnalytics") else { return }
        let config = TelemetryManagerConfiguration(appID: "YOUR_TELEMETRYDECK_APP_ID")
        TelemetryManager.initialize(with: config)
        
        trackEvent("appLaunched")
    }
    
    func trackEvent(_ name: String, parameters: [String: String] = [:]) {
        guard !UserDefaults.standard.bool(forKey: "disableAnalytics") else { return }
        TelemetryManager.send(name, with: parameters)
    }
}
