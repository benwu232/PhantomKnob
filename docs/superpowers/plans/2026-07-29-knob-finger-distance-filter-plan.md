# 双指距离小于10mm避错与超时退出 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在双指间距小于 10mm 时避免判定为旋钮，在已激活状态下若双指小于 10mm 持续 1.0 秒则自动退回普通手势并渲染 10mm 警告圆。

**架构：**
1. 在 `GestureClassifier` 引入 10mm 校验及 1.0s 计时器。在 Began 处强校验，在 Moved 中检测超时并触发退出。
2. 在 `OverlayView` 中新增 `isTooClose` 渲染状态并支持自画 10mm (50pt) 同色警示圆。
3. 在 `OverlayController` 中传递 `isTooClose` 状态并自适应覆写 `diameter` 为 50pt。
4. 在 `KnobStateManager` 中，当 `state.isKnobing` 且返回手势变为非 `.knob` 时触发退出到 `.cooling`；并在移动期间更新并传递 `isTooClose`。

**技术栈：** Swift, SwiftUI, XCTest, CoreGraphics

---

## 计划变更文件

- 修改 `PhantomKnob/Service/GestureClassifier.swift`
- 修改 `PhantomKnob/View/OverlayView.swift`
- 修改 `PhantomKnob/Service/OverlayController.swift`
- 修改 `PhantomKnob/Service/KnobStateManager.swift`
- 修改 `PhantomKnob/PhantomKnobTests/GestureClassifierTests.swift`

---

### 任务 1：编写与运行失败测试 (TDD)

**文件：**
- 修改：`PhantomKnob/PhantomKnobTests/GestureClassifierTests.swift`

- [ ] **步骤 1：在 `GestureClassifierTests.swift` 中新增测试用例**

在 `GestureClassifierTests` 类中添加以下两个方法：
```swift
    func testBeganDistanceFilter() {
        let classifier = GestureClassifier()
        // 双指物理间距为 8.0 mm (小于 10.0mm 阈值)
        let points1: [Int: CGPoint] = [
            1: CGPoint(x: 4.0, y: 0.0),
            2: CGPoint(x: -4.0, y: 0.0)
        ]
        classifier.processTouchesBegan(points: points1)
        
        // 模拟旋转了 15 度，位移为 0.0 (未超标)
        let radians = 15.0 * .pi / 180.0
        let points2: [Int: CGPoint] = [
            1: CGPoint(x: 4.0 * cos(radians), y: 4.0 * sin(radians)),
            2: CGPoint(x: -4.0 * cos(radians), y: -4.0 * sin(radians))
        ]
        let mode = classifier.processTouchesMoved(points: points2)
        XCTAssertEqual(mode, .pan, "双指初始物理间距小于 10mm 时，不应该开启或进入旋钮判定")
    }

    func testKnobDistanceTimeout() {
        let classifier = GestureClassifier()
        // 双指物理间距为 20.0 mm (大于 10.0mm 阈值)
        let points1: [Int: CGPoint] = [
            1: CGPoint(x: 10.0, y: 0.0),
            2: CGPoint(x: -10.0, y: 0.0)
        ]
        classifier.processTouchesBegan(points: points1)
        
        // 旋转 15 度以激活旋钮
        let radians = 15.0 * .pi / 180.0
        let points2: [Int: CGPoint] = [
            1: CGPoint(x: 10.0 * cos(radians), y: 10.0 * sin(radians)),
            2: CGPoint(x: -10.0 * cos(radians), y: -10.0 * sin(radians))
        ]
        let mode = classifier.processTouchesMoved(points: points2)
        XCTAssertEqual(mode, .knob, "正常旋转应当激活旋钮")
        
        // 保持旋转，但双指突然缩拢到距离仅 8.0 mm
        let points3: [Int: CGPoint] = [
            1: CGPoint(x: 4.0 * cos(radians), y: 4.0 * sin(radians)),
            2: CGPoint(x: -4.0 * cos(radians), y: -4.0 * sin(radians))
        ]
        
        // 刚缩拢时，由于未到 1 秒，应当继续维持 knob
        let modeImmediately = classifier.processTouchesMoved(points: points3)
        XCTAssertEqual(modeImmediately, .knob, "未超时前应当维持旋钮状态")
        
        // 模拟等待 1.1 秒
        Thread.sleep(forTimeInterval: 1.1)
        
        // 再次移动，应当由于超时退回 .pan 模式
        let modeAfterTimeout = classifier.processTouchesMoved(points: points3)
        XCTAssertEqual(modeAfterTimeout, .pan, "两指距离过小持续 1.0 秒后，应自动降级退出旋钮状态")
    }
```

- [ ] **步骤 2：运行测试验证失败 (红灯)**

运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS'`
预期：测试失败，有编译或断言错误（由于 `minDistanceThreshold` 和超时逻辑尚未实现）。

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnob/PhantomKnobTests/GestureClassifierTests.swift
git commit -m "test: add distance filter and timeout test cases for GestureClassifier"
```

---

### 任务 2：实现 `GestureClassifier` 过滤与超时机制 (TDD)

**文件：**
- 修改：`PhantomKnob/Service/GestureClassifier.swift`

- [ ] **步骤 1：修改 `GestureClassifier.swift` 以支持距离检查和计时器**

1. 引入成员属性：
   ```swift
   private let minDistanceThreshold: CGFloat = 10.0 // 最小距离阈值 10mm
   private var closeDistanceStartTime: Date?       // 记录靠拢的开始时间
   ```
2. 更新 `processTouchesBegan(points:)`：
   ```swift
       func processTouchesBegan(points: [Int: CGPoint]) {
           let (knobCore, _, _) = algorithm.calKnob(points)
           if knobCore.isValid && knobCore.radius * 2 >= minDistanceThreshold {
               initialAngle = knobCore.angle
               initialCentroid = calculateCentroid(points: points)
               detectionStartTime = Date()
           } else {
               initialAngle = nil
               initialCentroid = nil
               detectionStartTime = nil
           }
           closeDistanceStartTime = nil
           currentMode = .pan
       }
   ```
3. 更新 `processTouchesMoved(points:) -> GestureMode`：
   ```swift
       func processTouchesMoved(points: [Int: CGPoint]) -> GestureMode {
           if currentMode == .knob {
               if points.count >= 2 {
                   let (knobCore, _, _) = algorithm.calKnob(points)
                   let currentDistance = knobCore.isValid ? knobCore.radius * 2 : 0
                   if currentDistance < minDistanceThreshold {
                       if closeDistanceStartTime == nil {
                           closeDistanceStartTime = Date()
                       } else if Date().timeIntervalSince(closeDistanceStartTime!) >= 1.0 {
                           currentMode = .pan
                           closeDistanceStartTime = nil
                           initialAngle = calculateAngle(points: points)
                           initialCentroid = calculateCentroid(points: points)
                           detectionStartTime = Date()
                       }
                   } else {
                       closeDistanceStartTime = nil
                   }
               } else {
                   // 单指延续状态，不需要距离校验，重置计时器
                   closeDistanceStartTime = nil
               }
               return currentMode
           }
           
           guard let initialAngle = initialAngle,
                 let initialCentroid = initialCentroid,
                 let startTime = detectionStartTime else {
               return currentMode
           }
           
           if Date().timeIntervalSince(startTime) > detectionWindow {
               return .pan
           }
           
           let currentCentroid = calculateCentroid(points: points)
           let distanceMoved = distance(initialCentroid, currentCentroid)
           
           let currentAngle = calculateAngle(points: points)
           let delta = abs(angleDelta(from: initialAngle, to: currentAngle))
           
           if distanceMoved < translationThreshold && delta > angleThreshold {
               let (knobCore, _, _) = algorithm.calKnob(points)
               let currentDistance = knobCore.isValid ? knobCore.radius * 2 : 0
               if currentDistance >= minDistanceThreshold {
                   currentMode = .knob
               }
           }
           
           return currentMode
       }
   ```
4. 更新 `processTouchesEnded()` 和 `forcePassthrough()` 以重置 `closeDistanceStartTime = nil`。

- [ ] **步骤 2：运行测试验证通过 (绿灯)**

运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS'`
预期：先前新增的 `testBeganDistanceFilter` 与 `testKnobDistanceTimeout` 以及所有其他既有测试均通过。

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnob/Service/GestureClassifier.swift
git commit -m "feat: implement 10mm distance threshold and 1.0s timeout exit in GestureClassifier"
```

---

### 任务 3：升级 `OverlayView` 和 `OverlayController`

**文件：**
- 修改：`PhantomKnob/View/OverlayView.swift`
- 修改：`PhantomKnob/Service/OverlayController.swift`

- [ ] **步骤 1：在 `OverlayView` 中新增 `isTooClose` 属性与绘制警示圆**

1. 修改 `OverlayView` 结构体：
   ```swift
       let isTooClose: Bool
   ```
2. 在 `init` 构造函数中增加 `isTooClose: Bool = false` 参数并赋值。
3. 修改 `body`：
   ```swift
       var body: some View {
           let activeColor: Color = {
               let base = Color(hex: themeColorHex)
               return isActive ? base : base.opacity(0.3)
           }()
           
           VStack(spacing: 4) {
               if isTooClose {
                   ZStack {
                       Circle()
                           .stroke(activeColor, lineWidth: 2)
                           .frame(width: 50, height: 50)
                       Circle()
                           .fill(activeColor.opacity(0.15))
                           .frame(width: 48, height: 48)
                   }
                   .frame(width: diameter, height: diameter)
               } else {
                   // ... 原本的所有正常 Overlay 子 View 逻辑 ...
               }
           }
           .frame(width: diameter, height: diameter + (isTooClose ? 0 : (valueText != nil ? 38 : 20)))
       }
   ```

- [ ] **步骤 2：修改 `OverlayController` 传递 `isTooClose` 并自动调整尺寸**

1. 引入属性：
   ```swift
   @Published var isTooClose: Bool = false
   ```
2. 修改 `update` 方法以接收 `isTooClose`：
   ```swift
       func update(angle: Double, 
                   radius: Double, 
                   isDeadzone: Bool = false, 
                   isTooClose: Bool = false,
                   scale: Double? = nil, 
                   themeColor: String? = nil,
                   outerThemeColor: String? = nil,
                   innerThemeColor: String? = nil,
                   configType: KnobConfigType = .single) {
           self.angle = angle
           self.isDeadzone = isDeadzone
           self.isTooClose = isTooClose
           self.scale = scale
           self.configType = configType
           // ...
           if isTooClose {
               self.diameter = 50.0 // 10mm 的圆在屏幕上为 50pt
           } else {
               self.diameter = Self.calculateDiameter(for: radius)
           }
           updatePanelFrame()
           updateOverlayView()
       }
   ```
3. 修改 `createPanel()` 和 `updateOverlayView()` 传入 `isTooClose: isTooClose` 至 `OverlayView` 初始化方法。

- [ ] **步骤 3：运行项目测试确保无编译报错**

运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS'`
预期：单元测试全部通过。

- [ ] **步骤 4：Commit**

```bash
git add PhantomKnob/View/OverlayView.swift PhantomKnob/Service/OverlayController.swift
git commit -m "feat: add support for isTooClose state in OverlayView and OverlayController"
```

---

### 任务 4：在 `KnobStateManager` 中整合状态判定与 UI 响应

**文件：**
- 修改：`PhantomKnob/Service/KnobStateManager.swift`

- [ ] **步骤 1：修改 `onMultitouchMoved(points:)` 以支持双指靠拢判定与超时退出**

1. 在 `onMultitouchMoved` 前半段，检测 `isTooClose` 状态：
   ```swift
           let isTooClose = scaledPoints.count >= 2 && {
               let (knobCore, _, _) = KnobAlgorithm().calKnob(scaledPoints)
               return knobCore.isValid && knobCore.radius * 2 < 10.0
           }()
   ```
2. 更新对分类器 mode 的检测：
   ```swift
           let mode = gestureClassifier.processTouchesMoved(points: points)
           
           if state.isKnobing {
               if mode != .knob {
                   PKLogger.knob.debug("Exiting knobing early because gesture mode is no longer .knob (distance filter timeout)")
                   if let target = currentTarget {
                       transition(to: .cooling(target: target))
                       if target.axRole != "ControlPanel" {
                           overlayController.fadeOut { [weak self] in
                               self?.startCoolingTimer()
                           }
                       } else {
                           startCoolingTimer()
                       }
                   } else {
                       transition(to: .activated)
                   }
                   return
               }
           }
   ```
3. 在 `state.isKnobing` 逻辑块内部：
   * 如果 `isTooClose` 为 `true`，则直接更新 Overlay (传入 `isTooClose: true`) 并跳过事件注入和 `previousAngle` 挪动，即静默挂起：
     ```swift
               if isTooClose {
                   let color = knob.flatMap { resolveThemeColor(for: $0, zoneIndex: currentZoneIndex, radius: radius) }
                   overlayController.update(
                       angle: currentAngle,
                       radius: radius,
                       isDeadzone: false,
                       isTooClose: true,
                       scale: self.lastResolvedBaseScale,
                       themeColor: color,
                       outerThemeColor: knob?.cvkConfig?.outerThemeColor,
                       innerThemeColor: knob?.cvkConfig?.innerThemeColor,
                       configType: knob?.configType ?? .single
                   )
                   self.currentAngle = currentAngle
                   previousAngle = currentAngle
                   return
               }
     ```
   * 否则在原有的 `overlayController.update` (正常态和 Deadzone 态) 调用中，显示传入 `isTooClose: false`：
     ```swift
                   overlayController.update(
                       angle: currentAngle,
                       radius: radius,
                       isDeadzone: true,
                       isTooClose: false,
                       ...
                   )
     ```
     和：
     ```swift
               overlayController.update(
                   angle: currentAngle,
                   radius: radius,
                   isDeadzone: false,
                   isTooClose: false,
                   ...
               )
     ```

- [ ] **步骤 2：运行整体单元测试验证稳定性**

运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS'`
预期：全部单元测试通过，没有任何旧手势逻辑损坏。

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnob/Service/KnobStateManager.swift
git commit -m "feat: integrate isTooClose condition check and early exit trigger in KnobStateManager"
```
