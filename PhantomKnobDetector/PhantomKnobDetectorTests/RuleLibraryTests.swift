// PhantomKnobDetector/PhantomKnobDetectorTests/RuleLibraryTests.swift
import XCTest
@testable import PhantomKnobDetector

final class RuleLibraryTests: XCTestCase {

    private func makeLibrary(rules: [ControlRule]) -> RuleLibrary {
        let lib = RuleLibrary()
        // 直接注入测试规则（绕过文件加载）
        lib.injectRulesForTesting(rules)
        return lib
    }

    func testExactMatchWins() {
        let exactRule = ControlRule(
            key: RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: "timeline"),
            translation: .arrowKeyLeftRight,
            scaleConfig: .fixed(2.0)
        )
        let broadRule = ControlRule(
            key: RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: nil),
            translation: .scrollWheelVertical
        )
        let lib = makeLibrary(rules: [exactRule, broadRule])
        let key = RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: "timeline")
        XCTAssertEqual(lib.lookup(for: key)?.translation, .arrowKeyLeftRight)
    }

    func testBroadRuleFallsBack() {
        let broadRule = ControlRule(
            key: RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: nil),
            translation: .scrollWheelVertical
        )
        let lib = makeLibrary(rules: [broadRule])
        let key = RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: "unknownControl")
        XCTAssertEqual(lib.lookup(for: key)?.translation, .scrollWheelVertical)
    }

    func testNoMatchReturnsNil() {
        let lib = makeLibrary(rules: [])
        let key = RuleKey(bundleID: "com.unknown.app", axRole: "AXSlider", identifier: nil)
        XCTAssertNil(lib.lookup(for: key))
    }

    func testScaleConfigParsing() throws {
        let json = """
        [{"key":{"bundleID":"x","axRole":"AXSlider","identifier":null},
          "translation":"scrollWheelVertical",
          "scaleConfig":{"fixed":8.0}}]
        """.data(using: .utf8)!
        let rules = try JSONDecoder().decode([ControlRule].self, from: json)
        XCTAssertEqual(rules.first?.scaleConfig.resolve(), 8.0)
    }
}
