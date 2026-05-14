import XCTest
@testable import PhantomKnobDetector

final class SensitivityConfigTests: XCTestCase {
    
    func testDefaultSensitivity() {
        let config = SensitivityConfig()
        XCTAssertEqual(config.globalDefault, 0.5, accuracy: 0.01)
    }
    
    func testSensitivityForControlType() {
        var config = SensitivityConfig()
        config.sliderSensitivity = 1.0
        
        XCTAssertEqual(config.sensitivity(for: .slider), 1.0, accuracy: 0.01)
        XCTAssertEqual(config.sensitivity(for: .progressIndicator), 0.5, accuracy: 0.01)
    }
    
    func testCodable() {
        var config = SensitivityConfig()
        config.globalDefault = 0.75
        config.sliderSensitivity = 1.2
        
        let data = try! JSONEncoder().encode(config)
        let decoded = try! JSONDecoder().decode(SensitivityConfig.self, from: data)
        
        XCTAssertEqual(decoded.globalDefault, 0.75, accuracy: 0.01)
        XCTAssertEqual(decoded.sliderSensitivity, 1.2, accuracy: 0.01)
    }
}
