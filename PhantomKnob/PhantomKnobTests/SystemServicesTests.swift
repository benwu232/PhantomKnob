import XCTest
@testable import PhantomKnob

class SystemServicesTests: XCTestCase {
    func testAudioControlService() {
        let service = AudioControlService()
        if let vol = service.getVolume() {
            XCTAssert(vol >= 0.0 && vol <= 1.0, "Volume scalar should be between 0.0 and 1.0")
            let success = service.setVolume(vol)
            XCTAssertTrue(success, "Should succeed in setting current volume")
        }
    }
    
    func testDisplayBrightnessService() {
        let service = DisplayBrightnessService()
        // Some systems/CI might not support brightness adjustments (e.g. headless machines)
        // If it does support, verify the range and that setting works.
        if let br = service.getBrightness() {
            XCTAssert(br >= 0.0 && br <= 1.0, "Brightness should be between 0.0 and 1.0")
            let success = service.setBrightness(br)
            XCTAssertTrue(success, "Should succeed in setting current brightness")
        }
    }
    
    func testKeyboardBacklightService() {
        let service = KeyboardBacklightService()
        // Verify it doesn't crash even if the device doesn't have a backlit keyboard.
        if let back = service.getBrightness() {
            XCTAssert(back >= 0.0 && back <= 1.0, "Keyboard backlight should be between 0.0 and 1.0")
            let success = service.setBrightness(back)
            XCTAssertTrue(success, "Should succeed in setting current keyboard backlight")
        }
    }
}
