# DaVinci Resolve 色轮 Master Wheel 控制功能实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 Phantom Knob 中实现对 DaVinci Resolve 色轮 Master Wheel 拨轮的控制，支持通过规则文件配置旋转方向反转，并优化非 AX 元素下的 Overlay App 名称显示。

**架构：** 
1. 在 `ControlRule` 模型中新增可选的 `invert` 布尔属性（默认 `false`）。
2. 在 `ScrollWheelTranslator` 中实现反转逻辑，顺时针旋转在反转模式下生成正 delta 滚动事件。
3. 在 `KnobStateManager` 的 `makeTranslator` 中传递 `invert` 配置，并在目标探测 fallback 时读取前台应用本地化名称。
4. 更新内置规则库 `bundled-rules.json` 以配置 Resolve 的垂直滚动和方向反转。

**技术栈：** Swift (AppKit/SwiftUI), XCTest, JSON 序列化

---

### 任务 1：更新 ControlRule 数据模型

**文件：**
- 修改：`PhantomKnob/Model/ControlRule.swift`
- 测试：`PhantomKnob/PhantomKnobTests/RuleLibraryTests.swift`

- [ ] **步骤 1：编写解析反转属性的测试**
  在 `RuleLibraryTests.swift` 中添加测试用例，验证 JSON 反序列化 `ControlRule` 时对 `invert` 属性的正确解析及缺失时的默认处理：
  ```swift
  func testInvertPropertyParsing() throws {
      let jsonWithInvert = """
      {"key":{"bundleID":"com.test.app","axRole":"AXSlider","identifier":null},
        "translation":"scrollWheelVertical",
        "scaleConfig":{"fixed":1.0},
        "invert":true}
      """.data(using: .utf8)!
      
      let jsonWithoutInvert = """
      {"key":{"bundleID":"com.test.app2","axRole":"AXSlider","identifier":null},
        "translation":"scrollWheelVertical",
        "scaleConfig":{"fixed":1.0}}
      """.data(using: .utf8)!
      
      let rule1 = try JSONDecoder().decode(ControlRule.self, from: jsonWithInvert)
      XCTAssertEqual(rule1.invert, true)
      
      let rule2 = try JSONDecoder().decode(ControlRule.self, from: jsonWithoutInvert)
      XCTAssertNil(rule2.invert) // 缺失时解析为 nil，调用方使用 ?? false 处理
  }
  ```

- [ ] **步骤 2：运行测试验证失败**
  运行：`swift test --filter RuleLibraryTests.testInvertPropertyParsing`
  预期：编译失败，提示 `ControlRule` 中没有 `invert` 成员变量。

- [ ] **步骤 3：在 `ControlRule` 中增加 `invert` 属性**
  修改 [ControlRule.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Model/ControlRule.swift#L51-L76)：
  ```swift
  struct ControlRule: Codable {
      let key: RuleKey
      let translation: InputTranslation
      let scaleConfig: ScaleConfig
      var extra: [String: String]?

      var themeColor: String?
      var overlayStyle: String?
      var rotationStyle: String?
      var invert: Bool? // 新增

      init(key: RuleKey,
           translation: InputTranslation,
           scaleConfig: ScaleConfig = .fixed(1.0),
           themeColor: String? = nil,
           overlayStyle: String? = nil,
           rotationStyle: String? = nil,
           invert: Bool? = false, // 新增
           extra: [String: String]? = nil) {
          self.key = key
          self.translation = translation
          self.scaleConfig = scaleConfig
          self.themeColor = themeColor
          self.overlayStyle = overlayStyle
          self.rotationStyle = rotationStyle
          self.invert = invert
          self.extra = extra
      }
  }
  ```

- [ ] **步骤 4：运行测试验证通过**
  运行：`swift test --filter RuleLibraryTests.testInvertPropertyParsing`
  预期：编译成功且测试通过（PASS）。

- [ ] **步骤 5：Commit**
  ```bash
  git add PhantomKnob/Model/ControlRule.swift PhantomKnob/PhantomKnobTests/RuleLibraryTests.swift
  git commit -m "feat: add invert property to ControlRule data model and corresponding tests"
  ```

---

### 任务 2：在 ScrollWheelTranslator 中实现滚轮方向反转逻辑

**文件：**
- 修改：`PhantomKnob/Control/ScrollWheelTranslator.swift`
- 测试：`PhantomKnob/PhantomKnobTests/InputTranslationTests.swift`

- [ ] **步骤 1：编写滚轮方向反转的测试**
  在 `InputTranslationTests.swift` 的 `ArrowKeyTranslatorTests` 类下方添加 `ScrollWheelTranslatorTests` 测试类。同时，在 `ScrollWheelTranslator` 类中，用 `#if DEBUG` 导出最后生成的 `delta` 变量，以便进行单元测试。
  
  在 `InputTranslationTests.swift` 中添加：
  ```swift
  final class ScrollWheelTranslatorTests: XCTestCase {
      func testScrollWheelTranslatorInversion() {
          let normalTranslator = ScrollWheelTranslator(axis: .vertical, scale: 1.0, invert: false)
          let invertedTranslator = ScrollWheelTranslator(axis: .vertical, scale: 1.0, invert: true)
          
          // 顺时针旋转
          normalTranslator.apply(units: 10.0, direction: .clockwise)
          invertedTranslator.apply(units: 10.0, direction: .clockwise)
          
          #if DEBUG
          // 默认顺时针为负 delta（向下滚动）
          XCTAssertTrue(normalTranslator.testLastDeltaY < 0)
          // 反转后顺时针为正 delta（向上滚动）
          XCTAssertTrue(invertedTranslator.testLastDeltaY > 0)
          #endif
      }
  }
  ```

- [ ] **步骤 2：运行测试验证失败**
  运行：`swift test --filter InputTranslationTests.testScrollWheelTranslatorInversion`
  预期：编译失败，提示 `ScrollWheelTranslator` 中没有 `invert` 参数及 `testLastDeltaY` 变量。

- [ ] **步骤 3：在 `ScrollWheelTranslator` 中实现反转和测试观察机制**
  修改 [ScrollWheelTranslator.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Control/ScrollWheelTranslator.swift)：
  ```swift
  final class ScrollWheelTranslator: InputTranslator {
      private let axis: Axis
      var scale: Double
      private let invert: Bool // 新增
      private var accumulator: Double = 0
      
      #if DEBUG
      var testLastDeltaY: CGFloat = 0
      var testLastDeltaX: CGFloat = 0
      #endif

      enum Axis { case vertical, horizontal }

      init(axis: Axis = .vertical, scale: Double = 1.0, invert: Bool = false) {
          self.axis = axis
          self.scale = scale
          self.invert = invert // 新增
      }

      func apply(units: Double, direction: RotationDirection) {
          let isClockwise = direction == .clockwise
          let effectiveClockwise = invert ? !isClockwise : isClockwise
          let delta = units * scale * (effectiveClockwise ? -1.0 : 1.0)
          accumulator += delta
          
          let steps = Int(accumulator)
          guard steps != 0 else { return }
          
          accumulator -= Double(steps)
          
          #if DEBUG
          if axis == .vertical {
              testLastDeltaY = CGFloat(steps)
          } else {
              testLastDeltaX = CGFloat(steps)
          }
          #endif

          switch axis {
          case .vertical:
              synthesizeScroll(deltaY: CGFloat(steps), deltaX: 0)
          case .horizontal:
              synthesizeScroll(deltaY: 0, deltaX: CGFloat(steps))
          }
      }
      
      // ... 其它代码保持不变 ...
  }
  ```

- [ ] **步骤 4：运行测试验证通过**
  运行：`swift test --filter InputTranslationTests.testScrollWheelTranslatorInversion`
  预期：编译成功且测试通过（PASS）。

- [ ] **步骤 5：Commit**
  ```bash
  git add PhantomKnob/Control/ScrollWheelTranslator.swift PhantomKnob/PhantomKnobTests/InputTranslationTests.swift
  git commit -m "feat: implement scroll wheel direction inversion and TDD verification"
  ```

---

### 任务 3：在 KnobStateManager 中对接配置与优化 Overlay 名称显示

**文件：**
- 修改：`PhantomKnob/Service/KnobStateManager.swift`

- [ ] **步骤 1：确认前台 App 显示名称获取方式**
  确认通过 `NSWorkspace.shared.frontmostApplication?.localizedName` 可以安全获取前台应用名称。

- [ ] **步骤 2：应用更改到 `KnobStateManager`**
  修改 [KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/KnobStateManager.swift)：
  1. 在 `makeTranslator` 中传递 `invert` 状态到所有 `ScrollWheelTranslator` 实例中。
  2. 在 `onMultitouchBegan` 中，构造 fallback `DetectedTarget` 时的 `displayName` 设为 `appName`。
  
  代码调整如下：
  * 修改 `makeTranslator(for:target:)` 中的 `.scrollWheelVertical` 等分支：
    ```swift
        let isInverted = rule?.invert ?? false

        switch translation {
        case .axWrite:
            // ...
        case .scrollWheelVertical:
            return ScrollWheelTranslator(axis: .vertical, scale: scale, invert: isInverted)

        case .scrollWheelHorizontal:
            return ScrollWheelTranslator(axis: .horizontal, scale: scale, invert: isInverted)

        case .swipeVertical:
            return ScrollWheelTranslator(axis: .vertical, scale: scale, invert: isInverted)

        case .swipeHorizontal:
            return ScrollWheelTranslator(axis: .horizontal, scale: scale, invert: isInverted)
    ```
  * 修改 `onMultitouchBegan` 中 `target` 的 fallback 构建：
    ```swift
        // 2. 创建 DetectedTarget（无 AX 元素时用当前 app 信息填充）
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let appName = frontmostApp?.localizedName ?? ""
        let target = detectedTarget ?? DetectedTarget(
            bundleID: frontmostApp?.bundleIdentifier ?? "",
            axRole: "unknown",
            identifier: nil,
            displayName: appName,
            element: nil
        )
    ```

- [ ] **步骤 3：运行全局测试验证未破坏现有功能**
  运行：`swift test`
  预期：全部测试用例 PASS。

- [ ] **步骤 4：Commit**
  ```bash
  git add PhantomKnob/Service/KnobStateManager.swift
  git commit -m "feat: pass invert to translators and optimize overlay application display name"
  ```

---

### 任务 4：更新 Resolve 的内置规则配置并编写最终集成测试

**文件：**
- 修改：`PhantomKnob/App/bundled-rules.json`
- 测试：`PhantomKnob/PhantomKnobTests/RuleLibraryTests.swift`

- [ ] **步骤 1：编写验证 DaVinci Resolve 规则被成功加载的测试**
  在 `RuleLibraryTests.swift` 中添加 `testDaVinciResolveRuleIsLoaded`：
  ```swift
  func testDaVinciResolveRuleIsLoaded() {
      let lib = RuleLibrary.shared
      lib.reload()
      
      let key = RuleKey(bundleID: "com.blackmagic-design.DaVinciResolve", axRole: "unknown")
      let rule = lib.lookup(for: key)
      
      XCTAssertNotNil(rule, "Resolve rule must exist")
      XCTAssertEqual(rule?.translation, .scrollWheelVertical)
      XCTAssertEqual(rule?.invert, true)
  }
  ```

- [ ] **步骤 2：运行测试验证失败**
  运行：`swift test --filter RuleLibraryTests.testDaVinciResolveRuleIsLoaded`
  预期：测试 FAIL，因为 Resolve 的内置规则目前 translation 为 `arrowKeyLeftRight` 且没有 `invert` 属性。

- [ ] **步骤 3：修改 Resolve 的内置规则**
  修改 [bundled-rules.json](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/App/bundled-rules.json)：
  找到匹配 `com.blackmagic-design.DaVinciResolve` 且 `axRole: "unknown"` 的条目，将 `translation` 设为 `"scrollWheelVertical"`，且新增 `"invert": true`：
  ```json
    {
      "key": {
        "bundleID": "com.blackmagic-design.DaVinciResolve",
        "axRole": "unknown",
        "identifier": null
      },
      "translation": "scrollWheelVertical",
      "scaleConfig": {
        "fixed": 1.0
      },
      "invert": true,
      "extra": null
    },
  ```

- [ ] **步骤 4：运行测试验证通过**
  运行：`swift test --filter RuleLibraryTests.testDaVinciResolveRuleIsLoaded`
  预期：全部通过（PASS）。

- [ ] **步骤 5：运行所有单元测试确保完整无误**
  运行：`swift test`
  预期：全部 PASS。

- [ ] **步骤 6：Commit**
  ```bash
  git add PhantomKnob/App/bundled-rules.json PhantomKnob/PhantomKnobTests/RuleLibraryTests.swift
  git commit -m "config: update DaVinci Resolve default rule to vertical scroll with direction inversion"
  ```
