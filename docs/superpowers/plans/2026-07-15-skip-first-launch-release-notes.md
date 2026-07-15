# 首次启动跳过版本更新日志/欢迎弹窗 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在应用首次启动时跳过自动弹出版本更新日志窗口，只有在未来发生版本升级时才自动弹出，且关闭窗口即默认标记已读，并精简 UI。

**架构：**
- 修改 `ReleaseNotesController` 以在首次运行阶段直接写入当前版本并拦截弹窗，增加 `isVisible` 属性以供测试使用。
- 修改 `ReleaseNotesView` 移除 "Don't show this version again" 复选框及其状态绑定，改为无参 `onDismiss` 闭包。
- 完善 `ReleaseNotesTests` 的测试用例，验证首次运行静默机制及升级弹窗行为。

---

### 任务 1：重构更新日志 UI (ReleaseNotesView)

**文件：**
- 修改：`PhantomKnob/View/ReleaseNotesView.swift`

- [ ] **步骤 1：移除 dontShowAgain 选项及状态**
  修改 [ReleaseNotesView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/ReleaseNotesView.swift) 中的 `dontShowAgain` 变量和底部多余的 `Toggle`，将其改为简单的、无参 `onDismiss: () -> Void` 闭包回调。

  修改后的 `ReleaseNotesView.swift` 完整代码：
  ```swift
  import SwiftUI

  struct ReleaseNotesView: View {
      let version: String
      let title: String
      let items: [String]
      
      var onDismiss: () -> Void
      
      var body: some View {
          VStack(spacing: 0) {
              // Header
              VStack(spacing: 8) {
                  Text(title)
                      .font(.system(size: 22, weight: .bold))
                      .foregroundColor(.white)
                  Text(String(format: String(localized: "release.version.format", defaultValue: "Version %@"), version))
                      .font(.system(size: 13, weight: .medium))
                      .foregroundColor(.white.opacity(0.5))
              }
              .padding(.top, 28)
              .padding(.bottom, 16)
              
              Divider()
                  .background(Color.white.opacity(0.15))
              
              // Content
              ScrollView {
                  VStack(alignment: .leading, spacing: 14) {
                      ForEach(items, id: \.self) { item in
                          HStack(alignment: .top, spacing: 10) {
                              Text("•")
                                  .foregroundColor(.accentColor)
                                  .font(.system(size: 16, weight: .bold))
                              Text(item)
                                  .font(.system(size: 13))
                                  .foregroundColor(.white.opacity(0.85))
                                  .lineSpacing(4)
                                  .multilineTextAlignment(.leading)
                          }
                      }
                  }
                  .padding(.horizontal, 24)
                  .padding(.vertical, 20)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              .frame(maxHeight: .infinity)
              
              Divider()
                  .background(Color.white.opacity(0.15))
              
              // Footer
              HStack {
                  Spacer()
                  
                  Button(action: {
                      onDismiss()
                  }) {
                      Text(String(localized: "release.button.gotIt", defaultValue: "Got it"))
                          .font(.system(size: 13, weight: .semibold))
                          .foregroundColor(.white)
                          .padding(.horizontal, 20)
                          .padding(.vertical, 8)
                          .background(Color.accentColor)
                          .cornerRadius(8)
                  }
                  .buttonStyle(.plain)
              }
              .padding(.horizontal, 20)
              .padding(.vertical, 16)
          }
          .frame(width: 520, height: 380)
          .background(Color.clear)
      }
  }

  struct ReleaseNotesView_Previews: PreviewProvider {
      static var previews: some View {
          ReleaseNotesView(
              version: "1.0",
              title: "Welcome to PhantomKnob!",
              items: [
                  "🎛️ Global knob control with two-finger rotation gesture",
                  "🎬 Pro knob packs for DaVinci Resolve, Final Cut Pro, and Logic Pro",
                  "⚡ Three knob modes: Fixed, Double-Ring, and Variable Speed",
                  "🔧 Full customization with Customizer HUD"
              ]
          ) {}
      }
  }
  ```

- [ ] **步骤 2：Commit**
  运行：
  ```bash
  git add PhantomKnob/View/ReleaseNotesView.swift
  git commit -m "style: remove 'don't show again' toggle from ReleaseNotesView"
  ```

---

### 任务 2：重构更新日志控制器 (ReleaseNotesController)

**文件：**
- 修改：`PhantomKnob/Service/ReleaseNotesController.swift`

- [ ] **步骤 1：增加首启动拦截逻辑和 onDismiss 适配**
  修改 [ReleaseNotesController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/ReleaseNotesController.swift)，优化 `showIfNeeded()` 方法，捕获首次运行状态；提供 `isVisible` 计算属性以方便测试；将 `show` 中对 `ReleaseNotesView` 的回调闭包改写为无参形式，在关闭时直接标记已读。同时在失去焦点 `windowDidResignKey` 时也记录为已读。

  修改后的 `ReleaseNotesController.swift` 完整代码：
  ```swift
  import AppKit
  import SwiftUI

  class ReleaseNotesWindow: NSWindow {
      override var canBecomeKey: Bool { true }
  }

  final class ReleaseNotesController: NSObject, NSWindowDelegate {
      static let shared = ReleaseNotesController()
      
      private var window: ReleaseNotesWindow?
      
      var isVisible: Bool {
          return window?.isVisible ?? false
      }
      
      func showIfNeeded() {
          // 1. Skip if user guide onboarding isn't completed
          let guideCompleted = UserDefaults.app.bool(forKey: "firstRunUserGuideCompleted")
          guard guideCompleted else { return }
          
          // 2. Check version changes
          let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
          
          // If lastSeenVersion is nil, user is running the app/feature for the first time.
          // We register the current version as read and skip showing.
          guard let lastSeenVersion = UserDefaults.app.string(forKey: "lastSeenReleaseNotesVersion") else {
              UserDefaults.app.set(currentVersion, forKey: "lastSeenReleaseNotesVersion")
              return
          }
          
          guard currentVersion != lastSeenVersion else { return }
          
          // 3. Load release notes content
          guard let notes = loadReleaseNotes(for: currentVersion) else { return }
          
          // 4. Show window
          show(version: currentVersion, title: notes.title, items: notes.items)
      }
      
      private func show(version: String, title: String, items: [String]) {
          guard window == nil else { return }
          
          let width: CGFloat = 520
          let height: CGFloat = 380
          let screenFrame = NSScreen.main?.visibleFrame ?? .zero
          let originX = screenFrame.origin.x + (screenFrame.width - width) / 2
          let originY = screenFrame.origin.y + (screenFrame.height - height) / 2
          let contentRect = NSRect(x: originX, y: originY, width: width, height: height)
          
          let win = ReleaseNotesWindow(
              contentRect: contentRect,
              styleMask: [.borderless],
              backing: .buffered,
              defer: false
          )
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
          
          let view = ReleaseNotesView(version: version, title: title, items: items) { [weak self] in
              UserDefaults.app.set(version, forKey: "lastSeenReleaseNotesVersion")
              self?.hide()
          }
          
          let hostingView = NSHostingView(rootView: view)
          hostingView.frame = visualEffectView.bounds
          hostingView.autoresizingMask = [.width, .height]
          visualEffectView.addSubview(hostingView)
          
          self.window = win
          win.makeKeyAndOrderFront(nil)
          NSApp.activate(ignoringOtherApps: true)
      }
      
      func hide() {
          window?.orderOut(nil)
          window = nil
      }
      
      struct ReleaseNoteModel: Decodable {
          let title: String
          let items: [String]
      }
      
      func loadReleaseNotes(for version: String) -> ReleaseNoteModel? {
          guard let url = Bundle.main.url(forResource: "release-notes", withExtension: "json"),
                let data = try? Data(contentsOf: url),
                let dict = try? JSONDecoder().decode([String: ReleaseNoteModel].self, from: data) else {
              return nil
          }
          return dict[version]
      }
      
      func windowDidResignKey(_ notification: Notification) {
          let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
          UserDefaults.app.set(currentVersion, forKey: "lastSeenReleaseNotesVersion")
          hide()
      }
  }
  ```

- [ ] **步骤 2：Commit**
  运行：
  ```bash
  git add PhantomKnob/Service/ReleaseNotesController.swift
  git commit -m "feat: intercept release notes on first launch and auto-read on dismiss"
  ```

---

### 任务 3：更新与添加单元测试 (ReleaseNotesTests)

**文件：**
- 修改：`PhantomKnob/PhantomKnobTests/ReleaseNotesTests.swift`

- [ ] **步骤 1：添加测试用例以验证首次启动静默及升级自动标记已读行为**
  修改 [ReleaseNotesTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnobTests/ReleaseNotesTests.swift)，在其中添加 `testReleaseNotesFirstLaunchAndUpgrade`。

  修改后的 `ReleaseNotesTests.swift` 完整代码：
  ```swift
  import XCTest
  @testable import PhantomKnob

  final class ReleaseNotesTests: XCTestCase {
      
      func testReleaseNotesLoadingAndParsing() {
          let controller = ReleaseNotesController.shared
          
          // Test loading version 1.0 which we defined in release-notes.json
          let notes = controller.loadReleaseNotes(for: "1.0")
          
          XCTAssertNotNil(notes, "Failed to load release notes for version 1.0")
          XCTAssertEqual(notes?.title, "Welcome to PhantomKnob!")
          XCTAssertEqual(notes?.items.count, 4)
          
          XCTAssertEqual(notes?.items[0], "🎛️ Global knob control with two-finger rotation gesture")
          XCTAssertEqual(notes?.items[1], "🎬 Pro knob packs for DaVinci Resolve, Final Cut Pro, and Logic Pro")
          XCTAssertEqual(notes?.items[2], "⚡ Three knob modes: Fixed, Double-Ring, and Variable Speed")
          XCTAssertEqual(notes?.items[3], "🔧 Full customization with Customizer HUD")
      }
      
      func testReleaseNotesFirstLaunchAndUpgrade() {
          let suiteName = "ReleaseNotesTestsSuite"
          UserDefaults.app = UserDefaults(suiteName: suiteName) ?? .standard
          UserDefaults.app.removePersistentDomain(forName: suiteName)
          
          defer {
              UserDefaults.app.removePersistentDomain(forName: suiteName)
              UserDefaults.app = .standard
          }
          
          let controller = ReleaseNotesController.shared
          
          // 1. Initially lastSeenReleaseNotesVersion is nil
          XCTAssertNil(UserDefaults.app.string(forKey: "lastSeenReleaseNotesVersion"))
          
          // Guide completed must be true for ReleaseNotes to be evaluated
          UserDefaults.app.set(true, forKey: "firstRunUserGuideCompleted")
          
          // Call showIfNeeded
          controller.showIfNeeded()
          
          // Verify it did not show and directly marked current version as seen
          XCTAssertFalse(controller.isVisible)
          let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
          XCTAssertEqual(UserDefaults.app.string(forKey: "lastSeenReleaseNotesVersion"), currentVersion)
          
          // 2. Upgrade Scenario: set lastSeen to older version
          UserDefaults.app.set("0.9", forKey: "lastSeenReleaseNotesVersion")
          
          // Call showIfNeeded
          controller.showIfNeeded()
          
          // Verify it displays the release notes window now
          XCTAssertTrue(controller.isVisible)
          
          // Dismiss the release notes
          controller.hide()
          
          // Verify it is closed
          XCTAssertFalse(controller.isVisible)
      }
  }
  ```

- [ ] **步骤 2：运行单元测试**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnob -destination 'platform=macOS' test`
  预期：所有测试通过，且包含新测试通过记录。

- [ ] **步骤 3：Commit**
  运行：
  ```bash
  git add PhantomKnob/PhantomKnobTests/ReleaseNotesTests.swift
  git commit -m "test: add release notes first launch and upgrade behavior verification"
  ```
