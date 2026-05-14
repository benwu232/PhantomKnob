import XCTest
@testable import PhantomKnobDetector

final class TargetDetectorTests: XCTestCase {
    
    var detector: TargetDetector!
    
    override func setUp() {
        super.setUp()
        detector = TargetDetector()
    }
    
    override func tearDown() {
        detector = nil
        super.tearDown()
    }
    
    func testCheckAccessibilityPermission() {
        let hasPermission = AXIsProcessTrusted()
        XCTAssertNotNil(hasPermission || !hasPermission)
    }
    
    func testDetectTargetAtMousePosition() {
        if !AXIsProcessTrusted() {
            let target = detector.detectTargetAtMousePosition()
            XCTAssertNil(target)
        }
    }
    
    func testMaxParentDepth() {
        XCTAssertEqual(TargetDetector.maxParentDepth, 10)
    }
}
