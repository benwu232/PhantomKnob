// PhantomKnob/PhantomKnobTests/KnobCustomizerTests.swift
import XCTest
@testable import PhantomKnob

final class KnobCustomizerTests: XCTestCase {

    private func makeCustomizer(knobs: [Knob]) -> KnobCustomizer {
        let customizer = KnobCustomizer()
        // 直接注入测试配置（绕过文件加载）
        customizer.injectKnobsForTesting(knobs)
        return customizer
    }

    func testExactMatchWins() {
        let exactKnob = Knob(
            key: KnobKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: "timeline"),
            translation: .arrowKeyLeftRight,
            scaleConfig: .fixed(2.0)
        )
        let broadKnob = Knob(
            key: KnobKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: nil),
            translation: .scrollWheelVertical
        )
        let customizer = makeCustomizer(knobs: [exactKnob, broadKnob])
        let key = KnobKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: "timeline")
        XCTAssertEqual(customizer.knob(for: key)?.translation, .arrowKeyLeftRight)
    }

    func testBroadRuleFallsBack() {
        let broadKnob = Knob(
            key: KnobKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: nil),
            translation: .scrollWheelVertical
        )
        let customizer = makeCustomizer(knobs: [broadKnob])
        let key = KnobKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: "unknownControl")
        XCTAssertEqual(customizer.knob(for: key)?.translation, .scrollWheelVertical)
    }

    func testNoMatchReturnsNil() {
        let customizer = makeCustomizer(knobs: [])
        let key = KnobKey(bundleID: "com.unknown.app", axRole: "AXSlider", identifier: nil)
        XCTAssertNil(customizer.knob(for: key))
    }

    func testDisplayNameMatchWins() {
        let displayNameKnob = Knob(
            key: KnobKey(bundleID: "com.apple.QuickTimePlayerX", axRole: "AXSlider", displayName: "timeline"),
            translation: .arrowKeyLeftRight
        )
        let broadKnob = Knob(
            key: KnobKey(bundleID: "com.apple.QuickTimePlayerX", axRole: "AXSlider"),
            translation: .scrollWheelVertical
        )
        
        let customizer = makeCustomizer(knobs: [displayNameKnob, broadKnob])
        
        // 当查询时间轴（displayName == "timeline"）时，应该命中特定配置
        let timelineKey = KnobKey(bundleID: "com.apple.QuickTimePlayerX", axRole: "AXSlider", displayName: "timeline")
        XCTAssertEqual(customizer.knob(for: timelineKey)?.translation, .arrowKeyLeftRight)
        
        // 当查询音量（displayName == "volume"）时，应该退回到宽泛配置
        let volumeKey = KnobKey(bundleID: "com.apple.QuickTimePlayerX", axRole: "AXSlider", displayName: "volume")
        XCTAssertEqual(customizer.knob(for: volumeKey)?.translation, .scrollWheelVertical)
    }

    func testScaleConfigParsing() throws {
        let json = """
        [{"key":{"bundleID":"x","axRole":"AXSlider","identifier":null},
          "translation":"scrollWheelVertical",
          "scaleConfig":{"fixed":8.0}}]
        """.data(using: .utf8)!
        let knobs = try JSONDecoder().decode([Knob].self, from: json)
        XCTAssertEqual(knobs.first?.scaleConfig?.resolve(), 8.0)
    }

    func testCapCutRulesAreBundled() {
        let customizer = KnobCustomizer.shared
        customizer.reload() // Make sure bundled rules are loaded
        
        let bundleIDs = [
            "com.lemon.lvoverseas",
            "com.lemon.lv",
            "com.lemon.lvediting",
            "com.lemon.jianying",
            "com.lemon.jianyingpro"
        ]
        
        for bid in bundleIDs {
            let key = KnobKey(bundleID: bid, axRole: "unknown")
            let match = customizer.knob(for: key)
            XCTAssertNotNil(match, "CapCut/Jianying configuration should be bundled for \(bid)")
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
        
        let knob1 = try JSONDecoder().decode(Knob.self, from: jsonWithInvert)
        XCTAssertEqual(knob1.invert, true)
        
        let knob2 = try JSONDecoder().decode(Knob.self, from: jsonWithoutInvert)
        XCTAssertNil(knob2.invert) // 缺失时解析为 nil，调用方使用 ?? false 处理
    }

    func testDaVinciResolveRuleIsLoaded() {
        let customizer = KnobCustomizer.shared
        customizer.reload()
        
        let key = KnobKey(bundleID: "com.blackmagic-design.DaVinciResolve", axRole: "unknown")
        let knob = customizer.knob(for: key)
        
        XCTAssertNotNil(knob, "Resolve configuration must exist")
        XCTAssertEqual(knob?.translation, .scrollWheelVertical)
        XCTAssertEqual(knob?.invert, true)
    }

    func testParentChainSubsequenceMatching() {
        let knobChain = [
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
        
        XCTAssertTrue(KnobCustomizer.matchParentChain(knobChain: knobChain, targetChain: targetChain1))
        XCTAssertFalse(KnobCustomizer.matchParentChain(knobChain: knobChain, targetChain: targetChain2))
    }
    
    func testLookupPrioritizesParentChainConstraints() {
        let specKnob = Knob(
            key: KnobKey(bundleID: "com.test.app", axRole: "AXStaticText", parentChain: [ParentNodeInfo(axRole: "AXGroup", displayName: "对比度")]),
            translation: .arrowKeyUpDown
        )
        
        let broadKnob = Knob(
            key: KnobKey(bundleID: "com.test.app", axRole: "AXStaticText"),
            translation: .scrollWheelVertical
        )
        
        let customizer = makeCustomizer(knobs: [specKnob, broadKnob])
        
        let keyWithMatchingParent = KnobKey(
            bundleID: "com.test.app",
            axRole: "AXStaticText",
            parentChain: [ParentNodeInfo(axRole: "AXGroup", displayName: "对比度"), ParentNodeInfo(axRole: "AXWindow", displayName: nil)]
        )
        
        let keyWithNonMatchingParent = KnobKey(
            bundleID: "com.test.app",
            axRole: "AXStaticText",
            parentChain: [ParentNodeInfo(axRole: "AXGroup", displayName: "饱和度")]
        )
        
        XCTAssertEqual(customizer.knob(for: keyWithMatchingParent)?.translation, .arrowKeyUpDown)
        XCTAssertEqual(customizer.knob(for: keyWithNonMatchingParent)?.translation, .scrollWheelVertical)
    }
    
    func testDaVinciResolveWindowModeExtraction() {
        // 1. 验证模式提取
        XCTAssertEqual(TargetDetector.extractResolvePageMode(from: "DaVinci Resolve - MyProject - Color"), "Color")
        XCTAssertEqual(TargetDetector.extractResolvePageMode(from: "DaVinci Resolve - MyProject - Cut"), "Cut")
        XCTAssertEqual(TargetDetector.extractResolvePageMode(from: "DaVinci Resolve - MyProject - Edit"), "Edit")
        XCTAssertNil(TargetDetector.extractResolvePageMode(from: "DaVinci Resolve - MyProject"))
        XCTAssertNil(TargetDetector.extractResolvePageMode(from: "Safari - DaVinci Resolve - Color"))
        
        // 2. 验证根据 parentChain 分流匹配
        let colorKnob = Knob(
            key: KnobKey(bundleID: "com.blackmagic-design.DaVinciResolve", axRole: "unknown", parentChain: [ParentNodeInfo(axRole: "AXWindow", displayName: "Color")]),
            translation: .scrollWheelVertical,
            invert: true
        )
        let cutKnob = Knob(
            key: KnobKey(bundleID: "com.blackmagic-design.DaVinciResolve", axRole: "unknown", parentChain: [ParentNodeInfo(axRole: "AXWindow", displayName: "Cut")]),
            translation: .scrollWheelHorizontal,
            invert: false
        )
        let genericKnob = Knob(
            key: KnobKey(bundleID: "com.blackmagic-design.DaVinciResolve", axRole: "unknown"),
            translation: .swipeVertical
        )
        
        let customizer = makeCustomizer(knobs: [colorKnob, cutKnob, genericKnob])
        
        let colorKey = KnobKey(bundleID: "com.blackmagic-design.DaVinciResolve", axRole: "unknown", parentChain: [ParentNodeInfo(axRole: "AXWindow", displayName: "Color")])
        let cutKey = KnobKey(bundleID: "com.blackmagic-design.DaVinciResolve", axRole: "unknown", parentChain: [ParentNodeInfo(axRole: "AXWindow", displayName: "Cut")])
        let otherKey = KnobKey(bundleID: "com.blackmagic-design.DaVinciResolve", axRole: "unknown", parentChain: [ParentNodeInfo(axRole: "AXWindow", displayName: "Fusion")])
        
        XCTAssertEqual(customizer.knob(for: colorKey)?.translation, .scrollWheelVertical)
        XCTAssertEqual(customizer.knob(for: colorKey)?.invert, true)
        
        XCTAssertEqual(customizer.knob(for: cutKey)?.translation, .scrollWheelHorizontal)
        XCTAssertEqual(customizer.knob(for: cutKey)?.invert, false)
        
        XCTAssertEqual(customizer.knob(for: otherKey)?.translation, .swipeVertical)
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
            KnobCustomizer.shared.reload()
        }
        
        // Ensure the file is deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: rulesURL.path))
        
        // Triggers reloading and creation of default my_knobs
        let customizer = KnobCustomizer()
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: rulesURL.path))
        
        // Verify we can lookup default my_knobs rules
        let jianyingKey = KnobKey(bundleID: "com.lemon.jianyingpro", axRole: "AXSlider", displayName: "Timeline")
        let match = customizer.knob(for: jianyingKey)
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.configType, .double)
        
        let davinciKey = KnobKey(bundleID: "com.blackmagic-design.DaVinciResolve", axRole: "AXSlider", displayName: "ColorWheel")
        let davinciMatch = customizer.knob(for: davinciKey)
        XCTAssertNotNil(davinciMatch)
        XCTAssertEqual(davinciMatch?.configType, .single)
    }
}
