import XCTest
@testable import PhantomKnob

class KnobActiveStatePersistenceTests: XCTestCase {
    var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: "KnobActiveStatePersistenceTests_\(UUID().uuidString)")!
        UserDefaults.app = testDefaults
    }

    override func tearDown() {
        if let defaults = testDefaults {
            defaults.removePersistentDomain(forName: defaults.description)
        }
        testDefaults = nil
        UserDefaults.app = .standard
        super.tearDown()
    }

    func testUserDefaultsDefaultValues() {
        XCTAssertTrue(UserDefaults.app.restoreActiveStateOnStartup)
        XCTAssertFalse(UserDefaults.app.lastKnobActiveState)
    }

    func testUserDefaultsPropertyMutations() {
        UserDefaults.app.restoreActiveStateOnStartup = false
        XCTAssertFalse(UserDefaults.app.restoreActiveStateOnStartup)

        UserDefaults.app.lastKnobActiveState = true
        XCTAssertTrue(UserDefaults.app.lastKnobActiveState)
    }

    func testStateTransitionUpdatesLastKnobActiveState() {
        class TestFeatureGate: FeatureGate {
            override var activationDelay: Double { return 0.0 }
            override var sessionLimitSeconds: Double? { return nil }
        }

        let statusBar = StatusBarController()
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: statusBar,
            touchHandler: GlobalTouchHandler(),
            featureGate: TestFeatureGate()
        )
        manager.isProcessTrusted = { true }

        XCTAssertFalse(UserDefaults.app.lastKnobActiveState)

        // 切换到 activated 状态
        manager.toggleMode()
        XCTAssertEqual(manager.state, .activated)
        XCTAssertTrue(UserDefaults.app.lastKnobActiveState)

        // 切换到 inactive 状态
        manager.toggleMode()
        XCTAssertEqual(manager.state, .inactive)
        XCTAssertFalse(UserDefaults.app.lastKnobActiveState)
    }

    func testStartRestoresActivatedStateWhenEnabled() {
        class TestFeatureGate: FeatureGate {
            override var activationDelay: Double { return 0.0 }
            override var sessionLimitSeconds: Double? { return nil }
        }

        UserDefaults.app.restoreActiveStateOnStartup = true
        UserDefaults.app.lastKnobActiveState = true

        let statusBar = StatusBarController()
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: statusBar,
            touchHandler: GlobalTouchHandler(),
            featureGate: TestFeatureGate()
        )
        manager.isProcessTrusted = { true }

        manager.start()
        XCTAssertEqual(manager.state, .activated)
    }

    func testStartDoesNotRestoreWhenSettingDisabled() {
        class TestFeatureGate: FeatureGate {
            override var activationDelay: Double { return 0.0 }
            override var sessionLimitSeconds: Double? { return nil }
        }

        UserDefaults.app.restoreActiveStateOnStartup = false
        UserDefaults.app.lastKnobActiveState = true

        let statusBar = StatusBarController()
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: statusBar,
            touchHandler: GlobalTouchHandler(),
            featureGate: TestFeatureGate()
        )
        manager.isProcessTrusted = { true }

        manager.start()
        XCTAssertEqual(manager.state, .inactive)
    }

    func testStartDoesNotRestoreWhenNotTrusted() {
        class TestFeatureGate: FeatureGate {
            override var activationDelay: Double { return 0.0 }
            override var sessionLimitSeconds: Double? { return nil }
        }

        UserDefaults.app.restoreActiveStateOnStartup = true
        UserDefaults.app.lastKnobActiveState = true

        let statusBar = StatusBarController()
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: statusBar,
            touchHandler: GlobalTouchHandler(),
            featureGate: TestFeatureGate()
        )
        manager.isProcessTrusted = { false }

        manager.start()
        XCTAssertEqual(manager.state, .inactive)
    }
}
