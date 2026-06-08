# 旋钮手势与系统缩放、旋转手势冲突解决实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现自适应 Event Tap 控制流程，防止在指向可调节控件时泄漏系统缩放和旋转手势，同时在指向空白画布时允许正常手势。

**架构：** 在 `KnobStateManager` 中，当双指触摸开始时（`onMultitouchBegan`）立即判断鼠标下的控件是否属于可调节控件或命中了规则例外。若是，标记并立即激活 `Event Tap` 全局屏蔽两指缩放/旋转/手势事件；当双指抬起时重置状态并注销拦截。

**技术栈：** Swift, CoreGraphics (Event Tap), macOS Accessibility (AXUIElement)

---

### 任务 1：创建单元测试并实现 isAdjustable 骨架

**文件：**
- 创建：`PhantomKnobDetector/PhantomKnobDetectorTests/GestureConflictTests.swift`
- 修改：`PhantomKnobDetector/Service/KnobStateManager.swift`

- [ ] **步骤 1：在 `KnobStateManager.swift` 中定义 `isAdjustable` 骨架**

在 `KnobStateManager.swift` 的 `// MARK: - Helper Methods` 区域添加一个总是返回 `false` 的骨架函数，并定义 `isInterceptingGestures` 变量：

```swift
    // 在 class 属性区域（大约第 33 行之后）添加：
    var isInterceptingGestures = false

    // 在 Helper Methods 区域（大约第 615 行之后）添加：
    func isAdjustable(target: DetectedTarget) -> Bool {
        return false
    }
```

- [ ] **步骤 2：创建 `GestureConflictTests.swift` 并编写失败测试**

创建 `PhantomKnobDetector/PhantomKnobDetectorTests/GestureConflictTests.swift` 并编写以下单元测试：

```swift
import XCTest
@testable import PhantomKnobDetector

final class GestureConflictTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        RuleLibrary.shared.reload()
        super.tearDown()
    }
    
    func testIsAdjustableRuleLibraryMatch() {
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        
        let rule = ControlRule(
            key: RuleKey(bundleID: "com.test.adjustable", axRole: "unknown", identifier: nil, displayName: nil),
            translation: .scrollWheelVertical
        )
        RuleLibrary.shared.injectRulesForTesting([rule])
        
        let target = DetectedTarget(
            bundleID: "com.test.adjustable",
            axRole: "unknown",
            identifier: nil,
            displayName: "Test",
            element: nil
        )
        
        XCTAssertTrue(manager.isAdjustable(target: target))
    }
    
    func testIsAdjustableNoMatch() {
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        
        RuleLibrary.shared.injectRulesForTesting([])
        
        let target = DetectedTarget(
            bundleID: "com.test.nonadjustable",
            axRole: "unknown",
            identifier: nil,
            displayName: "Test",
            element: nil
        )
        
        XCTAssertFalse(manager.isAdjustable(target: target))
    }
}
```

- [ ] **步骤 3：运行测试并确认失败**

运行：`xcodebuild test -scheme PhantomKnobDetector -destination 'platform=macOS' -only-testing:PhantomKnobDetectorTests/GestureConflictTests 2>&1`
预期：XCTAssertTrue 失败（因为骨架总是返回 `false`）。

- [ ] **步骤 4：Commit 骨架与测试**

```bash
git add PhantomKnobDetector/Service/KnobStateManager.swift PhantomKnobDetector/PhantomKnobDetectorTests/GestureConflictTests.swift
git commit -m "test: add gesture conflict tests and isAdjustable skeleton"
```

---

### 任务 2：实现 isAdjustable 的完整判定逻辑

**文件：**
- 修改：`PhantomKnobDetector/Service/KnobStateManager.swift`

- [ ] **步骤 1：编写完整的 `isAdjustable` 逻辑**

修改 `KnobStateManager.swift` 中的 `isAdjustable(target:)` 方法：

```swift
    func isAdjustable(target: DetectedTarget) -> Bool {
        // 1. 如果命中规则库中的任何规则，说明用户/内置规则已为此进行了特化，必然是可调节的
        if RuleLibrary.shared.lookup(for: target.ruleKey) != nil {
            return true
        }
        
        // 2. 如果具备 AX 元素，根据 AX 角色与属性判定
        if let element = target.element {
            // A. Role 白名单中的标准可调节控件
            let role = TargetDetector.getString(from: element, attribute: kAXRoleAttribute) ?? ""
            let adjustableRoles: Set<String> = ["AXSlider", "AXScrollBar", "AXValueIndicator", "AXStepper", "AXDial", "AXIncrementor"]
            if adjustableRoles.contains(role) {
                return true
            }
            
            // B. 具备最小值和最大值的数值控件
            if TargetDetector.getDouble(from: element, attribute: kAXMinValueAttribute) != nil &&
               TargetDetector.getDouble(from: element, attribute: kAXMaxValueAttribute) != nil {
                return true
            }
            
            // C. 具备可写的 AXValue 属性
            var settable: DarwinBoolean = false
            if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success, settable.boolValue {
                return true
            }
            
            // D. 支持递增/递减 Action
            var actions: CFArray?
            if AXUIElementCopyActionNames(element, &actions) == .success,
               let actionList = actions as? [String],
               (actionList.contains(kAXIncrementAction) || actionList.contains(kAXDecrementAction)) {
                return true
            }
        }
        
        return false
    }
```

- [ ] **步骤 2：再次运行测试验证通过**

运行：`xcodebuild test -scheme PhantomKnobDetector -destination 'platform=macOS' -only-testing:PhantomKnobDetectorTests/GestureConflictTests 2>&1`
预期：所有测试 PASS。

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnobDetector/Service/KnobStateManager.swift
git commit -m "feat: implement isAdjustable detection in KnobStateManager"
```

---

### 任务 3：集成自适应 Event Tap 控制逻辑与生命周期测试

**文件：**
- 修改：`PhantomKnobDetector/Service/KnobStateManager.swift`
- 修改：`PhantomKnobDetector/PhantomKnobDetectorTests/GestureConflictTests.swift`

- [ ] **步骤 1：在 `KnobStateManager.swift` 中升级手势拦截**

1. 修改 `onMultitouchBegan` 方法：在大约第 211 行 `currentTarget = target` 之后，加入 Event Tap 的立即激活判断：
```swift
        currentTarget = target

        // 检查修饰键激活或当前控件是否可调节
        if isOptionHoldActive || isAdjustable(target: target) {
            isInterceptingGestures = true
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                writeDebugLog("[KnobStateManager] Enabled event tap on begin (adjustable/option hold)")
            }
        } else {
            isInterceptingGestures = false
        }
```

2. 修改 `onMultitouchEnded` 方法：在第 413 行 `onMultitouchEnded` 开始处，重置拦截标志：
```swift
    func onMultitouchEnded() {
        guard state != .inactive else { return }
        isInterceptingGestures = false
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        gestureClassifier.processTouchesEnded()
...
```

3. 修改 `handleEventTap` 方法：在第 497 行处，将守卫条件扩展为包含 `isInterceptingGestures`：
```swift
    private func handleEventTap(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Bool {
        guard state.isKnobing || isInterceptingGestures else { return false }
        
        // Skip events posted by our own translators
        let sourceUserData = event.getIntegerValueField(.eventSourceUserData)
        guard sourceUserData != 0xDEADC0DE else { return false }
        
        // Block zoom (magnify), rotate, and general gestures during knobing/interception
        let typeVal = type.rawValue
        if typeVal == 29 || typeVal == 19 || typeVal == 18 {
            writeDebugLog("[KnobStateManager] Swallowed gesture event of type: \(typeVal) (knobing: \(state.isKnobing), intercepting: \(isInterceptingGestures))")
            return true
        }
```

- [ ] **步骤 2：在 `GestureConflictTests.swift` 中添加集成测试**

添加对 `isInterceptingGestures` 生命周期的测试用例：

```swift
    func testIsInterceptingGesturesBeganAndEnded() {
        let manager = KnobStateManager(
            targetDetector: TargetDetector(),
            gestureClassifier: GestureClassifier(),
            overlayController: OverlayController(),
            statusBarController: StatusBarController(),
            touchHandler: GlobalTouchHandler()
        )
        
        // 模拟当前前台 App Bundle ID 的规则命中
        let frontmostID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "com.apple.dt.xctest.tool"
        let rule = ControlRule(
            key: RuleKey(bundleID: frontmostID, axRole: "unknown", displayName: ""),
            translation: .scrollWheelVertical
        )
        RuleLibrary.shared.injectRulesForTesting([rule])
        
        // 1. 模拟激活状态下的双指触摸开始
        manager.transition(to: .activated)
        XCTAssertFalse(manager.isInterceptingGestures)
        
        manager.onMultitouchBegan(points: [0: CGPoint.zero, 1: CGPoint(x: 10, y: 10)])
        XCTAssertTrue(manager.isInterceptingGestures)
        
        // 2. 模拟触摸结束
        manager.onMultitouchEnded()
        XCTAssertFalse(manager.isInterceptingGestures)
    }
```

- [ ] **步骤 3：运行所有测试验证通过**

运行：`xcodebuild test -scheme PhantomKnobDetector -destination 'platform=macOS' 2>&1 | grep -E "(error:|FAIL)"`
预期：全部编译通过且无测试 FAIL。

- [ ] **步骤 4：Commit 并集成**

```bash
git add PhantomKnobDetector/Service/KnobStateManager.swift PhantomKnobDetector/PhantomKnobDetectorTests/GestureConflictTests.swift
git commit -m "feat: integrate adaptive Event Tap interception and write lifecycle tests"
```
