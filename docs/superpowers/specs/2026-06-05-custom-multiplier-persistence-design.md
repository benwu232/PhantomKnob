# 设计文档：旋钮手势个性化倍率记忆与按键调速优化

本设计文档规划了“对旋钮手势支持单旋钮/多档半径独立倍率微调、自动记忆持久化、安全重置以及 Option 组合键防冲突”的优化方案。

## 目标描述

为了提升手势操作的连贯性与个性化体验，我们需要在现有毫米坐标系和多档半径机制上进行以下改进：
1. **防按键冲突 (Option Modifier)**：手势旋转调节时，用户需同时按下 `Option` 键加数字键 `1-9` 或方向键才能触发倍率修改，避免污染目标 App 默认的单键快捷键。
2. **多档半径独立倍率微调**：双半径旋钮具有两个独立的 multiplier，在旋转的某个 Zone 时按键修改倍率，只改变并保存该 Zone 的倍率，两档独立使用互不干扰。
3. **交互学习式记忆 (Persistence)**：用户微调好的倍率会自动保存，下次使用该旋钮进入该档位（Zone）时直接加载，避免每次重新设置。
4. **安全重置 (Safe Reset)**：按下 `Option + 1` 将当前档位（Zone）倍率重置回原速 `1.0`，并同步更新/保存，不影响该旋钮的其它有用配置（如 rules.json 中的 translation 类型）。
5. **缺省单半径**：新旋钮默认采用单半径模式（恒定倍率 1.0）。用户可在 `settings.jsonc` 全局配置或 `rules.json` 单一规则中配置开启双半径或线性模式。
6. **Overlay UI 反馈与精度控制**：修改倍率时在 Overlay UI 上实时以 `(倍数.0x)` 形式显示（如 `音量 (3.0x)`），且对计算精度四舍五入保留一位小数，防止 IEEE 754 精度误差。

---

## 详细设计

### 1. 默认单半径全局配置
更新 `AppSettings.swift` 的默认 `FixedSchemeConfig`，将 Zone 默认配置为单个：
```swift
struct FixedSchemeConfig: Codable {
    var zones: [RadiusZone] = [
        RadiusZone(minRadius: 5.0, maxRadius: 100.0, margin: 2.0, scale: 1.0)
    ]
}
```
这使得未定义特定规则的新旋钮默认工作在单个 5mm~100mm 范围、恒定 1.0 倍率 spacing 的单半径模式下。用户可以通过修改本地 `settings.jsonc` 增加 zones 来开启双半径全局默认值。

### 2. 按键边沿检测与 Option 组合键检测
在 `onMultitouchMoved` 每帧处理中：
1. 检测 `Option` 键是否按下（Left Option `58` 或 Right Option `61`）。若未按下，直接跳过按键处理。
2. 维护上一帧 of 按键状态集合 `previousKeysState: Set<CGKeyCode>`，通过差集检测出当前帧**新按下的键（Edge-triggered）**，防止按键长按导致数值无限累加。
3. 关键键码映射：
   * 数字 1 (重置): `18`
   * 数字 2-9: `19(2), 20(3), 21(4), 23(5), 22(6), 26(7), 28(8), 25(9)`
   * 方向键: `126(Up), 125(Down), 123(Left), 124(Right)`

### 3. 多档半径独立倍率调整与持久化
当在手势过程中检测到新按键事件时，获取当前计算出的 Zone 索引 `currentZoneIndex`：
1. **修改与保存**：
   * **数字键 2-9**：设置当前 Zone 倍率覆盖值为对应数字（`2.0` ~ `9.0`）。
   * **方向键**：
     * `Up` 键增加 `1.0`；`Down` 键减少 `1.0`。
     * `Right` 键增加 `0.1`；`Left` 键减少 `0.1`。
     * 计算后将值做小数点后一位四舍五入 `(val * 10).rounded() / 10`。
     * 限制下限为 `0.1`，不设上限。
   * 修改后，将该倍率保存至 `UserDefaults`。
2. **重置**：
   * **数字键 1**：将当前 Zone 倍率覆盖值显式设置为 `1.0`，并保存至 `UserDefaults`。

### 4. 数据模型与存储键设计
我们通过控件的 `RuleKey` 和 Zone 的 `Index` 组合成唯一的持久化键名：
```swift
func persistentKey(for target: ControlTarget, zoneIndex: Int) -> String {
    let bundleID = target.bundleID
    let axRole = target.axRole
    let identifier = target.identifier ?? ""
    let displayName = target.displayName
    return "knob_scale_override_\(bundleID)_\(axRole)_\(identifier)_\(displayName)_zone_\(zoneIndex)"
}
```
在运行时进行倍率求值时：
1. 计算当前 Zone 索引（例如双半径时为 0 或 1）。
2. 获取当前 Zone 的默认倍率 `defaultScale`。
3. 如果 `currentTarget` 不为空，使用 `persistentKey` 查询 `UserDefaults`。若有保存的覆盖倍率，则使用覆盖倍率作为 `baseScale`，否则使用 `defaultScale`。

---

## 验证方案

### 自动化单元测试
在 `PhantomKnobDetectorTests` 目录下补充以下测试用例：
1. **测试单半径默认值**：验证 `AppSettings` 默认只有一个 Zone，且倍率为 `1.0`。
2. **测试按键精度控制**：验证在增减 `0.1` 后对浮点数四舍五入处理，确保无 IEEE 754 精度偏离。
3. **测试 Zone 独立修改与持久化**：模拟双 Zone 环境，在 Zone 0 改变倍率并保存，验证 Zone 1 不受影响。
4. **测试重置逻辑**：模拟修改后按 `1` 键，验证其倍率安全变回 `1.0`。

### 手动验证
1. 打开 QuickTime Player 音量滑块（无预定义规则，默认单半径）。
   * 旋转时倍率恒定为 `1.0`。
   * 按下 `Option + 3`，Overlay UI 实时更新显示为 `音量 (3.0x)` 且旋转速度变快。
   * 手势结束后，再次触发旋转，验证倍率直接加载为 `3.0x`。
   * 按下 `Option + 1`，Overlay 恢复显示为 `音量 (1.0x)`。
2. 修改 `settings.jsonc` 将全局默认设置为双半径（Zone 0: 5-20mm (10x), Zone 1: 20-100mm (1x)）。
   * 手指捏合时处于 Zone 0，按下 `Option + 5`，倍率变为 `5.0x`。
   * 将手指张开至 Zone 1，倍率自动变回 `1.0x`。
   * 再次捏合回 Zone 0，倍率自动恢复为之前设置 of 5.0x。
