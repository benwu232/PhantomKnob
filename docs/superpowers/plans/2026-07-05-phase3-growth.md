# Phase 3 增长功能 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现自动更新、使用分析、用户反馈、营销落地页展示、版本更新日志弹窗等功能以提升用户留存和活跃度。

**架构：**
1. **Sparkle 模块**：集成 `Sparkle` SDK，封装在 `UpdateManager` 单例中，由主应用及菜单栏触发更新检测。
2. **使用分析模块**：通过 `TelemetryClient` SDK 监测生命周期和关键动作，由 `AnalyticsManager` 控制配置及 opt-out 设置。
3. **反馈及日志模块**：利用 `mailto` 打开默认客户端回发设备调试信息；在应用冷启动检测本地版本缓存并解析 `release-notes.json` 触发毛玻璃版更新日志弹窗。
4. **营销展示**：采用 `generate_image` 生成核心界面 3 张 16:10 mockup 截图，扩充落地页布局并加设悬浮拟态播放器 placeholder。

**技术栈：** Swift 5.9, SwiftUI, AppKit, Sparkle 2.x, TelemetryDeck SwiftClient, HTML/CSS.

---

## 任务列表

### 任务 1：SPM 依赖和 XcodeGen 配置
**文件：**
- 修改：`PhantomKnob/project.yml`
- 修改：`PhantomKnob/Info.plist`

- [ ] **步骤 1：修改 project.yml 添加 Sparkle 与 TelemetryClient 依赖**
  修改 `PhantomKnob/project.yml` 在 `packages` 下增加：
  ```yaml
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    from: "2.5.0"
  TelemetryClient:
    url: https://github.com/TelemetryDeck/SwiftClient
    from: "1.0.0"
  ```
  同时，在 `targets/PhantomKnob/dependencies` 增加：
  ```yaml
  - package: Sparkle
    product: Sparkle
  - package: TelemetryClient
    product: TelemetryClient
  ```

- [ ] **步骤 2：添加 Sparkle info 键**
  修改 `targets/PhantomKnob/info/properties`，在 Info.plist 字典中添加以下配置：
  ```yaml
  SUFeedURL: "https://phantomknob.com/appcast.xml"
  SUPublicEDKey: "PLACEHOLDER_PUBLIC_KEY"
  SUEnableAutomaticChecks: true
  ```

- [ ] **步骤 3：生成 Xcode 项目验证依赖配置**
  运行：`cd PhantomKnob && xcodegen generate`
  预期：生成成功，Package Dependencies 成功包含 Sparkle 与 TelemetryClient。

- [ ] **步骤 4：Commit**
  ```bash
  git add PhantomKnob/project.yml
  git commit -m "feat: configure Sparkle and TelemetryClient dependencies in project.yml"
  ```

---

### 任务 2：创建 UpdateManager 与 AnalyticsManager
**文件：**
- 创建：`PhantomKnob/Service/UpdateManager.swift`
- 创建：`PhantomKnob/Service/AnalyticsManager.swift`

- [ ] **步骤 1：创建 UpdateManager.swift**
  写入以下代码：
  ```swift
  import Foundation
  import Sparkle

  final class UpdateManager: ObservableObject {
      static let shared = UpdateManager()
      
      private let updaterController: SPUStandardUpdaterController
      
      private init() {
          updaterController = SPUStandardUpdaterController(
              startingUpdater: true,
              updaterDelegate: nil,
              userDriverDelegate: nil
          )
      }
      
      func checkForUpdates() {
          updaterController.checkForUpdates(nil)
      }
      
      var canCheckForUpdates: Bool {
          updaterController.updater.canCheckForUpdates
      }
  }
  ```

- [ ] **步骤 2：创建 AnalyticsManager.swift**
  写入以下代码：
  ```swift
  import Foundation
  import TelemetryClient

  final class AnalyticsManager {
      static let shared = AnalyticsManager()
      
      private init() {}
      
      func initialize() {
          guard !UserDefaults.standard.bool(forKey: "disableAnalytics") else { return }
          let config = TelemetryManagerConfiguration(appID: "YOUR_TELEMETRYDECK_APP_ID")
          TelemetryManager.initialize(with: config)
          trackEvent("appLaunched")
      }
      
      func trackEvent(_ name: String, parameters: [String: String] = [:]) {
          guard !UserDefaults.standard.bool(forKey: "disableAnalytics") else { return }
          TelemetryManager.send(name, with: parameters)
      }
  }
  ```

- [ ] **步骤 3：集成启动生命周期**
  修改 `PhantomKnob/App/PhantomKnobApp.swift` 中的 `AppState.init()`：
  ```swift
  // 在 init() 首行或者 Sentry 之后初始化 TelemetryDeck
  AnalyticsManager.shared.initialize()
  ```

- [ ] **步骤 4：编译验证**
  运行：`xcodebuild -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob build`
  预期：编译成功，无类型缺失错误。

- [ ] **步骤 5：Commit**
  ```bash
  git add PhantomKnob/Service/UpdateManager.swift PhantomKnob/Service/AnalyticsManager.swift PhantomKnob/App/PhantomKnobApp.swift
  git commit -m "feat: implement UpdateManager and AnalyticsManager wrappers"
  ```

---

### 任务 3：反馈选项与状态栏菜单交互
**文件：**
- 修改：`PhantomKnob/Service/StatusBarController.swift`

- [ ] **步骤 1：在 setupMenu 中添加更新与反馈菜单项**
  修改 `PhantomKnob/Service/StatusBarController.swift` 中的 `setupMenu()`。在 Settings 菜单项前加入 Check for Updates 和 Send Feedback：
  ```swift
  let updateItem = NSMenuItem(
      title: String(localized: "menu.checkUpdates", defaultValue: "Check for Updates…"),
      action: #selector(checkForUpdates),
      keyEquivalent: ""
  )
  updateItem.target = self
  menu?.addItem(updateItem)
  
  let feedbackItem = NSMenuItem(
      title: String(localized: "menu.feedback", defaultValue: "Send Feedback…"),
      action: #selector(sendFeedback),
      keyEquivalent: ""
  )
  feedbackItem.target = self
  menu?.addItem(feedbackItem)
  
  menu?.addItem(NSMenuItem.separator())
  ```

- [ ] **步骤 2：实现 @objc 反馈与更新检测函数**
  在 `StatusBarController` 中增加：
  ```swift
  @objc private func checkForUpdates() {
      UpdateManager.shared.checkForUpdates()
  }

  @objc private func sendFeedback() {
      let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
      let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
      let os = ProcessInfo.processInfo.operatingSystemVersionString
      let model = Host.current().localizedName ?? "Unknown Mac"
      let license = "\(LicenseManager.shared.currentState)"

      let subject = "PhantomKnob Feedback (v\(version) build \(build))"
      let body = """
      
      
      ---
      App: PhantomKnob v\(version) (\(build))
      macOS: \(os)
      Device: \(model)
      License: \(license)
      """

      let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
      let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
      let mailto = "mailto:support@phantomknob.com?subject=\(encodedSubject)&body=\(encodedBody)"

      if let url = URL(string: mailto) {
          NSWorkspace.shared.open(url)
      }
      
      AnalyticsManager.shared.trackEvent("feedbackClicked")
  }
  ```

- [ ] **步骤 3：编译检查**
  运行：`xcodebuild -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob build`
  预期：编译成功。

- [ ] **步骤 4：Commit**
  ```bash
  git add PhantomKnob/Service/StatusBarController.swift
  git commit -m "feat: add Check for Updates and Send Feedback items to Status Bar menu"
  ```

---

### 任务 4：隐私与自动更新设置
**文件：**
- 修改：`PhantomKnob/View/SettingsView.swift`

- [ ] **步骤 1：添加设置项**
  修改 `PhantomKnob/View/SettingsView.swift`，在设置表单中增加自动更新 Toggle 及使用分析 Toggle：
  ```swift
  @AppStorage("autoCheckUpdates") private var autoCheckUpdates = true
  @AppStorage("disableAnalytics") private var disableAnalytics = false
  ```
  在 SwiftUI 视图的适当 Section (例如 General 或 Privacy 区域) 渲染这两个 Toggle。当用户关闭使用分析时，`AnalyticsManager` 将自动停止事件的记录。

- [ ] **步骤 2：集成逻辑**
  确保 toggle 的行为可以触发：
  ```swift
  Toggle(String(localized: "settings.autoUpdate", defaultValue: "Automatically check for updates"), isOn: $autoCheckUpdates)
      .onChange(of: autoCheckUpdates) { newValue in
          // 可以在此处同步更新 Sparkle 的自动检查状态
      }
  
  Toggle(String(localized: "settings.disableAnalytics", defaultValue: "Share anonymous usage statistics"), isOn: Binding(
      get: { !disableAnalytics },
      set: { disableAnalytics = !$0 }
  ))
  ```

- [ ] **步骤 3：编译验证**
  运行：`xcodebuild -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob build`
  预期：编译成功。

- [ ] **步骤 4：Commit**
  ```bash
  git add PhantomKnob/View/SettingsView.swift
  git commit -m "feat: add auto-update and analytics toggles to SettingsView"
  ```

---

### 任务 5：Release Notes UI 与控制机制
**文件：**
- 创建：`PhantomKnob/Resources/release-notes.json`
- 创建：`PhantomKnob/View/ReleaseNotesView.swift`
- 创建：`PhantomKnob/Service/ReleaseNotesController.swift`
- 修改：`PhantomKnob/App/PhantomKnobApp.swift`

- [ ] **步骤 1：创建 release-notes.json 声明首发特性**
  创建 `PhantomKnob/Resources/release-notes.json` 并写入：
  ```json
  {
    "1.0": {
      "title": "Welcome to PhantomKnob!",
      "items": [
        "🎛️ Global knob control with two-finger rotation gesture",
        "🎬 Pro knob packs for DaVinci Resolve, Final Cut Pro, and Logic Pro",
        "⚡ Three knob modes: Fixed, Double-Ring, and Variable Speed",
        "🔧 Full customization with Customizer HUD"
      ]
    }
  }
  ```

- [ ] **步骤 2：创建 ReleaseNotesView.swift**
  创建 `PhantomKnob/View/ReleaseNotesView.swift` 并写入完整的 SwiftUI 毛玻璃质感弹框界面。包含 items 循环展示、不再显示当前版本 Toggle 以及 "Got It" 确认操作。

- [ ] **步骤 3：创建 ReleaseNotesController.swift**
  创建 `PhantomKnob/Service/ReleaseNotesController.swift`，管理 `ReleaseNotesWindow` (无边框毛玻璃面板，宽520高380)。读取并解析 json 资源，判定 `lastSeenReleaseNotesVersion`。

- [ ] **步骤 4：在 AppState.init() 中调用**
  修改 `PhantomKnob/App/PhantomKnobApp.swift` 中的 `AppState.init()`，在 User Guide 及 Tutorial 检测的分支中，或者紧随其后运行：
  ```swift
  DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      ReleaseNotesController.shared.showIfNeeded()
  }
  ```

- [ ] **步骤 5：单元测试验证 JSON 数据解析**
  在 `PhantomKnobTests` 下新建一个测试文件验证 `release-notes.json` 解析无误。
  运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS'`
  预期：测试通过。

- [ ] **步骤 6：Commit**
  ```bash
  git add PhantomKnob/Resources/release-notes.json PhantomKnob/View/ReleaseNotesView.swift PhantomKnob/Service/ReleaseNotesController.swift PhantomKnob/App/PhantomKnobApp.swift
  git commit -m "feat: implement Release Notes window and version display logic"
  ```

---

### 任务 6：生成 Sparkle 密钥对及项目最终编译
**文件：**
- 修改：`PhantomKnob/project.yml`

- [ ] **步骤 1：定位或构建 Sparkle generate_keys 命令行工具**
  运行编译/拉取 SPM 产物：
  `swift build -c release` 或利用 Xcode package cache 生成。

- [ ] **步骤 2：生成密钥对并将公钥更新进 project.yml**
  生成完后，将公钥字符串替换 `project.yml` 中的 `PLACEHOLDER_PUBLIC_KEY`。

- [ ] **步骤 3：再次生成并构建项目**
  运行：`cd PhantomKnob && xcodegen generate && cd .. && xcodebuild -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob build`
  预期：整个项目成功编译打包，Info.plist 正确嵌入公钥和 Feed URL。

- [ ] **步骤 4：Commit**
  ```bash
  git add PhantomKnob/project.yml
  git commit -m "feat: populate Sparkle EdDSA public signature key in project configuration"
  ```

---

### 任务 7：营销素材及落地页更新
**文件：**
- 创建：`website/assets/screenshot_overlay.png` (由 generate_image 生成)
- 创建：`website/assets/screenshot_hud.png` (由 generate_image 生成)
- 创建：`website/assets/screenshot_settings.png` (由 generate_image 生成)
- 修改：`website/index.html`
- 修改：`website/style.css`

- [ ] **步骤 1：利用 generate_image 生成 screenshot_overlay 截图**
  利用 prompt 生成与网页完美搭配的高级色调 DaVinci Resolve 中的旋转刻度盘概念画，保存至 `website/assets/screenshot_overlay.png`。

- [ ] **步骤 2：利用 generate_image 生成 screenshot_hud 截图**
  生成毛玻璃 Customizer HUD 窗口高保真插画，保存至 `website/assets/screenshot_hud.png`。

- [ ] **步骤 3：利用 generate_image 生成 screenshot_settings 截图**
  生成 macOS 样式设置选项概念插画，保存至 `website/assets/screenshot_settings.png`。

- [ ] **步骤 4：修改 website/index.html 增加 Showcase 节点**
  在 `index.html` 的 Hero 节与 Features 节之间添加带有 hover 缩放动画、半透背景的 `#showcase` 块，展示这 3 张截图和视频占位符。

- [ ] **步骤 5：修改 website/style.css 完善 Showcase 排版**
  在 CSS 尾部添加样式以确保 Showcase 排版在桌面和移动端适配。

- [ ] **步骤 6：Commit**
  ```bash
  git add website/index.html website/style.css website/assets/*.png
  git commit -m "feat: update landing page with modern showcase sections and high-fidelity interface mockup illustrations"
  ```
