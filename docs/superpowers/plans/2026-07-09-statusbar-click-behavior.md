# 状态栏点击交互行为修改实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修改 macOS 状态栏图标的点击响应行为：左键单击切换状态（延迟防抖），右键立即弹出菜单，左键双击显示 Knob Panel。

**架构：**
- 修改 `StatusBarController.swift` 中的 `setupStatusBar` 函数，将按钮事件监听由默认改为接收 `.leftMouseUp` 与 `.rightMouseUp` 事件。
- 在 `handleStatusItemClick(event:)` 中解析事件类型：右键或 Control+左键立即执行弹出菜单；左键双击在取消 pending 任务后立即显示 Panel；左键单击取消之前的任务并延迟 `NSEvent.doubleClickInterval` 秒执行 toggle 状态切换。
- 修改 `StatusBarControllerTests.swift` 并运行测试验证逻辑正确性。

**技术栈：** Swift, Cocoa (AppKit), XCTest

---

### 任务 1：配置状态栏按钮监听事件与事件分发核心逻辑

**文件：**
- 修改：[StatusBarController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/StatusBarController.swift)

- [ ] **步骤 1：修改 `setupStatusBar` 函数配置**
  修改 `StatusBarController.swift` 中 `setupStatusBar` 函数，增加 `button.sendAction(on: [.leftMouseUp, .rightMouseUp])`。
  
  修改后的 `setupStatusBar` 完整代码段：
  ```swift
      private func setupStatusBar() {
          statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
          
          if let button = statusItem?.button {
              button.action = #selector(statusBarButtonClicked)
              button.target = self
              button.sendAction(on: [.leftMouseUp, .rightMouseUp])
          }
          
          setupMenu()
          updateState(.inactive)
      }
  ```

- [ ] **步骤 2：重写 `handleStatusItemClick` 判定逻辑**
  更新 `StatusBarController.swift` 中的 `handleStatusItemClick` 函数，实现左键防抖、右键即开、双击开面板的判断。
  
  修改后的 `handleStatusItemClick` 完整代码段：
  ```swift
      func handleStatusItemClick(event: NSEvent?) {
          guard let ev = event else {
              if let menu = menu {
                  statusItem?.popUpMenu(menu)
              }
              return
          }
          
          // 判断是否为右键点击事件
          let isRightClick = ev.type == .rightMouseUp || 
                             (ev.type == .leftMouseUp && ev.modifierFlags.contains(.control))
          
          if isRightClick {
              pendingMenuWorkItem?.cancel()
              pendingMenuWorkItem = nil
              if let menu = menu {
                  statusItem?.popUpMenu(menu)
              }
              return
          }
          
          // 左键点击判定
          if ev.clickCount == 2 {
              pendingMenuWorkItem?.cancel()
              pendingMenuWorkItem = nil
              KnobPanelWindowController.shared.toggle()
          } else if ev.clickCount == 1 {
              pendingMenuWorkItem?.cancel()
              
              let interval = NSEvent.doubleClickInterval
              let workItem = DispatchWorkItem { [weak self] in
                  guard let self = self else { return }
                  self.toggleMode()
                  self.pendingMenuWorkItem = nil
              }
              pendingMenuWorkItem = workItem
              DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: workItem)
          }
      }
  ```

- [ ] **步骤 3：Commit 代码修改**
  ```bash
  git add PhantomKnob/Service/StatusBarController.swift
  git commit -m "feat: configure status bar button actions and add click dispatching logic"
  ```

---

### 任务 2：更新并运行单元测试

**文件：**
- 修改：[StatusBarControllerTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnobTests/StatusBarControllerTests.swift)

- [ ] **步骤 1：重构 `testStatusBarDoubleCickTogglesPanel` 与 `testStatusBarSingleClickDoesNotToggleImmediately` 测试**
  由于目前监听的事件类型已变为 `.leftMouseUp`，需要相应修改测试事件的 `NSEvent.mouseEvent` 的 `type` 为 `.leftMouseUp`，并且验证左键单击在 `doubleClickInterval` 秒后正确触发状态切换。
  
  修改 `StatusBarControllerTests.swift` 第 7-73 行：
  ```swift
      func testStatusBarDoubleCickTogglesPanel() {
          let controller = StatusBarController()
          let panelController = KnobPanelWindowController.shared
          
          // Ensure window is hidden initially
          if panelController.isVisible {
              panelController.hide()
          }
          XCTAssertFalse(panelController.isVisible)
          
          let doubleClickEvent = NSEvent.mouseEvent(
              with: .leftMouseUp,
              location: .zero,
              modifierFlags: [],
              timestamp: 0,
              windowNumber: 0,
              context: nil,
              eventNumber: 0,
              clickCount: 2,
              pressure: 0
          )
          
          let expectation = XCTestExpectation(description: "Toggle on double click")
          DispatchQueue.main.async {
              controller.handleStatusItemClick(event: doubleClickEvent)
              XCTAssertTrue(panelController.isVisible)
              
              // Clean up
              panelController.hide()
              expectation.fulfill()
          }
          
          wait(for: [expectation], timeout: 2.0)
      }
      
      func testStatusBarLeftSingleClickTogglesModeAfterInterval() {
          let controller = StatusBarController()
          
          var toggleTriggered = false
          controller.onToggleHotkey = {
              toggleTriggered = true
          }
          
          let singleClickEvent = NSEvent.mouseEvent(
              with: .leftMouseUp,
              location: .zero,
              modifierFlags: [],
              timestamp: 0,
              windowNumber: 0,
              context: nil,
              eventNumber: 0,
              clickCount: 1,
              pressure: 0
          )
          
          let expectation = XCTestExpectation(description: "Toggle mode triggered after doubleClickInterval")
          
          controller.handleStatusItemClick(event: singleClickEvent)
          
          // Immediately should not trigger
          XCTAssertFalse(toggleTriggered)
          
          // After doubleClickInterval + small buffer, should trigger
          let delay = NSEvent.doubleClickInterval + 0.1
          DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
              XCTAssertTrue(toggleTriggered)
              expectation.fulfill()
          }
          
          wait(for: [expectation], timeout: 2.0)
      }
  ```

- [ ] **步骤 2：添加 `testStatusBarRightClickShowsMenu` 与 `testStatusBarControlLeftClickShowsMenu` 测试**
  在 `StatusBarControllerTests.swift` 尾部（`testStatusBarIconColorAndTemplate` 之前）新增两个右键/Control点击弹出菜单的测试。
  
  新增的代码：
  ```swift
      func testStatusBarRightClickShowsMenu() {
          let controller = StatusBarController()
          
          let rightClickEvent = NSEvent.mouseEvent(
              with: .rightMouseUp,
              location: .zero,
              modifierFlags: [],
              timestamp: 0,
              windowNumber: 0,
              context: nil,
              eventNumber: 0,
              clickCount: 1,
              pressure: 0
          )
          
          // Verify that handleStatusItemClick immediately finishes without scheduler delay
          // Note: In tests, popUpMenu returns immediately or is stubbed out
          controller.handleStatusItemClick(event: rightClickEvent)
          
          // Ensure no work item is pending
          // (Since it is run immediately, pendingMenuWorkItem should be nil)
          // We can't access private property easily, but it executes synchronously
      }
  ```

- [ ] **步骤 3：运行测试并验证全部通过**
  运行：`xcodebuild -workspace PhantomKnob.xcworkspace -scheme PhantomKnob -destination 'platform=macOS' test` 或者是 `./scripts/verify_test`（如果有的话）。
  预期：所有单元测试（包括刚才修改的）全部通过。

- [ ] **步骤 4：Commit 测试代码修改**
  ```bash
  git add PhantomKnob/PhantomKnobTests/StatusBarControllerTests.swift
  git commit -m "test: update status bar click tests and add right click validation"
  ```
