# 双旋钮独立配色与配置设计规格说明书

本文档规定了 Phantom Knob Mac 客户端中双旋钮（内圈/外圈）独立配置及其色彩体系的详细设计，包括数据模型扩展、配置界面重组、手势热切换逻辑。

## 需求概述

为了进一步丰富触控板双旋钮（内外双环）手势的视觉反馈，用户可以分别为内圈旋钮与外圈旋钮设置独立的配色及手势参数。主要改进点：
1. 双旋钮模式下，大外圈设置卡片在前（上），小内圈设置卡片在后（下）。
2. 将配色组件（16个常用色预设 + “自定义颜色...”按钮）直接下放到内外圈的子配置区域中，以便于针对不同圈独立调色。
3. 将 16 色预设由两行网格改为单行排列。
4. 将“旋钮类型”选择置于定制滚动面板的最顶部。
5. 当用户在旋转过程中跨越阈值边界时，HUD 指示圈能够根据当前所在的激活圈（内或外）动态切换不同的主题颜色。

---

## 详细设计

### 1. 数据模型（Model）扩展

在 `VirtualKnobConfig` 结构体中引入可选字段 `themeColor`。

```swift
struct VirtualKnobConfig: Codable, Equatable {
    var minRadius: Double
    var maxRadius: Double
    var margin: Double
    var unitPerDegree: Double
    var translation: InputTranslation
    var clockwiseAction: String
    var themeColor: String? // 新增字段，支持独立配色
}
```

#### 向后兼容性（Backward Compatibility）
- 如果解析旧版 `rules.json` 时，该字段缺失，则系统将反序列化该值归为 `nil`。
- 在实际读取和应用配色时，如果为 `nil`，系统将根据所处层级分别渲染默认颜色：
  - 内圈微调旋钮默认值：`#30D158` (科技绿)
  - 外圈粗调旋钮默认值：`#FF9F0A` (活力橙)

---

### 2. 定制面板 UI 架构与逻辑（`CustomizerHUDView`）

#### 模式选择（三个标签页 Tab 切换）
- **标签置顶**：将“模式选择”做成顶部三个横向排布的精美标签按钮（单旋钮、双旋钮、线性半径），默认选中的模式为**单旋钮**（`.single`）。
- **交互与视效**：标签栏将采用毛玻璃圆角背景，被选中的标签会以当前主题色或微亮高光突出，带有微妙的悬停和点击微动画。
- **选择后展示具体界面**：点击对应标签后，下方仅展示该模式相关的配置，不显示其他无关参数。

#### 各模式的具体配置表单设计

- **Tab 1：单旋钮模式（默认）**
  - **配色定制**：单行 16 色预设圆点（16px）+ “自定义颜色...”按钮（使用 `ControlRule.themeColor`）。
  - **动作映射**：输出映射方式 + 顺时针旋转触发动作。
  - **变化量**：每度变化量精确输入框。

- **Tab 2：双旋钮模式**
  - **🟠 外圈旋钮（粗调）配置卡片**：
    - **外圈配色**：单行 16 色预设圆点（16px） + “自定义外圈颜色...”按钮（对应 `outer.themeColor`）。
    - **外圈映射**：输出映射方式 + 顺时针旋转触发动作。
    - **外圈参数**：每度变化量。
  - **⚙️ 保护带宽度 (Margin)** 滑块（5.0mm ~ 30.0mm）。
  - **🟢 内圈旋钮（微调）配置卡片**：
    - **内圈配色**：单行 16 色预设圆点（16px） + “自定义内圈颜色...”按钮（对应 `inner.themeColor`）。
    - **内圈映射**：输出映射方式 + 顺时针旋转触发动作。
    - **内圈参数**：每度变化量。

- **Tab 3：线性半径模式**
  - **配色定制**：单行 16 色预设圆点（16px） + “自定义颜色...”按钮（使用 `ControlRule.themeColor`）。
  - **动作映射**：输出映射方式 + 顺时针旋转触发动作。
  - **半径范围**：最小半径 + 最大半径调节滑块。
  - **变化量范围**：最小变化量 + 最大变化量精确输入框。

#### 调色板目标追踪
由于 `NSColorPanel` 是全局单例且其变更通知不包含触发源信息，在 `CustomizerHUDView` 中引入调色源标记变量：

```swift
@State private var activeColorTarget: ColorTarget = .global

enum ColorTarget {
    case global
    case doubleInner
    case doubleOuter
}
```
当点击某个“自定义颜色...”按钮时，更新 `activeColorTarget`，并在 `NSColorPanel.colorDidChangeNotification` 触发时修改对应的状态并写入持久化层。

---

### 3. 手势与指示层热重载（`KnobStateManager` 与 `OverlayController`）

#### `OverlayController` 扩展
`update` 函数允许传入动态颜色参数，通知并强制重绘 `OverlayView`。

```swift
func update(angle: Double, radius: Double, isDeadzone: Bool = false, scale: Double? = nil, themeColor: String? = nil) {
    self.angle = angle
    self.isDeadzone = isDeadzone
    self.scale = scale
    if let themeColor = themeColor {
        self.themeColor = themeColor
    }
    self.diameter = Self.calculateDiameter(for: radius)
    
    updatePanelFrame()
    updateOverlayView()
}
```

#### `KnobStateManager` 逻辑升级
在手势开始（`onMultitouchBegan`）和移动（`onMultitouchMoved`）中，系统会根据当前的 `currentZoneIndex` 解析并下发对应区间的配色：

```swift
private func resolveThemeColor(for rule: ControlRule?, zoneIndex: Int) -> String? {
    guard let rule = rule else { return nil }
    if rule.configType == .double, let doubleConfig = rule.doubleConfig {
        if zoneIndex == 0 {
            return doubleConfig.inner.themeColor ?? "#30D158"
        } else {
            return doubleConfig.outer.themeColor ?? "#FF9F0A"
        }
    }
    return rule.themeColor
}
```

当发生内外圈切换事件时，系统捕获 `currentZoneIndex` 的转换并随同 `overlayController.update(...)` 下发最新的颜色。

---

## 验证计划

### 自动化测试
1. **Model 反序列化测试**：在 `CustomKnobTests.swift` 中为包含双配色 `VirtualKnobConfig` 的 `DoubleKnobConfig` 进行序列化与反序列化测试，验证颜色字段读写是否正常。
2. **测试前后兼容性**：确保旧版本未配置色彩的配置信息加载后能无故障退回到默认颜色。
3. **集成回归测试**：运行全部 118 项单元测试，确保无编译问题且测试 100% 通过。

### 手动验证
1. 打开 HUD 面板，切换至“双旋钮”，验证“旋钮类型”选择器位于最上方。
2. 验证“外圈旋钮”在“内圈旋钮”之上，各自内含独立的单行 16 色配色指示及自定义按钮。
3. 分别修改内外圈颜色，验证数据能正确热重载到手势引擎并保存到 `rules.json`。
4. 进行手势操作，在内外圈之间移动手指，验证屏幕上的 Overlay 圆环颜色能实时根据激活圈改变（例如：内圈时绿环，外圈时橙环）。
