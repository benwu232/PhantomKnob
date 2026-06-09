# DaVinci Resolve 色轮 Master Wheel 控制功能设计文档

本设计旨在允许用户使用两指旋转旋钮手势，直接控制 DaVinci Resolve 中的色轮下方的一维 Master Wheel 拨轮（Lift / Gamma / Gain / Offset 亮度/对比度调节）。

由于 DaVinci Resolve 采用自定义非标准 UI 框架，无法通过 Accessibility API 直接读写其控件的 `AXValue` 属性，因此我们将通过全局规则匹配其 `bundleID`（`com.blackmagic-design.DaVinciResolve`），并利用优化后的模拟垂直滚轮事件驱动拨轮的增减，同时引入方向反转属性来确保顺时针增加、逆时针减少的直观手感。

## User Review Required

> [!NOTE]
> 本次更改不会破坏现有的任何其他控制规则或翻译器。所有新增的 `invert` 配置默认为可选，在旧的规则 JSON 中省略时会自动 fallback 为 `false`。

## Open Questions

无（已在头脑风暴讨论中闭环解决）。

---

## Proposed Changes

### 1. 规则数据模型组件 (Rule Data Model Component)

#### [MODIFY] [ControlRule.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Model/ControlRule.swift)
* 在 `ControlRule` 结构体中新增属性 `var invert: Bool?`（默认为可选以确保向前/向后兼容性）。
* 更新它的构造函数，提供默认参数 `invert: Bool? = false`。
* 这样现有的 `JSONDecoder` 会在 `invert` 键不存在时将其解析为 `nil`，我们在调用时使用 `rule.invert ?? false`。

---

### 2. 交互翻译与控制服务组件 (Translation & Control Service Component)

#### [MODIFY] [ScrollWheelTranslator.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Control/ScrollWheelTranslator.swift)
* 为 `ScrollWheelTranslator` 类新增 `private let invert: Bool` 只读属性。
* 更新 `init(axis:scale:invert:)` 以接收并缓存 `invert` 参数（缺省值为 `false`）。
* 修改 `apply(units:direction:)` 方法：如果 `invert` 为 `true`，则将 `.clockwise` 与 `.counterClockwise` 的滚轮物理滚动方向进行反转。
  * 默认未反转下，`.clockwise` 映射为负 `deltaY`（向下滚动）；
  * 在反转下，`.clockwise` 应映射为正 `deltaY`（向上滚动，即在调色面板中表现为增加数值）。

#### [MODIFY] [KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/KnobStateManager.swift)
* 修改 `makeTranslator(for:rule:)` 函数：
  * 在匹配 `.scrollWheelVertical`、`.scrollWheelHorizontal`、`.swipeVertical`、`.swipeHorizontal` 等策略分支时，将 `rule?.invert ?? false` 提取为 `isInverted` 参数传递给 `ScrollWheelTranslator` 的构造器。
* 优化 `onMultitouchBegan` 函数：
  * 当在 DaVinci Resolve 等非标准应用中无法查找到 AX 元素返回 `detectedTarget` 为 `nil` 时，我们在构建 fallback `DetectedTarget` 的 `displayName` 时，不再使用默认空串，而是读取前台 App 的本地化应用名称 `frontmostApp?.localizedName ?? ""`，即显示 `"DaVinci Resolve"`。这样可以提升 Overlay 悬浮面板展示的精致感与专业度。

---

### 3. 应用预置配置组件 (App Preset Config Component)

#### [MODIFY] [bundled-rules.json](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/App/bundled-rules.json)
* 更新 DaVinci Resolve 的全局规则（匹配 `bundleID` = `"com.blackmagic-design.DaVinciResolve"`，`axRole` = `"unknown"`）：
  * 将 `translation` 修改为 `"scrollWheelVertical"`。
  * 在规则主体中新增 `"invert": true`。

---

## Verification Plan

### Automated Tests
可以使用 Swift PM 或 Xcode 运行以下测试用例：
```bash
swift test --filter RuleLibraryTests
swift test --filter ControlTests
```

* **单元测试 1 (`RuleLibraryTests.swift`)**：
  * 编写 `testInvertPropertyParsing()`：验证从 JSON 解码 `ControlRule` 时如果配置了 `"invert": true`，则能够正确解析；如果未配置，解析结果在 fallback 下为 `false`。
  * 验证 bundled-rules 成功加载 Resolve 规则且其 `invert` 属性为 `true`。
* **单元测试 2 (`ControlTests.swift`)**：
  * 编写 `testScrollWheelTranslatorInversion()`：实例化 `ScrollWheelTranslator(axis: .vertical, scale: 1.0, invert: true)`。
  * 传入顺时针旋转，断言合成生成的 `CGEvent` 携带的 `deltaY` 为正值（上滚）；传入逆时针旋转，断言生成的 `deltaY` 为负值（下滚）。

### Manual Verification
1. 运行应用程序，激活 `⌘⇧K` 全局模式。
2. 打开 DaVinci Resolve，将光标移动 to 色轮下方的拨轮输入栏上。
3. 两指按在触控板上旋转：
   * 验证屏幕右上方的 HUD 气泡能够显示 `"DaVinci Resolve"` 字样；
   * 顺时针旋转，验证色轮底下的拨轮增加，色彩调整数值上升；
   * 逆时针旋转，验证拨轮减少，色彩调整数值下降。
