import XCTest
@testable import PhantomKnob

class FeatureGateTests: XCTestCase {
    func testFeatureGateWithLicensedState() {
        let mockStorage = ["licenseKey": "VALID-KEY", "licenseEmail": "user@example.com"]
        let licenseManager = LicenseManager(
            currentDateProvider: { Date() },
            storageRead: { key in mockStorage[key] },
            storageWrite: { _, _ in }
        )
        let gate = FeatureGate(licenseManager: licenseManager)
        
        XCTAssertTrue(gate.isPremiumActive)
        XCTAssertTrue(gate.hasStyleCustomization)
        XCTAssertTrue(gate.hasCloudSync)
        XCTAssertEqual(gate.activationDelay, 0.0)
        XCTAssertNil(gate.sessionLimitSeconds)
    }
    
    func testFeatureGateWithTrialingState() {
        let formatter = ISO8601DateFormatter()
        let startDateStr = formatter.string(from: Date())
        let mockStorage = ["trialStartDate": startDateStr]
        let licenseManager = LicenseManager(
            currentDateProvider: { Date() },
            storageRead: { key in mockStorage[key] },
            storageWrite: { _, _ in }
        )
        let gate = FeatureGate(licenseManager: licenseManager)
        
        XCTAssertTrue(gate.isPremiumActive)
        XCTAssertTrue(gate.hasStyleCustomization)
        XCTAssertTrue(gate.hasCloudSync)
        XCTAssertEqual(gate.activationDelay, 0.0)
        XCTAssertNil(gate.sessionLimitSeconds)
    }
    
    func testFeatureGateWithFreeState() {
        // Force free state by having an expired trial date
        let formatter = ISO8601DateFormatter()
        let startDateStr = formatter.string(from: Date().addingTimeInterval(-16 * 24 * 60 * 60))
        let mockStorage = ["trialStartDate": startDateStr]
        let licenseManager = LicenseManager(
            currentDateProvider: { Date() },
            storageRead: { key in mockStorage[key] },
            storageWrite: { _, _ in }
        )
        let gate = FeatureGate(licenseManager: licenseManager)
        
        XCTAssertFalse(gate.isPremiumActive)
        XCTAssertFalse(gate.hasStyleCustomization)
        XCTAssertFalse(gate.hasCloudSync)
        XCTAssertEqual(gate.activationDelay, 2.0)
        XCTAssertEqual(gate.sessionLimitSeconds, 900.0)
    }
}
