# 状态栏图标悬浮提示 (Tooltip) 优化设计规格

本规格说明书定义了 PhantomKnob macOS 应用状态栏图标在鼠标悬浮（Hover）时显示的提示信息（Tooltip）的优化方案。

## 1. 目标 (Goal)

优化状态栏图标的 Hover 提示信息结构与内容层次，去除重复和不必要的前缀，提供清晰、极简的两行文本格式信息。

---

## 2. 设计规范 (Design Specifications)

### 2.1 格式定义
提示信息固定采用以下两行格式：
```
PhantomKnob
[当前控制状态描述]
```

### 2.2 状态内容极简映射 (简体中文 & English)

| 状态类型 | 简体中文 (zh-Hans) | English (Default) |
| :--- | :--- | :--- |
| **`inactive`** | 未激活 | Inactive |
| **`activated`** | 已激活 | Active |
| **`knobing` (无目标)** | 正在控制 | Controlling |
| **`knobing.withTarget`** | 正在控制 %@ | Controlling %@ |
| **`cooling` (无目标)** | 冷却中 | Cooling down |
| **`cooling.withTarget`** | 冷却中 (%@) | Cooling down (%@) |
| **`customizing`** | 定制中 | Customizing |

---

## 3. 技术实现方案 (Technical Implementation)

### 3.1 提示信息构建逻辑修改
更新 `StatusBarController.swift` 中的 `createTooltip` 方法：
```swift
private func createTooltip(for state: KnobGlobalState, targetName: String?) -> String {
    let stateStr: String
    switch state {
    case .inactive:
        stateStr = String(localized: "tooltip.inactive", defaultValue: "Inactive")
    case .activated:
        stateStr = String(localized: "tooltip.activated", defaultValue: "Active")
    case .knobing:
        if let name = targetName {
            let format = String(localized: "tooltip.knobing.withTarget", defaultValue: "Controlling %@")
            stateStr = String(format: format, name)
        } else {
            stateStr = String(localized: "tooltip.knobing", defaultValue: "Controlling")
        }
    case .cooling:
        if let name = targetName {
            let format = String(localized: "tooltip.cooling.withTarget", defaultValue: "Cooling down (%@)")
            stateStr = String(format: format, name)
        } else {
            stateStr = String(localized: "tooltip.cooling", defaultValue: "Cooling down")
        }
    case .customizing:
        stateStr = String(localized: "tooltip.customizing", defaultValue: "Customizing")
    }
    return "PhantomKnob\n\(stateStr)"
}
```

### 3.2 本地化资源更新
在 `Localizable.xcstrings` 中更新对应的提示文案映射，移除 `"Knob 控制："` 等前缀及快捷键提示。
