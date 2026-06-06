# 圆型个性化触控旋钮 UI 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将全局旋钮 Overlay UI 重构为圆形、毛玻璃材质、去中心指针、外围刻度旋转跟随、尺寸比例自适应、动态碰撞规避以及由配置文件/规则库驱动的个性化颜色和样式。

**架构：**
1. **模型层**：在 `ControlRule` 和 `AppSettings` 中拓展 `themeColor` (十六进制)、`overlayStyle` (枚举) 和 `rotationStyle` (枚举) 字段。
2. **逻辑控制层**：在 `OverlayController` 中实现物理毫米半径到 UI 直径的公式换算 (`[80px, 400px]` Clamping)，并开发可见屏幕范围 (`NSScreen.visibleFrame`) 内基于右下 -> 右上 -> 左下 -> 左上优先级顺序的碰撞规避算法。
3. **渲染层**：在 `OverlayView` 中重构布局，用 `VisualEffectView` 实现圆形原生毛玻璃背景，并用 SwiftUI `Canvas` 实现 24 个刻度的整体旋转动画（`angle` 驱动），突出主刻度主题色，并在死区 `isDeadzone` 时渐变为灰色。

**技术栈：** Swift, SwiftUI, AppKit (NSPanel, NSVisualEffectView, NSScreen), XCTest

---

## 计划涉及文件清单

### 修改文件：
* [ControlRule.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Model/ControlRule.swift) - 拓展规则模型字段
* [AppSettings.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Model/AppSettings.swift) - 增加全局默认样式项
* [OverlayController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Service/OverlayController.swift) - 尺寸映射换算与边缘碰撞规避逻辑
* [OverlayView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/View/OverlayView.swift) - 重构为圆形 HUD，SwiftUI Canvas 绘制旋转刻度盘
* [KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Service/KnobStateManager.swift) - 触发时检索 Rule 样式并下发到 Overlay 实例

### 新建测试文件：
* [OverlayControllerTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/PhantomKnobDetectorTests/OverlayControllerTests.swift) - 测试避让计算和公式直径换算

---

## 详细任务步骤

### 任务 1：扩展配置与数据模型

**文件：**
- 修改：[ControlRule.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Model/ControlRule.swift:51-68)
- 修改：[AppSettings.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Model/AppSettings.swift:4-15)
- 测试：[ModelTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/PhantomKnobDetectorTests/ModelTests.swift)

- [ ] **步骤 1：在 ModelTests.swift 中编写用于解析新字段的测试用例**
  
  在 [ModelTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/PhantomKnobDetectorTests/ModelTests.swift) 中添加：
  ```swift
  func testControlRuleCustomStyleDecoding() throws {
      let json = """
      {
          "key": {
              "bundleID": "com.apple.FinalCut",
              "axRole": "AXSlider"
          },
          "translation": {
              "axWrite": {}
          },
          "scaleConfig": {
              "fixed": 1.5
          },
          "themeColor": "#0A84FF",
          "overlayStyle": "minimal",
          "rotationStyle": "cleanArc"
      }
      """.data(using: .utf8)!
      
      let rule = try JSONDecoder().decode(ControlRule.self, from: json)
      XCTAssertEqual(rule.themeColor, "#0A84FF")
      XCTAssertEqual(rule.overlayStyle, "minimal")
      XCTAssertEqual(rule.rotationStyle, "cleanArc")
  }
  ```

- [ ] **步骤 2：运行测试并验证失败**
  
  运行：
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnobDetector -project PhantomKnobDetector/PhantomKnobDetector.xcodeproj -destination 'platform=macOS' -only-testing PhantomKnobDetectorTests/ModelTests/testControlRuleCustomStyleDecoding test
  ```
  预期：FAIL (编译错误，`ControlRule` 没有 `themeColor` 等属性)

- [ ] **步骤 3：在 ControlRule.swift 和 AppSettings.swift 中增加新字段**
  
  在 [ControlRule.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Model/ControlRule.swift) 的 `ControlRule` 结构体中添加：
  ```swift
  var themeColor: String?
  var overlayStyle: String?
  var rotationStyle: String?
  ```
  更新其 `init` 初始化方法：
  ```swift
  init(key: RuleKey,
       translation: InputTranslation,
       scaleConfig: ScaleConfig = .fixed(1.0),
       themeColor: String? = nil,
       overlayStyle: String? = nil,
       rotationStyle: String? = nil,
       extra: [String: String]? = nil) {
      self.key = key
      self.translation = translation
      self.scaleConfig = scaleConfig
      self.themeColor = themeColor
      self.overlayStyle = overlayStyle
      self.rotationStyle = rotationStyle
      self.extra = extra
  }
  ```
  在 [AppSettings.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Model/AppSettings.swift) 的 `AppSettings` 结构体中添加默认样式选项：
  ```swift
  var defaultThemeColor: String = "#0A84FF"
  var defaultOverlayStyle: String = "hud"
  var defaultRotationStyle: String = "ticks"
  ```

- [ ] **步骤 4：运行测试验证通过**
  
  运行：
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnobDetector -project PhantomKnobDetector/PhantomKnobDetector.xcodeproj -destination 'platform=macOS' -only-testing PhantomKnobDetectorTests/ModelTests/testControlRuleCustomStyleDecoding test
  ```
  预期：PASS

- [ ] **步骤 5：Commit 变更**
  
  ```bash
  git add PhantomKnobDetector/Model/ControlRule.swift PhantomKnobDetector/Model/AppSettings.swift PhantomKnobDetectorTests/ModelTests.swift
  git commit -m "feat: extend ControlRule and AppSettings models for custom styles"
  ```

---

### 任务 2：编写 OverlayController 的尺寸计算与避让单元测试

**文件：**
- 新建：[OverlayControllerTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/PhantomKnobDetectorTests/OverlayControllerTests.swift)
- 修改：[OverlayController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Service/OverlayController.swift)

- [ ] **步骤 1：新建 OverlayControllerTests.swift 并编写测试避让与尺寸公式的用例**
  
  创建 [OverlayControllerTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/PhantomKnobDetectorTests/OverlayControllerTests.swift)：
  ```swift
  import XCTest
  @testable import PhantomKnobDetector

  class OverlayControllerTests: XCTestCase {
      
      // 测试半径公式换算及 Clamping [80, 400]
      func testDiameterCalculation() {
          let testCases: [(radius: Double, expectedDiameter: CGFloat)] = [
              (2.0, 80.0),   // 2mm * 2 * 10 = 40, clamped to 80
              (5.0, 100.0),  // 5mm * 2 * 10 = 100
              (15.0, 300.0), // 15mm * 2 * 10 = 300
              (30.0, 400.0)  // 30mm * 2 * 10 = 600, clamped to 400
          ]
          
          for tc in testCases {
              let calculated = OverlayController.calculateDiameter(for: tc.radius)
              XCTAssertEqual(calculated, tc.expectedDiameter, accuracy: 0.001)
          }
      }
      
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
          // 预期右下：x = 500 + 15 = 515, y = 500 - 15 - 100 = 385
          XCTAssertEqual(frame1.origin.x, 515)
          XCTAssertEqual(frame1.origin.y, 385)
          
          // Case 2: 鼠标在右下角 (950, 50)，右下、右上、左下均越界，应该使用左上
          let posBottomRight = CGPoint(x: 950, y: 50)
          let frame2 = OverlayController.calculateBestFrame(
              cursor: posBottomRight,
              diameter: diameter,
              visibleFrame: visibleFrame
          )
          // 预期左上：x = 950 - 15 - 100 = 835, y = 50 + 15 = 65
          XCTAssertEqual(frame2.origin.x, 835)
          XCTAssertEqual(frame2.origin.y, 65)
          
          // Case 3: 鼠标在左下角 (30, 30)，越界，夹紧在屏幕边界
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
  }
  ```

- [ ] **步骤 2：运行测试验证失败**
  
  运行：
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnobDetector -project PhantomKnobDetector/PhantomKnobDetector.xcodeproj -destination 'platform=macOS' -only-testing PhantomKnobDetectorTests/OverlayControllerTests test
  ```
  预期：FAIL (编译错误，`OverlayController` 没有 `calculateDiameter` 和 `calculateBestFrame` 方法)

- [ ] **步骤 3：在 OverlayController.swift 中实现计算静态方法**
  
  在 [OverlayController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Service/OverlayController.swift) 中添加：
  ```swift
  static func calculateDiameter(for radius: Double) -> CGFloat {
      let raw = CGFloat(radius * 2.0 * 10.0)
      return min(max(raw, 80.0), 400.0)
  }
  
  static func calculateBestFrame(cursor: CGPoint, diameter: CGFloat, visibleFrame: NSRect) -> NSRect {
      let offset: CGFloat = 15.0
      let w = diameter
      let h = diameter
      
      // 定义四个象限备选位置的 frame Origin
      let candidates: [CGPoint] = [
          // 1. 右下 (Bottom-Right)
          CGPoint(x: cursor.x + offset, y: cursor.y - offset - h),
          // 2. 右上 (Top-Right)
          CGPoint(x: cursor.x + offset, y: cursor.y + offset),
          // 3. 左下 (Bottom-Left)
          CGPoint(x: cursor.x - offset - w, y: cursor.y - offset - h),
          // 4. 左上 (Top-Left)
          CGPoint(x: cursor.x - offset - w, y: cursor.y + offset)
      ]
      
      for origin in candidates {
          let rect = NSRect(origin: origin, size: CGSize(width: w, height: h))
          if visibleFrame.contains(rect) {
              return rect
          }
      }
      
      // Fallback: 使用右下，并对其进行屏幕边缘夹紧 (Clamp)
      let rawOrigin = candidates[0]
      let clampedX = min(max(rawOrigin.x, visibleFrame.minX), visibleFrame.maxX - w)
      let clampedY = min(max(rawOrigin.y, visibleFrame.minY), visibleFrame.maxY - h)
      return NSRect(x: clampedX, y: clampedY, width: w, height: h)
  }
  ```

- [ ] **步骤 4：运行测试验证通过**
  
  运行：
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnobDetector -project PhantomKnobDetector/PhantomKnobDetector.xcodeproj -destination 'platform=macOS' -only-testing PhantomKnobDetectorTests/OverlayControllerTests test
  ```
  预期：PASS

- [ ] **步骤 5：将新建测试文件注册到 Xcode 目标**
  
  为确保 Xcode 识别新测试文件，建议运行 xcodegen（如果项目包含 `project.yml`），或者手动确认已成功编译。我们直接利用现有脚本重新构建或直接 commit。
  ```bash
  git add PhantomKnobDetectorTests/OverlayControllerTests.swift PhantomKnobDetector/Service/OverlayController.swift
  git commit -m "test: add OverlayController diameter and collision avoidance tests and static implementations"
  ```

---

### 任务 3：重构 OverlayController 以使用物理半径、自定义配置以及边缘避让

**文件：**
- 修改：[OverlayController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Service/OverlayController.swift)

- [ ] **步骤 1：增加属性并在 show/update 阶段集成尺寸及避让定位计算**
  
  修改 [OverlayController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Service/OverlayController.swift) 中的属性和方法：
  * **属性更新**：
    ```swift
    @Published var themeColor: String = "#0A84FF"
    @Published var overlayStyle: String = "hud"
    @Published var rotationStyle: String = "ticks"
    @Published var diameter: CGFloat = 160.0 // 默认值
    ```
  * **`show` 方法更新**：
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
        
        showCount += 1
        
        if panel == nil {
            createPanel()
        }
        
        panel?.animator().alphaValue = 1.0
        panel?.alphaValue = 1.0
        
        // 初始大小设定（由于 touchesBegan 时尚无半径数据，这里默认使用全局设定的直径，例如 160）
        self.diameter = 160.0
        updatePanelFrame()
        
        panel?.orderFrontRegardless()
        isVisible = true
    }
    ```
  * **`update` 方法更新**：
    ```swift
    func update(angle: Double, radius: Double, isDeadzone: Bool = false, scale: Double? = nil) {
        self.angle = angle
        self.isDeadzone = isDeadzone
        self.scale = scale
        
        // 核心改动：根据物理毫米半径实时更新 UI 直径
        self.diameter = Self.calculateDiameter(for: radius)
        
        updatePanelFrame()
        updateOverlayView()
    }
    ```
  * **面板更新与避让计算 `updatePanelFrame()`**：
    ```swift
    private func updatePanelFrame() {
        guard let panel = panel else { return }
        
        // 获取包含鼠标光标的可用屏幕
        let cursorPt = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first { $0.frame.contains(cursorPt) } ?? NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = activeScreen.visibleFrame
        
        // 转换鼠标坐标系为 AppKit 屏幕坐标系 (Y轴朝上)，避让算法直接在屏幕坐标系进行
        let targetFrame = Self.calculateBestFrame(
            cursor: cursorPt,
            diameter: diameter,
            visibleFrame: visibleFrame
        )
        
        panel.setFrame(targetFrame, display: true)
    }
    ```
  * **`createPanel` 与 `updateOverlayView` 实例化传参修改**：
    确保实例化 `OverlayView` 时传入全部配置项。

- [ ] **步骤 2：编译验证代码**
  
  编译验证 `OverlayController` 修改是否正常：
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnobDetector -project PhantomKnobDetector/PhantomKnobDetector.xcodeproj -destination 'generic/platform=macOS' build
  ```
  预期：FAIL（因为 `OverlayView` 和 `KnobStateManager` 相关的调用还没有修改，编译会报错）

---

### 任务 4：重构 OverlayView SwiftUI 视图

**文件：**
- 修改：[OverlayView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/View/OverlayView.swift)

- [ ] **步骤 1：重构 OverlayView 以支持圆形布局、毛玻璃特效和旋转刻度 Canvas**
  
  修改 [OverlayView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/View/OverlayView.swift) 完整实现：
  * **主题色解析 Color Helper**：
    ```swift
    extension Color {
        init(hex: String) {
            let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&int)
            let a, r, g, b: UInt64
            switch hex.count {
            case 3: // RGB (12-bit)
                (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
            case 6: // RGB (24-bit)
                (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
            case 8: // ARGB (32-bit)
                (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
            default:
                (a, r, g, b) = (255, 0, 113, 227) // 科技蓝 Fallback
            }
            self.init(
                .sRGB,
                red: Double(r) / 255,
                green: Double(g) / 255,
                blue: Double(b) / 255,
                opacity: Double(a) / 255
            )
        }
    }
    ```
  * **毛玻璃包装器 VisualEffectView**：
    ```swift
    struct VisualEffectView: NSViewRepresentable {
        var material: NSVisualEffectView.Material
        var blendingMode: NSVisualEffectView.BlendingMode
        
        func makeNSView(context: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.material = material
            view.blendingMode = blendingMode
            view.state = .active
            return view
        }
        
        func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
            nsView.material = material
            nsView.blendingMode = blendingMode
        }
    }
    ```
  * **`OverlayView` 结构体大修**：
    ```swift
    struct OverlayView: View {
        let targetName: String?
        let angle: Double
        var isDeadzone: Bool = false
        var scale: Double? = nil
        
        let themeColorHex: String
        let overlayStyle: String
        let rotationStyle: String
        let diameter: CGFloat
        
        var body: some View {
            let activeColor = Color(hex: themeColorHex)
            
            VStack(spacing: 8) {
                // 1. 名字悬浮正上方
                let titleText: String = {
                    let name = (targetName == nil || targetName!.isEmpty) ? "Knob" : targetName!
                    return name
                }()
                Text(titleText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isDeadzone ? .gray : .white)
                    .shadow(color: Color.black.opacity(0.6), radius: 2, x: 0, y: 1)
                
                // 2. 圆形 Overlay 容器
                ZStack {
                    // 圆形背景渲染
                    if overlayStyle == "hud" {
                        VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(isDeadzone ? Color.gray.opacity(0.3) : activeColor.opacity(0.4), lineWidth: 1.5)
                            )
                    } else if overlayStyle == "solid" {
                        Circle()
                            .fill(Color.black.opacity(0.85))
                            .overlay(
                                Circle()
                                    .stroke(isDeadzone ? Color.gray.opacity(0.5) : activeColor, lineWidth: 2)
                            )
                    } else {
                        // "minimal": 无背景，仅绘制虚线外圈
                        Circle()
                            .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4]))
                    }
                    
                    // 3. 外围旋转反馈 Canvas
                    Canvas { context, size in
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        let r = min(size.width, size.height) / 2 - 8
                        
                        // 应用手势旋转
                        context.rotate(by: Angle(degrees: angle))
                        
                        if rotationStyle == "ticks" {
                            let tickCount = 24
                            for i in 0..<tickCount {
                                let tickAngle = Double(i) * (2 * .pi) / Double(tickCount)
                                let isMain = (i == 0)
                                let startR = isMain ? (r - 8) : (r - 4)
                                
                                var path = Path()
                                path.move(to: CGPoint(
                                    x: center.x + CGFloat(startR * cos(tickAngle)),
                                    y: center.y + CGFloat(startR * sin(tickAngle))
                                ))
                                path.addLine(to: CGPoint(
                                    x: center.x + CGFloat(r * cos(tickAngle)),
                                    y: center.y + CGFloat(r * sin(tickAngle))
                                ))
                                
                                context.stroke(
                                    path,
                                    with: .color(isMain ? (isDeadzone ? .gray : activeColor) : Color.white.opacity(0.3)),
                                    lineWidth: isMain ? 2.0 : 1.0
                                )
                            }
                        } else if rotationStyle == "rimDot" {
                            // 边缘圆点反馈
                            let dotX = center.x + r * CGFloat(cos(0.0))
                            let dotY = center.y + r * CGFloat(sin(0.0))
                            
                            var path = Path()
                            path.addArc(center: CGPoint(x: dotX, y: dotY), radius: 4, startAngle: .zero, endAngle: Angle(degrees: 360), clockwise: false)
                            context.fill(path, with: .color(isDeadzone ? .gray : activeColor))
                        }
                    }
                    
                    // 4. 正中心倍数显示
                    if let scale = scale {
                        Text(String(format: "%.1fx", scale))
                            .font(.system(size: max(12, diameter * 0.22), weight: .black, design: .monospaced))
                            .foregroundColor(isDeadzone ? .gray : .white)
                            .shadow(color: Color.black.opacity(0.4), radius: 1, x: 0, y: 1)
                    }
                }
                .frame(width: diameter, height: diameter)
            }
            .padding(16)
        }
    }
    ```

- [ ] **步骤 2：Commit 变更**
  
  ```bash
  git add PhantomKnobDetector/View/OverlayView.swift
  git commit -m "feat: complete OverlayView circular glassmorphism & Canvas ticks rotation design"
  ```

---

### 任务 5：与 KnobStateManager 和原有代码对接并编译测试

**文件：**
- 修改：[KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Service/KnobStateManager.swift)
- 修改：[OverlayController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Service/OverlayController.swift) (update 实例化部分)

- [ ] **步骤 1：在 KnobStateManager 中检索匹配的 Rule 样式参数下发**
  
  在 [KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Service/KnobStateManager.swift) 中：
  * **在触发手势 show overlay 处**：
    找到调用 `overlayController.show(...)` 的地方，通过当前匹配到的 `ControlRule` 读取 `themeColor`、`overlayStyle`、`rotationStyle` 并下传：
    ```swift
    // 假设当前匹配的规则是 rule
    overlayController.show(
        at: cursorPosition,
        targetName: target.displayName,
        scale: currentScale,
        themeColor: rule?.themeColor,
        overlayStyle: rule?.overlayStyle,
        rotationStyle: rule?.rotationStyle
    )
    ```
  * **在手势更新 update overlay 处**：
    找到调用 `overlayController.update(...)` 的地方，将 `radius` 参数实时回传给 controller（由 controller 负责直径线性换算和位置微调）：
    ```swift
    overlayController.update(
        angle: currentAngle,
        radius: currentRadius, // 毫米单位的当前半径
        isDeadzone: isDeadzone,
        scale: currentScale
    )
    ```

- [ ] **步骤 2：对 OverlayController.swift 内部剩余的旧版 OverlayView() 构造传参进行适配修改**
  
  在 [OverlayController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Service/OverlayController.swift) 中，确保 `createPanel` 与 `updateOverlayView` 中使用重构后的新参数构造 `OverlayView`：
  ```swift
  OverlayView(
      targetName: targetName,
      angle: angle,
      isDeadzone: isDeadzone,
      scale: scale,
      themeColorHex: themeColor,
      overlayStyle: overlayStyle,
      rotationStyle: rotationStyle,
      diameter: diameter
  )
  ```

- [ ] **步骤 3：整体编译项目代码**
  
  运行：
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnobDetector -project PhantomKnobDetector/PhantomKnobDetector.xcodeproj -destination 'generic/platform=macOS' build
  ```
  预期：PASS (编译通过，没有任何错漏的变量签名)

- [ ] **步骤 4：运行全部单元测试确保没有 Regressions**
  
  运行：
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnobDetector -project PhantomKnobDetector/PhantomKnobDetector.xcodeproj -destination 'platform=macOS' test
  ```
  预期：PASS (全部 89 个测试，包括新建的 Overlay 尺寸与避让测试全部成功通过)

- [ ] **步骤 5：Commit 并完成分支合并**
  
  ```bash
  git add PhantomKnobDetector/Service/KnobStateManager.swift PhantomKnobDetector/Service/OverlayController.swift
  git commit -m "feat: integrate rules styling lookup in KnobStateManager and build successfully"
  ```
