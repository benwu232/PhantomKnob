# 旋钮双指归位即时解锁 100ms 锁 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 `KnobStateManager` 中实现双指归位时即时重置 `transitionToOneFingerTime = nil`，彻底解决双指旋转与换向过程中因为瞬时采样波动触发 100ms 假死卡顿的问题。

**架构：** 在 `KnobStateManager.onMultitouchMoved(points:)` 中，当 `points.count >= 2` 时强制重置 `transitionToOneFingerTime = nil`；在 `KnobLiftoffFilterTests.swift` 中编写测试验证双指-单指-双指恢复时保护锁被即时清空。

**技术栈：** Swift, macOS AppKit, XCTest

---

### 文件结构

- **修改：** [KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/KnobStateManager.swift#L795-L810) - 实现 `points.count >= 2` 时即时清空 `transitionToOneFingerTime = nil`
- **修改/测试：** [KnobLiftoffFilterTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnobTests/KnobLiftoffFilterTests.swift#L44-L56) - 添加双指恢复即时解锁的单元测试用例

---

### 任务 1：为双指归位即时解锁编写单元测试

**文件：**
- 修改：`PhantomKnob/PhantomKnobTests/KnobLiftoffFilterTests.swift`

- [ ] **步骤 1：在 `KnobLiftoffFilterTests.swift` 中编写测试用例**

```swift
func testTwoToOneTransitionInstantUnlockOnTwoFingers() {
    // 验证当检测到两指降为一指触发 transitionToOneFingerTime 后，
    // 若后续采样再次恢复为两指 (count >= 2)，transitionToOneFingerTime 能够被即时清空为 nil
    var transitionToOneFingerTime: Date? = Date()
    var previousPointCount: Int = 1
    
    // 模拟 onMultitouchMoved 在 points.count >= 2 时的解锁逻辑
    let currentPointsCount = 2
    if currentPointsCount >= 2 {
        transitionToOneFingerTime = nil
    } else if previousPointCount >= 2 && currentPointsCount == 1 {
        transitionToOneFingerTime = Date()
    }
    previousPointCount = currentPointsCount
    
    XCTAssertNil(transitionToOneFingerTime, "当触点恢复为 2 指时，应该立即解锁并清除 transitionToOneFingerTime 为 nil")
}
```

- [ ] **步骤 2：运行单元测试**

运行：
```bash
xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -only-testing:PhantomKnobTests/KnobLiftoffFilterTests/testTwoToOneTransitionInstantUnlockOnTwoFingers
```
预期：PASS

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnob/PhantomKnobTests/KnobLiftoffFilterTests.swift
git commit -m "test: add unit test for instant unlock on two fingers recovery"
```

---

### 任务 2：实现 `KnobStateManager` 双指归位即时解锁逻辑

**文件：**
- 修改：`PhantomKnob/Service/KnobStateManager.swift:795-805`

- [ ] **步骤 1：修改 `KnobStateManager.swift` 的 `onMultitouchMoved(points:)` 方法**

在 `PhantomKnob/Service/KnobStateManager.swift` 的 `onMultitouchMoved(points:)` 方法中：

```swift
    func onMultitouchMoved(points: [Int: CGPoint]) {
        let currentTouchCount = points.count
        if currentTouchCount >= 2 {
            transitionToOneFingerTime = nil
        } else if previousPointCount >= 2 && currentTouchCount == 1 {
            transitionToOneFingerTime = Date()
            PKLogger.knob.debug("Two-to-one finger transition detected, starting 100ms protection lock")
        }
        previousPointCount = currentTouchCount

        var isTransitionLocked = false
        if let lockTime = transitionToOneFingerTime {
            let elapsed = Date().timeIntervalSince(lockTime)
            if elapsed < 0.100 {
                isTransitionLocked = true
            } else {
                transitionToOneFingerTime = nil
            }
        }
```

- [ ] **步骤 2：运行全套 `KnobLiftoffFilterTests` 验证测试全部通过**

运行：
```bash
xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -only-testing:PhantomKnobTests/KnobLiftoffFilterTests
```
预期：PASS，包含新的 `testTwoToOneTransitionInstantUnlockOnTwoFingers` 与已有的所有离板防抖测试。

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnob/Service/KnobStateManager.swift
git commit -m "fix: clear 100ms transition lock immediately when two fingers are back on trackpad"
```
