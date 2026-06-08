import XCTest
@testable import PhantomKnob

final class AccessibilityTargetTests: XCTestCase {
    
    func testControlTypeFromRole() {
        XCTAssertEqual(ControlType.fromAXRole("AXSlider"), .slider)
        XCTAssertEqual(ControlType.fromAXRole("AXProgressIndicator"), .progressIndicator)
        XCTAssertEqual(ControlType.fromAXRole("AXScrollBar"), .scrollbar)
        XCTAssertEqual(ControlType.fromAXRole("AXButton"), .unknown)
    }
    
    func testValueClamping() {
        let clamped = (150.0).clamped(to: 0...100)
        XCTAssertEqual(clamped, 100.0, accuracy: 0.01)
        
        let clamped2 = (-10.0).clamped(to: 0...100)
        XCTAssertEqual(clamped2, 0.0, accuracy: 0.01)
    }
    
    func testFormatDisplayValue() {
        XCTAssertEqual(formatDisplayValue(65, min: 0, max: 100), "65%")
        XCTAssertEqual(formatDisplayValue(3725, min: 0, max: 7200), "01:02:05.00")
        XCTAssertEqual(formatDisplayValue(50, min: 0, max: 200), "00:50.00")
    }
}
