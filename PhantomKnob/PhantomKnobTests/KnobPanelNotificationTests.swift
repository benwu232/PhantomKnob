// PhantomKnob/PhantomKnobTests/KnobPanelNotificationTests.swift
import XCTest
@testable import PhantomKnob

final class KnobPanelNotificationTests: XCTestCase {
    
    func testPanelShowAndHideTransitions() {
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        manager.isProcessTrusted = { true }
        
        // Initially, the state should be inactive
        XCTAssertEqual(manager.state, .inactive)
        
        // Post did show notification
        NotificationCenter.default.post(name: NSNotification.Name("KnobPanelDidShow"), object: nil)
        
        // State should transition to activated
        XCTAssertEqual(manager.state, .activated)
        
        // Post did hide notification
        NotificationCenter.default.post(name: NSNotification.Name("KnobPanelDidHide"), object: nil)
        
        // State should transition back to inactive
        XCTAssertEqual(manager.state, .inactive)
    }
    
    func testPanelShowWhenAlreadyActiveDoesNotDeactivateOnHide() {
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        manager.isProcessTrusted = { true }
        
        // Manually activate
        manager.toggleMode()
        XCTAssertEqual(manager.state, .activated)
        
        // Post did show notification
        NotificationCenter.default.post(name: NSNotification.Name("KnobPanelDidShow"), object: nil)
        
        // State should remain activated
        XCTAssertEqual(manager.state, .activated)
        
        // Post did hide notification
        NotificationCenter.default.post(name: NSNotification.Name("KnobPanelDidHide"), object: nil)
        
        // State should remain activated (since it was already activated before the panel opened)
        XCTAssertEqual(manager.state, .activated)
    }
}
