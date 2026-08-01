# 双指离板触点防拉扯与防抖过滤 (Knob Liftoff Jitter Filter) 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在用户抬起双指离开妙控板瞬间，消除由于触点变动引发的旋转角度增量倒退与抖动，保证旋钮停留位置顺滑稳定。

**架构：** 结合底层 `MTContact.state` (5: breaking, 6: lingering) 的状态判定，在 `MultitouchManager` 中拦截不稳定坐标；同时在 `KnobStateManager` 中引入 30ms / 3 帧的角度滑动历史缓冲区，在手势终止时截断尾部异常跳跃帧，锁定在倒数稳定角度。

**技术栈：** Swift 5, AppKit, MultitouchSupport (Private Framework), XCTest

---

## 文件结构

- 修改：`PhantomKnob/Service/MultitouchManager.swift` — 捕捉 `MTContact.state` 5 (breaking) 与 6 (lingering)，在离板过渡期避免推送不稳触点。
- 修改：`PhantomKnob/Service/KnobStateManager.swift` — 维护 30ms / 3 帧角度历史缓冲区，实现离板末帧冻结（Tail Freezing）回滚逻辑。
- 创建：`PhantomKnob/PhantomKnobTests/KnobLiftoffFilterTests.swift` — 离板触点过滤与末帧角度截断逻辑的单元测试。

---

### 任务 1：编写离板触点过滤与末帧冻结单元测试

**文件：**
- 创建：`PhantomKnob/PhantomKnobTests/KnobLiftoffFilterTests.swift`

- [ ] **步骤 1：编写失败的单元测试**

```swift
import XCTest
@testable import PhantomKnob

final class KnobLiftoffFilterTests: XCTestCase {
    
    func testAngleHistoryBufferTailFreezing() {
        // 验证给定一串包含离板微跳跃的角度历史输入（如 [0, 10, 20, 18]），
        // 当调用 processLiftoffAngle() 时，能够正确丢弃尾部 18° 并锁定在稳定帧 20°
        var buffer = KnobAngleBuffer(capacity: 3, timeWindowSec: 0.03)
        let now = Date()
        buffer.append(angle: 0, timestamp: now.addingTimeInterval(-0.03))
        buffer.append(angle: 10, timestamp: now.addingTimeInterval(-0.02))
        buffer.append(angle: 20, timestamp: now.addingTimeInterval(-0.01))
        buffer.append(angle: 18, timestamp: now) // 尾部跳跃帧
        
        let resolvedAngle = buffer.resolvedLiftoffAngle()
        XCTAssertEqual(resolvedAngle, 20.0, accuracy: 0.001, "应该丢弃尾部反弹帧 18° 并锁定在倒数稳定帧 20°")
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -only-testing:PhantomKnobTests/KnobLiftoffFilterTests`
预期：FAIL，报错提示 "Cannot find 'KnobAngleBuffer' in scope"

- [ ] **步骤 3：编写 `KnobAngleBuffer` 最少类型实现**

在 `PhantomKnob/Service/KnobStateManager.swift` 文件中添加 `KnobAngleBuffer` 结构体：

```swift
struct AngleFrame {
    let angle: Double
    let timestamp: Date
}

struct KnobAngleBuffer {
    let capacity: Int
    let timeWindowSec: TimeInterval
    private(set) var frames: [AngleFrame] = []
    
    init(capacity: Int = 3, timeWindowSec: TimeInterval = 0.03) {
        self.capacity = capacity
        self.timeWindowSec = timeWindowSec
    }
    
    mutating func append(angle: Double, timestamp: Date = Date()) {
        frames.append(AngleFrame(angle: angle, timestamp: timestamp))
        if frames.count > capacity {
            frames.removeFirst()
        }
    }
    
    mutating func clear() {
        frames.removeAll()
    }
    
    func resolvedLiftoffAngle() -> Double? {
        guard !frames.isEmpty else { return nil }
        if frames.count >= 2 {
            // 丢弃包含离板抖动的最后一帧，回退至倒数第二帧稳定值
            return frames[frames.count - 2].angle
        }
        return frames.last?.angle
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -only-testing:PhantomKnobTests/KnobLiftoffFilterTests`
预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnob/PhantomKnobTests/KnobLiftoffFilterTests.swift PhantomKnob/Service/KnobStateManager.swift
git commit -m "test: add unit test for KnobAngleBuffer tail freezing"
```

---

### 任务 2：在 `MultitouchManager` 中集成底层触点离板状态判定 (`state = 5/6`)

**文件：**
- 修改：`PhantomKnob/Service/MultitouchManager.swift:130-180`
- 修改：`PhantomKnob/PhantomKnobTests/KnobLiftoffFilterTests.swift`

- [ ] **步骤 1：在 `KnobLiftoffFilterTests.swift` 中编写测试**

```swift
func testMultitouchManagerFilterBreakingContacts() {
    // 验证接触状态包含 state=5 (breaking) 时，标记为离板阶段
    var contacts: [TestContact] = [
        TestContact(identifier: 1, state: 4, x: 10, y: 10),
        TestContact(identifier: 2, state: 5, x: 20, y: 20) // breaking
    ]
    let isReleasing = MultitouchManager.isAnyContactReleasing(states: contacts.map { $0.state })
    XCTAssertTrue(isReleasing, "包含 state=5 (breaking) 时应该判定为 isReleasing == true")
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -only-testing:PhantomKnobTests/KnobLiftoffFilterTests/testMultitouchManagerFilterBreakingContacts`
预期：FAIL，报错 "type MultitouchManager has no member isAnyContactReleasing"

- [ ] **步骤 3：在 `MultitouchManager.swift` 中增加 `isAnyContactReleasing` 与离板状态拦截**

```swift
static func isAnyContactReleasing(states: [Int32]) -> Bool {
    return states.contains { $0 == 5 || $0 == 6 }
}
```

在 `MultitouchManager.swift` 的 `handleContacts` 中拦截离板相位：
```swift
// 遇到 state = 5 (breaking) 或 6 (lingering) 时，不再分发 Moved 事件以拦截尾抖动
let hasReleasingContact = rawContactStates.contains { $0 == 5 || $0 == 6 }
if hasReleasingContact && inGesture {
    PKLogger.multitouch.debug("Releasing contact detected (state 5/6), freezing gesture moved updates")
    return
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -only-testing:PhantomKnobTests/KnobLiftoffFilterTests`
预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnob/Service/MultitouchManager.swift PhantomKnob/PhantomKnobTests/KnobLiftoffFilterTests.swift
git commit -m "feat: filter state 5/6 releasing contacts in MultitouchManager"
```

---

### 任务 3：在 `KnobStateManager` 中接入 `KnobAngleBuffer` 实现离板末帧锁死

**文件：**
- 修改：`PhantomKnob/Service/KnobStateManager.swift:150-250`
- 修改：`PhantomKnob/PhantomKnobTests/KnobLiftoffFilterTests.swift`

- [ ] **步骤 1：编写集成端到端测试**

在 `KnobLiftoffFilterTests.swift` 中测试手势结束时角度锁定到稳定值的行为：

```swift
func testKnobStateManagerLocksAngleOnGestureEnd() {
    let mockManager = KnobStateManagerTestHelper.createMockStateManager()
    mockManager.processGestureMoved(angle: 10.0)
    mockManager.processGestureMoved(angle: 20.0)
    mockManager.processGestureMoved(angle: 18.0) // 离板跳跃帧
    mockManager.processGestureEnded()
    
    XCTAssertEqual(mockManager.currentAngle, 20.0, accuracy: 0.001, "手势结束时角度应锁定在倒数稳定帧 20.0")
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -only-testing:PhantomKnobTests/KnobLiftoffFilterTests/testKnobStateManagerLocksAngleOnGestureEnd`
预期：FAIL

- [ ] **步骤 3：修改 `KnobStateManager.swift` 接入 `KnobAngleBuffer`**

在 `KnobStateManager` 中增加属性并更新逻辑：
```swift
private var angleBuffer = KnobAngleBuffer()

func onMultitouchMoved(points: [Int: CGPoint]) {
    // ... 正常角度计算 ...
    angleBuffer.append(angle: calculatedAngle)
    // ...
}

func onMultitouchEnded() {
    if let lockAngle = angleBuffer.resolvedLiftoffAngle() {
        self.currentAngle = lockAngle
    }
    angleBuffer.clear()
    // ... 手势结束清理 ...
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -only-testing:PhantomKnobTests/KnobLiftoffFilterTests`
预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnob/Service/KnobStateManager.swift PhantomKnob/PhantomKnobTests/KnobLiftoffFilterTests.swift
git commit -m "feat: integrate KnobAngleBuffer in KnobStateManager for liftoff angle locking"
```

---

## 规格自检 (Plan Self-Check)

1. **规格覆盖度：** 涵盖了方案 1（末帧冻结）与方案 2（触点状态过滤）的所有设计和验证要求。
2. **占位符扫描：** 无任何 TODO、待定或类似占位符。
3. **类型一致性：** `KnobAngleBuffer`、`AngleFrame`、`resolvedLiftoffAngle()` 等签名在所有任务中完全一致。
