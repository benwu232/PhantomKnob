# 状态栏未激活图标配色设计规格

本规格说明书定义了 PhantomKnob macOS 应用状态栏图标在未激活（`inactive`）状态下的配色优化方案。

## 1. 目标 (Goal)

优化状态栏图标未激活状态下的视觉展现，使其在 macOS 系统深色/浅色菜单栏中都能展现出符合系统规范的“退让感”与“静默感”。

---

## 2. 设计规范 (Design Specifications)

### 2.1 现有方案的局限性
先前方案使用 `NSColor.systemGray` 作为未激活状态的染色。
- 在浅色菜单栏下，该灰色相对偏深，不够静默。
- 在深色菜单栏下，该灰色亮度相对偏高，略显突兀。
- 无法自适应高对比度、不同饱和度壁纸下的融合效果。

### 2.2 优化方案：带透明度的系统标签色
使用 `NSColor.labelColor.withAlphaComponent(0.35)` 对模板图进行运行期染色：
- **浅色菜单栏**：自适应呈现为 **35% 不透明度的黑色**，形成极其柔和的浅灰色，完美表现未激活状态。
- **深色菜单栏**：自适应呈现为 **35% 不透明度的白色**，形成与菜单栏融合度高、存在感低的深灰色。

---

## 3. 实现与文档更新计划 (Implementation & Document Synchronization)

### 3.1 状态栏控制器染色逻辑修改
在 `StatusBarController.swift` 的 `updateState` 中：
```swift
let tintColor: NSColor
switch state {
case .inactive:
    tintColor = NSColor.labelColor.withAlphaComponent(0.35)
case .activated:
    tintColor = .systemCyan
case .knobing, .cooling:
    tintColor = .systemYellow
case .customizing:
    tintColor = NSColor.labelColor.withAlphaComponent(0.35)
}
```

### 3.2 视觉规格说明书更新
将 [2026-07-07-icon-and-logo-design.md](file:///Users/wb/work/phantom_knob_mac/docs/superpowers/specs/2026-07-07-icon-and-logo-design.md) 中关于 `inactive` 状态的染色逻辑（第 108、116、130、131 行）同步更新为 `NSColor.labelColor.withAlphaComponent(0.35)`。
