# Knob Gesture 全局控制功能设计

## 概述

将 PhantomKnobDetector 从演示应用扩展为系统级控制工具，允许用户通过 Knob gesture（两指旋转手势）控制任意应用中的可调整值（滑块、进度条等）。

## 核心需求

- **全局模式**：通过热键激活，控制鼠标下的任意可调整控件
- **持续激活**：激活后持续有效，需要再次按热键退出
- **智能目标识别**：自动识别鼠标下的可调整控件，递归查找父级
- **手势区分**：区分旋钮手势和两指平移手势，避免干扰正常滚动

---

## 整体架构

### 模块划分

```
┌─────────────────────────────────────────────────────────────┐
│                    StatusBarController                        │
│  - 状态栏图标显示（三色状态）                                    │
│  - 点击打开主页面                                              │
│  - 监听全局热键，转发给 KnobStateManager                        │
│  - 显示 tooltip（状态信息）                                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     KnobStateManager                          │
│  - 中央状态机（唯一状态源）                                      │
│  - 管理四状态转换：inactive → activated → knobing → cooling   │
│  - 监听全局热键                                                │
│  - 协调 TargetDetector、KnobController、OverlayController      │
│  - 发布状态变化通知                                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      TargetDetector                           │
│  - 获取鼠标位置 (NSEvent.mouseLocation)                        │
│  - 使用 Accessibility API 查找可调整控件                        │
│  - 向上查找父元素（最多 10 层）                                  │
│  - 返回 AccessibilityTarget 实现                               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      KnobController                           │
│  ├─ KnobAlgorithm（现有）：计算角度                             │
│  ├─ GestureClassifier：判定旋钮/平移模式                        │
│  └─ OverlayController：管理 overlay 显示                       │
└─────────────────────────────────────────────────────────────┘
```

### 状态流转

```
未激活（灰色图标）
    │
    ▼ [热键激活]
激活无目标（蓝色图标）
    │
    ▼ [gesture 开始 + 检测到目标 + 角度变化 > 5°]
控制中（橙色图标）
    │
    ├─ [gesture 更新] → 更新值
    │
    ├─ [手指离开 touchpad] → 冷却中（橙色图标，overlay 淡出）
    │     ├─ [1 秒内新 gesture + 同一目标] → 回到控制中
    │     ├─ [1 秒内新 gesture + 不同目标] → 激活无目标
    │     └─ [1 秒超时] → 激活无目标，清除目标
    │
    ├─ [应用切换] → 激活无目标，清除目标
    │
    └─ [热键退出]
未激活（灰色图标）
```

### 状态定义

| 状态 | 英文名 | 图标颜色 | 目标 | 含义 |
|------|--------|----------|------|------|
| 未激活 | `inactive` | 灰色 | 无 | 功能关闭 |
| 激活无目标 | `activated` | 蓝色 | 无 | 功能开启，等待 gesture |
| 控制中 | `knobing` | 橙色 | 有 | 正在控制目标值 |
| 冷却中 | `cooling` | 橙色 | 有 | gesture 结束，1 秒等待期 |

---

## 目标识别机制

### Accessibility API 使用

**权限申请**：
- 首次启动检测是否拥有辅助功能权限
- 未授权时引导用户到系统偏好设置授权
- 无权限时禁用全局控制功能

**目标检测流程**：
```
1. 获取鼠标位置 (NSEvent.mouseLocation)
2. 获取鼠标下的 UI 元素 (AXUIElement)
3. 检查元素是否可调整:
   - 检查 AXRole: slider, progress indicator, scroll bar
   - 检查 AXValue, AXMinValue, AXMaxValue 是否存在
4. 如果不可调整，递归查找父元素 (AXParent)
5. 直到找到可调整元素或到达顶层窗口
```

**支持的控件类型**：
- `AXSlider` - 系统滑块、音量控制等
- `AXProgressIndicator` - 进度条、加载条
- `AXScrollBar` - 滚动条（可作为值控制）
- 自定义控件 - 检查是否有 `AXValue` + `AXMinValue` + `AXMaxValue`

**ControlTarget 实现**：
```swift
class AccessibilityTarget: ControlTarget {
    let element: AXUIElement
    var value: Double // 从 AXValue 读取
    let minValue, maxValue: Double // 从 AXMinValue/AXMaxValue 读取
    let displayName: String // 从 AXTitle 或 AXDescription 读取
    
    func applyDelta(_ delta: Double) -> Double {
        // 计算新值，设置到 AXValue
    }
}
```

### 目标识别失败处理

- 无目标时，不显示任何提示（避免干扰）
- 状态栏图标保持蓝色（激活但无目标）
- 两指手势透传给系统，正常滚动等功能不受影响

### 目标锁定策略

- 目标在 gesture 开始时（`touchesBegan`）检测并锁定
- gesture 期间目标固定，不会因鼠标移动而切换
- gesture 结束（手指离开 touchpad）后，进入 cooling 状态，目标仍保持
- cooling 状态结束（1 秒超时）后，清除目标

---

## 手势判定逻辑

### 区分旋钮手势 vs 两指平移

**核心原理：**
- 旋钮手势：两指连线角度持续变化
- 两指平移：两指连线角度基本不变

**默认模式：** Pan（平移），gesture 透传给系统

**判定流程：**
```
touchesBegan:
  - 检测鼠标下是否有可控制目标
  - if 无目标:
      mode = passthrough（透传模式）
      return
  - 有目标:
      锁定目标
      记录 initialAngle = 当前两指连线角度
      mode = pan（缺省模式，gesture 透传）
      启动 2 秒检测计时器

touchesMoved:
  - if mode == passthrough:
      return（透传给系统）
  - 计算 currentAngle
  - 计算 delta = |currentAngle - initialAngle|
  - if delta > 5° && mode == pan:
      mode = knob（旋钮模式，锁定）
      reset initialAngle = currentAngle（后续以此为基准）
      状态 = knobing
      显示 overlay（淡入）
  - if mode == knob:
      正常处理旋钮更新

touchesEnded:
  - if mode == knob:
      状态 = cooling
      overlay 开始淡出（1 秒）
  - 重置模式（保持激活状态）
```

**阈值设置：**
- 角度阈值：5°（在 2 秒检测窗口内）
- 检测窗口：2 秒
- 超过 2 秒未达到阈值，锁定为 pan 模式

**阈值选择理由：**
- 5° 足够敏感，用户轻微旋转即可触发
- 同时避免手抖导致的误触发

---

## 控制会话与 Overlay UI

### Overlay UI 设计

**显示位置**：gesture 开始时的鼠标位置附近（固定，不跟随鼠标移动）

**UI 元素（自适应）：**
```
┌─────────────┐
│   [目标名称]  │  ← 如果 AXTitle 存在且 < 10 字符
│     ╱       │  ← 角度指示器
│   ◉         │  ← 圆心
│     65%     │  ← 当前值
└─────────────┘
```

**值显示格式：**
- 范围 0-100：百分比（65%）
- 范围 0-3600+（视频）：时间格式（01:23:45）
- 其他：原始值

**技术实现：**
- 使用 `NSPanel` 作为 overlay
- `level = .floating` 确保在最上层
- `ignoresMouseEvents = true` 不干扰用户操作
- 位置在 `touchesBegan` 时确定，整个 gesture 期间不变

**显示时机：**
- 进入 `knobing` 状态时：overlay 淡入
- gesture 更新时：同步更新角度和值
- 进入 `cooling` 状态时：overlay 开始淡出（1 秒动画）
- cooling 状态内回到 `knobing`：overlay 淡入
- cooling 状态结束（1 秒超时）：overlay 完全消失

---

## 全局热键与状态栏

### 状态栏图标（三色状态）

| 颜色 | 状态 | 含义 |
|------|------|------|
| 灰色 | inactive | Knob 控制功能未开启 |
| 蓝色 | activated | 已激活，等待 gesture |
| 橙色 | knobing / cooling | 正在控制或冷却中 |

**行为：**
- 点击图标：打开应用主窗口
- 鼠标悬停：显示 tooltip（当前状态说明）
- 首次激活时：显示引导说明颜色含义

**Tooltip 内容：**
- inactive: "Knob 控制：未激活（按 ⌘⇧K 激活）"
- activated: "Knob 控制：已激活，等待手势"
- knobing/cooling: "Knob 控制：正在控制 [目标名称]"

### 全局热键

- 默认热键：`⌘⇧K`（K for Knob）
- 可在设置中自定义
- 使用 `NSEvent.addGlobalMonitorForEvents` 监听
- **冲突检测**：注册时检查热键是否被占用，提示用户修改

### 主页面内容

- 当前激活状态显示
- 热键设置入口（可自定义热键）
- 灵敏度设置（全局默认 + 按控件类型覆盖）
- 辅助功能权限状态 + 跳转系统偏好设置
- 重新检测触控板入口
- 关于/帮助

### 灵敏度设置

**存储结构：**
```swift
struct SensitivityConfig {
    var globalDefault: Double = 0.5  // 1° → 0.5 值
    
    var sliderSensitivity: Double?      // nil 表示用全局默认
    var progressSensitivity: Double?
    var scrollbarSensitivity: Double?
}
```

**Radius 分档灵敏度（未来扩展）：**
- 半径 < 0.3（normalized）：高灵敏度（1° → 1.0 值）
- 半径 0.3-0.7：默认灵敏度（1° → 0.5 值）
- 半径 > 0.7：低灵敏度（1° → 0.25 值）

**存储：** UserDefaults，自动保存

---

## 错误处理与边界情况

### 权限管理

**检测时机：**
- 应用启动时检查辅助功能权限
- 进入控制模式前再次检查（防止用户中途撤销）
- 每次 Accessibility API 调用时捕获错误

**处理方式：**
- 无权限时：显示引导界面，带按钮跳转系统偏好设置
- 引导页面：轮询检测权限状态 + "已授权，继续"按钮
- 状态栏菜单中显示权限状态
- API 调用失败时：捕获错误，发布权限撤销通知，状态回到 inactive

### 多显示器支持

- 使用 `NSScreen.screens` 获取所有显示器
- 根据 `NSEvent.mouseLocation` 判断在哪个显示器
- 正确计算 overlay 位置（注意 AppKit 左下角原点 vs SwiftUI 左上角原点）

### 应用切换

**检测方式：** 监听 `NSWorkspace.didActivateApplicationNotification`

**行为：**
- 应用切换时，隐藏 overlay，清除当前目标
- 状态回到 `activated`（蓝色）
- 等待新的 gesture 开始后重新检测目标

### 性能优化

- **检测时机**：仅在 gesture 开始时检测目标，期间不重复检测
- **查找深度限制**：递归查找父元素时，最多向上查找 10 层

---

## 扩展计划

### 方案 C：模拟输入（未来扩展）

当 Accessibility API 不支持某些控件时，使用模拟输入作为回退：

- 模拟键盘事件（←/→ 或 ↑/↓）
- 模拟鼠标滚轮
- 模拟两指滑动手势

**触发条件**：
- 控件不支持 `AXValue` 设置
- 用户在设置中启用"兼容模式"

---

## 实现优先级

1. **P0 - 核心功能**
   - KnobStateManager + 四状态转换
   - StatusBarController + 三色图标 + tooltip
   - 全局热键监听 + 冲突检测
   - TargetDetector + Accessibility API
   - GestureClassifier + 手势判定（2 秒窗口，5° 阈值）
   - OverlayController + overlay UI

2. **P1 - 完善功能**
   - 辅助功能权限引导
   - 多显示器支持
   - 应用切换处理
   - 主页面 UI
   - 灵敏度设置（按类型）

3. **P2 - 可选功能**
   - 热键自定义
   - Radius 分档灵敏度
   - 方案 C 模拟输入

---

## 技术依赖

- macOS Accessibility API (`AXUIElement`)
- `NSEvent.mouseLocation` 获取鼠标位置
- `NSPanel` + `level = .floating` 实现 overlay
- `NSEvent.addGlobalMonitorForEvents` 监听全局热键
- 辅助功能权限 (`AXIsProcessTrusted`)
