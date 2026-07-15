# 快捷面板极简与手势扫动切换实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 彻底清除标题和旋钮之间的引导组件，并增加触控板两指水平扫动切换焦点的功能，保证单元测试全部通过。

**架构：** 
- 在 KnobPanelView 中彻底移除 TutorialView 与相关判定。
- 在 KnobPanelWindow 中重写 `scrollWheel(with:)` 事件，判断两指水平滑动并触发 ViewModel 的切换逻辑。

**技术栈：** Swift, SwiftUI, AppKit (NSWindow, NSEvent, CGEvent)

---

### 任务 1：彻底清理标题与旋钮之间的引导组件

**文件：**
- 修改：`PhantomKnob/View/KnobPanelView.swift`

- [ ] **步骤 1：编写最少实现代码**
  修改 `PhantomKnob/View/KnobPanelView.swift`，删除对 `firstRunTutorialCompleted` 的分支渲染逻辑，直接渲染 `mainControlLayout`，并在 `.onAppear` 中强制写入 `firstRunTutorialCompleted = true`。
  
- [ ] **步骤 2：运行单元测试验证**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnob -destination 'platform=macOS' test`
  预期：所有原本测试依然全部通过。

- [ ] **步骤 3：Commit**
  运行：
  ```bash
  git add PhantomKnob/View/KnobPanelView.swift
  git commit -m "feat: completely remove tutorial view from KnobPanelView and auto-set complete flag"
  ```

---

### 任务 2：实现 KnobPanelWindow 两指左右扫动切换焦点

**文件：**
- 修改：`PhantomKnob/Service/KnobPanelWindowController.swift`
- 修改：`PhantomKnob/PhantomKnobTests/KnobPanelWindowControllerTests.swift`

- [ ] **步骤 1：编写扫动测试用例**
  在 `PhantomKnob/PhantomKnobTests/KnobPanelWindowControllerTests.swift` 中增加测试，利用 `CGEvent` 模拟水平 scrollWheel 事件，并验证 `focusedVariable` 发生对应改变。
  ```swift
  func testWindowScrollWheelSwipeFocusSwitching() {
      let controller = KnobPanelWindowController.shared
      controller.show()
      
      let viewModel = ControlPanelViewModel.shared
      viewModel.focusedVariable = .volume
      
      if let window = controller.window {
          // 模拟向右滚动的 scrollWheel 事件 (deltaX > 2.0)
          let cgEventRight = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 0, wheel2: 5, wheel3: 0)
          if let cg = cgEventRight, let ev = NSEvent(cgEvent: cg) {
              window.scrollWheel(with: ev)
              XCTAssertEqual(viewModel.focusedVariable, .brightness)
          }
          
          // 模拟向左滚动的 scrollWheel 事件 (deltaX < -2.0)
          let cgEventLeft = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 0, wheel2: -5, wheel3: 0)
          if let cg = cgEventLeft, let ev = NSEvent(cgEvent: cg) {
              window.scrollWheel(with: ev)
              XCTAssertEqual(viewModel.focusedVariable, .volume)
          }
      }
      controller.hide()
  }
  ```

- [ ] **步骤 2：运行测试验证失败**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnob -destination 'platform=macOS' test`
  预期：测试编译失败，因为 `KnobPanelWindow` 还未实现 `scrollWheel(with:)` 处理扫动手势。

- [ ] **步骤 3：修改 KnobPanelWindow 实现**
  修改 `PhantomKnob/Service/KnobPanelWindowController.swift` 中的 `KnobPanelWindow` 类，重写 `scrollWheel(with:)` 并加入防抖限流变量 `lastSwipeTime`：
  ```swift
  class KnobPanelWindow: NSWindow {
      private var lastSwipeTime: Double = 0
      
      override var canBecomeKey: Bool {
          return true
      }
      
      override func keyDown(with event: NSEvent) {
          let keyCode = event.keyCode
          if keyCode == 123 { // Left arrow
              ControlPanelViewModel.shared.selectPrevVariable()
          } else if keyCode == 124 { // Right arrow
              ControlPanelViewModel.shared.selectNextVariable()
          } else if keyCode == 48 { // Tab key
              if event.modifierFlags.contains(.shift) {
                  ControlPanelViewModel.shared.selectPrevVariable()
              } else {
                  ControlPanelViewModel.shared.selectNextVariable()
              }
          } else {
              super.keyDown(with: event)
          }
      }
      
      override func scrollWheel(with event: NSEvent) {
          let deltaX = event.scrollingDeltaX
          let deltaY = event.scrollingDeltaY
          
          if abs(deltaX) > abs(deltaY) && abs(deltaX) > 2.0 {
              let now = ProcessInfo.processInfo.systemUptime
              if now - lastSwipeTime > 0.4 {
                  if deltaX > 0 {
                      ControlPanelViewModel.shared.selectNextVariable()
                  } else if deltaX < 0 {
                      ControlPanelViewModel.shared.selectPrevVariable()
                  }
                  lastSwipeTime = now
              }
          } else {
              super.scrollWheel(with: event)
          }
      }
  }
  ```

- [ ] **步骤 4：运行测试验证通过**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnob -destination 'platform=macOS' test`
  预期：测试编译通过，并且新增的扫动聚焦测试用例与其它所有测试全部通过。

- [ ] **步骤 5：Commit**
  运行：
  ```bash
  git add PhantomKnob/Service/KnobPanelWindowController.swift PhantomKnob/PhantomKnobTests/KnobPanelWindowControllerTests.swift
  git commit -m "feat: override KnobPanelWindow scrollWheel to support two-finger horizontal swiping to switch focus"
  ```
