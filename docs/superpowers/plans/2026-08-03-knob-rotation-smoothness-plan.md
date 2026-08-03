# 旋钮旋转顺滑度恢复与离板防抖优化 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 恢复旋钮旋转时的零延迟顺滑体验，彻底消除中途丢帧与 100ms 锁定，同时保留抬指完全离开触控板时的尾端防抖。

**架构：** 在 `MultitouchManager` 中移除 `state 5/6` 中途丢包机制；在 `KnobStateManager` 中彻底删除 100ms 保护锁并保持 Moved 事件实时应用；在 `onMultitouchEnded` 处保留 `KnobAngleBuffer` 的离板末端稳定帧锁定。

**技术栈：** Swift, macOS Multitouch Native API, ObservableObject, XCTest

---

### 任务 1：移除 MultitouchManager 中的 state 5/6 中途丢包机制

**文件：**
- 修改：`PhantomKnob/Service/MultitouchManager.swift:115-180`

- [ ] **步骤 1：删除 `MultitouchManager.swift` 中 `isAnyContactReleasing` 方法及 `isReleasing` 检查**

在 [MultitouchManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/MultitouchManager.swift) 中，删除：
```swift
static func isAnyContactReleasing(states: [Int32]) -> Bool {
    return states.contains { $0 == 5 || $0 == 6 }
}
```
并将 `handleContacts` 中关于 `isReleasing` 的判定恢复为直通逻辑：
```swift
if activePoints.count >= 2 {
    if !inGesture {
        inGesture = true
        PKLogger.multitouch.debug("Gesture trigger: onMultitouchBegan with points = \(String(describing: activePoints))")
        DispatchQueue.main.async {
            self.delegate?.onMultitouchBegan(points: activePoints)
        }
    } else {
        PKLogger.multitouch.debug("Gesture trigger: onMultitouchMoved with points = \(String(describing: activePoints))")
        DispatchQueue.main.async {
            self.delegate?.onMultitouchMoved(points: activePoints)
        }
    }
} else if activePoints.count == 1 {
    if inGesture {
        PKLogger.multitouch.debug("Gesture trigger: onMultitouchMoved (1 finger) with points = \(String(describing: activePoints))")
        DispatchQueue.main.async {
            self.delegate?.onMultitouchMoved(points: activePoints)
        }
    }
}
```

- [ ] **步骤 2：编译验证**

运行：`swift build`
预期：`Build complete!` 无任何编译错误。

---

### 任务 2：移除 KnobStateManager 中的 100ms 保护锁逻辑

**文件：**
- 修改：`PhantomKnob/Service/KnobStateManager.swift:25-30, 755-760, 795-816, 1095-1105, 1140-1145`

- [ ] **步骤 1：从 `KnobStateManager.swift` 移除 100ms 锁属性与逻辑**

在 [KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/KnobStateManager.swift) 中：
1. 移除属性定义 `private var transitionToOneFingerTime: Date?` 和 `private var previousPointCount: Int = 0`。
2. 在 `onMultitouchBegan` 中，移除 `transitionToOneFingerTime = nil` 和 `previousPointCount = points.count`。
3. 在 `onMultitouchMoved` 开头，移除触点变化统计及 `isTransitionLocked` 计算逻辑。
4. 在 `onMultitouchMoved` 应用逻辑处，无条件执行 `translator.apply`：
```swift
let deltaAngle = abs(knobState.deltaAngle)
let direction: RotationDirection = knobState.deltaAngle >= 0 ? .clockwise : .counterClockwise

translator.apply(units: deltaAngle, direction: direction)
PKLogger.knob.debug("applied delta=\(deltaAngle) dir=\(String(describing: direction)) scale=\(finalScale)")
```
5. 在 `onMultitouchEnded` 中，移除 `transitionToOneFingerTime = nil` 和 `previousPointCount = 0` 重置代码。

- [ ] **步骤 2：编译验证**

运行：`swift build`
预期：`Build complete!` 无任何编译错误。

---

### 任务 3：更新单元测试并全量验证

**文件：**
- 修改：`PhantomKnob/PhantomKnobTests/KnobLiftoffFilterTests.swift:1-75`

- [ ] **步骤 1：更新 `KnobLiftoffFilterTests.swift` 测试用例**

更新 [KnobLiftoffFilterTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnobTests/KnobLiftoffFilterTests.swift)，移除关于 100ms 锁的测试项，断言 `onMultitouchMoved` 实时计算更新，`onMultitouchEnded` 离板回退过滤生效。

- [ ] **步骤 2：运行单元测试**

运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
预期：所有测试套件通过（`Test Suite 'All tests' passed`）。

- [ ] **步骤 3：提交 Git Commit**

```bash
git add PhantomKnob/Service/MultitouchManager.swift PhantomKnob/Service/KnobStateManager.swift PhantomKnob/PhantomKnobTests/KnobLiftoffFilterTests.swift
git commit -m "fix: restore smooth knob rotation by removing 100ms lock and state 5/6 suppression"
```

---

## 自检检查清单

1. **规格覆盖度：** 完美映射设计文档中 MultitouchManager 丢帧撤销、KnobStateManager 100ms 锁撤销、Ended 尾端防抖保留的要求。
2. **占位符扫描：** 无任何 TODO、待定或红旗占位符。
3. **类型与接口一致性：** `onMultitouchMoved` 与 `KnobAngleBuffer` 的公共接口与类型完全匹配。
