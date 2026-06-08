// PhantomKnobDetector/PhantomKnobDetectorTests/GestureConflictTests.swift
import XCTest
@testable import PhantomKnobDetector

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
            element: nil
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
            element: nil
        )
        
        XCTAssertFalse(manager.isAdjustable(target: target))
    }
}
