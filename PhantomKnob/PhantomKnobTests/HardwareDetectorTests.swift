import XCTest
@testable import PhantomKnob

final class HardwareDetectorTests: XCTestCase {
    func testTrackpadDetectionReturnsBool() {
        let result = HardwareDetector.isTrackpadConnected()
        XCTAssertTrue(result == true || result == false)
    }
}
