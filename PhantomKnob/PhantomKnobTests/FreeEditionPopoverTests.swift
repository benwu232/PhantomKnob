import XCTest
@testable import PhantomKnob

final class FreeEditionPopoverTests: XCTestCase {
    func testModeEquality() {
        XCTAssertEqual(FreePopoverMode.activating(secondsRemaining: 2.0), FreePopoverMode.activating(secondsRemaining: 2.0))
        XCTAssertNotEqual(FreePopoverMode.activating(secondsRemaining: 2.0), FreePopoverMode.activating(secondsRemaining: 1.0))
        XCTAssertNotEqual(FreePopoverMode.activating(secondsRemaining: 2.0), FreePopoverMode.sessionExpired)
    }
}
