# Phantom Knob 旋钮定制化设计规格说明书 (Custom Knob Design)

本文档详述了 Phantom Knob 中旋钮定制化（Custom Knob Configuration）的激活触发、配置属性、多模态切换（单旋钮、独立双旋钮、线性半径）、输入翻译映射、本地持久化及手势热重载的设计规格。

---

## 1. 业务目标与用户体验 (Goals & UX Flow)

* **免培训快捷激活**：
  * 在任何 Overlay HUD 显示期间（包括 `activated` 已激活、`knobing` 旋转中、`cooling` 冷却中），用户按下键盘 `C` 键，立即在当前光标位置展开**悬浮定制面板 HUD**。
  * 激活时，手势状态机进入 `.customizing` 挂起状态，暂停向系统重投递事件，以防在定制设置时发生误触。
* **修改即生效（Autosave & Hot Reload）**：
  * 定制面板不设置任何“确定”或“取消”按钮。用户对任何表单项的修改（如切换颜色、拖动数值）都会**实时保存**到本地文件，并热更新到当前手势引擎中。
  * 视觉颜色、灵敏度、方向映射在手指未松开时立即改变，方便用户在调节过程中“边调边试”。
* **无缝退出**：
  * 点击定制面板外部区域、或按下 `Esc` 键，定制面板会平滑淡出关闭，状态机恢复。

---

## 2. 定制内容与数据结构 (Customization Fields & Data Model)

### 2.1 基础配置与翻译映射 (Basic Config & Translation Mappings)
* **主题色 (themeColor)**：提供颜色预设（蓝 `#0A84FF`、橙 `#FF9F0A`、绿 `#30D158`、紫 `#BF5AF2`、红 `#FF453A`）。修改后，整个 HUD 背景外发光与圆圈刻度线毫秒级同步变色。
* **单度变化量 (unitPerDegree)**：定义每 1° 旋转对应的基础控制变化量（即灵敏度系数）。
* **方向映射 (Clockwise Mapping)**：
  * 用户指定**顺时针旋转 (Clockwise)** 对应的正向事件，逆时针则自动反向绑定。
  * 支持映射类型：
    * **上下键 (ArrowKeyUpDown)**：CW 映射为“上键”或“下键”（CCW 自动相反）。
    * **左右键 (ArrowKeyLeftRight)**：CW 映射为“右键”或“左键”。
    * **鼠标滚轮上下 (ScrollWheelVertical)**：CW 映射为“向上滚动”或“向下滚动”。
    * **双指上下 pan (SwipeVertical)**：CW 映射为“向上滑”或“向下滑”。
    * **双指左右 pan (SwipeHorizontal)**：CW 映射为“向右滑”或“向左滑”。
    * **无障碍写入 (AXWrite)**：CW 映射为“递增值”或“递减值”。

### 2.2 旋钮类型策略 (Knob Config Types)

定制面板支持在三种策略之间无缝切换，面板会使用平滑高度过渡动画展示对应的配置子项：

#### 1. 单旋钮 (Single)
* 最简单的全局单一映射策略，参数包括：
  * `unitPerDegree` (Double)
  * `translation` (InputTranslation)
  * `clockwiseAction` (String)

#### 2. 双旋钮 (Double - 两个旋钮完全独立)
* 同心圆嵌套（Concentric Zones），两圈所触发的按键/滚轮甚至系数可以完全不同。例如：内圈进行左右方向键微调，外圈进行水平滚轮粗调。
* **参数配置**：
  * **内圈 (Inner Knob)** 与 **外圈 (Outer Knob)** 均拥有完全独立的 `VirtualKnobConfig`：
    * `minRadius`、`maxRadius`：定义响应的物理半径区间。
    * `margin`：缓冲保护带宽度。
    * `unitPerDegree`、`translation`、`clockwiseAction`：该圈独立的事件和变化量。
  * **过渡带机制 (Hysteresis Lock)**：
    * 采用**迟滞锁定算法**。手指在拉伸/收缩过程中，如果进入 `margin` 区间，将锁定并维持在上一时刻的旋钮状态，只有彻底跨越 `margin` 边界时才切换。

#### 3. 线性半径控制 (Linear)
* 根据两指距离（物理半径）的大小，线性插值计算出旋转变化的灵敏度，提供渐进式调节手感。
* **参数配置**：
  * `minRadius`、`maxRadius`：有效半径范围。
  * `minScale`、`maxScale`：半径最小值/最大值分别对应的控制系数 `unitPerDegree`。
  * `translation`、`clockwiseAction`。

### 2.3 数据结构表示 (Codable Structural Spec)

```swift
// PhantomKnob/Model/ControlRule.swift

enum KnobConfigType: String, Codable {
    case single
    case double
    case linear
}

struct SingleKnobConfig: Codable {
    var unitPerDegree: Double
    var translation: InputTranslation
    var clockwiseAction: String
}

struct VirtualKnobConfig: Codable {
    var minRadius: Double
    var maxRadius: Double
    var margin: Double
    var unitPerDegree: Double
    var translation: InputTranslation
    var clockwiseAction: String
}

struct DoubleKnobConfig: Codable {
    var inner: VirtualKnobConfig
    var outer: VirtualKnobConfig
}

struct LinearKnobConfig: Codable {
    var minRadius: Double
    var maxRadius: Double
    var minScale: Double
    var maxScale: Double
    var translation: InputTranslation
    var clockwiseAction: String
}

struct ControlRule: Codable {
    let key: RuleKey
    var themeColor: String?
    var configType: KnobConfigType
    
    var singleConfig: SingleKnobConfig?
    var doubleConfig: DoubleKnobConfig?
    var linearConfig: LinearKnobConfig?
    
    var extra: [String: String]?
}
```

---

## 3. 技术架构与组件设计 (System Architecture)

### 3.1 核心状态流转与热重载
* **手势状态机 (`KnobStateManager`)**：
  * 新增 `.customizing` 状态。
  * 状态流转规则：
    * 任何非 `.inactive` 状态下，接收到 `C` 键按下通知 ➔ 挂起当前手势，状态置为 `.customizing`，显示定制面板 HUD。
    * 点击外部或按 `Esc` 关闭面板 ➔ 状态回退到 `.activated` 或进入 `.cooling` 退出。
* **配置侦听与热更**：
  * `KnobStateManager` 保持对当前激活规则实例的引用。
  * 定制面板的 SwiftUI View 对 Rule 各字段使用绑定。每一次操作（例如滑块拖动），调用 `RuleLibrary.shared.saveRule(updatedRule)` 写入 `rules.json`。
  * `RuleLibrary` 发送全局通知 `ControlRuleDidUpdate`。
  * `KnobStateManager` 收到通知后，动态更新其当前的 `InputTranslator` 配置。若用户仍在接触触控板，则在下一个手势 tick 时以全新的灵敏度和方向触发。

### 3.2 交互设计：物理半径实时反馈
* 在定制面板展示时，若用户双指保持在触控板上，SwiftUI 界面会在显眼位置呈现一个**“当前双指半径：XX pt”**的动态动画指示环。
* 该机制调用 `KnobStateManager` 的 `normalizedPosition` 计算实时物理半径，极大方便用户校准 `minRadius`/`maxRadius`/`margin` 数值。

---

## 4. 本地持久化 (Storage Implementation)

* **存储路径**：`~/Library/Application Support/PhantomKnob/rules.json`
* **合并与优先级**：
  * `RuleLibrary.shared.saveRule(_ rule: ControlRule)` 会解析该文件，若已存在相同 `bundleID + axRole` 精度匹配的规则，则进行字段合并或完全覆盖，然后写回磁盘。
  * 用户规则优先级绝对高于系统自带的 `bundled-rules.json`。

---

## 5. 测试与验证计划 (Testing & Verification)

### 5.1 自动化测试
* **`ControlRuleTests`**：
  * 验证不同 `configType` 对应的数据序列化与反序列化（JSON 读写）。
  * 验证 `rules.json` 覆盖合并逻辑的准确性。
* **`ScaleResolutionTests`**：
  * 验证独立双旋钮下的迟滞锁定（Hysteresis Margin）判定算法，在越过临界保护带时的状态切换。
  * 验证线性插值中，半径在线性区间、超限 Clamp 等边界值上的输出计算。

### 5.2 手动测试用例
1. **激活测试**：在 QuickTime 调节音量期间按下 `C`，验证音量调节立刻挂起且原地展开毛玻璃配置面板。
2. **实时效果测试**：
   - 更改主题颜色（例如从蓝色改为紫色），验证 HUD 背景即时变紫。
   - 拖动灵敏度从 1.0 变到 5.0，手指继续旋转，验证系统音量条的变化速度发生急剧上升。
   - 切换顺时针映射（如从“上键”改为“下键”），验证继续顺时针转动时，系统音量条转为递减。
3. **独立双旋钮验证**：配置内圈（r=0~20）为左右键，外圈（r=25~100）为滚轮。双指紧贴旋转时发送左右方向键，拉开双指旋转时发送滚轮，确认在 20pt 到 25pt 的 margin 区域内不发生频繁抖动切换。
4. **持久化验证**：退出 App 并重新启动，验证刚才所定制的参数依然存在且能完美生效。
