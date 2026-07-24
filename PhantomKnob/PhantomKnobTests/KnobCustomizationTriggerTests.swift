import XCTest
import AppKit
@testable import PhantomKnob

final class KnobCustomizationTriggerTests: XCTestCase {
    override func tearDown() {
        CustomizerHUDWindowController.shared.hide()
        super.tearDown()
    }

    func testCKeyTriggerCustomizationDuringKnobing() throws {
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        
        let target = DetectedTarget(
            bundleID: "com.test.customization",
            axRole: "AXSlider",
            identifier: "volume",
            displayName: "Volume",
            element: nil,
            parentChain: []
        )
        
        manager.currentTarget = target
        manager.transition(to: .knobing(target: target))
        
        let source = CGEventSource(stateID: .privateState)
        let event = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)!
        
        let swallowed = manager.handleEventTap(proxy: nil, type: .keyDown, event: event)
        
        // 断言事件应当被吞掉
        XCTAssertTrue(swallowed, "按 c 键应该返回 true 被吞掉")
        
        // enterCustomization 会在 DispatchQueue.main.async 执行，需要等待
        let expectation = XCTestExpectation(description: "Enter customization on main thread")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertEqual(manager.state, .customizing, "状态应当变为 customizing")
        XCTAssertTrue(CustomizerHUDWindowController.shared.isVisible, "定制面板应当是显示状态")
    }
}
