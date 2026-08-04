import XCTest
@testable import PhantomKnob

final class FeedbackWindowControllerTests: XCTestCase {
    func testFeedbackWindowControllerShowAndHide() {
        let controller = FeedbackWindowController.shared
        XCTAssertFalse(controller.isVisible)
        
        controller.show()
        XCTAssertTrue(controller.isVisible)
        
        controller.hide()
        XCTAssertFalse(controller.isVisible)
    }
}
