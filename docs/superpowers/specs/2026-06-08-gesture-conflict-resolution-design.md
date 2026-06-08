# 旋钮手势与系统缩放、旋转手势冲突解决设计文档

## 1. 背景与目标

在 Phantom Knob 中，用户使用触控板两指旋转作为“虚拟旋钮”操作。然而，当该手势在系统的 `.activated`（激活）状态下发生时，在手势分类器判定它为旋钮手势之前，系统的两指缩放（Magnify / Pinch-to-zoom）与旋转（Rotate）事件会先发送到当前激活的前台应用。这导致被控应用（如浏览器、剪辑软件画布等）在滑块被微调前先产生缩放或旋转抖动。

本设计旨在通过**“自适应 Event Tap 控制流程”**解决该冲突，使其既能让用户在任意软件的常规滑块、文本微调区域上完美流畅地使用旋钮（无缩放泄露），又能在普通画布、网页等空白区域保留系统默认的缩放和旋转手势。

---

## 2. 核心设计方案

本方案的核心思想为：**“基于控件可调节性与规则库的拦截决定（Adaptive Gesture Interception）”**。

当用户两指放置于触控板上时（触发 `onMultitouchBegan`），系统不等待手势识别完成，而是立即进行目标判定。如果当前鼠标位置下的控件具备可调节特征或命中了规则例外，则立即启用 `Event Tap` 全局屏蔽系统级缩放与旋转事件；反之，则保持 `Event Tap` 禁用，将所有事件交还给 macOS 系统原生处理。

### 2.1 可调节控件判定标准 (`isAdjustable`)
我们通过以下三个维度判定一个控件是否可被调节：
1. **规则库匹配 (Rule Override)**：若前台应用与当前控件匹配了 `RuleLibrary` 中的任何规则（包括特化的 `axRole: "unknown"`），则无条件视为可调节。
2. **标准可调节角色 (Standard AX Roles)**：若 AX 元素的 Role 为 `AXSlider`、`AXScrollBar`、`AXValueIndicator`、`AXStepper`、`AXDial`、`AXIncrementor` 之一。
3. **动态属性与行为探测 (Dynamic Attributes & Actions)**：
   * 包含 `AXMinValue` 且包含 `AXMaxValue`；或
   * 包含 `AXValue` 且该属性是可写的 (`AXUIElementIsAttributeSettable` 返回 true)；或
   * 支持 `AXIncrement` (递增) 或 `AXDecrement` (递减) 动作（Action）。

### 2.2 核心状态机与 Event Tap 状态控制

引入辅助控制状态变量 `isInterceptingGestures`：
* 在 `onMultitouchBegan` 中：
  * 检测 `isOptionHoldActive` (修饰键激活) 是否为 `true`，或者 `isAdjustable` 是否为 `true`。
  * 如果是，设置 `isInterceptingGestures = true`，并立即启用 `Event Tap`（`CGEvent.tapEnable(tap: tap, enable: true)`）。
* 在 `handleEventTap` 中：
  * 若 `state.isKnobing` 或 `isInterceptingGestures` 为 `true`，拦截并吞噬所有类型为 `18`（旋转）、`19`（缩放）和 `29`（通用手势）的 `CGEvent`。
* 在 `onMultitouchEnded` 中：
  * 重置 `isInterceptingGestures = false`，如果当前未转入 `.cooling` 或 `.knobing`，则停用 `Event Tap`。

---

## 3. 组件级详细改动设计

### 3.1 `KnobStateManager.swift` [MODIFY]
1. 添加私有变量 `isInterceptingGestures: Bool = false`。
2. 添加私有方法 `isAdjustable(target: DetectedTarget) -> Bool`：
   - 实现前述 2.1 节中的三维度判定。
3. 在 `onMultitouchBegan` 方法中：
   - 提取对 `isOptionHoldActive` 和 `isAdjustable(target)` 的判定，如果任一为真，设置 `isInterceptingGestures = true` 并启用 `eventTap`。
4. 修改 `handleEventTap(proxy:type:event:)`：
   - 守卫条件由 `guard state.isKnobing else { return false }` 修改为 `guard state.isKnobing || isInterceptingGestures else { return false }`。
5. 在 `onMultitouchEnded` 中：
   - 重置 `isInterceptingGestures = false`，并通过 `CGEvent.tapEnable(tap: tap, enable: false)` 显式注销拦截。

---

## 4. 异常处理与边缘用例

* **AX 元素获取超时**：`TargetDetector` 获取 AX 元素采用 0.1s 超时机制，因此判定是即时的，不会引起触控板操作卡顿。
* **非标剪辑应用（如 DaVinci Resolve）**：此类应用完全无法导出 AX 属性，但规则库中预置了匹配 `bundleID` 且 `axRole: "unknown"` 的全局规则。这会导致 `isAdjustable` 第一步（规则匹配）立即命中，保证 Resolve 全局都能流畅使用旋钮，Event Tap 完美拦截冲突手势。

---

## 5. 测试与验证计划

### 5.1 自动化测试
在 `PhantomKnobDetectorTests` 中，编写对 `isAdjustable` 逻辑的单元测试：
* **测试用例 1**：传入含有 `AXMinValue`/`AXMaxValue` 的模拟 `DetectedTarget`，应返回 `true`。
* **测试用例 2**：传入命中了规则库规则的 `DetectedTarget`（如 DaVinci Resolve，`axRole: "unknown"`），应返回 `true`。
* **测试用例 3**：传入空白区域的目标（无元素，无规则匹配），应返回 `false`。

### 5.2 手动功能测试
1. 启动应用，开启 `Hotkey Toggle`。
2. 移动鼠标到 Safari 的网页空白处，进行双指缩放和旋转，验证网页可以流畅缩放，且不会启动旋钮（Overlay UI 不显示）。
3. 移动鼠标到“系统设置”的音量或亮度滑块上，放下双指，做微小的两指旋转动作，验证：
   - 系统设置本身没有发生任何缩放/旋转/抖动。
   - 旋钮正常激活（Overlay UI 显示），并且滑块平滑被调节。
4. 按住 Option 键，移动到滑块上，验证 Option Hold 模式下表现与 3 一致。
