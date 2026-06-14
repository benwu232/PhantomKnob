import XCTest
import SwiftUI
@testable import PhantomKnob

final class CustomKnobTests: XCTestCase {
    func testControlRuleJSONSerializationSingle() throws {
        let single = SingleKnobConfig(unitPerDegree: 1.2, translation: .axWrite, clockwiseAction: "increase")
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
        XCTAssertNil(decoded.doubleConfig)
        XCTAssertNil(decoded.linearConfig)
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
            element: nil
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
        manager.currentTarget = DetectedTarget(bundleID: key.bundleID, axRole: key.axRole, identifier: key.identifier, displayName: key.displayName ?? "", element: nil)
        
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
            element: nil
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
        manager.currentTarget = DetectedTarget(bundleID: key.bundleID, axRole: key.axRole, identifier: key.identifier, displayName: key.displayName ?? "", element: nil)
        
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
}

