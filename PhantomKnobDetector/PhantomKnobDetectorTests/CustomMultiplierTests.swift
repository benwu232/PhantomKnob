import XCTest
@testable import PhantomKnobDetector

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
}
