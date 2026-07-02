import XCTest
@testable import PhantomKnob

class KnobStateManagerFeatureGateTests: XCTestCase {
    var mockStorage: [String: String] = [:]
    var licenseManager: LicenseManager!
    var featureGate: FeatureGate!
    var manager: KnobStateManager!
    
    override func setUp() {
        super.setUp()
        mockStorage = [:]
        
        // Force Free state by expiring trial
        let formatter = ISO8601DateFormatter()
        let startDate = Date().addingTimeInterval(-20 * 24 * 60 * 60)
        mockStorage["trialStartDate"] = formatter.string(from: startDate)
        
        licenseManager = LicenseManager(
            currentDateProvider: { Date() },
            storageRead: { key in self.mockStorage[key] },
            storageWrite: { _, _ in }
        )
    }
    
    func testActivationDelayForFreeLicense() {
        // We override activationDelay to 0.1s for fast test execution
        class TestFeatureGate: FeatureGate {
            override var activationDelay: Double { return 0.1 }
            override var sessionLimitSeconds: Double? { return nil }
        }
        
        let gate = TestFeatureGate(licenseManager: licenseManager)
        let statusBar = StatusBarController()
        
        manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: statusBar,
            touchHandler: GlobalTouchHandler(),
            featureGate: gate
        )
        manager.isProcessTrusted = { true }
        
        XCTAssertEqual(manager.state, .inactive)
        
        // Trigger activation
        manager.toggleMode()
        
        // Should not be activated immediately because of the delay
        XCTAssertEqual(manager.state, .inactive)
        
        // Wait 0.15 seconds for the delay to complete
        let expectation = XCTestExpectation(description: "Activation completes after delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            XCTAssertEqual(self.manager.state, .activated)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testActivationCancelledDuringDelay() {
        class TestFeatureGate: FeatureGate {
            override var activationDelay: Double { return 0.2 }
            override var sessionLimitSeconds: Double? { return nil }
        }
        
        let gate = TestFeatureGate(licenseManager: licenseManager)
        let statusBar = StatusBarController()
        
        manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: statusBar,
            touchHandler: GlobalTouchHandler(),
            featureGate: gate
        )
        manager.isProcessTrusted = { true }
        
        manager.toggleMode()
        XCTAssertEqual(manager.state, .inactive)
        
        // Cancel activation by toggling again
        manager.toggleMode()
        
        // Wait 0.25 seconds to make sure it doesn't activate later
        let expectation = XCTestExpectation(description: "Activation remains cancelled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            XCTAssertEqual(self.manager.state, .inactive)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSessionLimitAutoDeactivation() {
        class TestFeatureGate: FeatureGate {
            override var activationDelay: Double { return 0.0 }
            override var sessionLimitSeconds: Double? { return 0.1 } // 0.1s limit
        }
        
        let gate = TestFeatureGate(licenseManager: licenseManager)
        let statusBar = StatusBarController()
        
        manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: statusBar,
            touchHandler: GlobalTouchHandler(),
            featureGate: gate
        )
        manager.isProcessTrusted = { true }
        
        XCTAssertEqual(manager.state, .inactive)
        
        // Trigger activation (immediate, since delay is 0.0)
        manager.toggleMode()
        XCTAssertEqual(manager.state, .activated)
        
        // Wait 0.15s for the session to expire
        let expectation = XCTestExpectation(description: "Session automatically deactivates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            XCTAssertEqual(self.manager.state, .inactive)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}
