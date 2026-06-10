import XCTest
@testable import PhantomKnob

class KnobPanelWindowControllerTests: XCTestCase {
    func testWindowToggle() {
        let controller = KnobPanelWindowController.shared
        XCTAssertFalse(controller.isVisible)
        
        let expectation = XCTestExpectation(description: "Show and hide window")
        DispatchQueue.main.async {
            controller.show()
            XCTAssertTrue(controller.isVisible)
            
            controller.hide()
            XCTAssertFalse(controller.isVisible)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }
}
