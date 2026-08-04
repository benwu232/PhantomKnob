// SettingsWindowLanguageSwitchTests.swift
// 复现 Bug: 切换语言时，resignKey 导致设置窗口消失
// TDD Red 阶段: 先写失败测试，再修复

import XCTest
@testable import PhantomKnob

final class SettingsWindowLanguageSwitchTests: XCTestCase {
    private let suiteName = "com.phantomknob.SettingsWindowLanguageSwitchTests"

    override func setUp() {
        super.setUp()
        UserDefaults.app = UserDefaults(suiteName: suiteName) ?? .standard
        UserDefaults.app.removePersistentDomain(forName: suiteName)
        // 确保从已知状态开始
        SettingsWindowController.shared.hide()
    }

    override func tearDown() {
        SettingsWindowController.shared.hide()
        UserDefaults.app.removePersistentDomain(forName: suiteName)
        UserDefaults.app = .standard
        super.tearDown()
    }

    // MARK: - Bug 复现测试

    /// 验证：设置窗口有 attachedSheet 时，windowDidResignKey 不应关闭窗口
    ///
    /// 问题根因：NSAlert sheet 弹出时窗口 resign key，触发 windowDidResignKey → hide()
    /// 预期行为：有 attachedSheet 时 windowDidResignKey 不应调用 hide()
    func testWindowStaysVisibleWhenHasAttachedSheet() {
        // Arrange: 打开设置窗口
        SettingsWindowController.shared.show()
        XCTAssertTrue(SettingsWindowController.shared.isVisible, "设置窗口应先可见")

        // Act: 模拟 windowDidResignKey 在有 attachedSheet 的情况下被触发
        // 通过直接获取 window 并检查 controller 的 delegate 响应
        // 因无法在 unit test 中真实弹出 sheet，改为测试 SettingsWindowController
        // 是否暴露了 shouldHideOnResignKey 逻辑
        SettingsWindowController.shared.simulateResignKeyWithAttachedSheet()

        // Assert: 窗口仍然可见（有 sheet 时不应关闭）
        XCTAssertTrue(
            SettingsWindowController.shared.isVisible,
            "有 attachedSheet 时 windowDidResignKey 不应关闭设置窗口"
        )
    }

    /// 验证：没有 attachedSheet 时，windowDidResignKey 正常关闭窗口
    func testWindowHidesOnResignKeyWithoutAttachedSheet() {
        // Arrange
        SettingsWindowController.shared.show()
        XCTAssertTrue(SettingsWindowController.shared.isVisible)

        // Act: 模拟没有 sheet 时的 resignKey
        SettingsWindowController.shared.simulateResignKeyWithoutAttachedSheet()

        // Assert: 窗口应关闭
        XCTAssertFalse(
            SettingsWindowController.shared.isVisible,
            "无 sheet 时 windowDidResignKey 应关闭设置窗口"
        )
    }
}
