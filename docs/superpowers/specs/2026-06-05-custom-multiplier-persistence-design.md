# 设计文档：旋钮手势个性化倍率记忆与按键调速优化 (CGEventTap 拦截版)

本设计文档规划了“对旋钮手势支持单旋钮/多档半径独立倍率微调、自动记忆持久化、安全重置以及基于 CGEventTap 的键盘拦截防冲突”的最终方案。

## 目标描述

为了提升手势操作的连贯性与个性化体验，我们需要在现有毫米坐标系和多档半径机制上进行以下改进：
1. **彻底解决键盘冲突 (CGEventTap 拦截)**：手势旋转调节（Knobing）时，在系统层拦截并“吞掉”数字键 `1-9` 和方向键事件，使其不会穿透到前台的活跃 App（如 QuickTime 或 Final Cut）。手势结束时自动释放拦截。
2. **单键极简操作**：因为有了 CGEventTap 拦截保障，用户**无需组合按 Option 键**。在旋转手势期间直接按数字 `2-9` 或方向键微调速度，按 `1` 恢复。
3. **多档半径独立倍率微调**：双半径旋钮具有两个独立的 multiplier。在当前 Zone 下按键修改，只更新并保存该 Zone 的倍率，两档独立使用。
4. **交互学习式记忆 (Persistence)**：用户微调好的倍率会自动保存，下次使用该旋钮进入该档位（Zone）时直接加载，避免每次重新设置。
5. **安全重置**：按下 `1` 键将当前档位（Zone）倍率重置为 `1.0` 并保存，保留该旋钮的其它设置（如 translation 类型）。
6. **缺省单半径**：新旋钮默认采用单半径模式（恒定倍率 1.0）。用户可在 `settings.jsonc` 全局配置或 `rules.json` 中配置开启双半径或线性模式。
7. **Overlay UI 反馈与精度控制**：修改倍率时在 Overlay UI 上实时以 `(倍数.0x)` 形式显示（如 `音量 (3.0x)`），且对计算精度四舍五入保留一位小数，防止 IEEE 754 精度误差。

---

## 详细设计

### 1. 默认单半径全局配置
在 `AppSettings.swift` 的默认 `FixedSchemeConfig` 中，将 Zone 默认配置为单个：
```swift
struct FixedSchemeConfig: Codable {
    var zones: [RadiusZone] = [
        RadiusZone(minRadius: 5.0, maxRadius: 100.0, margin: 2.0, scale: 1.0)
    ]
}
```

### 2. CGEventTap 的生命周期与拦截逻辑
在 `KnobStateManager.swift` 初始化时，创建全局 EventTap（初始为 Disabled 状态）：
```swift
private var eventTap: CFMachPort?
private var runLoopSource: CFRunLoopSource?
```
在状态转换为 `knobing` 时开启拦截，在状态转换为 `cooling` / `activated` / `inactive` 时禁用拦截：
```swift
// 开启拦截：
if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }

// 关闭拦截：
if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
```

拦截回调逻辑：
* 只对 `keyDown` 和 `keyUp` 进行拦截。
* 感兴趣的键码：
  * 数字键 1-9: `18(1), 19(2), 20(3), 21(4), 23(5), 22(6), 26(7), 28(8), 25(9)`
  * 方向键: `126(Up), 125(Down), 123(Left), 124(Right)`
* 如果拦截到上述按键，返回 `nil`（吞掉该事件），并在 `keyDown` 时异步在主线程更新倍率；其它按键一律放行。

### 3. 多档半径独立倍率调整与持久化
当 `CGEventTap` 收到 `keyDown` 时：
1. **生成持久化 Key**：根据 `currentTarget` 的 `RuleKey` 和当前 `currentZoneIndex` 拼接成唯一键。
2. **应用覆盖值**：
   * **按 `1` 键**：将当前 Zone 的倍率覆盖值设为 `1.0` 并写入 `UserDefaults`。
   * **按 `2-9` 键**：将当前 Zone 的倍率覆盖值设为对应的 `Double(num)` 并写入 `UserDefaults`。
   * **按方向键**：
     * `Up` 键增加 `1.0`；`Down` 键减少 `1.0`。
     * `Right` 键增加 `0.1`；`Left` 键减少 `0.1`。
     * 限制下限为 `0.1`，不设上限，进行小数点后一位四舍五入。
3. **即时生效**：将最新倍率值同步应用到 translator 的 scale 属性，并即时刷新 Overlay UI 的显示。

### 4. 存储键名设计
```swift
func persistentKey(for target: DetectedTarget, zoneIndex: Int) -> String {
    return "knob_scale_override_\(target.bundleID)_\(target.axRole)_\(target.identifier ?? "")_\(target.displayName)_zone_\(zoneIndex)"
}
```

---

## 验证方案

### 自动化单元测试
在 `PhantomKnobDetectorTests` 目录下补充以下测试用例：
1. **测试单半径默认值**：验证 `AppSettings` 默认只有一个 Zone，且倍率为 `1.0`。
2. **测试按键精度控制与下限**：验证四舍五入及 `0.1` 下限限制。
3. **测试 Zone 独立修改与持久化**：验证不同 Zone 之间独立存储。
4. **测试重置逻辑**：验证按 `1` 键将当前 Zone 倍率设为 `1.0`。

### 手动验证
1. 打开 QuickTime Player 音量滑块（无预定义规则，默认单半径）。
   * 旋转时倍率恒定为 `1.0`。
   * **直接按下数字 `3`**（无需 Option）。Overlay UI 实时更新显示为 `音量 (3.0x)` 且旋转速度变快。同时验证 QuickTime 并没有打出字符 "3"。
   * 按下方向键 `Right`，倍率变为 `3.1x`。验证播放头并没有发生跳转。
   * 手势结束后，再次触发旋转，倍率保持为 `3.1x`。
   * **按下数字 `1`**，Overlay 恢复显示为 `音量 (1.0x)`。
