# PhantomKnob 官方 Logo 与状态栏着色实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 macOS 状态栏和 App 图标中落地 2D 弥散悬浮设计，在状态栏实现系统级自适应着色方案（方案乙：Grey、Cyan、Green）。

**架构：**
1. 状态栏载入 3 个单色白色模板图资产，开启 `isTemplate`。
2. 在 `StatusBarController.swift` 的状态转换方法中，动态切换对应的图标模板图片，并修改 `NSStatusItem.button` 的 `contentTintColor` 实现高对比度动态着色。
3. 替换 App 官方 AppIcon 并重新生成工程。

**技术栈：** Swift 5.0, SwiftUI, Xcode, xcodebuild, git

---

## 拟创建或修改的文件

* 修改：`PhantomKnob/Service/StatusBarController.swift`
  * 去除 `statusItem` 的 `private` 标记，使其包内可见（以便单元测试能访问并验证染色）。
  * 在 `updateState` 和 `updateStateActivating` 方法中，在为 `button` 赋值 image 后，根据运行状态分配对应的 `.systemGray` / `.systemCyan` / `.systemGreen` 着色。
* 修改：`PhantomKnob/PhantomKnobTests/StatusBarControllerTests.swift`
  * 编写单元测试 `testStatusBarIconColorAndTemplate` 验证在不同状态下的模板图和动态染色属性。
* 资源替换：将设计好的 PNG 静态图片覆盖至项目中对应的 `Assets.xcassets`。

---

## 实现任务列表

### 任务 1：暴露 StatusBarController 的 statusItem 并编写测试

**文件：**
- 修改：[StatusBarControllerTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnobTests/StatusBarControllerTests.swift)
- 修改：[StatusBarController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/StatusBarController.swift)

- [ ] **步骤 1：去除 statusItem 的 private 关键字**
  修改 `StatusBarController.swift` 第 7 行：
  ```swift
  // 修改前
  private var statusItem: NSStatusItem?
  // 修改后
  var statusItem: NSStatusItem?
  ```

- [ ] **步骤 2：在测试类中编写验证染色的失败测试**
  在 `StatusBarControllerTests.swift` 末尾添加测试：
  ```swift
  func testStatusBarIconColorAndTemplate() {
      let controller = StatusBarController()
      
      // 测试 inactive 状态
      controller.updateState(.inactive)
      if let button = controller.statusItem?.button {
          XCTAssertTrue(button.image?.isTemplate ?? false)
          XCTAssertEqual(button.contentTintColor, .systemGray)
      }
      
      // 测试 activated 状态
      controller.updateState(.activated)
      if let button = controller.statusItem?.button {
          XCTAssertTrue(button.image?.isTemplate ?? false)
          XCTAssertEqual(button.contentTintColor, .systemCyan)
      }
      
      // 测试 knobing 状态
      controller.updateState(.knobing)
      if let button = controller.statusItem?.button {
          XCTAssertTrue(button.image?.isTemplate ?? false)
          XCTAssertEqual(button.contentTintColor, .systemGreen)
      }
  }
  ```

- [ ] **步骤 3：运行测试验证失败**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO -only-testing PhantomKnobTests/StatusBarControllerTests/testStatusBarIconColorAndTemplate`
  预期：FAIL（未定义着色逻辑，button.contentTintColor 应该为 nil）

- [ ] **步骤 4：在控制器中编写最少实现代码**
  修改 `StatusBarController.swift` 中的 `updateState`（约第 214-220 行）和 `updateStateActivating` 方法，实现染色逻辑：
  
  ```swift
  // updateState 内：
  if let button = statusItem?.button {
      let newImage = createIcon(for: state)
      newImage?.isTemplate = true
      button.image = newImage
      button.toolTip = createTooltip(for: state, targetName: targetName)
      
      // 动态染色
      switch state {
      case .inactive:
          button.contentTintColor = .systemGray
      case .activated:
          button.contentTintColor = .systemCyan
      case .knobing, .cooling:
          button.contentTintColor = .systemGreen
      case .customizing:
          button.contentTintColor = .systemGray
      }
      PKLogger.statusBar.info("Image updated, isTemplate: \(newImage?.isTemplate ?? false)")
  }
  ```
  
  同时修改 `updateStateActivating`（约第 258-266 行）：
  ```swift
  func updateStateActivating(secondsRemaining: Double) {
      if let button = statusItem?.button {
          let symbolImage = NSImage(systemSymbolName: "circle.dashed", accessibilityDescription: nil)
          let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
          let finalImage = symbolImage?.withSymbolConfiguration(config) ?? symbolImage
          finalImage?.isTemplate = true
          button.image = finalImage
          button.contentTintColor = .systemCyan // 等待激活为青色
          
          let format = String(localized: "tooltip.activating", defaultValue: "Activating in %ds...")
          button.toolTip = String(format: format, Int(ceil(secondsRemaining)))
      }
      ...
  }
  ```

- [ ] **步骤 5：再次运行测试验证通过**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO -only-testing PhantomKnobTests/StatusBarControllerTests/testStatusBarIconColorAndTemplate`
  预期：PASS

- [ ] **步骤 6：Commit**
  ```bash
  git add PhantomKnob/Service/StatusBarController.swift PhantomKnob/PhantomKnobTests/StatusBarControllerTests.swift
  git commit -m "feat: implement statusbar dynamic tint coloring and tests"
  ```

---

### 任务 2：替换 StatusBar 模板图片与 AppIcon 资源

**文件：**
- 覆盖：`PhantomKnob/Assets.xcassets/StatusBar/statusbar_inactive.imageset/` 目录中的图片文件。
- 覆盖：`PhantomKnob/Assets.xcassets/StatusBar/statusbar_activated.imageset/` 目录中的图片文件。
- 覆盖：`PhantomKnob/Assets.xcassets/StatusBar/statusbar_knobing.imageset/` 目录中的图片文件。
- 覆盖：`PhantomKnob/Assets.xcassets/AppIcon.appiconset/` 中的 App 图标图片文件。

- [ ] **步骤 1：导入新的 2D 弥散阴影 App 官方 Logo**
  将已确认的 2D App Logo 设计图切图，覆盖项目 `Assets.xcassets/AppIcon.appiconset` 下的不同分辨率图片。
  
- [ ] **步骤 2：导入三状态 StatusBar 白色单色 PNG 模板资源**
  使用草图对应导出的 3 个白色单色图，覆盖 `statusbar_inactive`、`statusbar_activated`、`statusbar_knobing` 在 `Assets.xcassets` 下的文件。

- [ ] **步骤 3：验证编译并整体跑通所有单元测试**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
  预期：整个测试套件 100% PASS

- [ ] **步骤 4：Commit**
  ```bash
  git add PhantomKnob/Assets.xcassets/
  git commit -m "style: replace AppIcon and StatusBar template icon assets"
  ```
