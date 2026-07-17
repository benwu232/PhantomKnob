// PhantomKnob/PhantomKnobTests/GestureConflictTests.swift
import XCTest
@testable import PhantomKnob

final class GestureConflictTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        KnobCustomizer.shared.reload()
        super.tearDown()
    }
    
    func testIsAdjustableKnobCustomizerMatch() {
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        
        let knob = Knob(
            key: KnobKey(bundleID: "com.test.adjustable", axRole: "unknown", identifier: nil, displayName: nil),
            translation: .scrollWheelVertical
        )
        KnobCustomizer.shared.injectKnobsForTesting([knob])
        
        let target = DetectedTarget(
            bundleID: "com.test.adjustable",
            axRole: "unknown",
            identifier: nil,
            displayName: "Test",
            element: nil,
            parentChain: []
        )
        
        XCTAssertTrue(manager.isAdjustable(target: target))
    }
    
    func testIsAdjustableNoMatch() {
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        
        KnobCustomizer.shared.injectKnobsForTesting([])
        
        let target = DetectedTarget(
            bundleID: "com.test.nonadjustable",
            axRole: "unknown",
            identifier: nil,
            displayName: "Test",
            element: nil,
            parentChain: []
        )
        
        XCTAssertFalse(manager.isAdjustable(target: target))
    }
    
    func testIsInterceptingGesturesBeganAndEnded() {
        let mockDetector = MockTargetDetector()
        let target = DetectedTarget(
            bundleID: "com.test.intercepting",
            axRole: "AXSlider",
            identifier: nil,
            displayName: "TestSlider",
            element: nil,
            parentChain: []
        )
        mockDetector.mockTarget = target
        
        let manager = KnobStateManager(
            targetDetector: mockDetector,
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        
        let knob = Knob(
            key: KnobKey(bundleID: "com.test.intercepting", axRole: "AXSlider", displayName: "TestSlider"),
            translation: .scrollWheelVertical
        )
        KnobCustomizer.shared.injectKnobsForTesting([knob])
        
        // 1. 模拟激活状态下的双指触摸开始
        manager.transition(to: .activated)
        XCTAssertFalse(manager.isInterceptingGestures)
        
        manager.onMultitouchBegan(points: [0: CGPoint.zero, 1: CGPoint(x: 10, y: 10)])
        XCTAssertTrue(manager.isInterceptingGestures)
        
        // 2. 模拟触摸结束
        manager.onMultitouchEnded()
        XCTAssertFalse(manager.isInterceptingGestures)
    }
}

class MockTargetDetector: TargetDetector {
    var mockTarget: DetectedTarget?
    
    override func detectTargetAtMousePosition() -> DetectedTarget? {
        return mockTarget
    }
}
