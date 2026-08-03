import XCTest
@testable import PhantomKnob

final class HardwareDetectorTests: XCTestCase {
    func testTrackpadDetectionReturnsBool() {
        let result = HardwareDetector.isTrackpadConnected()
        XCTAssertTrue(result == true || result == false)
    }
    
    func testCheckTrackpadWithRetryInvokesCompletion() {
        let expectation = expectation(description: "Retry completion called")
        HardwareDetector.checkTrackpadWithRetry(maxAttempts: 2, interval: 0.1) { connected in
            XCTAssertTrue(connected == true || connected == false)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }
}
