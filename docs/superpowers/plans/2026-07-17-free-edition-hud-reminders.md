# 免费版气泡 HUD 提醒实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在免费版 PhantomKnob 触发 2 秒激活延迟和 15 分钟会话到期时，分别在状态栏图标正下方弹出倒计时和时限到期提醒气泡（NSPopover），并支持点击到期提示中的升级按钮跳转到“关于”设置页。

**架构：** 
1. 新建 `FreeEditionPopoverView.swift` 渲染倒计时与时限到期的 SwiftUI 内容，接受倒计时秒数或升级回调。
2. 修改 `SettingsWindowController.swift` 和 `SettingsView.swift` 支持接收 `SettingsSelectTab` 通知以动态切换至 “About” 标签。
3. 修改 `StatusBarController.swift` 管理 `NSPopover` 的显示与关闭，提供 `showFreeActivatingPopover` 和 `showFreeExpiredPopover` API。
4. 修改 `KnobStateManager.swift` 在状态机倒计时和到期断开处调用 `StatusBarController` 的气泡接口。

**技术栈：** Swift, SwiftUI, AppKit (NSStatusItem, NSPopover, NSHostingController)

---

## 拟变动文件列表

### 新建文件
* [FreeEditionPopoverView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/FreeEditionPopoverView.swift) - 气泡的 SwiftUI 界面
* [FreeEditionPopoverTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnobTests/FreeEditionPopoverTests.swift) - 气泡状态测试

### 修改文件
* [SettingsWindowController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/SettingsWindowController.swift) - 新增快捷切换标签页接口
* [SettingsView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/SettingsView.swift) - 监听切换标签通知
* [StatusBarController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/StatusBarController.swift) - 管理 NSPopover 展示与自动隐退，提供升级回调
* [KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/KnobStateManager.swift) - 在倒计时与会话到期时调用 StatusBarController

---

## 任务划分

### 任务 1：支持设置面板接收 Tab 切换通知

**文件：**
* 修改：`PhantomKnob/Service/SettingsWindowController.swift`
* 修改：`PhantomKnob/View/SettingsView.swift`

- [ ] **步骤 1：在 SettingsWindowController 中增加指定标签页打开方法**
  在 `SettingsWindowController.swift` 约第 53 行（在 `show()` 方法后）添加如下重载：
  ```swift
  func show(tab: SettingsTab) {
      show()
      NotificationCenter.default.post(
          name: NSNotification.Name("SettingsSelectTab"),
          object: nil,
          userInfo: ["tab": tab]
      )
  }
  ```

- [ ] **步骤 2：在 SettingsView 中监听 Tab 切换通知**
  修改 `SettingsView.swift` 中对 `SettingsTab` 状态的声明与接收通知（在 `SettingsView` 的 `body` 块后添加 `onReceive`）：
  ```swift
  // 查找：struct SettingsView: View
  // 确保 activeTab 可以被更新。
  // 在 VStack {} 外部的尾部添加：
  .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SettingsSelectTab"))) { notification in
      if let tab = notification.userInfo?["tab"] as? SettingsTab {
          withAnimation(.easeInOut(duration: 0.15)) {
              self.activeTab = tab
          }
      }
  }
  ```

- [ ] **步骤 3：编译代码确保无误**
  运行：`xcodebuild -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -configuration Debug`
  预期：Build Succeeded.

- [ ] **步骤 4：Commit**
  ```bash
  git add PhantomKnob/Service/SettingsWindowController.swift PhantomKnob/View/SettingsView.swift
  git commit -m "feat: add tab selection support via notification in Settings panel"
  ```

---

### 任务 2：创建 `FreeEditionPopoverView` 视图

**文件：**
* 创建：`PhantomKnob/View/FreeEditionPopoverView.swift`
* 创建：`PhantomKnob/PhantomKnobTests/FreeEditionPopoverTests.swift`

- [ ] **步骤 1：编写 FreeEditionPopoverView.swift**
  创建 [FreeEditionPopoverView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/FreeEditionPopoverView.swift) 渲染 UI：
  ```swift
  import SwiftUI

  enum FreePopoverMode: Equatable {
      case activating(secondsRemaining: Double)
      case sessionExpired
  }

  struct FreeEditionPopoverView: View {
      let mode: FreePopoverMode
      var onUpgrade: () -> Void
      
      var body: some View {
          VStack(spacing: 8) {
              switch mode {
              case .activating(let seconds):
                  HStack {
                      Text(String(localized: "popover.freeEdition", defaultValue: "FREE EDITION"))
                          .font(.system(size: 10, weight: .bold))
                          .foregroundColor(.orange)
                          .tracking(1)
                      Spacer()
                  }
                  
                  HStack(spacing: 12) {
                      ProgressView()
                          .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                          .scaleEffect(0.8)
                          .frame(width: 16, height: 16)
                      
                      Text(String(localized: "popover.preparing", defaultValue: "Preparing gesture environment..."))
                          .font(.system(size: 12, weight: .medium))
                          .foregroundColor(.white)
                  }
                  .padding(.vertical, 4)
                  
                  Text(String(format: String(localized: "popover.countdown", defaultValue: "Activating in %ds..."), Int(ceil(seconds))))
                      .font(.system(size: 14, weight: .bold))
                      .foregroundColor(.cyan)
                      
              case .sessionExpired:
                  HStack {
                      Text(String(localized: "popover.freeEdition", defaultValue: "FREE EDITION"))
                          .font(.system(size: 10, weight: .bold))
                          .foregroundColor(.red)
                          .tracking(1)
                      Spacer()
                  }
                  
                  VStack(alignment: .leading, spacing: 6) {
                      HStack(spacing: 6) {
                          Text("🔒")
                              .font(.system(size: 14))
                          Text(String(localized: "popover.expired.title", defaultValue: "Session Expired (15m)"))
                              .font(.system(size: 13, weight: .bold))
                              .foregroundColor(.white)
                      }
                      
                      Text(String(localized: "popover.expired.description", defaultValue: "The free edition automatically deactivated after 15 minutes. Press ⌥⌘K to activate again."))
                          .font(.system(size: 11))
                          .foregroundColor(.white.opacity(0.7))
                          .lineSpacing(3)
                  }
                  .padding(.vertical, 2)
                  
                  Button(action: onUpgrade) {
                      Text(String(localized: "popover.upgrade", defaultValue: "Get Premium for Unlimited Time ➔"))
                          .font(.system(size: 11, weight: .semibold))
                          .foregroundColor(.cyan)
                          .underline()
                  }
                  .buttonStyle(.plain)
                  .padding(.top, 4)
              }
          }
          .padding(12)
          .frame(width: 240)
          .preferredColorScheme(.dark)
      }
  }
  ```

- [ ] **步骤 2：编写 FreeEditionPopoverTests.swift**
  创建 [FreeEditionPopoverTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnobTests/FreeEditionPopoverTests.swift)：
  ```swift
  import XCTest
  @testable import PhantomKnob

  final class FreeEditionPopoverTests: XCTestCase {
      func testModeEquality() {
          XCTAssertEqual(FreePopoverMode.activating(secondsRemaining: 2.0), FreePopoverMode.activating(secondsRemaining: 2.0))
          XCTAssertNotEqual(FreePopoverMode.activating(secondsRemaining: 2.0), FreePopoverMode.activating(secondsRemaining: 1.0))
          XCTAssertNotEqual(FreePopoverMode.activating(secondsRemaining: 2.0), FreePopoverMode.sessionExpired)
      }
  }
  ```

- [ ] **步骤 3：在工程中引入并编译测试**
  通过运行 xcodebuild 自动校验：
  运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS'`
  预期：Tests Passed.

- [ ] **步骤 4：Commit**
  ```bash
  git add PhantomKnob/View/FreeEditionPopoverView.swift PhantomKnob/PhantomKnobTests/FreeEditionPopoverTests.swift
  git commit -m "feat: implement FreeEditionPopoverView and equality tests"
  ```

---

### 任务 3：集成 `NSPopover` 到 `StatusBarController`

**文件：**
* 修改：`PhantomKnob/Service/StatusBarController.swift`
* 修改：`PhantomKnob/PhantomKnobTests/StatusBarControllerTests.swift`

- [ ] **步骤 1：在 StatusBarController 中添加 Popover 成员变量与 API**
  在 `StatusBarController.swift` 中声明 `private var freePopover: NSPopover?` 并添加相关方法：
  ```swift
  // 在 StatusBarController 类内部声明
  private var freePopover: NSPopover?
  private var popoverDismissWorkItem: DispatchWorkItem?

  func showFreeActivatingPopover(secondsRemaining: Double) {
      DispatchQueue.main.async { [weak self] in
          guard let self = self else { return }
          self.popoverDismissWorkItem?.cancel()
          self.popoverDismissWorkItem = nil
          
          let popover = self.freePopover ?? NSPopover()
          popover.behavior = .transient
          popover.animates = true
          
          let contentView = FreeEditionPopoverView(mode: .activating(secondsRemaining: secondsRemaining)) { [weak self] in
              self?.dismissFreePopover()
              SettingsWindowController.shared.show(tab: .about)
          }
          popover.contentViewController = NSHostingController(rootView: contentView)
          self.freePopover = popover
          
          if let button = self.statusItem?.button {
              if !popover.isShown {
                  popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minYEdge)
              }
          }
      }
  }

  func showFreeExpiredPopover() {
      DispatchQueue.main.async { [weak self] in
          guard let self = self else { return }
          self.popoverDismissWorkItem?.cancel()
          
          let popover = self.freePopover ?? NSPopover()
          popover.behavior = .transient
          popover.animates = true
          
          let contentView = FreeEditionPopoverView(mode: .sessionExpired) { [weak self] in
              self?.dismissFreePopover()
              SettingsWindowController.shared.show(tab: .about)
          }
          popover.contentViewController = NSHostingController(rootView: contentView)
          self.freePopover = popover
          
          if let button = self.statusItem?.button {
              if !popover.isShown {
                  popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minYEdge)
              }
          }
          
          // 5s 后自动隐退
          let workItem = DispatchWorkItem { [weak self] in
              self?.dismissFreePopover()
          }
          self.popoverDismissWorkItem = workItem
          DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
      }
  }

  func dismissFreePopover() {
      DispatchQueue.main.async { [weak self] in
          self?.popoverDismissWorkItem?.cancel()
          self?.popoverDismissWorkItem = nil
          self?.freePopover?.performClose(nil)
          self?.freePopover = nil
      }
  }
  ```

- [ ] **步骤 2：在 StatusBarController 退出/模式切换时清理 Popover**
  修改 `StatusBarController.swift` 的 `updateState(_:targetName:)` 在非 Activating/Expired 状态时主动调用 `dismissFreePopover()`，避免气泡残留：
  ```swift
  // 在 updateState(state, targetName:) 最开始处添加：
  if state != .inactive && state != .customizing {
      dismissFreePopover()
  }
  ```

- [ ] **步骤 3：编写测试验证 API 运行无误**
  在 `StatusBarControllerTests.swift` 中增加测试用例：
  ```swift
  func testFreeActivatingPopoverInstantiation() {
      let controller = StatusBarController()
      controller.showFreeActivatingPopover(secondsRemaining: 2.0)
      
      let expectation = XCTestExpectation(description: "Show popover")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          controller.dismissFreePopover()
          expectation.fulfill()
      }
      wait(for: [expectation], timeout: 2.0)
  }
  ```

- [ ] **步骤 4：运行测试确认通过**
  运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS'`
  预期：Tests Passed.

- [ ] **步骤 5：Commit**
  ```bash
  git add PhantomKnob/Service/StatusBarController.swift PhantomKnob/PhantomKnobTests/StatusBarControllerTests.swift
  git commit -m "feat: integrate NSPopover into StatusBarController with auto-dismiss timers"
  ```

---

### 任务 4：连接 `KnobStateManager` 状态流

**文件：**
* 修改：`PhantomKnob/Service/KnobStateManager.swift`
* 修改：`PhantomKnob/PhantomKnobTests/KnobStateManagerFeatureGateTests.swift`

- [ ] **步骤 1：连接激活等待倒计时气泡**
  在 `KnobStateManager.swift` 约第 192 行，将 `let delay = featureGate.activationDelay` 下的代码块替换为包含 Popover 触发的逻辑：
  ```swift
  // 原有：
  // statusBarController.updateStateActivating(secondsRemaining: delay)
  // 替换为：
  statusBarController.updateStateActivating(secondsRemaining: delay)
  statusBarController.showFreeActivatingPopover(secondsRemaining: delay)
  
  // 定时器中如果分步倒计时，应同时更新气泡（如果 delay 大于 1.0 秒）：
  let timePassedWorkItem = DispatchWorkItem { [weak self] in
      self?.statusBarController.showFreeActivatingPopover(secondsRemaining: delay - 1.0)
  }
  DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: timePassedWorkItem)
  ```
  In `completeActivation` 方法首行，添加：
  ```swift
  statusBarController.dismissFreePopover()
  ```

- [ ] **步骤 2：连接会话到期时限气泡**
  在 `KnobStateManager.swift` 约第 252 行，当 `sessionTimeRemaining <= 0` 触发停用时，在 `self.toggleMode()` 调用后立即唤醒 Expired Popover：
  ```swift
  if self.sessionTimeRemaining <= 0 {
      PKLogger.knob.debug("Session limit reached. Automatically deactivating.")
      self.toggleMode()
      self.statusBarController.showFreeExpiredPopover()
  }
  ```

- [ ] **步骤 3：运行完整单元测试**
  运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS'`
  预期：所有 100+ 单元测试均测试通过，没有逻辑回退。

- [ ] **步骤 4：Commit**
  ```bash
  git add PhantomKnob/Service/KnobStateManager.swift
  git commit -m "feat: wire activation popover and session expired popover into KnobStateManager lifecycle"
  ```

---

## 验证计划

### 自动验证
运行命令：
`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob`

### 手动验证
1. **激活倒计时气泡验证**：
   * 将 App 模拟切换到 Free Edition 模式。
   * 按下 `⌥⌘K`，观察状态栏图标下方是否能准时弹出倒计时气泡，有 Progress 环且显示 `"Preparing gesture environment..."`。
   * 2 秒后气泡自动关闭，且应用变为激活蓝色。
2. **会话到期气泡验证**：
   * 在 [LicenseState.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Model/LicenseState.swift) 中临时将 `sessionLimitSeconds` 缩短为 `10.0`。
   * 激活手势，等待 10 秒。
   * 确认时间一到，手势立即退出激活，且状态栏自动展示带有 🔒 锁的 Expired 气泡。
   * 确认 5 秒后该气泡自动隐退。
3. **跳转机制验证**：
   * 到期气泡弹出后，点击“获取专业版解锁无限时”超链接，确认设置页面（Settings）被成功唤醒，且默认选中的是“About”标签页。
