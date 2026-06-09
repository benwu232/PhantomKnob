// PhantomKnob/PhantomKnobTests/RuleLibraryTests.swift
import XCTest
@testable import PhantomKnob

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

    func testDisplayNameMatchWins() {
        let displayNameRule = ControlRule(
            key: RuleKey(bundleID: "com.apple.QuickTimePlayerX", axRole: "AXSlider", displayName: "timeline"),
            translation: .arrowKeyLeftRight
        )
        let broadRule = ControlRule(
            key: RuleKey(bundleID: "com.apple.QuickTimePlayerX", axRole: "AXSlider"),
            translation: .scrollWheelVertical
        )
        
        let lib = makeLibrary(rules: [displayNameRule, broadRule])
        
        // 当查询时间轴（displayName == "timeline"）时，应该命中特定规则
        let timelineKey = RuleKey(bundleID: "com.apple.QuickTimePlayerX", axRole: "AXSlider", displayName: "timeline")
        XCTAssertEqual(lib.lookup(for: timelineKey)?.translation, .arrowKeyLeftRight)
        
        // 当查询音量（displayName == "volume"）时，应该退回到宽泛规则
        let volumeKey = RuleKey(bundleID: "com.apple.QuickTimePlayerX", axRole: "AXSlider", displayName: "volume")
        XCTAssertEqual(lib.lookup(for: volumeKey)?.translation, .scrollWheelVertical)
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

    func testCapCutRulesAreBundled() {
        let lib = RuleLibrary.shared
        lib.reload() // Make sure bundled rules are loaded
        
        let bundleIDs = [
            "com.lemon.lvoverseas",
            "com.lemon.lv",
            "com.lemon.lvediting",
            "com.lemon.jianying",
            "com.lemon.jianyingpro"
        ]
        
        for bid in bundleIDs {
            let key = RuleKey(bundleID: bid, axRole: "unknown")
            let match = lib.lookup(for: key)
            XCTAssertNotNil(match, "CapCut/Jianying rule should be bundled for \(bid)")
            XCTAssertEqual(match?.translation, .arrowKeyLeftRight)
        }
    }

    func testInvertPropertyParsing() throws {
        let jsonWithInvert = """
        {"key":{"bundleID":"com.test.app","axRole":"AXSlider","identifier":null},
          "translation":"scrollWheelVertical",
          "scaleConfig":{"fixed":1.0},
          "invert":true}
        """.data(using: .utf8)!
        
        let jsonWithoutInvert = """
        {"key":{"bundleID":"com.test.app2","axRole":"AXSlider","identifier":null},
          "translation":"scrollWheelVertical",
          "scaleConfig":{"fixed":1.0}}
        """.data(using: .utf8)!
        
        let rule1 = try JSONDecoder().decode(ControlRule.self, from: jsonWithInvert)
        XCTAssertEqual(rule1.invert, true)
        
        let rule2 = try JSONDecoder().decode(ControlRule.self, from: jsonWithoutInvert)
        XCTAssertNil(rule2.invert) // 缺失时解析为 nil，调用方使用 ?? false 处理
    }
}
