# PhantomKnob 购买与激活流程简化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现一键免输入 URL Scheme 激活、独立的 Pro 升级/激活窗口，并适配官网主页与激活中转页。

**架构：**
1. **URL Scheme 拦截**：在 `Info.plist` 中注册 `phantomknob` 协议，通过 `NSAppleEventManager` 在 App 启动时监听 `phantomknob://activate?key=XXX&email=YYY` 格式。
2. **专属激活窗口**：创建独立于设置的 `LicenseWindowController` 与 SwiftUI `LicenseWindowView` 窗口，统一管理未激活（Free/Trial）、激活中、已激活（Pro）三个视觉状态。
3. **状态栏集成**：修改 `StatusBarController` 的 Pro 菜单路由，移除 `SettingsView` 中的复杂激活输入框。
4. **网页端集成**：在静态网站库中更新主页并新建 `activate.html` 实现 URL 跳转和手动兜底。

**技术栈：** Swift (AppKit/SwiftUI), AppleEvent, HTML5/CSS3/JavaScript.

---

## 文件变更清单

### 新建文件
1. `PhantomKnob/Service/URLSchemeHandler.swift` — 自定义协议监听与路由类
2. `PhantomKnob/Service/LicenseWindowController.swift` — 专属激活窗口控制器 (AppKit)
3. `PhantomKnob/View/LicenseWindowView.swift` — 专属激活 SwiftUI 视图
4. `PhantomKnobTests/URLSchemeHandlerTests.swift` — 协议解析解析单元测试
5. `/Users/wb/work/PhantomKnob/activate.html` — 官网一键激活中转网页

### 修改文件
1. `PhantomKnob/Info.plist` — 注册 URL Scheme
2. `PhantomKnob/App/PhantomKnobApp.swift` — 初始化并注册 URL 监听
3. `PhantomKnob/Service/StatusBarController.swift` — 更新 Pro 菜单点击路由
4. `PhantomKnob/View/SettingsView.swift` — 清理偏好设置 About 页的激活模块
5. `/Users/wb/work/PhantomKnob/index.html` — 主页文案与购买链接调整
6. `/Users/wb/work/PhantomKnob/index_zh.html` — 中文主页文案与购买链接调整

---

## 详细实施步骤

### 任务 1：注册并拦截 URL Scheme (`Info.plist` & `URLSchemeHandler`)

**文件：**
- 修改：`PhantomKnob/Info.plist`
- 创建：`PhantomKnob/Service/URLSchemeHandler.swift`
- 修改：`PhantomKnob/App/PhantomKnobApp.swift`

- [ ] **步骤 1.1：在 Info.plist 中添加 URL Types 配置**
  在 `PhantomKnob/Info.plist` 的 `<dict>` 中间插入以下配置：
  ```xml
  	<key>CFBundleURLTypes</key>
  	<array>
  		<dict>
  			<key>CFBundleURLName</key>
  			<string>com.phantomknob.url-scheme</string>
  			<key>CFBundleURLSchemes</key>
  			<array>
  				<string>phantomknob</string>
  			</array>
  		</dict>
  	</array>
  ```

- [ ] **步骤 1.2：创建 URLSchemeHandler.swift 并实现解析逻辑**
  创建 [URLSchemeHandler.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/URLSchemeHandler.swift)：
  ```swift
  import AppKit
  import Foundation
  import os

  class URLSchemeHandler {
      static let shared = URLSchemeHandler()
      
      private init() {}
      
      func startListening() {
          NSAppleEventManager.shared().setEventHandler(
              self,
              andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
              forEventClass: AEEventClass(kInternetEventClass),
              andEventID: AEEventID(kAEGetURL)
          )
      }
      
      @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
          guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
                let url = URL(string: urlString) else {
              return
          }
          parseAndTriggerActivation(url: url)
      }
      
      func parseAndTriggerActivation(url: URL) {
          guard url.host == "activate" else { return }
          
          let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
          let key = components?.queryItems?.first(where: { $0.name == "key" || $0.name == "license_key" })?.value
          let email = components?.queryItems?.first(where: { $0.name == "email" })?.value
          
          if let key = key, let email = email {
              DispatchQueue.main.async {
                  NotificationCenter.default.post(
                      name: NSNotification.Name("TriggerLicenseActivationFromURL"),
                      object: nil,
                      userInfo: ["key": key, "email": email]
                  )
              }
          }
      }
  }
  ```

- [ ] **步骤 1.3：在 App 启动入口注册 URL 监听**
  修改 `PhantomKnob/App/PhantomKnobApp.swift`：
  在 `AppState.init()` 中的 `AnalyticsManager.shared.initialize()` 下面添加：
  ```swift
          URLSchemeHandler.shared.startListening()
  ```

- [ ] **步骤 1.4：提交此任务变更**
  ```bash
  git add PhantomKnob/Info.plist PhantomKnob/Service/URLSchemeHandler.swift PhantomKnob/App/PhantomKnobApp.swift
  git commit -m "feat: register and listen to custom URL scheme phantomknob://"
  ```

---

### 任务 2：编写 URL 协议解析测试

**文件：**
- 创建：`PhantomKnobTests/URLSchemeHandlerTests.swift`

- [ ] **步骤 2.1：创建单元测试文件**
  创建 [URLSchemeHandlerTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnobTests/URLSchemeHandlerTests.swift)：
  ```swift
  import XCTest
  @testable import PhantomKnob

  final class URLSchemeHandlerTests: XCTestCase {
      func testURLSchemeParsing() {
          let testURL = URL(string: "phantomknob://activate?key=ABCD-1234&email=tester@example.com")!
          
          let expectation = self.expectation(description: "Notification received")
          var receivedKey: String?
          var receivedEmail: String?
          
          let observer = NotificationCenter.default.addObserver(
              forName: NSNotification.Name("TriggerLicenseActivationFromURL"),
              object: nil,
              queue: .main
          ) { notification in
              receivedKey = notification.userInfo?["key"] as? String
              receivedEmail = notification.userInfo?["email"] as? String
              expectation.fulfill()
          }
          
          URLSchemeHandler.shared.parseAndTriggerActivation(url: testURL)
          
          waitForExpectations(timeout: 2.0) { _ in
              NotificationCenter.default.removeObserver(observer)
              XCTAssertEqual(receivedKey, "ABCD-1234")
              XCTAssertEqual(receivedEmail, "tester@example.com")
          }
      }
  }
  ```

- [ ] **步骤 2.2：运行测试并确认通过**
  运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnobTests`
  预期：测试通过。

- [ ] **步骤 2.3：提交测试代码**
  ```bash
  git add PhantomKnob/PhantomKnobTests/URLSchemeHandlerTests.swift
  git commit -m "test: add URL scheme parser unit test"
  ```

---

### 任务 3：构建专属激活窗口与 SwiftUI UI (`LicenseWindowController` & `LicenseWindowView`)

**文件：**
- 创建：`PhantomKnob/Service/LicenseWindowController.swift`
- 创建：`PhantomKnob/View/LicenseWindowView.swift`

- [ ] **步骤 3.1：新建 LicenseWindowController**
  创建 [LicenseWindowController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/LicenseWindowController.swift)：
  ```swift
  import AppKit
  import SwiftUI

  class LicenseWindow: NSWindow {
      override var canBecomeKey: Bool { return true }
  }

  class LicenseWindowController: NSObject, NSWindowDelegate {
      static let shared = LicenseWindowController()
      
      private var window: LicenseWindow?
      
      var isVisible: Bool {
          return window?.isVisible ?? false
      }
      
      func show() {
          if window == nil {
              createWindow()
          }
          NSApp.setActivationPolicy(.regular)
          window?.makeKeyAndOrderFront(nil)
          NSApp.activate(ignoringOtherApps: true)
      }
      
      func hide() {
          window?.orderOut(nil)
          NSApp.setActivationPolicy(.accessory)
      }
      
      private func createWindow() {
          let width: CGFloat = 480
          let height: CGFloat = 360
          let screenFrame = NSScreen.main?.visibleFrame ?? .zero
          let originX = screenFrame.origin.x + (screenFrame.width - width) / 2
          let originY = screenFrame.origin.y + (screenFrame.height - height) / 2
          
          let contentRect = NSRect(x: originX, y: originY, width: width, height: height)
          let win = LicenseWindow(
              contentRect: contentRect,
              styleMask: [.borderless],
              backing: .buffered,
              defer: false
          )
          win.isMovableByWindowBackground = true
          win.appearance = NSAppearance(named: .darkAqua)
          win.backgroundColor = .clear
          win.isOpaque = false
          win.level = .floating
          win.hidesOnDeactivate = true
          win.delegate = self
          
          let visualEffectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: contentRect.size))
          visualEffectView.material = .hudWindow
          visualEffectView.blendingMode = .behindWindow
          visualEffectView.state = .active
          visualEffectView.autoresizingMask = [.width, .height]
          visualEffectView.wantsLayer = true
          visualEffectView.layer?.cornerRadius = 20
          visualEffectView.layer?.masksToBounds = true
          
          win.contentView = visualEffectView
          
          let hostingView = NSHostingView(rootView: LicenseWindowView())
          hostingView.frame = visualEffectView.bounds
          hostingView.autoresizingMask = [.width, .height]
          visualEffectView.addSubview(hostingView)
          
          self.window = win
      }
      
      func windowDidResignKey(_ notification: Notification) {
          hide()
      }
  }
  ```

- [ ] **步骤 3.2：创建 LicenseWindowView SwiftUI 视图**
  创建 [LicenseWindowView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/LicenseWindowView.swift)：
  ```swift
  import SwiftUI

  struct LicenseWindowView: View {
      @State private var licenseState: LicenseState = LicenseManager.shared.currentState
      @State private var email: String = ""
      @State private var licenseKey: String = ""
      @State private var isActivating: Bool = false
      @State private var errorMessage: String? = nil
      @State private var showManualForm: Bool = false
      
      private func maskEmail(_ email: String) -> String {
          let parts = email.split(separator: "@")
          guard parts.count == 2 else { return email }
          let name = String(parts[0])
          let domain = String(parts[1])
          return name.count <= 2 ? "\(name.prefix(1))***@\(domain)" : "\(name.prefix(1))***\(name.suffix(1))@\(domain)"
      }

      var body: some View {
          VStack(spacing: 0) {
              // 顶部关闭与装饰栏
              HStack {
                  Button(action: {
                      LicenseWindowController.shared.hide()
                  }) {
                      Image(systemName: "xmark.circle.fill")
                          .font(.system(size: 14))
                          .foregroundColor(.white.opacity(0.5))
                  }
                  .buttonStyle(.plain)
                  Spacer()
              }
              .padding(.horizontal, 16)
              .padding(.top, 16)
              
              if isActivating {
                  activatingStateView
              } else {
                  switch licenseState {
                  case .licensed:
                      licensedStateView
                  case .free, .trialing:
                      unlicensedStateView
                  }
              }
          }
          .foregroundColor(.white)
          .preferredColorScheme(.dark)
          .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LicenseStateDidChange"))) { _ in
              self.licenseState = LicenseManager.shared.currentState
          }
          .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TriggerLicenseActivationFromURL"))) { notification in
              if let key = notification.userInfo?["key"] as? String,
                 let email = notification.userInfo?["email"] as? String {
                  self.licenseKey = key
                  self.email = email
                  triggerActivation()
              }
          }
      }
      
      // 正在激活状态
      private var activatingStateView: some View {
          VStack(spacing: 20) {
              Spacer()
              ProgressView()
                  .controlSize(.large)
              Text("正在验证授权协议，请稍候...")
                  .font(.system(size: 14, weight: .medium))
                  .foregroundColor(.white.opacity(0.85))
              Spacer()
          }
      }
      
      // 已激活 Pro 版状态
      private var licensedStateView: some View {
          VStack(spacing: 16) {
              Spacer()
              Image(systemName: "checkmark.seal.fill")
                  .resizable()
                  .frame(width: 60, height: 60)
                  .foregroundColor(.orange)
              
              Text("✨ Pro 激活成功")
                  .font(.system(size: 18, weight: .bold))
              
              if let savedEmail = UserDefaults.app.string(forKey: "proLicenseEmail") {
                  Text(String(format: "已绑定邮箱: %@", maskEmail(savedEmail)))
                      .font(.system(size: 12))
                      .foregroundColor(.white.opacity(0.7))
              }
              
              Text("感谢您支持 PhantomKnob 的开发！所有 Pro 特权均已生效。")
                  .font(.system(size: 12))
                  .foregroundColor(.white.opacity(0.6))
                  .multilineTextAlignment(.center)
                  .padding(.horizontal, 32)
              
              Spacer()
              
              Button(action: {
                  LicenseManager.shared.deactivate()
              }) {
                  Text("解绑当前设备")
                      .font(.system(size: 11, weight: .medium))
                      .foregroundColor(.red.opacity(0.8))
                      .padding(.horizontal, 16)
                      .padding(.vertical, 6)
                      .background(Color.red.opacity(0.12))
                      .cornerRadius(6)
                      .overlay(
                          RoundedRectangle(cornerRadius: 6)
                              .stroke(Color.red.opacity(0.2), lineWidth: 1)
                      )
              }
              .buttonStyle(.plain)
              .padding(.bottom, 24)
          }
      }
      
      // 未激活 (免费版/试用版) 状态
      private var unlicensedStateView: some View {
          VStack(spacing: 12) {
              Text("升级 PhantomKnob Pro")
                  .font(.system(size: 20, weight: .bold))
                  .foregroundColor(.orange)
                  .padding(.top, 4)
              
              VStack(alignment: .leading, spacing: 6) {
                  HStack(spacing: 6) {
                      Image(systemName: "checkmark.circle.fill").foregroundColor(.orange)
                      Text("无限活跃会话时间 (15分钟自动断开限制已移除)")
                  }
                  HStack(spacing: 6) {
                      Image(systemName: "checkmark.circle.fill").foregroundColor(.orange)
                      Text("瞬时启动控制模式 (移除 2 秒等待时间)")
                  }
                  HStack(spacing: 6) {
                      Image(systemName: "checkmark.circle.fill").foregroundColor(.orange)
                      Text("个性化视觉覆层定制与未来云端预设同步")
                  }
              }
              .font(.system(size: 11))
              .foregroundColor(.white.opacity(0.8))
              .padding(.horizontal, 24)
              .padding(.vertical, 8)
              .background(Color.white.opacity(0.04))
              .cornerRadius(10)
              
              Button(action: {
                  if let url = URL(string: "https://benwu232.github.io/PhantomKnob/#buy") {
                      NSWorkspace.shared.open(url)
                  }
              }) {
                  Text("🛒 立即获取 Pro 授权")
                      .font(.system(size: 13, weight: .semibold))
                      .foregroundColor(.black)
                      .padding(.horizontal, 28)
                      .padding(.vertical, 8)
                      .background(Color.orange)
                      .cornerRadius(8)
              }
              .buttonStyle(.plain)
              
              if showManualForm {
                  VStack(spacing: 8) {
                      HStack(spacing: 8) {
                          TextField("购买邮箱", text: $email)
                              .textFieldStyle(.plain)
                              .padding(.horizontal, 8)
                              .padding(.vertical, 4)
                              .background(Color.white.opacity(0.08))
                              .cornerRadius(4)
                          
                          SecureField("授权码 Key", text: $licenseKey)
                              .textFieldStyle(.plain)
                              .padding(.horizontal, 8)
                              .padding(.vertical, 4)
                              .background(Color.white.opacity(0.08))
                              .cornerRadius(4)
                      }
                      
                      if let error = errorMessage {
                          Text(error)
                              .font(.system(size: 10))
                              .foregroundColor(.red)
                      }
                      
                      HStack {
                          Button("手动激活") {
                              triggerActivation()
                          }
                          .font(.system(size: 11, weight: .medium))
                          .foregroundColor(.blue)
                          .buttonStyle(.plain)
                          
                          Spacer()
                          
                          Button("取消") {
                              showManualForm = false
                              errorMessage = nil
                          }
                          .font(.system(size: 11))
                          .foregroundColor(.white.opacity(0.6))
                          .buttonStyle(.plain)
                      }
                  }
                  .padding(.horizontal, 48)
                  .transition(.opacity)
              } else {
                  Button("手动输入授权码...") {
                      withAnimation {
                          showManualForm = true
                      }
                  }
                  .font(.system(size: 11))
                  .foregroundColor(.white.opacity(0.5))
                  .buttonStyle(.plain)
              }
              Spacer()
          }
      }
      
      private func triggerActivation() {
          guard !email.isEmpty && !licenseKey.isEmpty else {
              errorMessage = "请完整输入邮箱和授权码"
              return
          }
          isActivating = true
          errorMessage = nil
          LicenseManager.shared.activateOnline(licenseKey: licenseKey.trimmingCharacters(in: .whitespacesAndNewlines), email: email.trimmingCharacters(in: .whitespacesAndNewlines)) { success, error in
              isActivating = false
              if !success {
                  errorMessage = error ?? "激活验证失败"
              }
          }
      }
  }
  ```

- [ ] **步骤 3.3：提交专属激活 UI 模块**
  ```bash
  git add PhantomKnob/Service/LicenseWindowController.swift PhantomKnob/View/LicenseWindowView.swift
  git commit -m "feat: design dedicated LicenseWindow UI and state flows"
  ```

---

### 任务 4：状态栏与设置面板重构

**文件：**
- 修改：`PhantomKnob/Service/StatusBarController.swift`
- 修改：`PhantomKnob/View/SettingsView.swift`

- [ ] **步骤 4.1：将状态栏菜单中的 Pro 动作导向专用窗口**
  修改 `PhantomKnob/Service/StatusBarController.swift`：
  - 更新约第 538 行 `buyPro` 方法以唤起新激活窗口：
  ```swift
      @objc func buyPro() {
          LicenseWindowController.shared.show()
      }
  ```
  - 将所有指向 `SettingsWindowController.shared.show(tab: .about)` 的地方更新为 `LicenseWindowController.shared.show()`。具体修改：
    - 约第 562 行 `showFreeActivatingPopover` 点击事件。
    - 约第 586 行 `showFreeExpiredPopover` 点击事件。

- [ ] **步骤 4.2：移除偏好设置中的激活模块**
  修改 `PhantomKnob/View/SettingsView.swift`：
  - 移除 `AboutView` 中的激活表单（从约第 497 行 `else { ... }` 改为只在非 Pro 时显示升级提示按钮）。
  - 精简后的 `AboutView` 内部只在非 Licensed 状态下提供“升级至 Pro”的跳转按钮：
  ```swift
              if case .licensed = licenseState {
                  VStack(spacing: 8) {
                      Text(String(localized: "about.license.pro", defaultValue: "✨ Pro Edition Active"))
                          .font(.system(size: 13, weight: .bold))
                          .foregroundColor(.orange)
                      
                      if let savedEmail = UserDefaults.app.string(forKey: "proLicenseEmail") {
                          Text(String(format: String(localized: "about.license.email", defaultValue: "Licensed to: %@"), maskEmail(savedEmail)))
                              .font(.system(size: 11))
                              .foregroundColor(.white.opacity(0.75))
                      }
                      
                      Button(action: {
                          LicenseManager.shared.deactivate()
                      }) {
                          Text(String(localized: "about.license.deactivate", defaultValue: "Deactivate License"))
                              .font(.system(size: 11, weight: .medium))
                              .foregroundColor(.red.opacity(0.8))
                              .padding(.horizontal, 12)
                              .padding(.vertical, 4)
                              .background(Color.red.opacity(0.12))
                              .cornerRadius(4)
                              .overlay(
                                  RoundedRectangle(cornerRadius: 4)
                                      .stroke(Color.red.opacity(0.2), lineWidth: 1)
                              )
                      }
                      .buttonStyle(.plain)
                      .padding(.top, 4)
                  }
                  .padding(.vertical, 4)
              } else {
                  VStack(spacing: 8) {
                      Button(action: {
                          SettingsWindowController.shared.hide()
                          LicenseWindowController.shared.show()
                      }) {
                          Text("升级到 Pro 版 ➔")
                              .font(.system(size: 12, weight: .bold))
                              .foregroundColor(.white)
                              .padding(.horizontal, 16)
                              .padding(.vertical, 6)
                              .background(Color.orange)
                              .cornerRadius(6)
                      }
                      .buttonStyle(.plain)
                  }
                  .padding(.vertical, 4)
              }
  ```

- [ ] **步骤 4.3：提交重构的菜单与设置界面**
  ```bash
  git add PhantomKnob/Service/StatusBarController.swift PhantomKnob/View/SettingsView.swift
  git commit -m "refactor: separate license activation module from preference settings"
  ```

---

### 任务 5：网页端一键激活与主页适配 (分发库 `PhantomKnob`)

**文件：**
- 修改：`/Users/wb/work/PhantomKnob/index.html`
- 修改：`/Users/wb/work/PhantomKnob/index_zh.html`
- 创建：`/Users/wb/work/PhantomKnob/activate.html`

- [ ] **步骤 5.1：修改中文官网主页添加免输入宣传与购买链接**
  修改 `/Users/wb/work/PhantomKnob/index_zh.html`：
  - 将约第 248 行的购买许可按钮 `<a href="#" class="plan-btn pro" onclick="alert('购买流程即将上线！')">购买许可</a>` 修改为结账台购买直链（例如 Lemon Squeezy 占位链接）：
    ```html
    <a href="https://heavywater.lemonsqueezy.com/checkout/buy/pro" class="plan-btn pro">购买许可</a>
    ```
  - 在第 245 行优先支持一键激活卖点宣传：
    ```html
                            <li>
                                <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.5" viewBox="0 0 24 24"><path d="M5 13l4 4L19 7"></path></svg>
                                <strong>零输入一键激活</strong>（购买后直接唤醒自动授权）
                            </li>
    ```

- [ ] **步骤 5.2：同步修改英文官网主页**
  修改 `/Users/wb/work/PhantomKnob/index.html`，做与 5.1 相同的更改。

- [ ] **步骤 5.3：新建一键激活中转页 activate.html**
  创建 `/Users/wb/work/PhantomKnob/activate.html`：
  ```html
  <!DOCTYPE html>
  <html lang="zh-Hans">
  <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>正在激活 PhantomKnob Pro...</title>
      <style>
          body {
              background-color: #0b0f19;
              color: #ffffff;
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
              display: flex;
              align-items: center;
              justify-content: center;
              min-height: 100vh;
              margin: 0;
              text-align: center;
          }
          .container {
              max-width: 440px;
              padding: 40px 20px;
              background: rgba(255, 255, 255, 0.03);
              border: 1px solid rgba(255, 255, 255, 0.05);
              border-radius: 20px;
              box-shadow: 0 20px 40px rgba(0,0,0,0.5);
              backdrop-filter: blur(10px);
          }
          .logo {
              width: 80px;
              height: 80px;
              margin-bottom: 24px;
              animation: spin 6s infinite linear;
          }
          @keyframes spin {
              100% { transform: rotate(360deg); }
          }
          h1 {
              font-size: 22px;
              font-weight: 700;
              margin-bottom: 12px;
              background: linear-gradient(135deg, #ff9f43, #ff5252);
              -webkit-background-clip: text;
              -webkit-text-fill-color: transparent;
          }
          p {
              font-size: 14px;
              color: rgba(255, 255, 255, 0.7);
              line-height: 1.6;
              margin-bottom: 24px;
          }
          .btn {
              display: inline-block;
              background: #ff9f43;
              color: #000;
              font-weight: 600;
              padding: 12px 32px;
              border-radius: 8px;
              text-decoration: none;
              font-size: 14px;
              transition: background 0.2s;
              cursor: pointer;
          }
          .btn:hover {
              background: #ffb366;
          }
          .backup-box {
              margin-top: 32px;
              padding-top: 24px;
              border-top: 1px solid rgba(255, 255, 255, 0.1);
              text-align: left;
          }
          .backup-title {
              font-size: 12px;
              font-weight: 600;
              color: #ff9f43;
              margin-bottom: 8px;
          }
          .code-snippet {
              background: rgba(0, 0, 0, 0.3);
              padding: 8px 12px;
              border-radius: 6px;
              font-family: monospace;
              font-size: 12px;
              color: #00ffcc;
              word-break: break-all;
              user-select: all;
          }
      </style>
  </head>
  <body>
      <div class="container">
          <svg class="logo" viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
              <circle cx="50" cy="50" r="40" stroke="#ff9f43" stroke-width="4" stroke-dasharray="10 5" />
              <path d="M50 15V35" stroke="#ff9f43" stroke-width="6" stroke-linecap="round" />
          </svg>
          
          <h1 id="status-text">正在启动 PhantomKnob 激活...</h1>
          <p>我们正在向您 Mac 上的 PhantomKnob 客户端发送激活信号。如果没有自动弹出激活成功界面，请点击下方按钮手动唤醒。</p>
          
          <a class="btn" id="activate-btn">打开并激活 App</a>
          
          <div class="backup-box">
              <div class="backup-title">手动备份授权码 (非 Mac 设备或离线备用)</div>
              <p style="font-size:11px; margin-bottom:8px;">如果您是在手机上购买的，可以复制此授权码前往 Mac 端 App 手动输入：</p>
              <div class="code-snippet" id="key-display">正在加载...</div>
              <div style="margin-top: 8px; font-size: 11px; color: rgba(255,255,255,0.5)">
                  授权邮箱: <span id="email-display" style="color: #fff">...</span>
              </div>
          </div>
      </div>

      <script>
          window.onload = function() {
              const params = new URLSearchParams(window.location.search);
              const key = params.get('key') || params.get('license_key');
              const email = params.get('email');
              
              if (key && email) {
                  document.getElementById('key-display').textContent = key;
                  document.getElementById('email-display').textContent = email;
                  
                  const schemeUrl = `phantomknob://activate?key=${encodeURIComponent(key)}&email=${encodeURIComponent(email)}`;
                  
                  // 自动尝试唤起 App
                  setTimeout(() => {
                      window.location.href = schemeUrl;
                  }, 1000);
                  
                  // 按钮绑定点击
                  document.getElementById('activate-btn').onclick = function() {
                      window.location.href = schemeUrl;
                  };
              } else {
                  document.getElementById('status-text').textContent = "激活参数不完整";
                  document.getElementById('key-display').textContent = "无有效授权码";
              }
          };
      </script>
  </body>
  </html>
  ```

- [ ] **步骤 5.4：提交网页端更新**
  在分发库 `PhantomKnob` 目录下运行提交命令：
  ```bash
  cd /Users/wb/work/PhantomKnob
  git add index.html index_zh.html activate.html
  git commit -m "feat: add automatic activation page and update purchase button"
  ```
