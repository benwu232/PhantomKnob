# 设计文档：动态修改调整步长（速度）

本设计文档详细规划了“通过手指半径及数字键动态修改调整步长（速度）”的特性实现方案。

## 目标描述

在两指旋转（Knob）手势中，用户希望根据当前手指间的半径距离或辅助键盘按键，动态调整调节的步长灵敏度。
为此，系统需同时支持：
1. **键盘数字键倍率（键盘与旋钮并存）**：在调节过程中，长按数字键 `2-9` 可临时将当前步长放大 `2-9` 倍。
2. **迟滞缓冲区半径分段机制（Hysteresis Zone）**：防止临界点反复抖动，提供平稳的分段阶梯档位。
3. **线性渐变机制（Linear Interpolation）**：步长随半径大小在一定区间内线性平滑过渡。
4. **统一设置文件管理**：通过配置文件统一管理当前选用的方案及各项参数。

---

## 配置文件设计

设置文件统一存储于：`~/Library/Application Support/PhantomKnob/settings.json`。
如果文件不存在，App 启动时会采用默认配置自动创建该文件。

### 1. JSON 结构示例
```json
{
  "activeScheme": "hysteresis",
  "enableKeyboardNumberMultiplier": true,
  "hysteresis": {
    "multipliers": [1.0, 0.2],
    "boundaries": [
      {
        "low": 10.0,
        "high": 14.0
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
* `activeScheme`: 支持 `"fixed"`（固定倍率）、`"hysteresis"`（迟滞分段）、`"linear"`（线性渐变）。
* `enableKeyboardNumberMultiplier`: 开启后，在手势调整过程中，长按 `2` ~ `9` 会将最终步长乘以对应倍数。
* `hysteresis`:
  * `multipliers`: 各个档位的步长乘数。从最内圈（手指最贴合）开始排列。默认配置 `[1.0, 0.2]`（2个区间）。
  * `boundaries`: 迟滞临界线范围对。$N$ 个区间必须对应 $N-1$ 对边界。
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
* **Hysteresis 逻辑**：
  ```swift
  // 伪代码
  var zone = currentZoneIndex
  if zone < boundaries.count {
      let rightBoundary = boundaries[zone]
      if radius > rightBoundary.high { zone += 1 }
  }
  if zone > 0 {
      let leftBoundary = boundaries[zone - 1]
      if radius < leftBoundary.low { zone -= 1 }
  }
  let baseScale = multipliers[zone]
  ```
* **Linear 渐变逻辑**：
  ```swift
  // 伪代码
  if radius <= minRadius { return minScale }
  if radius >= maxRadius { return maxScale }
  let ratio = (radius - minRadius) / (maxRadius - minRadius)
  return minScale + ratio * (maxScale - minScale)
  ```

### 4. 键盘数字键监控器
* 仅在 `KnobStateManager` 的状态由其他状态转移到 `knobing` 时，调用 `NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp])`。
* 过滤 `event.characters` 在 `"2"` 到 `"9"` 之间的事件：
  * `keyDown`：设置 `activeKeyboardMultiplier = Double(char)`。
  * `keyUp`：如果松开的键值与当前激活的倍率一致，重置 `activeKeyboardMultiplier = 1.0`。
* 在手势结束退出 `knobing` 时，注销监控器，并将 `activeKeyboardMultiplier`重置为 `1.0`。

---

## 验证方案

### 自动化单元测试
在 `PhantomKnobDetectorTests` 目录下新增测试文件：
1. **`AppSettingsTests.swift`**：测试默认配置生成，文件读取与写入，配置校验（如边界数组长度必须为 multipliers 长度 - 1）。
2. **`ScaleResolverTests.swift`**：验证 Hysteresis 及 Linear 模式在各种输入半径下的输出倍率，确保迟滞边界符合预期，且无过度抖动。
3. **`InputTranslatorDynamicScaleTests.swift`**：测试修改 `InputTranslator.scale` 后，新输入的 units 能够正确按新 scale 累加并输出事件。

### 手动验证
1. 启动 App 后，通过修改 `settings.json` 中的 `activeScheme` 在三种模式（fixed/hysteresis/linear）中切换，并使用 Demo Slider 体验手势调节速度的动态变化。
2. 开启 `enableKeyboardNumberMultiplier`，在旋转过程中按下键盘数字键（2-9），验证数值变化速度是否瞬时加快。
3. 测试边界保护：当手指捏合非常紧或张开得非常大时，步长放大或缩小的倍率能够稳定在配置的最大值与最小值，没有溢出或程序崩溃。
