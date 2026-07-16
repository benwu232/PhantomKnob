# 设置面板精简与权限动态刷新设计规范 (Settings Panel Refinement & Active Status Refresh)

本文档规范了 PhantomKnob 设置面板的布局精简、冗余功能移除，以及辅助功能权限授权后状态瞬时更新的交互行为升级。

## 1. 升级目标 (Goals)

1. **移除冗余的触控板检测卡片**：由于应用在启动时已进行强检测（无触控板时会自动弹窗退出），且菜单栏已提供“使用指南”入口，设置面板中的触控板检测属冗余组件。完全移除该卡片可释放宝贵的垂直屏幕高度，使面板更清爽。
2. **语言设置项置顶**：将“语言设置卡片”（Language Card）调整至设置面板的最顶部，位于热键设置（Hotkey Card）之上，便于多国语言用户在打开设置的第一时间进行选择切换。
3. **辅助权限状态瞬时刷新与图标固定**：
   * 监听应用焦点的唤醒事件，保证用户从系统设置（System Settings）授予辅助功能权限切回 PhantomKnob 时，设置面板上的“未授权”状态瞬间更新为“已授权”，消除页面延迟与感知卡顿。
   * 将辅助功能卡片头部图标改为固定的静态图标 `accessibility`，以与其他卡片的静态风格保持一致，仅保留其文字和颜色的红/绿动态状态。
4. **语言选择项及面板英文项完全汉化**：
   * 在语言选择下拉框中，将“英文”和“简体中文”选项改为本地化文本（`language.english` 和 `language.chinese`），使其在中文环境下显示为“英文”/“简体中文”。
   * 补全设置面板内因未提供本地化 key 而在中文下仍回退显示为英文的若干文本（“Privacy”、“Send crash reports”、“Share anonymous usage statistics” 和 “Automatically check for updates”），使其中文翻译完全补全。
5. **“启动”和“隐私”卡片左对齐拉伸**：为“启动”与“隐私”设置卡片添加 `.frame(maxWidth: .infinity, alignment: .leading)`，使其中的 Checkbox 选项统一向左对齐，并让卡片宽度自动拉伸填满，与上方的热键、语言卡片对齐风格保持一致。
6. **保留并稳固崩溃日志/匿名统计卡片**：确认 Sentry 与 TelemetryDeck 遥测功能的正常启用，并维护其 opt-out 逻辑正常。

---

## 2. 详细设计 (Detailed Design)

### 2.1 移除触控板卡片与布局顺序调整
* **移除触控板检测**：
  * 在 [SettingsView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/SettingsView.swift) 的 `GeneralSettingsView` 结构体中，移除 `Trackpad Diagnostics Section Card` 相关的布局代码：
    * `VStack`（含有标题 `Trackpad`、图标 `hand.draw`、提示信息和 `Redetect…` 按钮）。
  * 移除 `GeneralSettingsView` 顶部的局部状态变量 `@State private var isTouchpadDetected`。
  * 移除私有工具方法 `resetAndRedetect()`。
* **语言设置卡片置顶**：
  * 将 `Language Section Card` 整体向上移动，将其排在 `GeneralSettingsView` 的 `body` 视图层次首位，成为第一个卡片。
  * 卡片顺序重新整理为：
    1. **Language Card** (Language)
    2. **Hotkey Card** (Hotkey)
    3. **Accessibility Card** (Accessibility Permission)
    4. **Startup & Updates Card** (Startup & Updates)
    5. **Privacy Card** (Privacy)

### 2.2 动态监测并自动刷新辅助功能状态与图标固定
* **实现逻辑**：
  在 `GeneralSettingsView` 容器 of `SettingsView.swift` 底部（或 `.onAppear` 同层）附加 `.onReceive` 监听器，监听来自系统通知中心的 **`NSApplication.didBecomeActiveNotification`**：
  ```swift
  .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      hasAccessibilityPermission = AXIsProcessTrusted()
      launchAtLogin = LaunchAtLoginService.shared.isEnabled
  }
  ```
* **图标固定**：
  * 在 `Accessibility Section Card` 头部，将 `Image(systemName: hasAccessibilityPermission ? "checkmark.shield" : "hand.raised.badge.ellipsis")` 修改为固定的静态图标 `Image(systemName: "accessibility")`。
  * 保留其颜色指示逻辑 `.foregroundColor(hasAccessibilityPermission ? .green : .red)`。

### 2.3 语言选择本地化与英文项汉化
* **语言展示名称修改**：
  在 [AppLanguageManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/AppLanguageManager.swift) 中，将 `displayName` 属性修改为：
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
* **本地化资源配置**：
  在 [Localizable.xcstrings](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Localizable.xcstrings) 中新增以下键值及中文翻译：
  * `language.english` -> 英文: `"English"`, 中文: `"英文"`
  * `language.chinese` -> 英文: `"Simplified Chinese"`, 中文: `"简体中文"`
  * `settings.section.privacy` -> 英文: `"Privacy"`, 中文: `"隐私设置"`
  * `settings.crashReporting` -> 英文: `"Send crash reports"`, 中文: `"发送崩溃报告"`
  * `settings.analytics` -> 英文: `"Share anonymous usage statistics"`, 中文: `"允许使用匿名统计信息"`
  * `settings.startup.autoUpdate` -> 英文: `"Automatically check for updates"`, 中文: `"自动检查更新"`

### 2.4 “启动”和“隐私”卡片左对齐拉伸
* **卡片宽度与内容对齐**：
  * 为 `Startup & Updates Section Card` 和 `Privacy Section Card` 的最外层 `VStack` 分别附加：
    `.frame(maxWidth: .infinity, alignment: .leading)`
  * 确保所有 Toggle 的子项排布统一靠左。

---

## 3. 验证计划 (Verification Plan)

### 3.1 自动化测试
* 运行项目单元测试，确保没有编译或控制逻辑错误：
  `xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob`

### 3.2 手动验证
1. **排版顺序与卡片移除验证**：打开设置面板，确认 `Trackpad` 卡片已不可见；验证首个卡片是否为 `Language`（语言）设置，且其下方是 `Hotkey`（快捷键）设置。
2. **辅助功能卡片头部图标验证**：确认图标在授权前后均保持为 `accessibility`（轮椅人像图标），仅颜色发生绿/红变化。
3. **“启动”和“隐私”卡片布局验证**：确认该两个卡片的背景宽度延伸填满，且里面的复选框靠左对齐。
4. **语言选择列表验证**：切换至中文环境，确认下拉菜单选项显示为“系统默认”、“英文”、“简体中文”；切换至英文环境，确认选项显示为“System Default”、“English”、“Simplified Chinese”。
5. **英文项完全汉化验证**：切换至中文环境，确认“隐私”、“发送崩溃报告”、“允许使用匿名统计信息”以及“自动检查更新”已完全显示为中文，无任何遗留英文单词。
6. **权限动态重加载**：
   * 在未授权辅助功能权限时打开设置面板，卡片应正确高亮警告红边框。
   * 点击按钮跳转到“系统设置”，勾选授予权限.
   * 切换回 PhantomKnob 的设置面板，**验证卡片是否自动刷新为绿色（已授权状态）**，无需重新打开设置面板。
