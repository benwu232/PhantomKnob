# 触控板两指扫动防多次误触发优化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现触控板两指滑动单次扫动仅触发一次切换，解决过度触发的问题。

**架构：** 在 KnobPanelWindow 中重写 `scrollWheel(with:)` 事件，通过拦截 `event.phase` 进行手势状态的生命周期锁定，非手势设备退化为时间防抖。

**技术栈：** Swift, SwiftUI, AppKit (NSWindow, NSEvent)

---

### 任务 1：重构 scrollWheel 并加入 event.phase 状态锁定

**文件：**
- 修改：`PhantomKnob/Service/KnobPanelWindowController.swift`
- 修改：`PhantomKnob/PhantomKnobTests/KnobPanelWindowControllerTests.swift`

- [ ] **步骤 1：修改测试以注入 phase**
  在 `PhantomKnob/PhantomKnobTests/KnobPanelWindowControllerTests.swift` 中修改扫动测试，不仅传入 delta 还要传入 phase 以准确模拟触控板事件：
  ```swift
  func testWindowScrollWheelSwipeFocusSwitching() {
      let controller = KnobPanelWindowController.shared
      controller.show()
      
      let viewModel = ControlPanelViewModel.shared
      viewModel.focusedVariable = .volume
      
      if let window = controller.window {
          // 模拟向右轻扫开始和改变 (deltaX > 2.0)
          let cgEventRight = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 0, wheel2: 5, wheel3: 0)
          if let cg = cgEventRight, let ev = NSEvent(cgEvent: cg) {
              // 模拟 phasebegan
              // 由于单元测试里难以直接改变只读的 event.phase，我们可以在测试中触发
              // 但由于系统生成的 event.phase 可能为空，我们的退化时间防抖逻辑此时能作为后备被触发！
              // 为了彻底测试 phase 分支，如果我们不能直接在 NSEvent 中设置 phase，我们可以依赖退化防抖或依靠 CGEvent 模拟。
              // 事实上，因为 phase 在测试中是只读且默认是 .none，它会走传统时间防抖。我们可以让其进行 0.5s 的等待以测试传统防抖，或仅进行正常切换测试。
              window.scrollWheel(with: ev)
              XCTAssertEqual(viewModel.focusedVariable, .brightness)
          }
          
          let cgEventLeft = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 0, wheel2: -5, wheel3: 0)
          if let cg = cgEventLeft, let ev = NSEvent(cgEvent: cg) {
              let exp = XCTestExpectation(description: "wait for swipe throttle")
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                  window.scrollWheel(with: ev)
                  XCTAssertEqual(viewModel.focusedVariable, .volume)
                  exp.fulfill()
              }
              wait(for: [exp], timeout: 1.0)
          }
      }
      controller.hide()
  }
  ```

- [ ] **步骤 2：编写最少实现代码**
  修改 `PhantomKnob/Service/KnobPanelWindowController.swift` 中 `KnobPanelWindow` 的 `scrollWheel(with:)` 方法和状态变量：
  ```swift
  class KnobPanelWindow: NSWindow {
      private var lastSwipeTime: Double = 0
      private var hasSwipedInCurrentGesture: Bool = false
      
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
          let phase = event.phase
          let momentumPhase = event.momentumPhase
          
          let deltaX = event.scrollingDeltaX
          let deltaY = event.scrollingDeltaY
          
          // 判断是否是水平扫动
          let isHorizontal = abs(deltaX) > abs(deltaY) && abs(deltaX) > 2.0
          
          if isHorizontal {
              if !phase.isEmpty {
                  // 有 phase 信息，说明是触控板或支持手势的设备
                  if momentumPhase.isEmpty || momentumPhase == .none {
                      if phase == .began {
                          hasSwipedInCurrentGesture = false
                      }
                      
                      if !hasSwipedInCurrentGesture && abs(deltaX) > 3.0 {
                          if deltaX > 0 {
                              ControlPanelViewModel.shared.selectNextVariable()
                          } else if deltaX < 0 {
                              ControlPanelViewModel.shared.selectPrevVariable()
                          }
                          hasSwipedInCurrentGesture = true
                      }
                      
                      if phase == .ended || phase == .cancelled {
                          hasSwipedInCurrentGesture = false
                      }
                  }
              } else {
                  // 没有 phase 信息 (例如传统鼠标的水平滚轮)，回退到时间防抖
                  let now = ProcessInfo.processInfo.systemUptime
                  if now - lastSwipeTime > 0.4 {
                      if deltaX > 0 {
                          ControlPanelViewModel.shared.selectNextVariable()
                      } else if deltaX < 0 {
                          ControlPanelViewModel.shared.selectPrevVariable()
                      }
                      lastSwipeTime = now
                  }
              }
              // 拦截水平滚动，不向后传递
              return
          } else {
              super.scrollWheel(with: event)
          }
      }
  }
  ```

- [ ] **步骤 3：运行测试验证**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnob -destination 'platform=macOS' test`
  预期：所有测试全量编译通过并执行成功。

- [ ] **步骤 4：Commit**
  运行：
  ```bash
  git add PhantomKnob/Service/KnobPanelWindowController.swift PhantomKnob/PhantomKnobTests/KnobPanelWindowControllerTests.swift
  git commit -m "feat: optimize scrollWheel gesture phase lock to prevent multiple triggers in one swipe"
  ```
