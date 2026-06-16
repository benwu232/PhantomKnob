import XCTest
import SwiftUI
@testable import PhantomKnob

final class CustomKnobTests: XCTestCase {
    func testControlRuleJSONSerializationSingle() throws {
        let single = SingleKnobConfig(unitPerDegree: 1.2, translation: .axWrite, clockwiseAction: "increase", minRadius: 12.0)
        let rule = ControlRule(
            key: RuleKey(bundleID: "test.app", axRole: "test.role", identifier: "test.id", displayName: "test.display"),
            themeColor: "#BF5AF2",
            configType: .single,
            singleConfig: single
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(rule)
        let decoded = try decoder.decode(ControlRule.self, from: data)
        
        XCTAssertEqual(decoded.key.bundleID, rule.key.bundleID)
        XCTAssertEqual(decoded.themeColor, "#BF5AF2")
        XCTAssertEqual(decoded.configType, .single)
        XCTAssertEqual(decoded.singleConfig, single)
        XCTAssertEqual(decoded.singleConfig?.minRadius, 12.0)
        XCTAssertNil(decoded.doubleConfig)
        XCTAssertNil(decoded.linearConfig)
    }
    
    func testSingleKnobConfigBackwardCompatibility() throws {
        let jsonWithoutMinRadius = """
        {
            "unitPerDegree": 1.2,
            "translation": "axWrite",
            "clockwiseAction": "increase"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SingleKnobConfig.self, from: jsonWithoutMinRadius)
        XCTAssertNil(decoded.minRadius)
    }
    
    func testControlRuleJSONSerializationDouble() throws {
        let inner = VirtualKnobConfig(minRadius: 5.0, maxRadius: 25.0, margin: 2.0, unitPerDegree: 0.5, translation: .arrowKeyUpDown, clockwiseAction: "arrowUp")
        let outer = VirtualKnobConfig(minRadius: 27.0, maxRadius: 100.0, margin: 2.0, unitPerDegree: 2.0, translation: .scrollWheelVertical, clockwiseAction: "scrollUp")
        let doubleConfig = DoubleKnobConfig(inner: inner, outer: outer)
        
        let rule = ControlRule(
            key: RuleKey(bundleID: "test.app", axRole: "test.role", identifier: "test.id", displayName: "test.display"),
            themeColor: "#FF9F0A",
            configType: .double,
            doubleConfig: doubleConfig
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(rule)
        let decoded = try decoder.decode(ControlRule.self, from: data)
        
        XCTAssertEqual(decoded.configType, .double)
        XCTAssertEqual(decoded.doubleConfig, doubleConfig)
    }
    
    func testControlRuleJSONSerializationLinear() throws {
        let linear = LinearKnobConfig(minRadius: 5.0, maxRadius: 60.0, minScale: 0.2, maxScale: 3.0, translation: .scrollWheelHorizontal, clockwiseAction: "scrollRight")
        let rule = ControlRule(
            key: RuleKey(bundleID: "test.app", axRole: "test.role", identifier: "test.id", displayName: "test.display"),
            themeColor: "#30D158",
            configType: .linear,
            linearConfig: linear
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(rule)
        let decoded = try decoder.decode(ControlRule.self, from: data)
        
        XCTAssertEqual(decoded.configType, .linear)
        XCTAssertEqual(decoded.linearConfig, linear)
    }
    
    func testRuleLibrarySaveAndMerge() {
        let key = RuleKey(bundleID: "test.library.app", axRole: "test.role", identifier: "test.id", displayName: "test.display")
        let initialRule = ControlRule(
            key: key,
            themeColor: "#0A84FF",
            configType: .single,
            singleConfig: SingleKnobConfig(unitPerDegree: 1.0, translation: .scrollWheelVertical, clockwiseAction: "scrollUp")
        )
        
        let expectation = self.expectation(description: "ControlRuleDidUpdate notification received")
        
        var receivedRule: ControlRule?
        let observer = NotificationCenter.default.addObserver(forName: NSNotification.Name("ControlRuleDidUpdate"), object: nil, queue: nil) { notification in
            receivedRule = notification.userInfo?["rule"] as? ControlRule
            expectation.fulfill()
        }
        
        RuleLibrary.shared.saveRule(initialRule)
        
        waitForExpectations(timeout: 2.0, handler: nil)
        NotificationCenter.default.removeObserver(observer)
        
        XCTAssertNotNil(receivedRule)
        XCTAssertEqual(receivedRule?.key.bundleID, key.bundleID)
        XCTAssertEqual(receivedRule?.themeColor, "#0A84FF")
        
        // Lookup rule in library
        let found = RuleLibrary.shared.lookup(for: key)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.themeColor, "#0A84FF")
    }
    
    func testNSColorPanelColorChangeUpdatesRule() {
        let key = RuleKey(bundleID: "test.color.app", axRole: "test.role", identifier: "test.id", displayName: "test.display")
        let target = DetectedTarget(
            bundleID: key.bundleID,
            axRole: key.axRole,
            identifier: key.identifier,
            displayName: key.displayName ?? "",
            element: nil,
            parentChain: []
        )
        
        let initialRule = ControlRule(
            key: key,
            themeColor: "#000000",
            configType: .single,
            singleConfig: SingleKnobConfig(unitPerDegree: 1.0, translation: .scrollWheelVertical, clockwiseAction: "scrollUp")
        )
        RuleLibrary.shared.saveRule(initialRule)
        
        let view = CustomizerHUDView(target: target)
        let hostingController = NSHostingController(rootView: view)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingController.view
        window.orderFront(nil)
        
        let expectation = self.expectation(description: "Wait for color update and library save")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let panel = NSColorPanel.shared
            panel.color = NSColor.red
            NotificationCenter.default.post(name: NSColorPanel.colorDidChangeNotification, object: panel)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                window.orderOut(nil)
                expectation.fulfill()
            }
        }
        
        self.waitForExpectations(timeout: 1.0, handler: nil)
        
        let updatedRule = RuleLibrary.shared.lookup(for: key)
        XCTAssertEqual(updatedRule?.themeColor, "#FF0000")
    }
    
    func testVirtualKnobConfigThemeColorCodable() throws {
        // 1. 测试能正确编码和解码 themeColor
        let configWithColor = VirtualKnobConfig(
            minRadius: 5.0, maxRadius: 25.0, margin: 2.0,
            unitPerDegree: 0.5, translation: .arrowKeyUpDown, clockwiseAction: "arrowUp",
            themeColor: "#30D158"
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(configWithColor)
        let decoded = try decoder.decode(VirtualKnobConfig.self, from: data)
        XCTAssertEqual(decoded.themeColor, "#30D158")
        
        // 2. 测试后向兼容性：缺少 themeColor 字段时能成功解码为 nil
        let jsonWithoutColor = """
        {
            "minRadius": 5.0,
            "maxRadius": 25.0,
            "margin": 2.0,
            "unitPerDegree": 0.5,
            "translation": "arrowKeyUpDown",
            "clockwiseAction": "arrowUp"
        }
        """.data(using: .utf8)!
        let decodedCompatible = try decoder.decode(VirtualKnobConfig.self, from: jsonWithoutColor)
        XCTAssertNil(decodedCompatible.themeColor)
    }
    
    func testKnobStateManagerResolvesZoneThemeColor() {
        let key = RuleKey(bundleID: "test.zone.app", axRole: "AXSlider", identifier: "test", displayName: "Test")
        let inner = VirtualKnobConfig(minRadius: 5.0, maxRadius: 20.0, margin: 2.0, unitPerDegree: 0.5, translation: .arrowKeyUpDown, clockwiseAction: "arrowUp", themeColor: "#30D158")
        let outer = VirtualKnobConfig(minRadius: 22.0, maxRadius: 100.0, margin: 2.0, unitPerDegree: 2.0, translation: .scrollWheelVertical, clockwiseAction: "scrollUp", themeColor: "#FF9F0A")
        let rule = ControlRule(key: key, themeColor: "#0A84FF", configType: .double, doubleConfig: DoubleKnobConfig(inner: inner, outer: outer))
        
        RuleLibrary.shared.saveRule(rule)
        
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        manager.currentTarget = DetectedTarget(bundleID: key.bundleID, axRole: key.axRole, identifier: key.identifier, displayName: key.displayName ?? "", element: nil, parentChain: [])
        
        // 触发规则重载
        NotificationCenter.default.post(name: NSNotification.Name("ControlRuleDidUpdate"), object: nil, userInfo: ["rule": rule])
        
        // 验证在 inner zone (zoneIndex = 0) 时解析为绿色
        let colorInner = manager.resolveThemeColor(for: rule, zoneIndex: 0)
        XCTAssertEqual(colorInner, "#30D158")
        
        // 验证在 outer zone (zoneIndex = 1) 时解析为橙色
        let colorOuter = manager.resolveThemeColor(for: rule, zoneIndex: 1)
        XCTAssertEqual(colorOuter, "#FF9F0A")
    }
    
    func testCustomizerHUDViewLoadsDefaultOrSavedSettings() {
        let key = RuleKey(bundleID: "test.load.app", axRole: "test.role", identifier: "test.id", displayName: "test.display")
        let target = DetectedTarget(
            bundleID: key.bundleID,
            axRole: key.axRole,
            identifier: key.identifier,
            displayName: key.displayName ?? "",
            element: nil,
            parentChain: []
        )
        
        // 1. 无保存设置时加载：默认值应为单旋钮
        RuleLibrary.shared.injectRulesForTesting([])
        
        var resolvedConfigType1: KnobConfigType? = nil
        var resolvedThemeColor1: String? = nil
        let expectation1 = self.expectation(description: "Load default settings")
        
        let view1 = CustomizerHUDView(target: target) { configType, themeColor in
            resolvedConfigType1 = configType
            resolvedThemeColor1 = themeColor
            expectation1.fulfill()
        }
        
        let hostingController1 = NSHostingController(rootView: view1)
        let window1 = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window1.contentView = hostingController1.view
        window1.orderFront(nil)
        
        waitForExpectations(timeout: 1.0, handler: nil)
        window1.orderOut(nil)
        
        XCTAssertEqual(resolvedConfigType1, .single)
        XCTAssertEqual(resolvedThemeColor1, "#0A84FF")
        
        // 2. 有保存设置时加载：验证能够正确读取并显示已保存的设置
        let inner = VirtualKnobConfig(minRadius: 5.0, maxRadius: 20.0, margin: 2.0, unitPerDegree: 0.5, translation: .arrowKeyUpDown, clockwiseAction: "arrowUp", themeColor: "#30D158")
        let outer = VirtualKnobConfig(minRadius: 22.0, maxRadius: 100.0, margin: 2.0, unitPerDegree: 2.0, translation: .scrollWheelVertical, clockwiseAction: "scrollUp", themeColor: "#FF9F0A")
        let savedRule = ControlRule(key: key, themeColor: "#BF5AF2", configType: .double, doubleConfig: DoubleKnobConfig(inner: inner, outer: outer))
        
        RuleLibrary.shared.injectRulesForTesting([savedRule])
        
        var resolvedConfigType2: KnobConfigType? = nil
        var resolvedThemeColor2: String? = nil
        let expectation2 = self.expectation(description: "Load saved settings")
        
        let view2 = CustomizerHUDView(target: target) { configType, themeColor in
            resolvedConfigType2 = configType
            resolvedThemeColor2 = themeColor
            expectation2.fulfill()
        }
        
        let hostingController2 = NSHostingController(rootView: view2)
        let window2 = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window2.contentView = hostingController2.view
        window2.orderFront(nil)
        
        waitForExpectations(timeout: 1.0, handler: nil)
        window2.orderOut(nil)
        
        XCTAssertEqual(resolvedConfigType2, .double)
        XCTAssertEqual(resolvedThemeColor2, "#BF5AF2")
        
        RuleLibrary.shared.reload()
    }
    
    func testDoubleKnobConfigHysteresisRadiusAlignment() {
        let key = RuleKey(bundleID: "test.align.app", axRole: "AXSlider", identifier: "test", displayName: "Test")
        let inner = VirtualKnobConfig(minRadius: 5.0, maxRadius: 25.0, margin: 2.0, unitPerDegree: 0.5, translation: .arrowKeyUpDown, clockwiseAction: "arrowUp", themeColor: "#30D158")
        let outer = VirtualKnobConfig(minRadius: 25.0, maxRadius: 100.0, margin: 2.0, unitPerDegree: 2.0, translation: .scrollWheelVertical, clockwiseAction: "scrollUp", themeColor: "#FF9F0A")
        let rule = ControlRule(key: key, themeColor: "#0A84FF", configType: .double, doubleConfig: DoubleKnobConfig(inner: inner, outer: outer))
        
        RuleLibrary.shared.saveRule(rule)
        
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        manager.currentTarget = DetectedTarget(bundleID: key.bundleID, axRole: key.axRole, identifier: key.identifier, displayName: key.displayName ?? "", element: nil, parentChain: [])
        
        // Load target and rule scale config
        NotificationCenter.default.post(name: NSNotification.Name("ControlRuleDidUpdate"), object: nil, userInfo: ["rule": rule])
        
        // 模拟 Multitouch Began
        manager.currentZoneIndex = 0
        let zones = [
            RadiusZone(minRadius: 5.0, maxRadius: 25.0, margin: 2.0, scale: 0.5),
            RadiusZone(minRadius: 25.0, maxRadius: 100.0, margin: 2.0, scale: 2.0)
        ]
        
        // 1. 在 Zone 0 时向外移动，小于 27.0 时应该保持在 Zone 0
        var zoneIndex = 0
        var scale = ScaleResolver.resolveHysteresis(radius: 26.5, zones: zones, currentZoneIndex: &zoneIndex)
        XCTAssertEqual(zoneIndex, 0)
        XCTAssertEqual(scale, 0.5)
        
        // 大于 27.0 时应该切换至 Zone 1
        scale = ScaleResolver.resolveHysteresis(radius: 27.5, zones: zones, currentZoneIndex: &zoneIndex)
        XCTAssertEqual(zoneIndex, 1)
        XCTAssertEqual(scale, 2.0)
        
        // 2. 在 Zone 1 时向内移动，大于 23.0 时应该保持在 Zone 1
        zoneIndex = 1
        scale = ScaleResolver.resolveHysteresis(radius: 23.5, zones: zones, currentZoneIndex: &zoneIndex)
        XCTAssertEqual(zoneIndex, 1)
        XCTAssertEqual(scale, 2.0)
        
        // 小于 23.0 时应该切换至 Zone 0
        scale = ScaleResolver.resolveHysteresis(radius: 22.5, zones: zones, currentZoneIndex: &zoneIndex)
        XCTAssertEqual(zoneIndex, 0)
        XCTAssertEqual(scale, 0.5)
        
        RuleLibrary.shared.reload()
    }
    
    func testSingleKnobConfigMinRadiusEnforcement() {
        let key = RuleKey(bundleID: "test.single.min.app", axRole: "AXSlider", identifier: "test", displayName: "Test")
        let single = SingleKnobConfig(unitPerDegree: 1.0, translation: .scrollWheelVertical, clockwiseAction: "scrollUp", minRadius: 12.0)
        let rule = ControlRule(key: key, themeColor: "#0A84FF", configType: .single, singleConfig: single)
        
        RuleLibrary.shared.saveRule(rule)
        
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        manager.currentTarget = DetectedTarget(bundleID: key.bundleID, axRole: key.axRole, identifier: key.identifier, displayName: key.displayName ?? "", element: nil, parentChain: [])
        
        NotificationCenter.default.post(name: NSNotification.Name("ControlRuleDidUpdate"), object: nil, userInfo: ["rule": rule])
        
        switch manager.activeScaleConfig {
        case .fixed(let val):
            XCTAssertEqual(val, 1.0)
        default:
            XCTFail("Should resolve to fixed scale")
        }
        
        RuleLibrary.shared.reload()
    }
    
    func testQuickTimeCustomizationToggleBug() {
        let timelineKey = RuleKey(bundleID: "com.apple.QuickTimePlayerX", axRole: "AXSlider", displayName: "timeline")
        let volumeKey = RuleKey(bundleID: "com.apple.QuickTimePlayerX", axRole: "AXSlider", displayName: "volume")
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let rulesURL = appSupport.appendingPathComponent("PhantomKnob/rules.json")
        let backupURL = appSupport.appendingPathComponent("PhantomKnob/rules.json.bak")
        
        if FileManager.default.fileExists(atPath: rulesURL.path) {
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.copyItem(at: rulesURL, to: backupURL)
            try? FileManager.default.removeItem(at: rulesURL)
        }
        
        defer {
            if FileManager.default.fileExists(atPath: backupURL.path) {
                try? FileManager.default.removeItem(at: rulesURL)
                try? FileManager.default.copyItem(at: backupURL, to: rulesURL)
                try? FileManager.default.removeItem(at: backupURL)
            }
            RuleLibrary.shared.reload()
        }
        
        RuleLibrary.shared.reload()
        
        let timelineTarget = DetectedTarget(bundleID: timelineKey.bundleID, axRole: timelineKey.axRole, identifier: nil, displayName: "timeline", element: nil, parentChain: [])
        
        let timelineView = CustomizerHUDView(target: timelineTarget)
        let hostingController = NSHostingController(rootView: timelineView)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 400), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hostingController.view
        window.orderFront(nil)
        
        let exp1 = self.expectation(description: "timeline save")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let found = RuleLibrary.shared.lookup(for: timelineKey)
            XCTAssertNotNil(found)
            XCTAssertEqual(found?.configType, .double)
            exp1.fulfill()
        }
        waitForExpectations(timeout: 2.0, handler: nil)
        
        let volumeTarget = DetectedTarget(bundleID: volumeKey.bundleID, axRole: volumeKey.axRole, identifier: nil, displayName: "volume", element: nil, parentChain: [])
        hostingController.rootView = CustomizerHUDView(target: volumeTarget)
        
        let exp2 = self.expectation(description: "volume save")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let found = RuleLibrary.shared.lookup(for: volumeKey)
            XCTAssertNotNil(found)
            XCTAssertEqual(found?.configType, .single)
            exp2.fulfill()
        }
        waitForExpectations(timeout: 2.0, handler: nil)
        
        let timelineRuleAfterVolumeSave = RuleLibrary.shared.lookup(for: timelineKey)
        XCTAssertEqual(timelineRuleAfterVolumeSave?.configType, .double)
        
        hostingController.rootView = CustomizerHUDView(target: timelineTarget)
        
        let exp3 = self.expectation(description: "timeline reload")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let found = RuleLibrary.shared.lookup(for: timelineKey)
            XCTAssertNotNil(found)
            XCTAssertEqual(found?.configType, .double)
            exp3.fulfill()
        }
        waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testSelectiveFocusClickForKeyboardRequiredTranslation() {
        let textKey = RuleKey(bundleID: "com.test.text", axRole: "AXStaticText", displayName: "TextLabel")
        
        // 1. 测试用例 1：使用键盘控制（arrowKeyUpDown），应该触发模拟点击
        let keyboardRule = ControlRule(
            key: textKey,
            themeColor: "#0A84FF",
            configType: .single,
            singleConfig: SingleKnobConfig(unitPerDegree: 1.0, translation: .arrowKeyUpDown, clockwiseAction: "arrowUp")
        )
        RuleLibrary.shared.saveRule(keyboardRule)
        
        let manager1 = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        manager1.currentTarget = DetectedTarget(bundleID: textKey.bundleID, axRole: textKey.axRole, identifier: textKey.identifier, displayName: textKey.displayName ?? "", element: nil, parentChain: [])
        manager1.initialTouchPosition = CGPoint(x: 100, y: 100)
        manager1.didSimulateClickForTest = false
        
        manager1.transition(to: .knobing(target: manager1.currentTarget!))
        
        XCTAssertTrue(manager1.didSimulateClickForTest, "Should simulate click for AXStaticText with arrowKeyUpDown translation")
        
        // 2. 测试用例 2：使用滚轮控制（scrollWheelVertical），不应该触发模拟点击
        let scrollRule = ControlRule(
            key: textKey,
            themeColor: "#0A84FF",
            configType: .single,
            singleConfig: SingleKnobConfig(unitPerDegree: 1.0, translation: .scrollWheelVertical, clockwiseAction: "scrollUp")
        )
        RuleLibrary.shared.saveRule(scrollRule)
        
        let manager2 = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        manager2.currentTarget = DetectedTarget(bundleID: textKey.bundleID, axRole: textKey.axRole, identifier: textKey.identifier, displayName: textKey.displayName ?? "", element: nil, parentChain: [])
        manager2.initialTouchPosition = CGPoint(x: 100, y: 100)
        manager2.didSimulateClickForTest = false
        
        manager2.transition(to: .knobing(target: manager2.currentTarget!))
        
        XCTAssertFalse(manager2.didSimulateClickForTest, "Should NOT simulate click for AXStaticText with scrollWheelVertical translation")
        
        // 3. 测试用例 3：AXStaticText，即使没有专属控制规则，也绝对不应该产生任何模拟点击（即使默认需要键盘）
        RuleLibrary.shared.injectRulesForTesting([])
        
        let manager3 = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        manager3.currentTarget = DetectedTarget(bundleID: textKey.bundleID, axRole: textKey.axRole, identifier: textKey.identifier, displayName: textKey.displayName ?? "", element: nil, parentChain: [])
        manager3.initialTouchPosition = CGPoint(x: 100, y: 100)
        manager3.didSimulateClickForTest = false
        
        manager3.transition(to: .knobing(target: manager3.currentTarget!))
        
        XCTAssertFalse(manager3.didSimulateClickForTest, "Should NOT simulate click for AXStaticText when no specific rule exists")
        
        RuleLibrary.shared.reload()
    }
}

