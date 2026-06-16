// PhantomKnob/PhantomKnobTests/GestureConflictTests.swift
import XCTest
@testable import PhantomKnob

final class GestureConflictTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        RuleLibrary.shared.reload()
        super.tearDown()
    }
    
    func testIsAdjustableRuleLibraryMatch() {
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        
        let rule = ControlRule(
            key: RuleKey(bundleID: "com.test.adjustable", axRole: "unknown", identifier: nil, displayName: nil),
            translation: .scrollWheelVertical
        )
        RuleLibrary.shared.injectRulesForTesting([rule])
        
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
        
        RuleLibrary.shared.injectRulesForTesting([])
        
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
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        
        // 模拟当前前台 App Bundle ID 的规则命中
        let frontmostID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "com.apple.dt.xctest.tool"
        let rule = ControlRule(
            key: RuleKey(bundleID: frontmostID, axRole: "unknown", displayName: ""),
            translation: .scrollWheelVertical
        )
        RuleLibrary.shared.injectRulesForTesting([rule])
        
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
