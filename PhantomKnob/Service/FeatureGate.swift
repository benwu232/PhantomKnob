import Foundation

class FeatureGate {
    static let shared = FeatureGate()
    
    private let licenseManager: LicenseManager
    
    init(licenseManager: LicenseManager = .shared) {
        self.licenseManager = licenseManager
    }
    
    var isPremiumActive: Bool {
        return licenseManager.currentState.isPremiumActive
    }
    
    var hasStyleCustomization: Bool {
        return licenseManager.currentState.hasStyleCustomization
    }
    
    var hasCloudSync: Bool {
        return licenseManager.currentState.hasCloudSync
    }
    
    var activationDelay: Double {
        return licenseManager.currentState.activationDelay
    }
    
    var sessionLimitSeconds: Double? {
        return licenseManager.currentState.sessionLimitSeconds
    }
}
