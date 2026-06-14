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
}

