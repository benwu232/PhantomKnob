import XCTest
@testable import PhantomKnobDetector

final class ControlTests: XCTestCase {
    
    func testInitialValue() {
        let target = DemoSliderTarget()
        XCTAssertEqual(target.value, 50.0)
    }
    
    func testMinValue() {
        let target = DemoSliderTarget()
        XCTAssertEqual(target.minValue, 0.0)
    }
    
    func testMaxValue() {
        let target = DemoSliderTarget()
        XCTAssertEqual(target.maxValue, 100.0)
    }
    
    func testIncreaseValue() {
        let target = DemoSliderTarget()
        let newValue = target.applyDelta(10)
        XCTAssertEqual(newValue, 55.0)
    }
    
    func testDecreaseValue() {
        let target = DemoSliderTarget()
        let newValue = target.applyDelta(-10)
        XCTAssertEqual(newValue, 45.0)
    }
    
    func testClampToUpper() {
        let target = DemoSliderTarget()
        target.value = 99.0
        let newValue = target.applyDelta(10)
        XCTAssertEqual(newValue, 100.0)
    }
    
    func testClampToLower() {
        let target = DemoSliderTarget()
        target.value = 1.0
        let newValue = target.applyDelta(-10)
        XCTAssertEqual(newValue, 0.0)
    }
}
