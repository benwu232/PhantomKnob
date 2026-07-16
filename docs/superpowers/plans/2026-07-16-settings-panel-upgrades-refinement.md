# 设置面板精简与权限动态刷新实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 精简设置面板，移除触控板检测冗余卡片，将语言设置卡片置顶，实现辅助功能权限在应用重新激活时的动态自动刷新，并优化样式一致性（固定辅助功能图标、下拉语言选项本地化、启动与隐私居左对齐）。

**架构：**
- 修改 `SettingsView.swift` 移除触控板卡片、`isTouchpadDetected` 状态和 `resetAndRedetect()`，将 `Language Section Card` 布局移至最顶部。
- 在 `GeneralSettingsView` 最外层容器增加对 `NSApplication.didBecomeActiveNotification` 的监听器，重置 `hasAccessibilityPermission` 和 `launchAtLogin` 状态以动态刷新 UI。
- 修改 `SettingsView.swift` 中辅助功能卡片的头部图标为静态的 `accessibility`；将“启动和更新”与“隐私”卡片的对齐方式调整为靠左延伸。
- 修改 `AppLanguageManager.swift` 开启语言选项的本地化字符串查找；在 `Localizable.xcstrings` 中补充对应字段。

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

### 任务 2：样式一致性精细化微调与语言本地化

**文件：**
- 修改：`PhantomKnob/View/SettingsView.swift` ([SettingsView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/SettingsView.swift))
- 修改：`PhantomKnob/Service/AppLanguageManager.swift` ([AppLanguageManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/AppLanguageManager.swift))
- 修改：`PhantomKnob/Localizable.xcstrings` ([Localizable.xcstrings](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Localizable.xcstrings))

- [ ] **步骤 1：固定辅助功能卡片头部图标**
  在 `SettingsView.swift` 中，将辅助功能卡片（Accessibility Section Card）的头部图标改为 `Image(systemName: "accessibility")`，并保留原有的 `.foregroundColor(hasAccessibilityPermission ? .green : .red)`。
  同时确保 `Text(String(localized: "settings.section.accessibility", ...))` 正常保留。

- [ ] **步骤 2：设置“启动”与“隐私”卡片为左对齐全宽**
  在 `SettingsView.swift` 中，为 `Startup & Updates Section Card` 和 `Privacy Section Card` 的外层 `VStack` 加上 `.frame(maxWidth: .infinity, alignment: .leading)`，使卡片内复选框靠左对齐且整行宽度占满。

- [ ] **步骤 3：实现语言选择列表选项的本地化**
  修改 `AppLanguageManager.swift` 中 `displayName` 计算属性：
  ```swift
  public var displayName: String {
      switch self {
      case .system:
          return String(localized: "language.system", defaultValue: "System Default")
      case .english:
          return String(localized: "language.english", defaultValue: "English")
      case .chinese:
          return String(localized: "language.chinese", defaultValue: "Simplified Chinese")
      }
  }
  ```
  使用 Xcode 编辑或直接替换修改 `Localizable.xcstrings` 插入新键值：
  - `language.english` -> 英文: `"English"`, 中文: `"英文"`
  - `language.chinese` -> 英文: `"Simplified Chinese"`, 中文: `"简体中文"`

- [ ] **步骤 4：编译并运行测试以确认一切正常**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -sdk macosx -destination 'platform=macOS' test`
  预期：测试通过 (TEST SUCCEEDED)。

- [ ] **步骤 5：Commit**
  ```bash
  git add PhantomKnob/View/SettingsView.swift PhantomKnob/Service/AppLanguageManager.swift PhantomKnob/Localizable.xcstrings
  git commit -m "style: fix accessibility icon, align cards left and localize language picker options"
  ```
