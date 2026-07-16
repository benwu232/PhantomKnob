# 设置面板精简与权限动态刷新实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 精简设置面板，移除触控板检测冗余卡片，将语言设置卡片置顶，实现辅助功能权限在应用重新激活时的动态自动刷新，并优化样式一致性（固定辅助功能图标、下拉语言选项本地化、启动与隐私居左对齐），最后完全汉化中文环境下的所有设置面板英文文本。

**架构：**
- 修改 `SettingsView.swift` 移除触控板卡片、`isTouchpadDetected` 状态和 `resetAndRedetect()`，将 `Language Section Card` 布局移至最顶部。
- 在 `GeneralSettingsView` 最外层容器增加对 `NSApplication.didBecomeActiveNotification` 的监听器，重置 `hasAccessibilityPermission` 和 `launchAtLogin` 状态以动态刷新 UI。
- 修改 `SettingsView.swift` 中辅助功能卡片的头部图标为静态的 `accessibility`；将“启动和更新”与“隐私”卡片的对齐方式调整为靠左延伸。
- 修改 `AppLanguageManager.swift` 开启语言选项的本地化字符串查找；在 `Localizable.xcstrings` 中补充对应字段。
- 在 `Localizable.xcstrings` 中补充缺失的 4 个设置文本翻译。

**技术栈：** SwiftUI, AppKit

---

### 任务 1：重构 `SettingsView.swift` 的状态变量与布局顺序（已完成）

**文件：**
- 修改：`PhantomKnob/View/SettingsView.swift` ([SettingsView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/SettingsView.swift))

- [x] **步骤 1：移除冗余的状态变量与方法**
- [x] **步骤 2：语言卡片置顶与移除触控板卡片**
- [x] **步骤 3：增加应用焦点变化时的自动状态刷新**
- [x] **步骤 4：编译并运行测试以确认一切正常**
- [x] **步骤 5：Commit**

---

### 任务 2：样式一致性精细化微调与语言本地化（已完成）

**文件：**
- 修改：`PhantomKnob/View/SettingsView.swift` ([SettingsView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/SettingsView.swift))
- 修改：`PhantomKnob/Service/AppLanguageManager.swift` ([AppLanguageManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/AppLanguageManager.swift))
- 修改：`PhantomKnob/Localizable.xcstrings` ([Localizable.xcstrings](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Localizable.xcstrings))

- [x] **步骤 1：固定辅助功能卡片头部图标**
- [x] **步骤 2：设置“启动”与“隐私”卡片为左对齐全宽**
- [x] **步骤 3：实现语言选择列表选项的本地化**
- [x] **步骤 4：编译并运行测试以确认一切正常**
- [x] **步骤 5：Commit**

---

### 任务 3：补充设置面板英文文本汉化

**文件：**
- 修改：`PhantomKnob/Localizable.xcstrings` ([Localizable.xcstrings](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Localizable.xcstrings))

- [ ] **步骤 1：在 Localizable.xcstrings 中补充缺失翻译**
  向 `Localizable.xcstrings` 补充以下 4 个字段：
  - `settings.section.privacy` -> 英文: `"Privacy"`, 中文: `"隐私设置"`
  - `settings.crashReporting` -> 英文: `"Send crash reports"`, 中文: `"发送崩溃报告"`
  - `settings.analytics` -> 英文: `"Share anonymous usage statistics"`, 中文: `"允许使用匿名统计信息"`
  - `settings.startup.autoUpdate` -> 英文: `"Automatically check for updates"`, 中文: `"自动检查更新"`

- [ ] **步骤 2：编译并运行测试以确认一切正常**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -sdk macosx -destination 'platform=macOS' test`
  预期：测试通过 (TEST SUCCEEDED)。

- [ ] **步骤 3：Commit**
  ```bash
  git add PhantomKnob/Localizable.xcstrings
  git commit -m "locale: translate settings privacy and autoupdate keys to Chinese"
  ```
