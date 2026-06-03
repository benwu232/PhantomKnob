# 设计文档：动态修改调整步长（速度）

本设计文档详细规划了“通过手指半径及数字键动态修改调整步长（速度）”的特性实现方案。

## 目标描述

在两指旋转（Knob）手势中，用户希望根据当前手指间的半径距离或辅助键盘按键，动态调整调节的步长灵敏度。
为了支持高度的定制化，系统需同时支持：
1. **键盘数字键倍率（键盘与旋钮并存）**：在调节过程中，长按数字键 `2-9` 可临时将当前步长放大 `2-9` 倍。
2. **多档半径分段机制（Fixed Zones with Hysteresis）**：
   * 支持多档半径分段（Zones），当配置 $\ge 2$ 个环时，自动启用**迟滞缓冲区机制（Hysteresis）**。
   * 每个环由：**内界（minRadius）**、**外界（maxRadius）**、**缓冲区宽度（margin）**和**步长倍率（scale）**定义。
3. **线性渐变机制（Linear Interpolation）**：步长随半径大小在一定区间内线性平滑过渡。
4. **两级配置与个性化定制**：
   * **全局默认**：由 `settings.json` 定义全局默认的步长方案及参数。
   * **单 Knob 定制**：在规则库 `rules.json` 或 `bundled-rules.json` 中，每条规则可以拥有专属的 `scaleConfig` 配置，覆盖全局默认设置，实现针对每个具体 Knob 的个性化微调。

---

## 配置文件设计

### 1. 全局默认设置 (`settings.json`)
存储于：`~/Library/Application Support/PhantomKnob/settings.json`。
```json
{
  "activeScheme": "fixed",
  "enableKeyboardNumberMultiplier": true,
  "fixed": {
    "zones": [
      {
        "minRadius": 0.0,
        "maxRadius": 12.0,
        "margin": 2.0,
        "scale": 1.0
      },
      {
        "minRadius": 12.0,
        "maxRadius": 100.0,
        "margin": 2.0,
        "scale": 0.2
      }
    ]
  },
  "linear": {
    "minRadius": 10.0,
    "maxRadius": 20.0,
    "minScale": 1.0,
    "maxScale": 0.2
  }
}
```

### 2. 单 Knob 规则配置 (`rules.json` 或 `bundled-rules.json`)
每条规则的 `scaleConfig` 可单独配置。我们对 `ScaleConfig` 进行了扩展，并保持了向后兼容性。

#### A. 兼容旧版固定步长（单值形式）：
```json
{
  "key": { "bundleID": "com.apple.QuickTimePlayerX", "axRole": "AXSlider", "displayName": "volume" },
  "translation": "arrowKeyUpDown",
  "scaleConfig": {
    "fixed": 1.0
  }
}
```

#### B. 新版个性化分档（多 Zones 形式）：
```json
{
  "key": { "bundleID": "com.apple.FinalCut", "axRole": "AXSlider", "displayName": "timeline" },
  "translation": "scrollWheelHorizontal",
  "scaleConfig": {
    "zones": [
      { "minRadius": 0.0, "maxRadius": 10.0, "margin": 1.5, "scale": 2.0 },
      { "minRadius": 10.0, "maxRadius": 100.0, "margin": 1.5, "scale": 0.5 }
    ]
  }
}
```

#### C. 新版个性化渐变（Linear 形式）：
```json
{
  "key": { "bundleID": "com.apple.LogicPro", "axRole": "AXSlider", "displayName": "frequency" },
  "translation": "axWrite",
  "scaleConfig": {
    "linear": {
      "minRadius": 5.0,
      "maxRadius": 15.0,
      "minScale": 1.5,
      "maxScale": 0.1
    }
  }
}
```

---

## 模块设计与交互流程

### 1. 数据模型与 Codable 改造
在 `ControlRule.swift` 中，对 `ScaleConfig` 进行重构，兼容旧版并支持新版：
```swift
struct RadiusZone: Codable {
    let minRadius: Double
    let maxRadius: Double
    let margin: Double
    let scale: Double
}

struct ScaleConfigLinear: Codable {
    let minRadius: Double
    let maxRadius: Double
    let minScale: Double
    let maxScale: Double
}

enum ScaleConfig: Codable {
    case fixed(Double)
    case zones([RadiusZone])
    case linear(ScaleConfigLinear)
}
```
**自定义 Codable 解码逻辑**：
* 尝试解码 `"fixed"` 键：
  * 若为 `Double` 数值 $\rightarrow$ 解码为 `.fixed(val)`。
* 尝试解码 `"zones"` 键 $\rightarrow$ 解码为 `.zones([RadiusZone])`。
* 尝试解码 `"linear"` 键 $\rightarrow$ 解码为 `.linear(ScaleConfigLinear)`。

### 2. 接口协议扩展 (`InputTranslator` 改造)
```swift
protocol InputTranslator: AnyObject {
    func apply(units: Double, direction: RotationDirection)
    var displayValue: String? { get }
    var scale: Double { get set }  // 新增：允许在手势运动中动态修改 scale
}
```

### 3. 动态步长解析流程
在手势开始时（`onMultitouchBegan`），确定采用哪套 `ScaleConfig`：
1. **策略优先级**：
   * 检查当前匹配规则的 `scaleConfig` 是否为定制版（即 `zones` 数量 $\ge 2$ 或为 `linear`）。
   * 如果是，则当前手势完全使用该规则自带的 `scaleConfig` 进行解析。
   * 如果规则不存在，或者规则为旧版 `.fixed(Double)` 且其值为 `1.0`（代表未特意覆盖默认步长），则**回退使用全局 `AppSettings` 中定义的 `activeScheme` 配置**。
2. **状态维护**：
   * `KnobStateManager` 内部维护一个 `var currentZoneIndex: Int = 0`。每次开始新手势时重置为 0。

### 4. 键盘数字键监控器
* 在手势开始并在 `.knobing` 时开启 `.keyDown`/`.keyUp` 全局监控。
* 若按下 `2-9`，设置全局叠加倍率乘数 `activeKeyboardMultiplier = Double(char)`。松开时还原为 `1.0`。
* `最终步长倍率 = 半径解析倍率 (baseScale) * 键盘乘数 (activeKeyboardMultiplier)`。

---

## 验证方案

### 自动化单元测试
在 `PhantomKnobDetectorTests` 目录下新增测试文件：
1. **`AppSettingsTests.swift`**：测试默认配置生成，文件读取与写入，配置校验。
2. **`ScaleConfigCompatibilityTests.swift`**：验证 `ScaleConfig` 能够正确解码旧版 JSON（单精度浮点）以及新版（多 zones / linear 格式）。
3. **`ScaleResolverTests.swift`**：验证在同时存在全局配置和单 Knob 专属规则时，解析器能正确匹配高优先级个性化配置。

### 手动验证
1. 编写一条特定 App 的 rules，并在其中配置独有的 zones，运行此 App，验证其步长变化半径临界点是按照 rule 内的数据触发，而不是按照全局 `settings.json`。
2. 在旋转过程中按下键盘数字键（2-9），验证数值变化速度是否瞬时加快。
