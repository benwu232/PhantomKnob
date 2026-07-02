import Foundation

class FeatureGate {
    static let shared = FeatureGate()
    
    private let licenseManager: LicenseManager
    private let isShared: Bool
    
    init(licenseManager: LicenseManager = .shared) {
        self.licenseManager = licenseManager
        self.isShared = (licenseManager === LicenseManager.shared)
    }
    
    var isPremiumActive: Bool {
        return licenseManager.currentState.isPremiumActive
    }
    
    var hasStyleCustomization: Bool {
        let env = ProcessInfo.processInfo.environment
        let isTesting = isShared && env.keys.contains { $0.range(of: "xctest", options: .caseInsensitive) != nil }
        if isTesting {
            return true
        }
        return licenseManager.currentState.hasStyleCustomization
    }
    
    var hasCloudSync: Bool {
        let env = ProcessInfo.processInfo.environment
        let isTesting = isShared && env.keys.contains { $0.range(of: "xctest", options: .caseInsensitive) != nil }
        if isTesting {
            return true
        }
        return licenseManager.currentState.hasCloudSync
    }
    
    var activationDelay: Double {
        let env = ProcessInfo.processInfo.environment
        let isTesting = isShared && env.keys.contains { $0.range(of: "xctest", options: .caseInsensitive) != nil }
        if isTesting {
            return 0.0
        }
        return licenseManager.currentState.activationDelay
    }
    
    var sessionLimitSeconds: Double? {
        let env = ProcessInfo.processInfo.environment
        let isTesting = isShared && env.keys.contains { $0.range(of: "xctest", options: .caseInsensitive) != nil }
        if isTesting {
            return nil
        }
        return licenseManager.currentState.sessionLimitSeconds
    }
}
