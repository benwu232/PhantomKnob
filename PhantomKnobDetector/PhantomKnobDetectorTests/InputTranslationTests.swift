// PhantomKnobDetector/PhantomKnobDetectorTests/InputTranslationTests.swift
import XCTest
@testable import PhantomKnobDetector

final class InputTranslationTests: XCTestCase {

    // MARK: - RuleKey matching

    func testRuleKeyExactMatch() {
        let key = RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: "timeline")
        let candidate = RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: "timeline")
        XCTAssertTrue(key.matches(candidate))
    }

    func testRuleKeyNilIdentifierMatchesAll() {
        let broadRule = RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: nil)
        let specific  = RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: "timeline")
        XCTAssertTrue(broadRule.matches(specific))
    }

    func testRuleKeyMismatch() {
        let a = RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: nil)
        let b = RuleKey(bundleID: "com.apple.QuickTime", axRole: "AXSlider", identifier: nil)
        XCTAssertFalse(a.matches(b))
    }

    // MARK: - ScaleConfig

    func testFixedScaleIgnoresRadius() {
        let config = ScaleConfig.fixed(2.5)
        XCTAssertEqual(config.resolve(radius: 0.0), 2.5)
        XCTAssertEqual(config.resolve(radius: 0.9), 2.5)
    }

    func testDefaultScaleIsOne() {
        let rule = ControlRule(
            key: RuleKey(bundleID: "x", axRole: "AXSlider", identifier: nil),
            translation: .axWrite
        )
        XCTAssertEqual(rule.scaleConfig.resolve(), 1.0)
    }

    // MARK: - DetectedTarget ruleKey

    func testDetectedTargetRuleKey() {
        let target = DetectedTarget(
            bundleID: "com.apple.FinalCut",
            axRole: "AXSlider",
            identifier: "timeline",
            displayName: "Playhead",
            element: nil
        )
        XCTAssertEqual(target.ruleKey.bundleID, "com.apple.FinalCut")
        XCTAssertEqual(target.ruleKey.axRole, "AXSlider")
        XCTAssertEqual(target.ruleKey.identifier, "timeline")
    }
}

// MARK: - ArrowKeyTranslator accumulator

final class ArrowKeyTranslatorTests: XCTestCase {

    func testAccumulatorHoldsSmallDeltas() {
        // scale=1, 每次 0.3，需要累积 4 次（1.2）才发 1 个按键
        // 本测试只验证 accumulator 不崩溃，实际按键无法在单元测试中验证
        let t = ArrowKeyTranslator(axis: .upDown, scale: 1.0)
        // 不超过 1.0，不应发送按键（无法断言无副作用，只验证不 crash）
        t.apply(units: 0.3, direction: .clockwise)
        t.apply(units: 0.3, direction: .clockwise)
        t.apply(units: 0.3, direction: .clockwise)
        // 第三次累积 = 0.9，仍不足 1.0
        XCTAssertNil(t.displayValue)
    }

    func testScrollWheelDisplayValueIsNil() {
        let t = ScrollWheelTranslator(axis: .vertical, scale: 1.0)
        XCTAssertNil(t.displayValue)
    }
}

