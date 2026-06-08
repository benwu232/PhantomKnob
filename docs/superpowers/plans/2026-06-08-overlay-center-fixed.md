# 旋钮 UI 圆心固定 (Overlay UI Center Fixed) 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在旋钮手势旋转期间，固定 Overlay UI 的圆心位置，仅让其半径/直径对称地变大或变小，从而消除视觉上的抖动和偏移。

**架构：**
1. 在手势启动时（`show` 方法中），根据初始鼠标坐标、选定的显示象限、最大直径（300.0）以及 0.6 的安全中心偏移比例计算出固定的圆心坐标 `fixedCenter`，并将其锁死。
2. 即使在屏幕边缘位置，也保证最大尺寸的框能够通过边界夹紧（Clamp）保持在屏幕可见范围内。
3. 后续更新（`update` 方法）时，根据 `fixedCenter` 以及当前的直径 `diameter` 直接对称计算 origin 坐标并刷新窗口，让圆心保持绝对静止。
4. 对应调整单元测试中对坐标值的断言。

**技术栈：** Swift, AppKit, SwiftUI, XCTest

---

## 文件职责列表

- 修改：[OverlayController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Service/OverlayController.swift) - 负责圆心坐标的确定、锁定与对称窗口位置的计算。
- 修改：[OverlayControllerTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/PhantomKnobDetectorTests/OverlayControllerTests.swift) - 负责对碰撞逃逸和边界位置计算进行验证。

---

## 详细任务步骤

### 任务 1：更新单元测试并验证失败 (TDD Red Phase)

**文件：**
- 修改：[OverlayControllerTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/PhantomKnobDetectorTests/OverlayControllerTests.swift)

- [ ] **步骤 1：修改单元测试中的坐标断言以匹配新设计的固定圆心逻辑**

在 `OverlayControllerTests.swift` 中，将 `testQuadrantCollisionAvoidance` 修改为：
```swift
    // 测试碰撞逃逸位置选择
    func testQuadrantCollisionAvoidance() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1000, height: 1000)
        let diameter: CGFloat = 100
        
        // Case 1: 鼠标在中间 (500, 500)，右下可以放下
        let posCenter = CGPoint(x: 500, y: 500)
        let frame1 = OverlayController.calculateBestFrame(
            cursor: posCenter,
            diameter: diameter,
            visibleFrame: visibleFrame
        )
        // 预期右下圆心：x = 500 + 105 = 605, y = 500 - 105 = 395
        // 对应直径 100 的窗口 origin 应该是：
        // x = 605 - 50 = 555
        // y = 395 - 50 = 345
        XCTAssertEqual(frame1.origin.x, 555)
        XCTAssertEqual(frame1.origin.y, 345)
        
        // Case 2: 鼠标在右下角 (950, 50)，右下、右上、左下均越界，应该使用左上
        let posBottomRight = CGPoint(x: 950, y: 50)
        let frame2 = OverlayController.calculateBestFrame(
            cursor: posBottomRight,
            diameter: diameter,
            visibleFrame: visibleFrame
        )
        // 左上圆心 x = 950 - 105 = 845, y = 50 + 105 = 155
        // 对应直径 100 的窗口 origin 应该是：
        // x = 845 - 50 = 795
        // y = 155 - 50 = 105
        XCTAssertEqual(frame2.origin.x, 795)
        XCTAssertEqual(frame2.origin.y, 105)
        
        // Case 3: 鼠标在左下角 (10, 10)，越界，夹紧在屏幕边界
        let posCorner = CGPoint(x: 10, y: 10)
        let frame3 = OverlayController.calculateBestFrame(
            cursor: posCorner,
            diameter: diameter,
            visibleFrame: visibleFrame
        )
        // 保证 x >= 0, y >= 0
        XCTAssertGreaterThanOrEqual(frame3.origin.x, 0)
        XCTAssertGreaterThanOrEqual(frame3.origin.y, 0)
    }
```

- [ ] **步骤 2：运行测试并确认失败**

运行：
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme PhantomKnobDetector -destination 'platform=macOS' -only-testing PhantomKnobDetectorTests/OverlayControllerTests
```
预期：测试失败，报 XCTAssertEqual 不匹配错误。

---

### 任务 2：实现圆心固定与对称更新逻辑 (TDD Green Phase)

**文件：**
- 修改：[OverlayController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Service/OverlayController.swift)

- [ ] **步骤 1：引入私有圆心属性并修改 `show` 与 `calculateBestFrame` 的摆放逻辑**

在 `OverlayController.swift` 中：
1. 引入属性：
   ```swift
   private var fixedCenter: CGPoint = .zero
   ```
2. 修改 `show()`，在手势启动时基于 0.6 比例的 maxRadius 计算并锁死圆心：
   ```swift
   func show(at position: CGPoint, 
             targetName: String?, 
             scale: Double? = nil, 
             themeColor: String? = nil, 
             overlayStyle: String? = nil, 
             rotationStyle: String? = nil) {
       self.position = position
       self.targetName = targetName
       self.scale = scale
       self.themeColor = themeColor ?? AppSettings.shared.defaultThemeColor
       self.overlayStyle = overlayStyle ?? AppSettings.shared.defaultOverlayStyle
       self.rotationStyle = rotationStyle ?? AppSettings.shared.defaultRotationStyle
       self.diameter = 80.0 // 默认直径 (16mm * 5px/mm)
       
       // 选择最佳固定圆心
       let activeScreen = NSScreen.screens.first { $0.frame.contains(position) } ?? NSScreen.main ?? NSScreen.screens[0]
       let visibleFrame = activeScreen.visibleFrame
       let maxD: CGFloat = 300.0
       let centerOffset: CGFloat = 105.0 // 15.0 + 150.0 * 0.6
       
       let candidates: [CGPoint] = [
           CGPoint(x: position.x + centerOffset, y: position.y - centerOffset), // 右下
           CGPoint(x: position.x + centerOffset, y: position.y + centerOffset), // 右上
           CGPoint(x: position.x - centerOffset, y: position.y - centerOffset), // 左下
           CGPoint(x: position.x - centerOffset, y: position.y + centerOffset)  // 左上
       ]
       
       var chosenCenter = candidates[0]
       var found = false
       for center in candidates {
           let rect = NSRect(
               x: center.x - maxD / 2,
               y: center.y - maxD / 2,
               width: maxD,
               height: maxD + 20.0
           )
           if visibleFrame.contains(rect) {
               chosenCenter = center
               found = true
               break
           }
       }
       
       if !found {
           let halfMaxD = maxD / 2
           let minX = visibleFrame.minX + halfMaxD
           let maxX = visibleFrame.maxX - halfMaxD
           let minY = visibleFrame.minY + halfMaxD
           let maxY = visibleFrame.maxY - (halfMaxD + 20.0)
           
           let clampedX = min(max(chosenCenter.x, minX), maxX)
           let clampedY = min(max(chosenCenter.y, minY), maxY)
           chosenCenter = CGPoint(x: clampedX, y: clampedY)
       }
       
       self.fixedCenter = chosenCenter
       
       showCount += 1
       writeDebugLog("[OverlayController] show() called: targetName = \(targetName ?? "nil"), scale = \(scale ?? 0.0), showCount = \(showCount), position = \(position), fixedCenter = \(fixedCenter)")

       if panel == nil {
           createPanel()
       }

       panel?.animator().alphaValue = 1.0
       panel?.alphaValue = 1.0

       updatePanelFrame()
       panel?.orderFrontRegardless()
       isVisible = true
   }
   ```
3. 修改 `updatePanelFrame()` 以直接围绕 `fixedCenter` 扩展：
   ```swift
   private func updatePanelFrame() {
       guard let panel = panel else { return }
       
       let targetFrame = NSRect(
           x: fixedCenter.x - diameter / 2,
           y: fixedCenter.y - diameter / 2,
           width: diameter,
           height: diameter + 20.0
       )
       
       panel.setFrame(targetFrame, display: true)
   }
   ```
4. 将辅助方法 `calculateBestFrame` 进行重构，以保持和测试套件计算的一致：
   ```swift
   static func calculateBestFrame(cursor: CGPoint, diameter: CGFloat, visibleFrame: NSRect) -> NSRect {
       let maxD: CGFloat = 300.0
       let centerOffset: CGFloat = 105.0 // 15 + 150 * 0.6
       
       let candidates: [CGPoint] = [
           CGPoint(x: cursor.x + centerOffset, y: cursor.y - centerOffset),
           CGPoint(x: cursor.x + centerOffset, y: cursor.y + centerOffset),
           CGPoint(x: cursor.x - centerOffset, y: cursor.y - centerOffset),
           CGPoint(x: cursor.x - centerOffset, y: cursor.y + centerOffset)
       ]
       
       var chosenCenter = candidates[0]
       var found = false
       for center in candidates {
           let rect = NSRect(
               x: center.x - maxD / 2,
               y: center.y - maxD / 2,
               width: maxD,
               height: maxD + 20.0
           )
           if visibleFrame.contains(rect) {
               chosenCenter = center
               found = true
               break
           }
       }
       
       if !found {
           let halfMaxD = maxD / 2
           let minX = visibleFrame.minX + halfMaxD
           let maxX = visibleFrame.maxX - halfMaxD
           let minY = visibleFrame.minY + halfMaxD
           let maxY = visibleFrame.maxY - (halfMaxD + 20.0)
           
           let clampedX = min(max(chosenCenter.x, minX), maxX)
           let clampedY = min(max(chosenCenter.y, minY), maxY)
           chosenCenter = CGPoint(x: clampedX, y: clampedY)
       }
       
       return NSRect(
           x: chosenCenter.x - diameter / 2,
           y: chosenCenter.y - diameter / 2,
           width: diameter,
           height: diameter + 20.0
       )
   }
   ```

- [ ] **步骤 2：运行测试验证通过**

运行：
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme PhantomKnobDetector -destination 'platform=macOS' -only-testing PhantomKnobDetectorTests/OverlayControllerTests
```
预期：测试成功（PASS）。

- [ ] **步骤 3：提交修改**

运行：
```bash
git add PhantomKnobDetector/Service/OverlayController.swift PhantomKnobDetector/PhantomKnobDetectorTests/OverlayControllerTests.swift
git commit -m "feat: fix overlay UI center during rotation gesture scale changes"
```
