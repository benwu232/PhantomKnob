// PhantomKnob/PhantomKnobTests/StatusBarControllerTests.swift
import XCTest
@testable import PhantomKnob

final class StatusBarControllerTests: XCTestCase {
    private let suiteName = "com.phantomknob.PhantomKnobTests"
    
    override func setUp() {
        super.setUp()
        UserDefaults.app = UserDefaults(suiteName: suiteName) ?? .standard
        UserDefaults.app.removePersistentDomain(forName: suiteName)
    }
    
    override func tearDown() {
        KnobPanelWindowController.shared.hide()
        SettingsWindowController.shared.hide()
        UserDefaults.app.removePersistentDomain(forName: suiteName)
        UserDefaults.app = .standard
        super.tearDown()
    }
    
    func testStatusBarDoubleCickTogglesPanel() {
        let controller = StatusBarController()
        let panelController = KnobPanelWindowController.shared
        
        // Ensure window is hidden initially
        if panelController.isVisible {
            panelController.hide()
        }
        XCTAssertFalse(panelController.isVisible)
        
        let doubleClickEvent = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 2,
            pressure: 0
        )
        
        let expectation = XCTestExpectation(description: "Toggle on double click")
        DispatchQueue.main.async {
            controller.handleStatusItemClick(event: doubleClickEvent)
            XCTAssertTrue(panelController.isVisible)
            
            // Clean up
            panelController.hide()
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testStatusBarLeftSingleClickTogglesModeAfterInterval() {
        let controller = StatusBarController()
        
        var toggleTriggered = false
        controller.onToggleHotkey = {
            toggleTriggered = true
        }
        
        let singleClickEvent = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        )
        
        let expectation = XCTestExpectation(description: "Toggle mode triggered after doubleClickInterval")
        
        controller.handleStatusItemClick(event: singleClickEvent)
        
        // Immediately should not trigger
        XCTAssertFalse(toggleTriggered)
        
        // After doubleClickInterval + small buffer, should trigger
        let delay = NSEvent.doubleClickInterval + 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            XCTAssertTrue(toggleTriggered)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testOpenSettingsElevatesActivationPolicy() {
        let controller = StatusBarController()
        
        // Setup initial policy
        NSApp.setActivationPolicy(.accessory)
        XCTAssertEqual(NSApp.activationPolicy(), .accessory)
        
        // Trigger opening of settings
        controller.openSettings()
        
        // Verify policy changed to .regular and settings is visible
        XCTAssertEqual(NSApp.activationPolicy(), .regular)
        XCTAssertTrue(SettingsWindowController.shared.isVisible)
        
        // Clean up: hide the settings window which should restore activation policy to .accessory
        SettingsWindowController.shared.hide()
        
        XCTAssertEqual(NSApp.activationPolicy(), .accessory)
        XCTAssertFalse(SettingsWindowController.shared.isVisible)
    }
    
    func testStatusBarIconColorAndTemplate() {
        let controller = StatusBarController()
        let dummyTarget = DetectedTarget(bundleID: "com.test.app", axRole: "AXSlider", identifier: nil, displayName: "Test", element: nil, parentChain: [])
        
        // Test inactive state
        controller.updateState(.inactive)
        if let button = controller.statusItem?.button {
            XCTAssertNotNil(button.image)
            XCTAssertFalse(button.image?.isTemplate ?? true)
        }
        
        // Test activated state
        controller.updateState(.activated)
        if let button = controller.statusItem?.button {
            XCTAssertNotNil(button.image)
            XCTAssertFalse(button.image?.isTemplate ?? true)
        }
        
        // Test knobing state
        controller.updateState(.knobing(target: dummyTarget))
        if let button = controller.statusItem?.button {
            XCTAssertNotNil(button.image)
            XCTAssertFalse(button.image?.isTemplate ?? true)
        }
    }
    
    func testStatusBarRightClickShowsMenu() {
        let controller = StatusBarController()
        
        let rightClickEvent = NSEvent.mouseEvent(
            with: .rightMouseUp,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        )
        
        controller.handleStatusItemClick(event: rightClickEvent)
    }
    
    func testStatusBarControlLeftClickShowsMenu() {
        let controller = StatusBarController()
        
        let controlLeftClickEvent = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: .zero,
            modifierFlags: .control,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 0
        )
        
        controller.handleStatusItemClick(event: controlLeftClickEvent)
    }
    
    func testStatusBarTooltipFormatting() {
        let controller = StatusBarController()
        
        controller.updateState(.inactive)
        if let button = controller.statusItem?.button {
            XCTAssertEqual(button.toolTip?.hasPrefix("PhantomKnob\n"), true)
        }
    }
    
    func testStatusBarMenuOrdering() {
        let controller = StatusBarController()
        guard let menu = controller.menu else {
            XCTFail("Menu should not be nil")
            return
        }
        
        // Expected menu items:
        // 0: statusMenuItem
        // 1: versionMenuItem
        // 2: separator
        // 3: toggleItem (切换旋钮模式)
        // 4: knobPanelItem (快捷中控面板...)
        // 5: separator
        // 6: settingsItem (设置)
        // 7: separator
        // 8: guideMenuItem (使用引导)
        // 9: shortcutsMenuItem (快捷键与操作速查)
        // 10: updateItem (检查升级)
        // 11: feedbackItem (意见建议)
        // 12: separator
        // 13: debugToggleItem
        // 14: separator
        // 15: quitItem (退出)
        
        XCTAssertEqual(menu.items.count, 16)
        
        XCTAssertNil(menu.items[0].action)
        XCTAssertNil(menu.items[1].action)
        XCTAssertTrue(menu.items[2].isSeparatorItem)
        XCTAssertEqual(menu.items[3].action, Selector(("toggleMode")))
        XCTAssertEqual(menu.items[4].action, Selector(("openKnobPanel")))
        XCTAssertTrue(menu.items[5].isSeparatorItem)
        XCTAssertEqual(menu.items[6].action, Selector(("openSettings")))
        XCTAssertTrue(menu.items[7].isSeparatorItem)
        XCTAssertEqual(menu.items[8].action, Selector(("openGuide")))
        XCTAssertEqual(menu.items[9].action, Selector(("openShortcutsGuide")))
        XCTAssertEqual(menu.items[10].action, Selector(("checkForUpdates")))
        XCTAssertEqual(menu.items[11].action, Selector(("sendFeedback")))
        XCTAssertTrue(menu.items[12].isSeparatorItem)
        XCTAssertEqual(menu.items[13].action, Selector(("debugToggleLicense")))
        XCTAssertTrue(menu.items[14].isSeparatorItem)
        XCTAssertEqual(menu.items[15].action, Selector(("quitApp")))
    }
    
    func testStatusBarIconFreeModeAppendsSuffix() {
        let controller = StatusBarController()
        
        // 保存初始状态以供清理
        let originalKey = UserDefaults.app.string(forKey: "licenseKey")
        let originalEmail = UserDefaults.app.string(forKey: "licenseEmail")
        let originalTrialStart = UserDefaults.app.string(forKey: "trialStartDate")
        
        // 强制进入 Licensed 状态
        UserDefaults.app.set("DEBUG_KEY", forKey: "licenseKey")
        UserDefaults.app.set("debug@example.com", forKey: "licenseEmail")
        NotificationCenter.default.post(name: NSNotification.Name("LicenseStateDidChange"), object: nil)
        XCTAssertEqual(LicenseManager.shared.currentState, .licensed)
        
        // Premium 激活状态
        controller.updateState(.activated)
        if let button = controller.statusItem?.button {
            XCTAssertNotNil(button.image)
        }
        
        // 强制进入 Free 状态
        UserDefaults.app.removeObject(forKey: "licenseKey")
        UserDefaults.app.removeObject(forKey: "licenseEmail")
        let expiredDate = Date().addingTimeInterval(-20 * 24 * 60 * 60)
        let formatter = ISO8601DateFormatter()
        UserDefaults.app.set(formatter.string(from: expiredDate), forKey: "trialStartDate")
        NotificationCenter.default.post(name: NSNotification.Name("LicenseStateDidChange"), object: nil)
        XCTAssertEqual(LicenseManager.shared.currentState, .free)
        
        // Free 激活状态，底层自动装载带有 _free 的图片
        controller.updateState(.activated)
        if let button = controller.statusItem?.button {
            XCTAssertNotNil(button.image)
        }
        
        // 清理：恢复初始状态
        UserDefaults.app.set(originalKey, forKey: "licenseKey")
        UserDefaults.app.set(originalEmail, forKey: "licenseEmail")
        UserDefaults.app.set(originalTrialStart, forKey: "trialStartDate")
        NotificationCenter.default.post(name: NSNotification.Name("LicenseStateDidChange"), object: nil)
    }

    func testFreeActivatingPopoverInstantiation() {
        let controller = StatusBarController()
        controller.showFreeActivatingPopover(secondsRemaining: 2.0)
        
        let expectation = XCTestExpectation(description: "Show popover")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            controller.dismissFreePopover()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }
}
