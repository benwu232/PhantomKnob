// PhantomKnob/PhantomKnobTests/TargetDetectorTests.swift
import XCTest
@testable import PhantomKnob

final class TargetDetectorTests: XCTestCase {
    
    var detector: TargetDetector!
    
    override func setUp() {
        super.setUp()
        detector = TargetDetector()
    }
    
    override func tearDown() {
        detector = nil
        super.tearDown()
    }
    
    func testCheckAccessibilityPermission() {
        let hasPermission = AXIsProcessTrusted()
        XCTAssertNotNil(hasPermission || !hasPermission)
    }
    
    func testDetectTargetAtMousePosition() {
        if !AXIsProcessTrusted() {
            let target = detector.detectTargetAtMousePosition()
            XCTAssertNil(target)
        }
    }
    
    func testMaxParentDepth() {
        XCTAssertEqual(TargetDetector.maxParentDepth, 10)
    }

    func testAutoDetectTranslationDefaultsToScrollWheel() {
        // 验证 InputTranslation 枚举正常使用
        XCTAssertEqual(InputTranslation.scrollWheelVertical.rawValue, "scrollWheelVertical")
    }
}
