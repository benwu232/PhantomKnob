# 快捷面板极简与操作便利性优化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现快捷旋钮面板的视觉极简，优化盲操聚焦，并添加键盘 Tab/方向键快捷切换焦点功能，保证单元测试全量通过。

**架构：** 在 ControlPanelViewModel 中实现聚焦非置空及循环切换方法，并在无边框 KnobPanelWindow 中重写键盘事件，截获 Tab 和方向键调用 ViewModel 的切换逻辑。

**技术栈：** Swift, SwiftUI, AppKit (NSWindow, NSEvent), XCTest

---

### 任务 1：设计与实现 ControlPanelViewModel 焦点切换逻辑

**文件：**
- 修改：`PhantomKnob/ViewModel/KnobPanelViewModel.swift`
- 修改：`PhantomKnob/PhantomKnobTests/KnobPanelViewModelTests.swift`

- [ ] **步骤 1：编写失败的测试**
  在 `PhantomKnob/PhantomKnobTests/KnobPanelViewModelTests.swift` 文件底部添加测试用例，校验默认聚焦为音量、移出时不失焦、以及循环切换焦点的行为：
  ```swift
  func testMinimalKnobPanelInteraction() {
      let viewModel = ControlPanelViewModel()
      
      // 默认聚焦应为 volume
      XCTAssertEqual(viewModel.focusedVariable, .volume)
      
      // selectNextVariable 应该切换到 brightness
      viewModel.selectNextVariable()
      XCTAssertEqual(viewModel.focusedVariable, .brightness)
      
      // selectNextVariable 应该切换到 keyboardBacklight
      viewModel.selectNextVariable()
      XCTAssertEqual(viewModel.focusedVariable, .keyboardBacklight)
      
      // selectNextVariable 应该回到 volume
      viewModel.selectNextVariable()
      XCTAssertEqual(viewModel.focusedVariable, .volume)
      
      // selectPrevVariable 应该切换到 keyboardBacklight
      viewModel.selectPrevVariable()
      XCTAssertEqual(viewModel.focusedVariable, .keyboardBacklight)
      
      // setHoverTarget 非 nil 应更新焦点
      viewModel.setHoverTarget(.brightness)
      XCTAssertEqual(viewModel.focusedVariable, .brightness)
      
      // setHoverTarget 传入 nil 应该不清除焦点 (仍为 brightness)
      viewModel.setHoverTarget(nil)
      XCTAssertEqual(viewModel.focusedVariable, .brightness)
  }
  ```

- [ ] **步骤 2：运行测试验证失败**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnob -destination 'platform=macOS' test`
  预期：编译失败，因为 `ControlPanelViewModel` 尚无 `selectNextVariable` 和 `selectPrevVariable` 方法。

- [ ] **步骤 3：编写最少实现代码**
  修改 `PhantomKnob/ViewModel/KnobPanelViewModel.swift` 中的 `ControlPanelViewModel` 类：
  1. 将 `@Published var focusedVariable: ControllableVariable? = nil` 修改为默认初始化值 `.volume`：
     ```swift
     @Published var focusedVariable: ControllableVariable? = .volume
     ```
  2. 修改 `setHoverTarget(_ target: ControllableVariable?)`，仅当传入的 target 非空时才赋值，为空时不清除焦点：
     ```swift
     func setHoverTarget(_ target: ControllableVariable?) {
         if let target = target {
             focusedVariable = target
         }
     }
     ```
  3. 新增焦点循环切换方法：
     ```swift
     func selectNextVariable() {
         switch focusedVariable {
         case .volume:
             focusedVariable = .brightness
         case .brightness:
             focusedVariable = .keyboardBacklight
         case .keyboardBacklight:
             focusedVariable = .volume
         case nil:
             focusedVariable = .volume
         }
     }
     
     func selectPrevVariable() {
         switch focusedVariable {
         case .volume:
             focusedVariable = .keyboardBacklight
         case .brightness:
             focusedVariable = .volume
         case .keyboardBacklight:
             focusedVariable = .brightness
         case nil:
             focusedVariable = .volume
         }
     }
     ```

- [ ] **步骤 4：运行测试验证通过**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnob -destination 'platform=macOS' test`
  预期：测试编译通过，并且新增的 `testMinimalKnobPanelInteraction` 测试用例和原有测试全部通过。

- [ ] **步骤 5：Commit**
  运行：
  ```bash
  git add PhantomKnob/ViewModel/KnobPanelViewModel.swift PhantomKnob/PhantomKnobTests/KnobPanelViewModelTests.swift
  git commit -m "feat: implement default focus, focus-holding and variable rotation switching logic"
  ```

---

### 任务 2：重写 KnobPanelWindow 键盘响应支持快捷切换

**文件：**
- 修改：`PhantomKnob/Service/KnobPanelWindowController.swift`
- 修改：`PhantomKnob/PhantomKnobTests/KnobPanelWindowControllerTests.swift`

- [ ] **步骤 1：编写键盘事件分发测试**
  在 `PhantomKnob/PhantomKnobTests/KnobPanelWindowControllerTests.swift` 中增加测试，注入键盘事件并验证 `ControlPanelViewModel.shared.focusedVariable` 发生对应改变。
  ```swift
  func testWindowKeyboardFocusSwitching() {
      let controller = KnobPanelWindowController.shared
      controller.show()
      
      let viewModel = ControlPanelViewModel.shared
      viewModel.focusedVariable = .volume
      
      // 创建模拟的左键(123)和右键(124)键盘事件
      if let window = controller.window {
          let rightEvent = NSEvent.keyEvent(
              with: .keyDown,
              location: .zero,
              modifierFlags: [],
              timestamp: 0,
              windowNumber: window.windowNumber,
              context: nil,
              characters: "",
              charactersIgnoringModifiers: "",
              isARepeat: false,
              keyCode: 124 // Right arrow
          )
          if let ev = rightEvent {
              window.keyDown(with: ev)
              XCTAssertEqual(viewModel.focusedVariable, .brightness)
          }
          
          let leftEvent = NSEvent.keyEvent(
              with: .keyDown,
              location: .zero,
              modifierFlags: [],
              timestamp: 0,
              windowNumber: window.windowNumber,
              context: nil,
              characters: "",
              charactersIgnoringModifiers: "",
              isARepeat: false,
              keyCode: 123 // Left arrow
          )
          if let ev = leftEvent {
              window.keyDown(with: ev)
              XCTAssertEqual(viewModel.focusedVariable, .volume)
          }
      }
      controller.hide()
  }
  ```

- [ ] **步骤 2：运行测试验证失败**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnob -destination 'platform=macOS' test`
  预期：新加测试执行失败，因为 `KnobPanelWindow` 还未拦截键盘事件进行焦点移动。

- [ ] **步骤 3：修改 KnobPanelWindow 实现**
  修改 `PhantomKnob/Service/KnobPanelWindowController.swift` 中的 `KnobPanelWindow` 类，重写 `keyDown(with:)`：
  ```swift
  class KnobPanelWindow: NSWindow {
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
  }
  ```

- [ ] **步骤 4：运行测试验证通过**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnob -destination 'platform=macOS' test`
  预期：测试编译通过，并且注入键盘测试以及全部测试通过。

- [ ] **步骤 5：Commit**
  运行：
  ```bash
  git add PhantomKnob/Service/KnobPanelWindowController.swift PhantomKnob/PhantomKnobTests/KnobPanelWindowControllerTests.swift
  git commit -m "feat: override KnobPanelWindow keyDown event to route Tab and Arrow keys to switch focus"
  ```
