import XCTest
@testable import PhantomKnob

class LicenseTests: XCTestCase {
    func testLicensedStateProperties() {
        let state = LicenseState.licensed
        XCTAssertTrue(state.isPremiumActive)
        XCTAssertTrue(state.hasStyleCustomization)
        XCTAssertTrue(state.hasCloudSync)
        XCTAssertEqual(state.activationDelay, 0.0)
        XCTAssertNil(state.sessionLimitSeconds)
    }
    
    func testTrialingStateProperties() {
        let state = LicenseState.trialing(daysRemaining: 10)
        XCTAssertTrue(state.isPremiumActive)
        XCTAssertTrue(state.hasStyleCustomization)
        XCTAssertTrue(state.hasCloudSync)
        XCTAssertEqual(state.activationDelay, 0.0)
        XCTAssertNil(state.sessionLimitSeconds)
    }
    
    func testFreeStateProperties() {
        let state = LicenseState.free
        XCTAssertFalse(state.isPremiumActive)
        XCTAssertFalse(state.hasStyleCustomization)
        XCTAssertFalse(state.hasCloudSync)
        XCTAssertEqual(state.activationDelay, 2.0)
        XCTAssertEqual(state.sessionLimitSeconds, 900.0)
    }
}
