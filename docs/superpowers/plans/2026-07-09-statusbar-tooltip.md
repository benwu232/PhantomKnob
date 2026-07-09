# 状态栏 Hover 提示优化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将状态栏图标的 Hover 提示信息结构修改为首行固定为 “PhantomKnob”，第二行为极简状态描述的格式。

**架构：**
- 修改 `StatusBarController.swift` 中的 `createTooltip` 函数实现。
- 修改 `Localizable.xcstrings` 中的中文本地化文本。
- 在 `StatusBarControllerTests.swift` 中新增测试验证提示格式。

**技术栈：** Swift, Cocoa (AppKit), XCTest

---

### 任务 1：重构状态栏提示构建逻辑与本地化映射

**文件：**
- 修改：[StatusBarController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/StatusBarController.swift:390-420)
- 修改：[Localizable.xcstrings](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Localizable.xcstrings:1423-1510)

- [ ] **步骤 1：修改 `createTooltip` 结构**
  打开 `StatusBarController.swift` 并修改 `createTooltip` 的分支返回，去除 "Knob Control:" 前缀并改为使用 `"PhantomKnob\n"` 拼接。
  
  修改后的完整代码段：
  ```swift
      private func createTooltip(for state: KnobGlobalState, targetName: String?) -> String {
          let stateStr: String
          switch state {
          case .inactive:
              stateStr = String(localized: "tooltip.inactive", defaultValue: "Inactive")
          case .activated:
              stateStr = String(localized: "tooltip.activated", defaultValue: "Active")
          case .knobing:
              if let name = targetName {
                  let format = String(localized: "tooltip.knobing.withTarget", defaultValue: "Controlling %@")
                  stateStr = String(format: format, name)
              } else {
                  stateStr = String(localized: "tooltip.knobing", defaultValue: "Controlling")
              }
          case .cooling:
              if let name = targetName {
                  let format = String(localized: "tooltip.cooling.withTarget", defaultValue: "Cooling down (%@)")
                  stateStr = String(format: format, name)
              } else {
                  stateStr = String(localized: "tooltip.cooling", defaultValue: "Cooling down")
              }
          case .customizing:
              stateStr = String(localized: "tooltip.customizing", defaultValue: "Customizing")
          }
          return "PhantomKnob\n\(stateStr)"
      }
  ```

- [ ] **步骤 2：更新本地化资源词条**
  打开 `Localizable.xcstrings` 并更新中文本地化配置（大约 1423-1510 行），移除多余的前缀引导。
  
  更新内容（提取出来的中文部分）：
  - `"tooltip.inactive"`: 翻译值改为 `"未激活"`
  - `"tooltip.activated"`: 翻译值改为 `"已激活"`
  - `"tooltip.knobing"`: 翻译值改为 `"正在控制"`
  - `"tooltip.knobing.withTarget"`: 翻译值改为 `"正在控制 %@"`
  - `"tooltip.cooling"`: 翻译值改为 `"冷却中"`
  - `"tooltip.cooling.withTarget"`: 翻译值改为 `"冷却中 (%@)"`
  - `"tooltip.customizing"`: 翻译值改为 `"定制中"`

- [ ] **步骤 3：Commit 代码与资源修改**
  ```bash
  git add PhantomKnob/Service/StatusBarController.swift PhantomKnob/Localizable.xcstrings
  git commit -m "feat: simplify status bar tooltip structure and update localizations"
  ```

---

### 任务 2：编写并运行测试

**文件：**
- 修改：[StatusBarControllerTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnobTests/StatusBarControllerTests.swift)

- [ ] **步骤 1：添加提示格式单元测试**
  在 `StatusBarControllerTests.swift` 尾部（例如在 `testStatusBarControlLeftClickShowsMenu` 后，大括号关闭前）加入测试：
  
  测试代码：
  ```swift
      func testStatusBarTooltipFormatting() {
          let controller = StatusBarController()
          
          controller.updateState(.inactive)
          if let button = controller.statusItem?.button {
              XCTAssertEqual(button.toolTip?.hasPrefix("PhantomKnob\n"), true)
          }
      }
  ```

- [ ] **步骤 2：运行单元测试**
  运行：`/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' test`
  预期：全部测试运行通过。

- [ ] **步骤 3：Commit 测试文件**
  ```bash
  git add PhantomKnob/PhantomKnobTests/StatusBarControllerTests.swift
  git commit -m "test: add status bar tooltip formatting assertion"
  ```
