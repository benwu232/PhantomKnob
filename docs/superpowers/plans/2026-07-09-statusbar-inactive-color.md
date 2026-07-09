# 状态栏未激活状态颜色修改实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修改 status bar icon 在 `inactive` 状态下的颜色逻辑，将其从 `NSColor.systemGray` 变更为带透明度的 `NSColor.labelColor.withAlphaComponent(0.35)`。

**架构：**
- 修改 `StatusBarController.swift` 中的 `updateState` 函数，在解析为 `.inactive` 和 `.customizing` 状态时，应用 `NSColor.labelColor.withAlphaComponent(0.35)`。
- 运行现有的单元测试套件以验证没有任何构建错误且已有测试全部通过。

**技术栈：** Swift, Cocoa (AppKit), XCTest

---

### 任务 1：修改状态栏控制器颜色逻辑

**文件：**
- 修改：[StatusBarController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/StatusBarController.swift:215-230)

- [ ] **步骤 1：修改 `updateState` 中的颜色解析分支**
  打开 `StatusBarController.swift` 并寻找到 `updateState` 中设置 `tintColor` 的 `switch` 分支，将其变更为使用 `.labelColor.withAlphaComponent(0.35)`。
  
  修改后的完整代码段：
  ```swift
              // Resolve tint color based on state (Option B)
              let tintColor: NSColor
              switch state {
              case .inactive:
                  tintColor = NSColor.labelColor.withAlphaComponent(0.35)
              case .activated:
                  tintColor = .systemCyan
              case .knobing, .cooling:
                  tintColor = .systemYellow
              case .customizing:
                  tintColor = NSColor.labelColor.withAlphaComponent(0.35)
              }
  ```

- [ ] **步骤 2：Commit 代码修改**
  ```bash
  git add PhantomKnob/Service/StatusBarController.swift
  git commit -m "feat: change inactive status bar icon color to semi-transparent labelColor"
  ```

---

### 任务 2：验证单元测试与构建

**文件：**
- 无需修改文件，仅执行测试与验证。

- [ ] **步骤 1：运行单元测试**
  运行：`/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' test`
  预期：全部 152 项测试均能编译并顺利通过。

- [ ] **步骤 2：验证测试通过后 Commit**
  若有文档修改尚未 commit，一并整理或直接声明验证通过。
