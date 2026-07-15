import XCTest
@testable import PhantomKnob

class KnobPanelWindowControllerTests: XCTestCase {
    private var openControllers: [KnobPanelWindowController] = []
    
    override func tearDown() {
        for controller in openControllers {
            controller.hide()
        }
        openControllers.removeAll()
        super.tearDown()
    }
    
    func testWindowToggle() {
        let controller = KnobPanelWindowController()
        openControllers.append(controller)
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
    
    func testWindowKeyboardFocusSwitching() {
        let controller = KnobPanelWindowController.shared
        controller.show()
        
        let viewModel = ControlPanelViewModel.shared
        viewModel.focusedVariable = .volume
        
        if let window = controller.window {
            let rightEvent = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: 124 // Right arrow
            )
            if let ev = rightEvent {
                window.keyDown(with: ev)
                XCTAssertEqual(viewModel.focusedVariable, .brightness)
            }
            
            let leftEvent = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: 123 // Left arrow
            )
            if let ev = leftEvent {
                window.keyDown(with: ev)
                XCTAssertEqual(viewModel.focusedVariable, .volume)
            }
        }
        controller.hide()
    }
}
