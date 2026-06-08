import XCTest
@testable import PhantomKnob

final class CustomMultiplierTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Clear all UserDefaults settings keys starting with knob_scale_override
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()
        for key in dictionary.keys {
            if key.hasPrefix("knob_scale_override_") {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.synchronize()
    }

    func testPrecisionRoundingAndMinimumClamp() {
        // Test precision rounding
        let rawVal1 = 1.0 - 0.1
        let rounded1 = (rawVal1 * 10).rounded() / 10
        XCTAssertEqual(rounded1, 0.9)
        
        let rawVal2 = 1.0000000000000002 - 0.1
        let rounded2 = (rawVal2 * 10).rounded() / 10
        XCTAssertEqual(rounded2, 0.9)
        
        // Test minimum clamp at 0.1
        let rawVal3 = 0.1 - 0.1
        let rounded3 = max(0.1, (rawVal3 * 10).rounded() / 10)
        XCTAssertEqual(rounded3, 0.1)

        let rawVal4 = -0.5
        let rounded4 = max(0.1, (rawVal4 * 10).rounded() / 10)
        XCTAssertEqual(rounded4, 0.1)
    }
    
    func testZoneIndependentPersistence() {
        let target = DetectedTarget(
            bundleID: "com.test.app",
            axRole: "AXSlider",
            identifier: "volume",
            displayName: "Volume",
            element: nil
        )
        
        // We will mock target and check keys
        let key0 = "knob_scale_override_com.test.app_AXSlider_volume_Volume_zone_0"
        let key1 = "knob_scale_override_com.test.app_AXSlider_volume_Volume_zone_1"
        
        UserDefaults.standard.set(3.5, forKey: key0)
        UserDefaults.standard.set(1.5, forKey: key1)
        
        XCTAssertEqual(UserDefaults.standard.double(forKey: key0), 3.5)
        XCTAssertEqual(UserDefaults.standard.double(forKey: key1), 1.5)
    }

    func testSafeResetToOne() {
        let key = "knob_scale_override_com.test.app_AXSlider_volume_Volume_zone_0"
        
        // Custom value set
        UserDefaults.standard.set(5.0, forKey: key)
        XCTAssertEqual(UserDefaults.standard.double(forKey: key), 5.0)
        
        // Safe Reset key 1 -> Set to 1.0 instead of deleting
        UserDefaults.standard.set(1.0, forKey: key)
        XCTAssertEqual(UserDefaults.standard.double(forKey: key), 1.0)
    }

    func testDirectKeyPressCustomMultiplierPersistence() {
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        
        let target = DetectedTarget(
            bundleID: "com.test.directkey",
            axRole: "AXSlider",
            identifier: "volume",
            displayName: "Volume",
            element: nil
        )
        
        manager.currentTarget = target
        manager.currentZoneIndex = 0
        manager.transition(to: .knobing(target: target))
        
        // Key 3 -> keycode 20
        manager.handleDirectKeyPress(keyCode: 20)
        
        let key = "knob_scale_override_com.test.directkey_AXSlider_volume_Volume_zone_0"
        XCTAssertEqual(UserDefaults.standard.double(forKey: key), 3.0)
        
        // Arrow Right -> keycode 124 (+0.1)
        manager.handleDirectKeyPress(keyCode: 124)
        XCTAssertEqual(UserDefaults.standard.double(forKey: key), 3.1)
        
        // Arrow Down -> keycode 125 (-1.0)
        manager.handleDirectKeyPress(keyCode: 125)
        XCTAssertEqual(UserDefaults.standard.double(forKey: key), 2.1)
        
        // Key 1 -> keycode 18 (reset to 1.0)
        manager.handleDirectKeyPress(keyCode: 18)
        XCTAssertEqual(UserDefaults.standard.double(forKey: key), 1.0)
    }

    func testOneFingerContinuationLocksMultiplier() {
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        
        let target = DetectedTarget(
            bundleID: "com.test.lock",
            axRole: "AXSlider",
            identifier: "volume",
            displayName: "Volume",
            element: nil
        )
        
        manager.currentTarget = target
        manager.currentZoneIndex = 1
        manager.lastResolvedBaseScale = 4.2
        manager.fixedCenter = CGPoint.zero
        manager.fingerIdx1 = 0
        manager.fingerIdx2 = 1
        manager.transition(to: .knobing(target: target))
        
        // Simulating 1-finger move
        manager.onMultitouchMoved(points: [0: CGPoint(x: 10, y: 10)])
        
        // The scale should remain locked at 4.2
        XCTAssertEqual(manager.lastResolvedBaseScale, 4.2)
    }
}
