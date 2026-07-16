# 设置面板精简与权限动态刷新实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 精简设置面板，移除触控板检测冗余卡片，将语言设置卡片置顶，并实现辅助功能权限在应用重新激活时的动态自动刷新。

**架构：**
- 修改 `SettingsView.swift` 移除触控板卡片、`isTouchpadDetected` 状态和 `resetAndRedetect()`，将 `Language Section Card` 布局移至最顶部。
- 在 `GeneralSettingsView` 最外层容器增加对 `NSApplication.didBecomeActiveNotification` 的监听器，重置 `hasAccessibilityPermission` 和 `launchAtLogin` 状态以动态刷新 UI。

**技术栈：** SwiftUI, AppKit

---

### 任务 1：重构 `SettingsView.swift` 的状态变量与布局顺序

**文件：**
- 修改：`PhantomKnob/View/SettingsView.swift` ([SettingsView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/SettingsView.swift))

- [ ] **步骤 1：移除冗余的状态变量与方法**
  在 `GeneralSettingsView` 结构体顶部（第 112-117 行）移除 `@State private var isTouchpadDetected`。
  在 `GeneralSettingsView` 底部（第 434-441 行）移除 `resetAndRedetect()` 方法。

- [ ] **步骤 2：语言卡片置顶与移除触控板卡片**
  将 `Language Section Card`（第 274-329 行）移动到 `Hotkey Section Card`（第 120 行）之上。
  完全删除 `Trackpad Diagnostics Section Card` 布局代码（第 330-380 行）。

- [ ] **步骤 3：增加应用焦点变化时的自动状态刷新**
  在 `GeneralSettingsView` 的 `onAppear` 后增加对 `NSApplication.didBecomeActiveNotification` 的监听：
  ```swift
  .onAppear {
      hasAccessibilityPermission = AXIsProcessTrusted()
      launchAtLogin = LaunchAtLoginService.shared.isEnabled
  }
  .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      hasAccessibilityPermission = AXIsProcessTrusted()
      launchAtLogin = LaunchAtLoginService.shared.isEnabled
  }
  ```

- [ ] **步骤 4：编译并运行测试以确认一切正常**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -sdk macosx -destination 'platform=macOS' test`
  预期：测试通过 (TEST SUCCEEDED)。

- [ ] **步骤 5：Commit**
  ```bash
  git add PhantomKnob/View/SettingsView.swift
  git commit -m "refactor: remove trackpad diagnostics card and move language selection to top of settings"
  ```
