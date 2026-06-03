# 设计文档：动态修改调整步长（速度）

本设计文档详细规划了“通过手指半径及数字键动态修改调整步长（速度）”的特性实现方案。

## 目标描述

在两指旋转（Knob）手势中，用户希望根据当前手指间的半径距离或辅助键盘按键，动态调整调节的步长灵敏度。
为了支持高度的定制化与可读性，系统需同时支持：
1. **键盘数字键倍率与步长锁定（键盘与旋钮并存）**：
   * 在调节过程中，长按数字键 `2-9` 可临时将当前步长放大 `2-9` 倍。
   * **锁定机制**：当按下数字键的瞬间，锁定当前旋钮的半径基础步长（Base Scale），在此期间忽略手指半径的波动，直到数字键松开。
   * **状态继承（Retroactive Detection）**：在进入旋钮控制（`knobing`）的瞬间，主动查询当前键盘的物理按键状态。如果用户在旋转前已经按住了数字键 `2-9`，进入状态时自动锁定并应用对应的倍率。
2. **多档半径分段机制（Fixed Zones with Hysteresis）与小半径死区（Deadzone）**：
   * 支持多档半径分段（Zones），当配置 $\ge 2$ 个环时，自动启用**迟滞缓冲区机制（Hysteresis）**。
   * 每个环由：**内界（minRadius）**、**外界（maxRadius）**、**缓冲区宽度（margin）**和**步长倍率（scale）**定义。
   * **死区保护**：如果 `radius < zones[0].minRadius`，判定手指贴合过紧，忽略该帧 of 旋转量不发送任何调节事件，并在 Overlay UI 上显示不可用的视觉反馈（灰色）。
3. **线性渐变机制（Linear Interpolation）**：步长随半径大小在一定区间内线性平滑过渡。如果 `radius < linear.minRadius`，同样进入死区保护，丢弃事件，且 Overlay UI 灰色显示。
4. **两级配置与个性化定制**：
   * **全局默认**：由 `settings.jsonc` 定义全局默认的步长方案及参数。
   * **单 Knob 定制**：在规则库中，每条规则可以拥有专属的 `scaleConfig` 配置，覆盖全局默认设置。
5. **系统灵敏度结合（Settings Sensitivity）**：
   * 乘数叠加逻辑：$\text{最终步长倍率} = \text{基础步长 (Base Scale)} \times \text{数字键倍数 (Keyboard Multiplier)} \times \text{系统设置灵敏度 (Settings Sensitivity)}$。
   * 系统设置灵敏度从 UserDefaults 中的 `globalSensitivity` 等读取（可通过控件类型进行覆盖），做为最终的总阀门。
6. **配置文件支持注释 (JSONC)**：配置文件使用 `.jsonc` 后缀，支持单行 `//` 和多行 `/* */` 注释，在 Swift 加载时进行预处理过滤。

---

## 配置文件设计

### 1. 全局默认设置 (`settings.jsonc`)
存储于：`~/Library/Application Support/PhantomKnob/settings.jsonc`。
```jsonc
{
  // 默认启用的半径方案: "fixed"（环分段/固定倍率）、"linear"（线性渐变）
  "activeScheme": "fixed",
  
  // 是否允许在调节时按数字键 2-9 放大步长
  "enableKeyboardNumberMultiplier": true,
  
  // 环分段方案配置
  "fixed": {
    "zones": [
      {
        "minRadius": 5.0,     // 物理死区下限，小于 5.0 触发死区保护
        "maxRadius": 12.0,
        "margin": 2.0,        // 迟滞宽度，防止临界点频繁抖动
        "scale": 1.0          // 捏合（小半径）时的步长倍率
      },
      {
        "minRadius": 12.0,
        "maxRadius": 100.0,
        "margin": 2.0,
        "scale": 0.2          // 张开（大半径）时的步长倍率
      }
    ]
  },
  
  // 线性渐变方案配置
  "linear": {
    "minRadius": 5.0,         // 物理死区下限
    "maxRadius": 20.0,
    "minScale": 1.0,
    "maxScale": 0.2
  }
}
```

---

## 模块设计与交互流程

### 1. 接口协议扩展 (`InputTranslator` 改造)
```swift
protocol InputTranslator: AnyObject {
    func apply(units: Double, direction: RotationDirection)
    var displayValue: String? { get }
    var scale: Double { get set }
}
```

### 2. 运行时死区与步长求解器 (`ScaleResolver` 新类)
* **死区状态判断**：求解器在计算基础步长时，若 `radius < minRadius`，返回 `nil`，表示当前处于死区状态。

### 3. Overlay UI 视觉反馈扩展
* 当处于死区时，OverlayView 中的线条和文本变为灰色半透明样式。

### 4. 最终步长合成流程 (`KnobStateManager` 整合)
* 读取当前 Target 的 `ControlType`。
* 从 `SensitivityConfig` 中读取对应的系统设置灵敏度 `settingsSensitivity`。
* 最终步长为 `(lockedBaseScale ?? lastResolvedBaseScale) * activeKeyboardMultiplier * settingsSensitivity`。

---

## 验证方案

### 自动化单元测试
在 `PhantomKnobDetectorTests` 目录下新增测试文件。

### 手动验证
1. 在缓慢捏合/张开手指（使步长不断发生变化）的同时，按下数字键 `5`，验证在此期间即使手指继续大幅度张开或捏合，数值变化幅度仅与按下瞬间的步长乘 5 挂钩（即步长被成功锁定）。
2. 将手指紧贴，使半径小于最小值（如 5.0），观察 Overlay UI 是否变灰，且调节动作暂停。稍微张开手指后，Overlay 恢复白色，调节继续。
3. 调整 App 设置窗口中的“全局灵敏度”滑块，验证动态步长的最终调节速度会按滑块比例成倍放大或缩小。
