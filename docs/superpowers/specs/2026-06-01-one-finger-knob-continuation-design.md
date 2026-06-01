# 2026-06-01 单指旋钮手势延续设计规格说明书 (One-Finger Knob Gesture Continuation Design Spec)

## 1. 概述与背景 (Overview & Background)

在现有的 `PhantomKnobDetector` 系统中，旋钮手势（Knob Gesture）是由双指放在触控板上触发的。当用户进行旋转操作时，系统计算两个触点在每一帧的中点作为动态圆心，并计算两指连线的角度以得出旋转增量。

### 1.1 现有局限
当前设计中，如果用户在旋转过程中无意中抬起了一根手指，触点数量降为 1：
1. `MultitouchManager` 底层的去抖动（Debounce）逻辑会在连续 6 帧检测到活动手指小于 2 后，触发 `onMultitouchEnded()`，从而意外终止旋钮手势。
2. 即使在底层不终止手势，在几何结算上，如果一根手指离开，两指连线矢量不复存在，会导致角度计算瞬间突变（Jump），造成严重的界面闪烁和误触。

### 1.2 升级目标
本设计旨在引入一种极其平滑、自然的**“双指旋转 ➡️ 抬起一指继续 ➡️ 单指围绕固定圆心旋转 ➡️ 抬起最后指头结束”**的手势续接机制：
1. **圆心生命周期锁死**：一旦检测到双指旋转手势启动，其初始中点被确立为**固定圆心**。该圆心的生命周期持续到手势彻底销毁（全部手指离开）。
2. **单指延续旋转**：抬起任意一根手指后，剩余的单指可以通过围绕固定圆心作圆周运动，无缝继续旋转操作。
3. **支持重新放下第二指**：在单指旋转过程中，如果放下第二根手指，手势平滑过渡回双指模式，圆心保持不变。
4. **零跳变过渡保障**：通过 **ID 矢量对齐** 极性反转逻辑，完美抵消双指降级为单指时的 180° 角度翻转，结合原有的 `clamped(to: -1...1)` 降噪，确保双指与单指过渡过程极其平顺、极简高效。

---

## 2. 核心数学模型与解算 (Core Mathematical Model)

### 2.1 矢量表示与 180° 跳变抵消 (Vector Representation & 180° Jump Cancellation)

在双指模式下，设两指点为 $P_1$（ID = `fingerIdx1`）和 $P_2$（ID = `fingerIdx2`）。
双指连线的物理矢量定义为：
$$V_{\text{two}} = P_1 - P_2$$
其角度为：
$$\theta_{\text{two}} = \text{atan2}(V_{\text{two}}.y, V_{\text{two}}.x)$$

固定圆心为手势启动时的双指中点：
$$C_{\text{fixed}} = \frac{P_1 + P_2}{2}$$

当抬起一根手指，只剩下 $P_{\text{remain}}$（ID = `remainId`）时：
* 如果留下的是 $P_1$（`remainId == fingerIdx1`）：
  单指矢量设为：
  $$V_{\text{single}} = P_{\text{remain}} - C_{\text{fixed}} = P_1 - \frac{P_1 + P_2}{2} = \frac{P_1 - P_2}{2}$$
  由于 $\frac{P_1 - P_2}{2}$ 与 $P_1 - P_2$ 方向完全相同，此时角度为：
  $$\theta_{\text{single}} = \theta_{\text{two}}$$
  此过渡的物理角度瞬时跳变 $\Delta \theta = 0.0$！

* 如果留下的是 $P_2$（`remainId == fingerIdx2`）：
  单指矢量设为：
  $$V_{\text{single}} = C_{\text{fixed}} - P_{\text{remain}} = \frac{P_1 + P_2}{2} - P_2 = \frac{P_1 - P_2}{2}$$
  由于 $\frac{P_1 - P_2}{2}$ 与 $P_1 - P_2$ 方向也完全相同，此时角度仍为：
  $$\theta_{\text{single}} = \theta_{\text{two}}$$
  此过渡的物理角度瞬时跳变 $\Delta \theta = 0.0$！

通过判断剩余手指的硬件 ID，动态决定单指矢量的极性（`P_remain - C` 还是 `C - P_remain`），可以**完美从几何源头抵消 180° 的轴向翻转跳变**。

---

## 3. 详细设计与模块改动 (Detailed Component Changes)

### 3.1 `MultitouchManager.swift` ── 触控管线重构

#### 功能变更：
* 修改 `handleContacts` 内的触点计数判断。
* 手势激活仍然必须满足 $\ge 2$ 根手指。
* 一旦 `inGesture` 激活，即使手指减少到 1 根，也将此 1 根手指的 `activePoints` 作为 `onMultitouchMoved` 派发。
* 彻底移除针对 1 根手指的 debounce 判定。
* 只有当 `activePoints.count == 0`（手指完全离开触控板）时，才触发 `onMultitouchEnded`。

#### 伪代码设计：
```swift
if activePoints.count >= 2 {
    consecutiveFramesBelowThreshold = 0
    if !inGesture {
        inGesture = true
        delegate?.onMultitouchBegan(points: activePoints)
    } else {
        delegate?.onMultitouchMoved(points: activePoints)
    }
} else if activePoints.count == 1 {
    consecutiveFramesBelowThreshold = 0
    if inGesture {
        // 单指时，手势延续，继续发送 Moved 事件
        delegate?.onMultitouchMoved(points: activePoints)
    }
} else if activePoints.count == 0 {
    if inGesture {
        inGesture = false
        consecutiveFramesBelowThreshold = 0
        delegate?.onMultitouchEnded()
    }
}
```

### 3.2 `KnobStateManager.swift` ── 状态机与几何对齐解算

#### 新增状态变量：
```swift
private var fixedCenter: CGPoint?            // 整个旋钮生命周期内绝对锁死的圆心
private var fingerIdx1: Int?                 // 触发旋钮手势时的第一指 ID (min)
private var fingerIdx2: Int?                 // 触发旋钮手势时的第二指 ID (max)
```

#### 手势开启 (`onMultitouchBegan`)：
* 当双指手势被 `MultitouchManager` 识别并分发时，计算初始中点：
  ```swift
  let (knobCore, idx1, idx2) = KnobAlgorithm().calKnob(scaledPoints)
  self.fixedCenter = knobCore.center
  self.fingerIdx1 = idx1
  self.fingerIdx2 = idx2
  self.previousAngle = knobCore.angle
  ```

#### 角度几何解算辅助函数 (`calculateRawAngle`)：
```swift
private func calculateRawAngle(points: [Int: CGPoint]) -> Double? {
    if points.count >= 2 {
        let (knobCore, _, _) = KnobAlgorithm().calKnob(points)
        return knobCore.isValid ? knobCore.angle : nil
    } else if points.count == 1,
              let fixedCenter = self.fixedCenter,
              let fingerIdx1 = self.fingerIdx1,
              let fingerIdx2 = self.fingerIdx2,
              let remainId = points.keys.first,
              let remainPoint = points[remainId] {
        
        let dx: CGFloat
        let dy: CGFloat
        if remainId == fingerIdx1 {
            dx = remainPoint.x - fixedCenter.x
            dy = remainPoint.y - fixedCenter.y
        } else if remainId == fingerIdx2 {
            dx = fixedCenter.x - remainPoint.x
            dy = fixedCenter.y - remainPoint.y
        } else {
            dx = remainPoint.x - fixedCenter.x
            dy = remainPoint.y - fixedCenter.y
        }
        return atan2(dy, dx) * 180 / .pi
    }
    return nil
}
```

#### 手势移动中 (`onMultitouchMoved`)：
* 每次获取 `rawAngle` 后更新双指 ID 并计算最终角度：
  ```swift
  let currentTouchCount = scaledPoints.count
  
  // 单指重新升级回双指时，重新缓存双指的 ID 对应关系以备下次抬指匹配
  if currentTouchCount >= 2 {
      let (_, idx1, idx2) = KnobAlgorithm().calKnob(scaledPoints)
      self.fingerIdx1 = idx1
      self.fingerIdx2 = idx2
  }
  
  let currentAngle = rawAngle
  ```

---

## 4. 验证与测试方案 (Verification Plan)

### 4.1 单元测试 (Unit Tests)
在 `GestureClassifierTests.swift` 或新创建 graves 的测试中，添加对几何解算的数学边界测试：
1. **测试双变单 ID-1 过渡**：在双指夹角为 $45^\circ$ 时模拟抬起第二指（第一指保留），验证解算的角度依然为 $45^\circ$（无跳变）。
2. **测试双变单 ID-2 过渡**：在双指夹角为 $45^\circ$ 时模拟抬起第一指（第二指保留），验证解算的角度经过对称变换后依然为 $45^\circ$（无跳变）。

### 4.2 手动功能测试 (Manual Interactive Tests)
1. **启动测试**：放上双指旋转，旋钮 Overlay 顺利显示并响应。
2. **抬指单转测试**：在旋转过程中，突然抬起一根手指（交替测试第一根和第二根），旋钮 Overlay **无任何闪烁或抖动**，继续用单指作画圆动作，旋钮可以顺畅延续增量调整。
3. **双指回放测试**：在单指旋转过程中，将第二根手指重新放回触控板，系统平滑过渡至双指旋转模式，数值基本无抖动。
4. **终结测试**：抬起最后一根手指，手势完美结束，Overlay 渐隐消失。
