# 设置面板精简与权限动态刷新设计规范 (Settings Panel Refinement & Active Status Refresh)

本文档规范了 PhantomKnob 设置面板的布局精简、冗余功能移除，以及辅助功能权限授权后状态瞬时更新的交互行为升级。

## 1. 升级目标 (Goals)

1. **移除冗余的触控板检测卡片**：由于应用在启动时已进行强检测（无触控板时会自动弹窗退出），且菜单栏已提供“使用指南”入口，设置面板中的触控板检测属冗余组件。完全移除该卡片可释放宝贵的垂直屏幕高度，使面板更清爽。
2. **语言设置项置顶**：将“语言设置卡片”（Language Card）调整至设置面板的最顶部，位于热键设置（Hotkey Card）之上，便于多国语言用户在打开设置的第一时间进行选择切换。
3. **辅助权限状态瞬时刷新**：监听应用焦点的唤醒事件，保证用户从系统设置（System Settings）授予辅助功能权限切回 PhantomKnob 时，设置面板上的“未授权”状态瞬间更新为“已授权”，消除页面延迟与感知卡顿。
4. **保留并稳固崩溃日志/匿名统计卡片**：确认 Sentry 与 TelemetryDeck 遥测功能的正常启用，并维护其 opt-out 逻辑正常。

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

### 2.2 动态监测并自动刷新辅助功能状态
* **实现逻辑**：
  在 `GeneralSettingsView` 容器的外部 `VStack` 底部（或 `.onAppear` 同层）附加 `.onReceive` 监听器，监听来自系统通知中心的 **`NSApplication.didBecomeActiveNotification`**：
  ```swift
  .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      hasAccessibilityPermission = AXIsProcessTrusted()
      launchAtLogin = LaunchAtLoginService.shared.isEnabled
  }
  ```
* **效果**：
  * 用户切出应用在“系统设置”勾选授权，再点击返回 PhantomKnob 时，触发 `didBecomeActive` 通知。
  * 瞬时拉取最新的信任状态和自启服务状态，驱动状态变量刷新，从而让卡片外边框变为绿色，按钮在第一时间安全隐去。

### 2.3 保障 Sentry 与 TelemetryDeck 开关就绪
* **状态卡片**：
  保留 Privacy Card 内的两个开关选项，无需对 `disableCrashReporting` / `disableAnalytics` 相关的存取和上报做任何改变。

---

## 3. 验证计划 (Verification Plan)

### 3.1 自动化测试
* 运行项目单元测试，确保没有编译或控制逻辑错误：
  `xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob`

### 3.2 手动验证
1. **排版顺序与卡片移除验证**：打开设置面板，确认 `Trackpad` 卡片已不可见；验证首个卡片是否为 `Language`（语言）设置，且其下方是 `Hotkey`（快捷键）设置。
2. **权限动态重加载**：
   * 在未授权辅助功能权限时打开设置面板，卡片应正确高亮警告红边框。
   * 点击按钮跳转到“系统设置”，勾选授予权限。
   * 切换回 PhantomKnob 的设置面板，**验证卡片是否自动刷新为绿色（已授权状态）**，无需重新打开设置面板。
