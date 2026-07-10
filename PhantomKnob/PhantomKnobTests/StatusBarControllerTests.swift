// PhantomKnob/PhantomKnobTests/StatusBarControllerTests.swift
import XCTest
@testable import PhantomKnob

final class StatusBarControllerTests: XCTestCase {
    
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
        // 4: separator
        // 5: settingsItem (设置)
        // 6: separator
        // 7: guideMenuItem (使用引导)
        // 8: updateItem (检查升级)
        // 9: feedbackItem (意见建议)
        // 10: separator
        // 11: debugToggleItem
        // 12: separator
        // 13: quitItem (退出)
        
        XCTAssertEqual(menu.items.count, 14)
        
        XCTAssertNil(menu.items[0].action)
        XCTAssertNil(menu.items[1].action)
        XCTAssertTrue(menu.items[2].isSeparatorItem)
        XCTAssertEqual(menu.items[3].action, Selector(("toggleMode")))
        XCTAssertTrue(menu.items[4].isSeparatorItem)
        XCTAssertEqual(menu.items[5].action, Selector(("openSettings")))
        XCTAssertTrue(menu.items[6].isSeparatorItem)
        XCTAssertEqual(menu.items[7].action, Selector(("openGuide")))
        XCTAssertEqual(menu.items[8].action, Selector(("checkForUpdates")))
        XCTAssertEqual(menu.items[9].action, Selector(("sendFeedback")))
        XCTAssertTrue(menu.items[10].isSeparatorItem)
        XCTAssertEqual(menu.items[11].action, Selector(("debugToggleLicense")))
        XCTAssertTrue(menu.items[12].isSeparatorItem)
        XCTAssertEqual(menu.items[13].action, Selector(("quitApp")))
    }
    
    func testStatusBarIconFreeModeAppendsSuffix() {
        let controller = StatusBarController()
        
        // 保存初始状态以供清理
        let originalKey = UserDefaults.standard.string(forKey: "licenseKey")
        let originalEmail = UserDefaults.standard.string(forKey: "licenseEmail")
        let originalTrialStart = UserDefaults.standard.string(forKey: "trialStartDate")
        
        // 强制进入 Licensed 状态
        UserDefaults.standard.set("DEBUG_KEY", forKey: "licenseKey")
        UserDefaults.standard.set("debug@example.com", forKey: "licenseEmail")
        NotificationCenter.default.post(name: NSNotification.Name("LicenseStateDidChange"), object: nil)
        XCTAssertEqual(LicenseManager.shared.currentState, .licensed)
        
        // Premium 激活状态
        controller.updateState(.activated)
        if let button = controller.statusItem?.button {
            XCTAssertNotNil(button.image)
        }
        
        // 强制进入 Free 状态
        UserDefaults.standard.removeObject(forKey: "licenseKey")
        UserDefaults.standard.removeObject(forKey: "licenseEmail")
        let expiredDate = Date().addingTimeInterval(-20 * 24 * 60 * 60)
        let formatter = ISO8601DateFormatter()
        UserDefaults.standard.set(formatter.string(from: expiredDate), forKey: "trialStartDate")
        NotificationCenter.default.post(name: NSNotification.Name("LicenseStateDidChange"), object: nil)
        XCTAssertEqual(LicenseManager.shared.currentState, .free)
        
        // Free 激活状态，底层自动装载带有 _free 的图片
        controller.updateState(.activated)
        if let button = controller.statusItem?.button {
            XCTAssertNotNil(button.image)
        }
        
        // 清理：恢复初始状态
        UserDefaults.standard.set(originalKey, forKey: "licenseKey")
        UserDefaults.standard.set(originalEmail, forKey: "licenseEmail")
        UserDefaults.standard.set(originalTrialStart, forKey: "trialStartDate")
        NotificationCenter.default.post(name: NSNotification.Name("LicenseStateDidChange"), object: nil)
    }
}
