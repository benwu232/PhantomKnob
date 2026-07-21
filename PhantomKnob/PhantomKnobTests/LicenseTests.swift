import XCTest
@testable import PhantomKnob

class LicenseTests: XCTestCase {
    func testLicensedStateProperties() {
        let state = LicenseState.licensed
        XCTAssertTrue(state.isProActive)
        XCTAssertTrue(state.hasStyleCustomization)
        XCTAssertTrue(state.hasCloudSync)
        XCTAssertEqual(state.activationDelay, 0.0)
        XCTAssertNil(state.sessionLimitSeconds)
    }
    
    func testTrialingStateProperties() {
        let state = LicenseState.trialing(daysRemaining: 10)
        XCTAssertTrue(state.isProActive)
        XCTAssertTrue(state.hasStyleCustomization)
        XCTAssertTrue(state.hasCloudSync)
        XCTAssertEqual(state.activationDelay, 0.0)
        XCTAssertNil(state.sessionLimitSeconds)
    }
    
    func testFreeStateProperties() {
        let state = LicenseState.free
        XCTAssertFalse(state.isProActive)
        XCTAssertFalse(state.hasStyleCustomization)
        XCTAssertFalse(state.hasCloudSync)
        XCTAssertEqual(state.activationDelay, 2.0)
        XCTAssertEqual(state.sessionLimitSeconds, 900.0)
    }
    
    func testLicenseStateDaysRemaining() {
        XCTAssertEqual(LicenseState.licensed.daysRemaining, nil)
        XCTAssertEqual(LicenseState.free.daysRemaining, nil)
        XCTAssertEqual(LicenseState.trialing(daysRemaining: 5).daysRemaining, 5)
    }
}
