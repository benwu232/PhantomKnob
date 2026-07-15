# 触控板两指扫动防多次误触发优化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现触控板两指滑动单次扫动仅触发一次切换，通过拦截 `event.phase` 进行状态生命周期锁定并忽略惯性滚动。

**架构：**
- 在 KnobPanelWindow 中重构出白盒测试接口 `handleScrollWheelGesture`。
- 实现无条件重置、惯性滚动（Momentum）忽略、触发后手势锁定的精细化手势流。
- 在 KnobPanelWindowControllerTests 中编写完整的确定性测试用例。

**技术栈：** Swift, SwiftUI, AppKit (NSWindow, NSEvent)

---

### 任务 1：重构与优化手势控制

**文件：**
- 修改：`PhantomKnob/Service/KnobPanelWindowController.swift`
- 修改：`PhantomKnob/PhantomKnobTests/KnobPanelWindowControllerTests.swift`

- [ ] **步骤 1：修改测试用例**
  在 `PhantomKnob/PhantomKnobTests/KnobPanelWindowControllerTests.swift` 中，用 `handleScrollWheelGesture` 编写确定性白盒测试用例，覆盖手势生命周期、锁定状态、惯性忽略与老设备退化防抖。
  
- [ ] **步骤 2：重构 KnobPanelWindow 并实现白盒逻辑**
  在 `PhantomKnob/Service/KnobPanelWindowController.swift` 中实现 `handleScrollWheelGesture`，并让 `scrollWheel` 进行调用。

- [ ] **步骤 3：运行测试验证**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnob -destination 'platform=macOS' test`
  预期：所有测试全部以 100% 成功率瞬时通过。

- [ ] **步骤 4：Commit**
  运行：
  ```bash
  git add PhantomKnob/Service/KnobPanelWindowController.swift PhantomKnob/PhantomKnobTests/KnobPanelWindowControllerTests.swift
  git commit -m "refactor: isolate scrollWheel logic for white-box testing, ignore momentum scrolling, decouple lifecycle reset"
  ```
