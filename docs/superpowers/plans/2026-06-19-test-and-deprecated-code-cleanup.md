# 单元测试修复与废弃代码清理 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修复 `testOptionHoldTemporaryToggle` 单元测试，移除废弃的 `ControlTarget` 相关类和文件，并将全局激活快捷键文档描述与现有代码对齐为 `⌘⌥R`。

**架构：** 在测试用例中注入对 `isProcessTrusted` 的 mock，保证其能够绕过权限验证；物理删除废弃的目标定义文件；对 `DemoSliderTarget` 移除协议继承并改用直接依赖调用；最终修改工程生成配置文件（project.yml）并重新生成 Xcode 工程。

**技术栈：** Swift 5.0, XcodeGen, xcodebuild, git

---

### 任务 1：修复 `testOptionHoldTemporaryToggle` 单元测试

**文件：**
- 修改：[CustomKnobTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnobTests/CustomKnobTests.swift)

- [ ] **步骤 1：在测试中 Mock 辅助功能权限**
  修改 `CustomKnobTests.swift` 中的 `testOptionHoldTemporaryToggle()` 方法，在实例化 `manager` 后，添加对 `isProcessTrusted` 的 Mock 注入：
  ```swift
      func testOptionHoldTemporaryToggle() {
          let manager = KnobStateManager(
              targetDetector: TargetDetector(),
              gestureClassifier: GestureClassifier(),
              overlayController: OverlayController(),
              statusBarController: StatusBarController(),
              touchHandler: GlobalTouchHandler()
          )
          // Mock start/stop to avoid C Private APIs that cause sandbox crashes
          manager.startMultitouch = {}
          manager.stopMultitouch = {}
          manager.isProcessTrusted = { true }
          
          // 1. 验证初始状态是 inactive
          XCTAssertEqual(manager.state, .inactive)
  ```

- [ ] **步骤 2：运行该单项单元测试验证通过**
  运行命令：
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' -only-testing PhantomKnobTests/CustomKnobTests/testOptionHoldTemporaryToggle CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
  ```
  预期：TEST SUCCEEDED，测试顺利通过且不再因权限问题报错。

- [ ] **步骤 3：Commit 变更**
  运行：
  ```bash
  git add PhantomKnob/PhantomKnobTests/CustomKnobTests.swift
  git commit -m "test: mock isProcessTrusted to fix testOptionHoldTemporaryToggle test failure"
  ```

---

### 任务 2：物理删除废弃协议及相关类文件，解耦演示目标

**文件：**
- 删除：`PhantomKnob/Control/ControlTarget.swift`
- 删除：`PhantomKnob/Control/GenericControlTarget.swift`
- 删除：`PhantomKnob/Service/AccessibilityTarget.swift`
- 删除：`PhantomKnob/PhantomKnobTests/AccessibilityTargetTests.swift`
- 修改：[DemoSliderTarget.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Control/DemoSliderTarget.swift)
- 修改：[DemoViewModel.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/ViewModel/DemoViewModel.swift)

- [ ] **步骤 1：物理删除废弃的目标和协议文件**
  运行：
  ```bash
  rm PhantomKnob/Control/ControlTarget.swift
  rm PhantomKnob/Control/GenericControlTarget.swift
  rm PhantomKnob/Service/AccessibilityTarget.swift
  rm PhantomKnob/PhantomKnobTests/AccessibilityTargetTests.swift
  ```

- [ ] **步骤 2：解耦 DemoSliderTarget 对 ControlTarget 的协议继承**
  修改 `DemoSliderTarget.swift`：
  ```swift
  import Foundation

  class DemoSliderTarget {
      var value: Double = 50.0
      let minValue: Double = 0
      let maxValue: Double = 100
      let displayName: String = "演示数值"
      
      private let sensitivity: Double = 0.5
      
      func applyDelta(_ deltaAngle: Double) -> Double {
          let newValue = value + deltaAngle * sensitivity
          value = newValue.clamped(to: minValue...maxValue)
          return value
      }
  }
  ```

- [ ] **步骤 3：修改 DemoViewModel 对 DemoSliderTarget 的引用**
  修改 `DemoViewModel.swift`：
  ```swift
  import Foundation
  import SwiftUI
  import AppKit

  class DemoViewModel: ObservableObject, TouchpadEventDelegate {
      @Published var knobAngle: Double = 0
      @Published var displayValue: Double = 50.0
      @Published var isActive: Bool = false
      @Published var centerX: Double = 0
      @Published var centerY: Double = 0
      @Published var radius: Double = 0
      
      private let touchpadEngine = TouchpadEngine()
      private let knobAlgorithm = KnobAlgorithm()
      private var controlTarget: DemoSliderTarget
      private var previousKnob: KnobCore = .invalid
  ```

- [ ] **步骤 4：使用 XcodeGen 重新生成工程文件**
  运行：
  ```bash
  cd PhantomKnob
  xcodegen generate
  cd ..
  ```
  预期：工程文件重新生成成功，已删除的文件不再包含在编译源列表中。

- [ ] **步骤 5：运行全部单元测试验证编译和运行状况**
  运行：
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
  ```
  预期：TEST SUCCEEDED，所有剩余的 127+ 个单元测试用例全部通过。

- [ ] **步骤 6：Commit 变更**
  运行：
  ```bash
  git add PhantomKnob/Control/DemoSliderTarget.swift PhantomKnob/ViewModel/DemoViewModel.swift PhantomKnob/PhantomKnob.xcodeproj/project.pbxproj
  git rm PhantomKnob/Control/ControlTarget.swift PhantomKnob/Control/GenericControlTarget.swift PhantomKnob/Service/AccessibilityTarget.swift PhantomKnob/PhantomKnobTests/AccessibilityTargetTests.swift
  git commit -m "refactor: clean up deprecated ControlTarget files and rewrite DemoViewModel to use DemoSliderTarget directly"
  ```

---

### 任务 3：对齐 CONTEXT.md 快捷键说明

**文件：**
- 修改：[CONTEXT.md](file:///Users/wb/work/phantom_knob_mac/CONTEXT.md)

- [ ] **步骤 1：修改 CONTEXT.md 中陈旧的 K 快捷键描述**
  修改 `CONTEXT.md` 第 84 行与第 319 行：
  ```markdown
  // Line 84 左右
  **Activation:** Hotkey (`⌘⌥R` by default, customizable in settings)

  // Line 319 左右
  ## Hotkey

  ### Default
  `⌘⌥R` (Command + Option + R)
  ```

- [ ] **步骤 2：验证文档修改无误并 Commit**
  运行：
  ```bash
  git add CONTEXT.md
  git commit -m "docs: align default hotkey to Cmd+Option+R in CONTEXT.md"
  ```
