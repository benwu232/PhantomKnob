import XCTest
import SwiftUI
@testable import PhantomKnob

final class CustomKnobTests: XCTestCase {
    private var originalMyKnobsURL: URL!
    private var tempMyKnobsURL: URL!

    override func setUp() {
        super.setUp()
        originalMyKnobsURL = KnobCustomizer.shared.myKnobsURL
        let tempDir = NSTemporaryDirectory()
        let filename = "my_knobs_test_\(UUID().uuidString).json"
        tempMyKnobsURL = URL(fileURLWithPath: tempDir).appendingPathComponent(filename)
        KnobCustomizer.shared.myKnobsURL = tempMyKnobsURL
        KnobCustomizer.shared.reload()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempMyKnobsURL)
        KnobCustomizer.shared.myKnobsURL = originalMyKnobsURL
        KnobCustomizer.shared.reload()
        
        // Clean up all open/visible test windows
        for window in NSApp.windows {
            if window.isVisible && window.title != "XCTest" && !window.className.contains("XC") {
                window.orderOut(nil)
            }
        }
        if NSColorPanel.shared.isVisible {
            NSColorPanel.shared.orderOut(nil)
        }
        
        super.tearDown()
    }

    func testKnobJSONSerializationSingle() throws {
        let single = SingleKnobConfig(unitPerDegree: 1.2, translation: .axWrite, clockwiseAction: "increase", minRadius: 12.0)
        let knob = Knob(
            key: KnobKey(bundleID: "test.app", axRole: "test.role", identifier: "test.id", displayName: "test.display"),
            themeColor: "#BF5AF2",
            configType: .single,
            singleConfig: single
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(knob)
        let decoded = try decoder.decode(Knob.self, from: data)
        
        XCTAssertEqual(decoded.key.bundleID, knob.key.bundleID)
        XCTAssertEqual(decoded.themeColor, "#BF5AF2")
        XCTAssertEqual(decoded.configType, .single)
        XCTAssertEqual(decoded.singleConfig, single)
        XCTAssertEqual(decoded.singleConfig?.minRadius, 12.0)
        XCTAssertNil(decoded.doubleConfig)
        XCTAssertNil(decoded.cvkConfig)
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
    
    func testKnobJSONSerializationDouble() throws {
        let inner = VirtualKnobConfig(minRadius: 5.0, maxRadius: 25.0, margin: 2.0, unitPerDegree: 0.5, translation: .arrowKeyUpDown, clockwiseAction: "arrowUp")
        let outer = VirtualKnobConfig(minRadius: 27.0, maxRadius: 100.0, margin: 2.0, unitPerDegree: 2.0, translation: .scrollWheelVertical, clockwiseAction: "scrollUp")
        let doubleConfig = DoubleKnobConfig(inner: inner, outer: outer)
        
        let knob = Knob(
            key: KnobKey(bundleID: "test.app", axRole: "test.role", identifier: "test.id", displayName: "test.display"),
            themeColor: "#FF9F0A",
            configType: .double,
            doubleConfig: doubleConfig
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(knob)
        let decoded = try decoder.decode(Knob.self, from: data)
        
        XCTAssertEqual(decoded.configType, .double)
        XCTAssertEqual(decoded.doubleConfig, doubleConfig)
    }
    
    func testKnobJSONSerializationLinear() throws {
        let linear = CVKKnobConfig(minRadius: 5.0, maxRadius: 60.0, minScale: 0.2, maxScale: 3.0, translation: .scrollWheelHorizontal, clockwiseAction: "scrollRight")
        let knob = Knob(
            key: KnobKey(bundleID: "test.app", axRole: "test.role", identifier: "test.id", displayName: "test.display"),
            themeColor: "#30D158",
            configType: .cvk,
            cvkConfig: linear
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(knob)
        let decoded = try decoder.decode(Knob.self, from: data)
        
        XCTAssertEqual(decoded.configType, .cvk)
        XCTAssertEqual(decoded.cvkConfig, linear)
    }
    
    func testKnobCustomizerSaveAndMerge() {
        let key = KnobKey(bundleID: "test.library.app", axRole: "test.role", identifier: "test.id", displayName: "test.display")
        let initialKnob = Knob(
            key: key,
            themeColor: "#0A84FF",
            configType: .single,
            singleConfig: SingleKnobConfig(unitPerDegree: 1.0, translation: .scrollWheelVertical, clockwiseAction: "scrollUp")
        )
        
        let expectation = self.expectation(description: "KnobDidUpdate notification received")
        
        var receivedKnob: Knob?
        let observer = NotificationCenter.default.addObserver(forName: NSNotification.Name("KnobDidUpdate"), object: nil, queue: nil) { notification in
            receivedKnob = notification.userInfo?["knob"] as? Knob
            expectation.fulfill()
        }
        
        KnobCustomizer.shared.saveKnob(initialKnob)
        
        waitForExpectations(timeout: 2.0, handler: nil)
        NotificationCenter.default.removeObserver(observer)
        
        XCTAssertNotNil(receivedKnob)
        XCTAssertEqual(receivedKnob?.key.bundleID, key.bundleID)
        XCTAssertEqual(receivedKnob?.themeColor, "#0A84FF")
        
        // Lookup knob in customizer
        let found = KnobCustomizer.shared.knob(for: key)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.themeColor, "#0A84FF")
    }
    
    func testNSColorPanelColorChangeUpdatesKnob() {
        let key = KnobKey(bundleID: "test.color.app", axRole: "test.role", identifier: "test.id", displayName: "test.display")
        let target = DetectedTarget(
            bundleID: key.bundleID,
            axRole: key.axRole,
            identifier: key.identifier,
            displayName: key.displayName ?? "",
            element: nil,
            parentChain: []
        )
        
        let initialKnob = Knob(
            key: key,
            themeColor: "#000000",
            configType: .single,
            singleConfig: SingleKnobConfig(unitPerDegree: 1.0, translation: .scrollWheelVertical, clockwiseAction: "scrollUp")
        )
        KnobCustomizer.shared.saveKnob(initialKnob)
        
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let panel = NSColorPanel.shared
            panel.color = NSColor.red
            NotificationCenter.default.post(name: NSColorPanel.colorDidChangeNotification, object: panel)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                window.orderOut(nil)
                expectation.fulfill()
            }
        }
        
        self.waitForExpectations(timeout: 5.0, handler: nil)
        
        let updatedKnob = KnobCustomizer.shared.knob(for: key)
        XCTAssertEqual(updatedKnob?.themeColor, "#FF0000")
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
        let key = KnobKey(bundleID: "test.zone.app", axRole: "AXSlider", identifier: "test", displayName: "Test")
        let inner = VirtualKnobConfig(minRadius: 5.0, maxRadius: 20.0, margin: 2.0, unitPerDegree: 0.5, translation: .arrowKeyUpDown, clockwiseAction: "arrowUp", themeColor: "#30D158")
        let outer = VirtualKnobConfig(minRadius: 22.0, maxRadius: 100.0, margin: 2.0, unitPerDegree: 2.0, translation: .scrollWheelVertical, clockwiseAction: "scrollUp", themeColor: "#FF9F0A")
        let knob = Knob(key: key, themeColor: "#0A84FF", configType: .double, doubleConfig: DoubleKnobConfig(inner: inner, outer: outer))
        
        KnobCustomizer.shared.saveKnob(knob)
        
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        manager.currentTarget = DetectedTarget(bundleID: key.bundleID, axRole: key.axRole, identifier: key.identifier, displayName: key.displayName ?? "", element: nil, parentChain: [])
        
        // 触发规则重载
        NotificationCenter.default.post(name: NSNotification.Name("KnobDidUpdate"), object: nil, userInfo: ["knob": knob])
        
        // 验证在 inner zone (zoneIndex = 0) 时解析为绿色
        let colorInner = manager.resolveThemeColor(for: knob, zoneIndex: 0)
        XCTAssertEqual(colorInner, "#30D158")
        
        // 验证在 outer zone (zoneIndex = 1) 时解析为橙色
        let colorOuter = manager.resolveThemeColor(for: knob, zoneIndex: 1)
        XCTAssertEqual(colorOuter, "#FF9F0A")
    }
    
    func testCustomizerHUDViewLoadsDefaultOrSavedSettings() {
        let key = KnobKey(bundleID: "test.load.app", axRole: "test.role", identifier: "test.id", displayName: "test.display")
        let target = DetectedTarget(
            bundleID: key.bundleID,
            axRole: key.axRole,
            identifier: key.identifier,
            displayName: key.displayName ?? "",
            element: nil,
            parentChain: []
        )
        
        // 1. 无保存设置时加载：默认值应为单旋钮
        KnobCustomizer.shared.injectKnobsForTesting([])
        
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
        let savedKnob = Knob(key: key, themeColor: "#BF5AF2", configType: .double, doubleConfig: DoubleKnobConfig(inner: inner, outer: outer))
        
        KnobCustomizer.shared.injectKnobsForTesting([savedKnob])
        
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
        
        KnobCustomizer.shared.reload()
    }
    
    func testDoubleKnobConfigHysteresisRadiusAlignment() {
        let key = KnobKey(bundleID: "test.align.app", axRole: "AXSlider", identifier: "test", displayName: "Test")
        let inner = VirtualKnobConfig(minRadius: 5.0, maxRadius: 25.0, margin: 2.0, unitPerDegree: 0.5, translation: .arrowKeyUpDown, clockwiseAction: "arrowUp", themeColor: "#30D158")
        let outer = VirtualKnobConfig(minRadius: 25.0, maxRadius: 100.0, margin: 2.0, unitPerDegree: 2.0, translation: .scrollWheelVertical, clockwiseAction: "scrollUp", themeColor: "#FF9F0A")
        let knob = Knob(key: key, themeColor: "#0A84FF", configType: .double, doubleConfig: DoubleKnobConfig(inner: inner, outer: outer))
        
        KnobCustomizer.shared.saveKnob(knob)
        
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        manager.currentTarget = DetectedTarget(bundleID: key.bundleID, axRole: key.axRole, identifier: key.identifier, displayName: key.displayName ?? "", element: nil, parentChain: [])
        
        // Load target and knob scale config
        NotificationCenter.default.post(name: NSNotification.Name("KnobDidUpdate"), object: nil, userInfo: ["knob": knob])
        
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
        
        KnobCustomizer.shared.reload()
    }
    
    func testSingleKnobConfigMinRadiusEnforcement() {
        let key = KnobKey(bundleID: "test.single.min.app", axRole: "AXSlider", identifier: "test", displayName: "Test")
        let single = SingleKnobConfig(unitPerDegree: 1.0, translation: .scrollWheelVertical, clockwiseAction: "scrollUp", minRadius: 12.0)
        let knob = Knob(key: key, themeColor: "#0A84FF", configType: .single, singleConfig: single)
        
        KnobCustomizer.shared.saveKnob(knob)
        
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        manager.currentTarget = DetectedTarget(bundleID: key.bundleID, axRole: key.axRole, identifier: key.identifier, displayName: key.displayName ?? "", element: nil, parentChain: [])
        
        NotificationCenter.default.post(name: NSNotification.Name("KnobDidUpdate"), object: nil, userInfo: ["knob": knob])
        
        switch manager.activeScaleConfig {
        case .fixed(let val):
            XCTAssertEqual(val, 1.0)
        default:
            XCTFail("Should resolve to fixed scale")
        }
        
        KnobCustomizer.shared.reload()
    }
    
    func testQuickTimeCustomizationToggleBug() {
        let timelineKey = KnobKey(bundleID: "com.apple.QuickTimePlayerX", axRole: "AXSlider", displayName: "timeline")
        let volumeKey = KnobKey(bundleID: "com.apple.QuickTimePlayerX", axRole: "AXSlider", displayName: "volume")
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let rulesURL = appSupport.appendingPathComponent("PhantomKnob/my_knobs.json")
        let backupURL = appSupport.appendingPathComponent("PhantomKnob/my_knobs.json.bak")
        
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
            KnobCustomizer.shared.reload()
        }
        
        KnobCustomizer.shared.reload()
        
        let timelineTarget = DetectedTarget(bundleID: timelineKey.bundleID, axRole: timelineKey.axRole, identifier: nil, displayName: "timeline", element: nil, parentChain: [])
        
        let timelineView = CustomizerHUDView(target: timelineTarget)
        let hostingController = NSHostingController(rootView: timelineView)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 400), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hostingController.view
        window.orderFront(nil)
        
        let exp1 = self.expectation(description: "timeline save")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let found = KnobCustomizer.shared.knob(for: timelineKey)
            XCTAssertNotNil(found)
            XCTAssertEqual(found?.configType, .double)
            exp1.fulfill()
        }
        waitForExpectations(timeout: 2.0, handler: nil)
        
        let volumeTarget = DetectedTarget(bundleID: volumeKey.bundleID, axRole: volumeKey.axRole, identifier: nil, displayName: "volume", element: nil, parentChain: [])
        hostingController.rootView = CustomizerHUDView(target: volumeTarget)
        
        let exp2 = self.expectation(description: "volume save")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let found = KnobCustomizer.shared.knob(for: volumeKey)
            XCTAssertNotNil(found)
            XCTAssertEqual(found?.configType, .single)
            exp2.fulfill()
        }
        waitForExpectations(timeout: 2.0, handler: nil)
        
        let timelineKnobAfterVolumeSave = KnobCustomizer.shared.knob(for: timelineKey)
        XCTAssertEqual(timelineKnobAfterVolumeSave?.configType, .double)
        
        hostingController.rootView = CustomizerHUDView(target: timelineTarget)
        
        let exp3 = self.expectation(description: "timeline reload")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let found = KnobCustomizer.shared.knob(for: timelineKey)
            XCTAssertNotNil(found)
            XCTAssertEqual(found?.configType, .double)
            exp3.fulfill()
        }
        waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testSelectiveFocusClickForKeyboardRequiredTranslation() {
        let textFieldKey = KnobKey(bundleID: "com.test.text", axRole: "AXTextField", displayName: "TextField")
        
        // 1. 测试用例 1：AXTextField，使用键盘控制（arrowKeyUpDown），应该触发模拟点击
        let keyboardKnob = Knob(
            key: textFieldKey,
            themeColor: "#0A84FF",
            configType: .single,
            singleConfig: SingleKnobConfig(unitPerDegree: 1.0, translation: .arrowKeyUpDown, clockwiseAction: "arrowUp")
        )
        KnobCustomizer.shared.saveKnob(keyboardKnob)
        
        let manager1 = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        manager1.currentTarget = DetectedTarget(bundleID: textFieldKey.bundleID, axRole: textFieldKey.axRole, identifier: textFieldKey.identifier, displayName: textFieldKey.displayName ?? "", element: nil, parentChain: [])
        manager1.initialTouchPosition = CGPoint(x: 100, y: 100)
        manager1.didSimulateClickForTest = false
        
        manager1.transition(to: .knobing(target: manager1.currentTarget!))
        
        XCTAssertTrue(manager1.didSimulateClickForTest, "Should simulate click for AXTextField with arrowKeyUpDown translation")
        
        // 2. 测试用例 2：AXStaticText，明确配置了专属 arrowKeyUpDown 配置，应该触发模拟点击
        let staticTextKey = KnobKey(bundleID: "com.test.text", axRole: "AXStaticText", displayName: "StaticText")
        let staticTextKnob = Knob(
            key: staticTextKey,
            themeColor: "#0A84FF",
            configType: .single,
            singleConfig: SingleKnobConfig(unitPerDegree: 1.0, translation: .arrowKeyUpDown, clockwiseAction: "arrowUp")
        )
        KnobCustomizer.shared.saveKnob(staticTextKnob)
        
        let manager2 = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        manager2.currentTarget = DetectedTarget(bundleID: staticTextKey.bundleID, axRole: staticTextKey.axRole, identifier: staticTextKey.identifier, displayName: staticTextKey.displayName ?? "", element: nil, parentChain: [])
        manager2.initialTouchPosition = CGPoint(x: 100, y: 100)
        manager2.didSimulateClickForTest = false
        
        manager2.transition(to: .knobing(target: manager2.currentTarget!))
        
        XCTAssertTrue(manager2.didSimulateClickForTest, "Should simulate click for AXStaticText with specific arrowKeyUpDown knob")
        
        // 3. 测试用例 3：AXStaticText，仅匹配到 App 的全局 "unknown" 兜底配置，绝对不产生任何模拟点击
        let fallbackTextKey = KnobKey(bundleID: "com.test.fallback", axRole: "AXStaticText", displayName: "StaticText")
        let unknownKnob = Knob(
            key: KnobKey(bundleID: "com.test.fallback", axRole: "unknown"),
            themeColor: "#0A84FF",
            configType: .single,
            singleConfig: SingleKnobConfig(unitPerDegree: 1.0, translation: .arrowKeyUpDown, clockwiseAction: "arrowUp")
        )
        KnobCustomizer.shared.saveKnob(unknownKnob)
        
        let manager3 = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        manager3.currentTarget = DetectedTarget(bundleID: fallbackTextKey.bundleID, axRole: fallbackTextKey.axRole, identifier: fallbackTextKey.identifier, displayName: fallbackTextKey.displayName ?? "", element: nil, parentChain: [])
        manager3.initialTouchPosition = CGPoint(x: 100, y: 100)
        manager3.didSimulateClickForTest = false
        
        manager3.transition(to: .knobing(target: manager3.currentTarget!))
        
        XCTAssertFalse(manager3.didSimulateClickForTest, "Should NOT simulate click for AXStaticText when only matching unknown fallback knob")
        
        KnobCustomizer.shared.reload()
    }
    
    func testSimulateReturnKeyOnFocusRelease() {
        let textFieldKey = KnobKey(bundleID: "com.test.focusrelease", axRole: "AXTextField", displayName: "TextField")
        let keyboardKnob = Knob(
            key: textFieldKey,
            themeColor: "#0A84FF",
            configType: .single,
            singleConfig: SingleKnobConfig(unitPerDegree: 1.0, translation: .arrowKeyUpDown, clockwiseAction: "arrowUp")
        )
        KnobCustomizer.shared.saveKnob(keyboardKnob)
        
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        manager.currentTarget = DetectedTarget(bundleID: textFieldKey.bundleID, axRole: textFieldKey.axRole, identifier: textFieldKey.identifier, displayName: textFieldKey.displayName ?? "", element: nil, parentChain: [])
        manager.initialTouchPosition = CGPoint(x: 100, y: 100)
        
        // 初始断言
        XCTAssertFalse(manager.didSimulateReturnForTest)
        
        // Transition to knobing -> Should click and set flag
        manager.transition(to: .knobing(target: manager.currentTarget!))
        XCTAssertTrue(manager.didSimulateClickForTest)
        
        // Transition to cooling -> Should simulate return and reset flag
        manager.transition(to: .cooling(target: manager.currentTarget!))
        XCTAssertTrue(manager.didSimulateReturnForTest)
        
        KnobCustomizer.shared.reload()
    }
    
    func testOptionHoldTemporaryToggle() {
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        // Mock start/stop to avoid C Private APIs that cause sandbox crashes
        manager.startMultitouch = {}
        manager.stopMultitouch = {}
        manager.isProcessTrusted = { true }
        
        // 1. 验证初始状态是 inactive
        XCTAssertEqual(manager.state, .inactive)
        
        // 2. 在 inactive 下按下 Option
        manager.onGlobalModifierOptionChanged(isPressed: true)
        XCTAssertEqual(manager.state, .activated)
        
        // 3. 在 Option 激活下松开 Option
        manager.onGlobalModifierOptionChanged(isPressed: false)
        XCTAssertEqual(manager.state, .inactive)
        
        // 4. 持久激活
        manager.toggleMode()
        XCTAssertEqual(manager.state, .activated)
        
        // 5. 在 activated 下按下 Option -> 临时进入 inactive
        manager.onGlobalModifierOptionChanged(isPressed: true)
        XCTAssertEqual(manager.state, .inactive)
        
        // 6. 松开 Option -> 恢复 activated
        manager.onGlobalModifierOptionChanged(isPressed: false)
        XCTAssertEqual(manager.state, .activated)
        
        // 7. 在 activated 下按下 Option -> 临时进入 inactive
        manager.onGlobalModifierOptionChanged(isPressed: true)
        XCTAssertEqual(manager.state, .inactive)
        
        // 8. 处于临时退出状态时按下热键 toggleMode -> 转化为持久 inactive
        manager.toggleMode()
        XCTAssertEqual(manager.state, .inactive)
        
        // 9. 松开 Option -> 应该保持为 inactive 状态，不再恢复 activated
        manager.onGlobalModifierOptionChanged(isPressed: false)
        XCTAssertEqual(manager.state, .inactive)
    }

    func testSaveAndLoadAnimationMode() {
        let key = KnobKey(bundleID: "test.anim.app", axRole: "AXSlider", identifier: nil, displayName: nil)
        var knob = Knob(
            key: key,
            themeColor: "#0A84FF",
            configType: .single,
            singleConfig: SingleKnobConfig(unitPerDegree: 1.0, translation: .scrollWheelVertical, clockwiseAction: "scrollUp")
        )
        knob.skinOverrides = HUDSkinOverride(
            primaryColorHex: "#0A84FF",
            animationMode: .fade,
            entranceDuration: 0.3,
            exitDuration: 0.5
        )
        
        KnobCustomizer.shared.saveKnob(knob)
        
        let loaded = KnobCustomizer.shared.knob(for: key)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.skinOverrides?.animationMode, .fade)
    }
}
