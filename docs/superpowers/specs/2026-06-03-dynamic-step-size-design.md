# 设计文档：动态修改调整步长（速度）

本设计文档详细规划了“通过手指半径及数字键动态修改调整步长（速度）”的特性实现方案。

## 目标描述

在两指旋转（Knob）手势中，用户希望根据当前手指间的半径距离或辅助键盘按键，动态调整调节的步长灵敏度。
为此，系统需同时支持：
1. **键盘数字键倍率（键盘与旋钮并存）**：在调节过程中，长按数字键 `2-9` 可临时将当前步长放大 `2-9` 倍。
2. **多档半径分段机制（Fixed Zones with Hysteresis）**：
   * 步长配置统一归并在 `fixed` 方案下。
   * 如果 `fixed` 方案只配置了 1 个环（Zone），则为固定步长。
   * 如果配置了 $\ge 2$ 个环，则自动启用**迟滞缓冲区机制（Hysteresis）**进行分段。
   * 每个环由：**内界（minRadius）**、**外界（maxRadius）**、**缓冲区宽度（margin）**和**步长倍率（scale）**定义。
3. **线性渐变机制（Linear Interpolation）**：步长随半径大小在一定区间内线性平滑过渡。
4. **统一设置文件管理**：通过配置文件统一管理当前选用的方案及各项参数。

---

## 配置文件设计

设置文件统一存储于：`~/Library/Application Support/PhantomKnob/settings.json`。
如果文件不存在，App 启动时会采用默认配置自动创建该文件。

### 1. JSON 结构示例
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

### 2. 参数项说明
* `activeScheme`: 支持 `"fixed"`（环分段/固定倍率）、`"linear"`（线性渐变）。
* `enableKeyboardNumberMultiplier`: 开启后，在手势调整过程中，长按 `2` ~ `9` 会将最终步长乘以对应倍数。
* `fixed.zones`:
  * 每个环（`RadiusZone`）的定义包括：
    * `minRadius`: 环的内界。
    * `maxRadius`: 环的外界。
    * `margin`: 缓冲区宽度（用于迟滞逻辑，防止临界线快速抖动）。
    * `scale`: 当前环对应的步长倍率。
* `linear`:
  * `minRadius`/`maxRadius`: 开始/结束渐变的半径点。
  * `minScale`/`maxScale`: 对应 `minRadius` 与 `maxRadius` 下的步长乘数。

---

## 模块设计与交互流程

### 1. 数据模型与配置文件加载
* **`AppSettings` (新文件)**：
  定义一个结构化的 Swift 结构体对应上述 JSON 配置。提供单例 `AppSettings.shared`，负责在初始化时加载并缓存配置。如加载失败则使用默认值并回写到磁盘。

### 2. 接口协议扩展 (`InputTranslator` 改造)
当前所有的 `InputTranslator` 在初始化时保存了不可变的 `scale` 属性。为支持动态灵敏度调节，需在接口中引入可变的 `scale`：
```swift
protocol InputTranslator: AnyObject {
    func apply(units: Double, direction: RotationDirection)
    var displayValue: String? { get }
    var scale: Double { get set }  // 新增：允许在手势运动中动态修改 scale
}
```
* **改造清单**：
  * `ArrowKeyTranslator`
  * `ScrollWheelTranslator`
  * `AXWriteTranslator`
  以上三个实现类的 `scale` 均由 `private let` 改为 `var`（或实现 `get set`）。

### 3. 半径步长求解器 (`ScaleResolver` 新类)
创建独立求解器类，接收 `AppSettings` 及运行时的 `radius` 和 `currentZoneIndex`，返回最终的基础倍率以及更新后的 `currentZoneIndex`。

#### Fixed 多环迟滞状态机实现逻辑：
1. **单环** (`zones.count == 1`)：直接返回唯一环的 `scale`。
2. **多环** (`zones.count >= 2`)：
   * 假设当前激活的环索引为 `i`（初始为符合 `radius >= zones[i].minRadius && radius <= zones[i].maxRadius` 的环，默认从 0 开始）。
   * 检查当前环的**带缓冲区有效范围**：
     * `effectiveMin = zones[i].minRadius - zones[i].margin`
     * `effectiveMax = zones[i].maxRadius + zones[i].margin`
   * 若 `radius >= effectiveMin` 且 `radius <= effectiveMax`，则判定继续留在当前环，返回 `zones[i].scale`。
   * 若超出上述有效范围：
     * 遍历所有环 $j$，寻找满足无缓冲区物理范围（`radius >= zones[j].minRadius && radius <= zones[j].maxRadius`）的环。
     * 若找到，更新 `currentZoneIndex = j` 并返回 `zones[j].scale`。
     * 若均未匹配（例如溢出最大半径），则返回当前距离最近的边界环的 `scale`。

#### Linear 渐变逻辑：
* 如果 `radius <= minRadius`，返回 `minScale`。
* 如果 `radius >= maxRadius`，返回 `maxScale`。
* 否则，按照 $\text{minScale} + \frac{\text{radius} - \text{minRadius}}{\text{maxRadius} - \text{minRadius}} \times (\text{maxScale} - \text{minScale})$ 计算并返回。

### 4. 键盘数字键监控器
* 仅在 `KnobStateManager` 的状态由其他状态转移到 `knobing` 时，调用 `NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp])`。
* 过滤 `event.characters` 在 `"2"` 到 `"9"` 之间的事件：
  * `keyDown`：设置 `activeKeyboardMultiplier = Double(char)`。
  * `keyUp`：如果松开的键值与当前激活的倍率一致，重置 `activeKeyboardMultiplier = 1.0`。
* 在手势结束退出 `knobing` 时，注销监控器，并将 `activeKeyboardMultiplier` 重置为 `1.0`。

---

## 验证方案

### 自动化单元测试
在 `PhantomKnobDetectorTests` 目录下新增测试文件：
1. **`AppSettingsTests.swift`**：测试默认配置生成，文件读取与写入，配置校验（如当 fixed 的 zones 数量 $\ge 2$ 时各个区间的连续性校验）。
2. **`ScaleResolverTests.swift`**：验证多环迟滞（Hysteresis）在临界半径来回波动时的稳定性，验证 Linear 模式在各种输入半径下的输出倍率。
3. **`InputTranslatorDynamicScaleTests.swift`**：测试修改 `InputTranslator.scale` 后，新输入的 units 能够正确按新 scale 累加并输出事件。

### 手动验证
1. 启动 App 后，通过修改 `settings.json` 中的 `activeScheme`，验证在 fixed（多档环）与 linear 之间切换的效果。
2. 开启 `enableKeyboardNumberMultiplier`，在旋转过程中按下键盘数字键（2-9），验证数值变化速度是否瞬时加快。
3. 测试迟滞缓冲：拉大/捏合手指跨越临界值（如 12），在 10~14 之间小幅度来回摆动手指，验证步长不会频繁发生跳变（即保持当前档位稳定）。
