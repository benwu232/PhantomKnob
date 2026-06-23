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
        XCTAssertEqual(rules.first?.scaleConfig?.resolve(), 8.0)
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

    func testDaVinciResolveRuleIsLoaded() {
        let lib = RuleLibrary.shared
        lib.reload()
        
        let key = RuleKey(bundleID: "com.blackmagic-design.DaVinciResolve", axRole: "unknown")
        let rule = lib.lookup(for: key)
        
        XCTAssertNotNil(rule, "Resolve rule must exist")
        XCTAssertEqual(rule?.translation, .scrollWheelVertical)
        XCTAssertEqual(rule?.invert, true)
    }

    func testParentChainSubsequenceMatching() {
        let ruleChain = [
            ParentNodeInfo(axRole: "AXGroup", displayName: "对比度"),
            ParentNodeInfo(axRole: "AXGroup", displayName: "调节")
        ]
        
        let targetChain1 = [
            ParentNodeInfo(axRole: "AXGroup", displayName: "对比度"),
            ParentNodeInfo(axRole: "AXGroup", displayName: "调节"),
            ParentNodeInfo(axRole: "AXWindow", displayName: nil)
        ]
        
        let targetChain2 = [
            ParentNodeInfo(axRole: "AXGroup", displayName: "饱和度"),
            ParentNodeInfo(axRole: "AXGroup", displayName: "调节"),
            ParentNodeInfo(axRole: "AXWindow", displayName: nil)
        ]
        
        XCTAssertTrue(RuleLibrary.matchParentChain(ruleChain: ruleChain, targetChain: targetChain1))
        XCTAssertFalse(RuleLibrary.matchParentChain(ruleChain: ruleChain, targetChain: targetChain2))
    }
    
    func testLookupPrioritizesParentChainConstraints() {
        let specRule = ControlRule(
            key: RuleKey(bundleID: "com.test.app", axRole: "AXStaticText", parentChain: [ParentNodeInfo(axRole: "AXGroup", displayName: "对比度")]),
            translation: .arrowKeyUpDown
        )
        
        let broadRule = ControlRule(
            key: RuleKey(bundleID: "com.test.app", axRole: "AXStaticText"),
            translation: .scrollWheelVertical
        )
        
        let lib = makeLibrary(rules: [specRule, broadRule])
        
        let keyWithMatchingParent = RuleKey(
            bundleID: "com.test.app",
            axRole: "AXStaticText",
            parentChain: [ParentNodeInfo(axRole: "AXGroup", displayName: "对比度"), ParentNodeInfo(axRole: "AXWindow", displayName: nil)]
        )
        
        let keyWithNonMatchingParent = RuleKey(
            bundleID: "com.test.app",
            axRole: "AXStaticText",
            parentChain: [ParentNodeInfo(axRole: "AXGroup", displayName: "饱和度")]
        )
        
        XCTAssertEqual(lib.lookup(for: keyWithMatchingParent)?.translation, .arrowKeyUpDown)
        XCTAssertEqual(lib.lookup(for: keyWithNonMatchingParent)?.translation, .scrollWheelVertical)
    }
    
    func testDaVinciResolveWindowModeExtraction() {
        // 1. 验证模式提取
        XCTAssertEqual(TargetDetector.extractResolvePageMode(from: "DaVinci Resolve - MyProject - Color"), "Color")
        XCTAssertEqual(TargetDetector.extractResolvePageMode(from: "DaVinci Resolve - MyProject - Cut"), "Cut")
        XCTAssertEqual(TargetDetector.extractResolvePageMode(from: "DaVinci Resolve - MyProject - Edit"), "Edit")
        XCTAssertNil(TargetDetector.extractResolvePageMode(from: "DaVinci Resolve - MyProject"))
        XCTAssertNil(TargetDetector.extractResolvePageMode(from: "Safari - DaVinci Resolve - Color"))
        
        // 2. 验证根据 parentChain 分流匹配
        let colorRule = ControlRule(
            key: RuleKey(bundleID: "com.blackmagic-design.DaVinciResolve", axRole: "unknown", parentChain: [ParentNodeInfo(axRole: "AXWindow", displayName: "Color")]),
            translation: .scrollWheelVertical,
            invert: true
        )
        let cutRule = ControlRule(
            key: RuleKey(bundleID: "com.blackmagic-design.DaVinciResolve", axRole: "unknown", parentChain: [ParentNodeInfo(axRole: "AXWindow", displayName: "Cut")]),
            translation: .scrollWheelHorizontal,
            invert: false
        )
        let genericRule = ControlRule(
            key: RuleKey(bundleID: "com.blackmagic-design.DaVinciResolve", axRole: "unknown"),
            translation: .swipeVertical
        )
        
        let lib = makeLibrary(rules: [colorRule, cutRule, genericRule])
        
        let colorKey = RuleKey(bundleID: "com.blackmagic-design.DaVinciResolve", axRole: "unknown", parentChain: [ParentNodeInfo(axRole: "AXWindow", displayName: "Color")])
        let cutKey = RuleKey(bundleID: "com.blackmagic-design.DaVinciResolve", axRole: "unknown", parentChain: [ParentNodeInfo(axRole: "AXWindow", displayName: "Cut")])
        let otherKey = RuleKey(bundleID: "com.blackmagic-design.DaVinciResolve", axRole: "unknown", parentChain: [ParentNodeInfo(axRole: "AXWindow", displayName: "Fusion")])
        
        XCTAssertEqual(lib.lookup(for: colorKey)?.translation, .scrollWheelVertical)
        XCTAssertEqual(lib.lookup(for: colorKey)?.invert, true)
        
        XCTAssertEqual(lib.lookup(for: cutKey)?.translation, .scrollWheelHorizontal)
        XCTAssertEqual(lib.lookup(for: cutKey)?.invert, false)
        
        XCTAssertEqual(lib.lookup(for: otherKey)?.translation, .swipeVertical)
    }
    
    func testDefaultMyKnobsInitialization() throws {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let rulesURL = appSupport.appendingPathComponent("PhantomKnob/my_knobs.json")
        let backupURL = appSupport.appendingPathComponent("PhantomKnob/my_knobs.json.test_bak")
        
        // Backup
        if FileManager.default.fileExists(atPath: rulesURL.path) {
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.copyItem(at: rulesURL, to: backupURL)
            try? FileManager.default.removeItem(at: rulesURL)
        }
        
        defer {
            // Restore
            try? FileManager.default.removeItem(at: rulesURL)
            if FileManager.default.fileExists(atPath: backupURL.path) {
                try? FileManager.default.copyItem(at: backupURL, to: rulesURL)
                try? FileManager.default.removeItem(at: backupURL)
            }
            RuleLibrary.shared.reload()
        }
        
        // Ensure the file is deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: rulesURL.path))
        
        // Triggers reloading and creation of default my_knobs
        let lib = RuleLibrary()
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: rulesURL.path))
        
        // Verify we can lookup default my_knobs rules
        let jianyingKey = RuleKey(bundleID: "com.lemon.jianyingpro", axRole: "AXSlider", displayName: "Timeline")
        let match = lib.lookup(for: jianyingKey)
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.configType, .double)
        
        let davinciKey = RuleKey(bundleID: "com.blackmagic-design.DaVinciResolve", axRole: "AXSlider", displayName: "ColorWheel")
        let davinciMatch = lib.lookup(for: davinciKey)
        XCTAssertNotNil(davinciMatch)
        XCTAssertEqual(davinciMatch?.configType, .single)
    }
}
