# Phase 3：增长功能 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。

**目标：** 添加提升用户留存和口碑的增长功能——自动更新、使用分析、反馈机制、营销素材、Release Notes。

**前置依赖：** Phase 1 + Phase 2 完成

---

## 任务 1：Sparkle 自动更新

**文件：**
- 修改：`PhantomKnob/project.yml`（SPM 依赖）
- 修改：`PhantomKnob/App/PhantomKnobApp.swift`
- 修改：`PhantomKnob/Service/StatusBarController.swift`
- 修改：`PhantomKnob/View/SettingsView.swift`
- 创建：`PhantomKnob/Service/UpdateManager.swift`

- [ ] **步骤 1：通过 SPM 添加 Sparkle 2.x**

```yaml
# project.yml
packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    from: "2.5.0"
```

- [ ] **步骤 2：生成 EdDSA 签名密钥对**

```bash
# 安装 Sparkle tools
./PhantomKnob/.build/artifacts/Sparkle/bin/generate_keys
# 保存 private key 到安全位置，public key 放入 Info.plist
```

- [ ] **步骤 3：在 Info.plist 中配置 Sparkle**

```xml
<key>SUFeedURL</key>
<string>https://phantomknob.com/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY</string>
<key>SUEnableAutomaticChecks</key>
<true/>
```

- [ ] **步骤 4：创建 UpdateManager**

```swift
// PhantomKnob/Service/UpdateManager.swift
import Sparkle

final class UpdateManager: ObservableObject {
    private let updaterController: SPUStandardUpdaterController

    init() {
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

- [ ] **步骤 5：在菜单栏添加 "Check for Updates..."**

```swift
// StatusBarController.setupMenu() 中添加：
let updateItem = NSMenuItem(
    title: String(localized: "menu.checkUpdates", defaultValue: "Check for Updates…"),
    action: #selector(checkForUpdates),
    keyEquivalent: ""
)
updateItem.target = self
menu?.addItem(updateItem)
```

- [ ] **步骤 6：在设置中添加自动更新开关**

```swift
Toggle(String(localized: "settings.autoUpdate", defaultValue: "Automatically check for updates"),
       isOn: $autoCheckUpdates)
```

- [ ] **步骤 7：创建 appcast.xml 模板并搭建托管**

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>PhantomKnob Updates</title>
    <item>
      <title>Version 1.0.0</title>
      <sparkle:version>1</sparkle:version>
      <sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <enclosure url="https://phantomknob.com/releases/PhantomKnob-1.0.0.dmg"
                 sparkle:edSignature="SIGNATURE"
                 length="FILE_SIZE"
                 type="application/octet-stream"/>
    </item>
  </channel>
</rss>
```

- [ ] **步骤 8：在 build_notarize.sh 中添加 appcast 生成步骤**

```bash
# 使用 Sparkle 的 generate_appcast 工具
./Sparkle/bin/generate_appcast dist/
```

- [ ] **步骤 9：Commit**

```bash
git commit -m "feat: integrate Sparkle 2 for automatic updates"
```

---

## 任务 2：使用分析（TelemetryDeck）

**文件：**
- 修改：`PhantomKnob/project.yml`
- 创建：`PhantomKnob/Service/AnalyticsManager.swift`
- 修改：`PhantomKnob/App/PhantomKnobApp.swift`
- 修改：`PhantomKnob/View/SettingsView.swift`

- [ ] **步骤 1：通过 SPM 添加 TelemetryDeck SDK**

```yaml
packages:
  TelemetryClient:
    url: https://github.com/TelemetryDeck/SwiftClient
    from: "1.0.0"
```

- [ ] **步骤 2：创建 AnalyticsManager**

```swift
// PhantomKnob/Service/AnalyticsManager.swift
import TelemetryClient

final class AnalyticsManager {
    static let shared = AnalyticsManager()

    func initialize() {
        guard !UserDefaults.standard.bool(forKey: "disableAnalytics") else { return }
        let config = TelemetryManagerConfiguration(appID: "YOUR_APP_ID")
        TelemetryManager.initialize(with: config)
    }

    func trackEvent(_ name: String, parameters: [String: String] = [:]) {
        guard !UserDefaults.standard.bool(forKey: "disableAnalytics") else { return }
        TelemetryManager.send(name, with: parameters)
    }
}
```

- [ ] **步骤 3：在关键位置添加事件追踪**

```swift
// App 启动
AnalyticsManager.shared.trackEvent("appLaunched")

// 旋钮使用
AnalyticsManager.shared.trackEvent("knobUsed", parameters: [
    "mode": "doubleRing",
    "duration": "\(sessionDuration)"
])

// 试用 → 付费转化
AnalyticsManager.shared.trackEvent("licenseActivated")
```

- [ ] **步骤 4：首次启动 opt-in 提示**

在 UserGuide Step 3 或首次启动时显示隐私提示。

- [ ] **步骤 5：设置中添加 analytics opt-out 开关**

- [ ] **步骤 6：Commit**

```bash
git commit -m "feat: add TelemetryDeck analytics with opt-in privacy controls"
```

---

## 任务 3：应用内反馈

**文件：**
- 修改：`PhantomKnob/Service/StatusBarController.swift`

- [ ] **步骤 1：在菜单栏添加 Send Feedback**

```swift
let feedbackItem = NSMenuItem(
    title: String(localized: "menu.feedback", defaultValue: "Send Feedback…"),
    action: #selector(sendFeedback),
    keyEquivalent: ""
)
feedbackItem.target = self
menu?.addItem(feedbackItem)
```

- [ ] **步骤 2：实现 sendFeedback 方法**

```swift
@objc private func sendFeedback() {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    let os = ProcessInfo.processInfo.operatingSystemVersionString
    let model = Host.current().localizedName ?? "Unknown"
    let license = LicenseManager.shared.state

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
}
```

- [ ] **步骤 3：Commit**

```bash
git commit -m "feat: add Send Feedback menu item with auto-populated system info"
```

---

## 任务 4：营销素材

- [ ] **步骤 1：录制 30-60 秒演示视频**

脚本：
1. 展示 DaVinci Resolve 中传统鼠标调色 vs PhantomKnob 旋钮调色对比
2. 展示热键激活 → 旋钮控制 → 实时 Overlay 反馈
3. 展示 Customizer HUD 定制旋钮

- [ ] **步骤 2：制作 App Store 风格截图（5 张）**

1. Overlay 控制效果图（DaVinci Resolve 中）
2. 设置界面
3. 三步引导
4. Customizer HUD
5. 菜单栏 + 状态指示

- [ ] **步骤 3：制作 GIF 动图用于 README 和社交媒体**

- [ ] **步骤 4：撰写产品描述文案**

一句话："Turn your trackpad into a precision dial for any creative app."

长描述："PhantomKnob transforms your MacBook trackpad into an intuitive rotary controller. Using a natural two-finger rotation gesture, you can precisely adjust any slider, color wheel, or parameter in your favorite creative apps — DaVinci Resolve, Final Cut Pro, Logic Pro, and more."

- [ ] **步骤 5：更新落地页内容**
- [ ] **步骤 6：Commit**

```bash
git commit -m "docs: add marketing materials — demo video, screenshots, product copy"
```

---

## 任务 5：Release Notes UI

**文件：**
- 创建：`PhantomKnob/Service/ReleaseNotesController.swift`
- 创建：`PhantomKnob/View/ReleaseNotesView.swift`
- 创建：`PhantomKnob/Resources/release-notes.json`
- 修改：`PhantomKnob/App/PhantomKnobApp.swift`

- [ ] **步骤 1：创建 release-notes.json**

```json
{
  "1.0.0": {
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

- [ ] **步骤 2：创建 ReleaseNotesView**

SwiftUI 窗口，深色毛玻璃风格（与现有 UI 一致），显示 release notes 列表，底部 "Don't show again" checkbox + "Got it" 按钮。

- [ ] **步骤 3：创建 ReleaseNotesController**

检查 UserDefaults 中的 lastSeenVersion，如果当前版本不同则显示 Release Notes 窗口。

- [ ] **步骤 4：集成到 App 启动流程**

在 `AppState.init()` 中，User Guide 检查之后：
```swift
ReleaseNotesController.shared.showIfNeeded()
```

- [ ] **步骤 5：Commit**

```bash
git commit -m "feat: add What's New release notes window shown after updates"
```

---

## 验证计划

### 自动化测试
```bash
xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnobTests
```

### 手动验证
1. **Sparkle**：修改 appcast 版本号，确认 App 弹出更新提示
2. **TelemetryDeck**：在 TelemetryDeck 面板中确认收到测试事件
3. **反馈**：点击 Send Feedback，确认邮件客户端打开且系统信息已填充
4. **Release Notes**：首次安装显示 What's New，第二次启动不再显示
