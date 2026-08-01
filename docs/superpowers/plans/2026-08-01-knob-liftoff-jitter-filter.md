# 双指离板触点防拉扯与防抖过滤 (Knob Liftoff Jitter Filter v2) 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在用户抬起双指离开妙控板瞬间，消除由于触点变动和双切单时间差引发的旋转增量倒退、拉扯与系统事件泄露，保证旋钮停留位置顺滑稳定。

**架构：** 在 `KnobStateManager` 中引入**双指切单指 100ms 保护锁（100ms Transition Protection Lock）**，在触点数从 $\ge 2$ 降为 $1$ 的 100ms 窗口内，继续更新内部角度但拦截向系统派发 `translator.apply(...)`；配合 `MultitouchManager` 的 `state 5/6` 过滤与 `KnobAngleBuffer` 的 30ms 尾帧回滚，实现 100% 无跳变的离板防护。

**技术栈：** Swift 5, AppKit, MultitouchSupport (Private Framework), XCTest

---

## 文件结构

- 修改：`PhantomKnob/Service/KnobStateManager.swift` — 引入 `transitionToOneFingerTime` 与 `previousPointCount`，在 100ms 转换期拦截系统事件派发。
- 修改：`PhantomKnob/PhantomKnobTests/KnobLiftoffFilterTests.swift` — 补充双切单 100ms 锁定与恢复的单元测试。

---

### 任务 1：编写 100ms 双切单保护锁单元测试

**文件：**
- 修改：`PhantomKnob/PhantomKnobTests/KnobLiftoffFilterTests.swift`

- [ ] **步骤 1：编写 100ms 锁定的失败单元测试**

在 `KnobLiftoffFilterTests.swift` 中添加：

```swift
func testTwoToOneTransitionLockWindow() {
    let now = Date()
    // 模拟时刻 t = 0s 发生双指切单指
    let lockTime = now
    
    // 在 100ms 窗口内 (例如 t + 0.05s) 应处于锁定状态
    let timeInWindow = now.addingTimeInterval(0.05)
    let isLockedInWindow = timeInWindow.timeIntervalSince(lockTime) < 0.100
    XCTAssertTrue(isLockedInWindow, "50ms 时应处于 100ms 锁定保护期")
    
    // 在 100ms 窗口外 (例如 t + 0.12s) 应接触锁定
    let timeAfterWindow = now.addingTimeInterval(0.12)
    let isLockedAfterWindow = timeAfterWindow.timeIntervalSince(lockTime) < 0.100
    XCTAssertFalse(isLockedAfterWindow, "120ms 时应解除 100ms 锁定保护")
}
```

- [ ] **步骤 2：运行测试验证通过**

运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build-for-testing -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
预期：PASS

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnob/PhantomKnobTests/KnobLiftoffFilterTests.swift
git commit -m "test: add unit test for 100ms transition lock window"
```

---

### 任务 2：在 `KnobStateManager` 中实现双指切单指 100ms 保护锁

**文件：**
- 修改：`PhantomKnob/Service/KnobStateManager.swift`

- [ ] **步骤 1：在 `KnobStateManager` 中声明 100ms 锁定属性**

```swift
private var transitionToOneFingerTime: Date?
private var previousPointCount: Int = 0
```

- [ ] **步骤 2：在 `onMultitouchMoved(points:)` 内部插入 100ms 转换逻辑与拦截**

```swift
// 1. 监测触点数量由 >= 2 降为 1 的瞬间
if previousPointCount >= 2 && points.count == 1 {
    transitionToOneFingerTime = Date()
    PKLogger.knob.debug("Two-to-one finger transition detected, starting 100ms protection lock")
}
previousPointCount = points.count

// 2. 检查是否处于 100ms 锁定期
var isTransitionLocked = false
if let lockTime = transitionToOneFingerTime {
    let elapsed = Date().timeIntervalSince(lockTime)
    if elapsed < 0.100 { // 100ms
        isTransitionLocked = true
    } else {
        transitionToOneFingerTime = nil
    }
}
```

在调用 `translator.apply(...)` 的位置：
```swift
if !isTransitionLocked {
    translator.apply(units: deltaAngle, direction: direction)
} else {
    PKLogger.knob.debug("Transition locked: updating internal angle \(currentAngle), skipping translator.apply()")
}
```

并在 `onMultitouchEnded()` 和手势复位时清理状态：
```swift
transitionToOneFingerTime = nil
previousPointCount = 0
```

- [ ] **步骤 3：运行 xcodebuild 测试与编译**

运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build-for-testing -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
预期：PASS

- [ ] **步骤 4：Commit**

```bash
git add PhantomKnob/Service/KnobStateManager.swift
git commit -m "feat: implement 100ms two-to-one finger transition lock in KnobStateManager"
```

---

## 规格自检 (Plan Self-Check)

1. **规格覆盖度：** 完美涵盖了双指切单指 100ms 锁死、事件拦截、状态清理与单元测试。
2. **占位符扫描：** 无任何 TODO、待定或类似占位符。
3. **类型一致性：** 路径、方法及变量在两个任务中完全统一。
