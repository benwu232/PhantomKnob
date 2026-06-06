# 设计文档：圆型个性化触控旋钮 UI 设计方案 (Data-Driven Circular Overlay HUD)

本设计文档规划了“将 macOS 全局旋钮 Overlay UI 重构为圆形、毛玻璃材质、去中心指针、外围刻度旋转跟随、尺寸比例自适应、动态碰撞规避以及数据/配置驱动的个性化色彩样式”的最终方案。

## 目标描述

为了大幅提升 PhantomKnob 的视觉档次，打造极具科技感与系统原生高级感的交互界面，我们需要对现有的 `OverlayView` 和 `OverlayController` 进行重构：
1. **圆形毛玻璃材质 (Circular Glassmorphism)**：去掉原有的方形圆角背景，整体改用圆形。底色使用 macOS 原生的毛玻璃材质 (`NSVisualEffectView`)，保留磨砂半透质感，对下方内容遮挡降至最低。
2. **中心无指针设计 (Pointer-Free Center)**：移除原有的穿过圆心的指针线条，保证倍数文本（如 `3.0x`）100% 毫无遮挡地呈现在圆心正中。
3. **刻度盘旋转跟随 (Rotating Ticks)**：在外边缘绘制一圈精细的径向刻度线，整圈刻度线随两指拧动角度（`angle`）同步转动，保留极强的物理旋转反馈。
4. **悬浮信息布局**：名字（如 Volume、Timeline Zoom 等）悬浮展示在圆形 Overlay 正上方；倍数（如 `3.0x`）显示在圆形正中心；暂不显示具体调节数值（在未来有需要时再开启）。
5. **尺寸物理关联**：Overlay 直径直接与两指物理间距线性对应（两指物理间距每 1mm 对应 UI 直径 10px），并提供合理的最大/最小尺寸保护夹紧 (`[80px, 400px]`)。
6. **碰撞避让与象限排序**：默认偏好位置为右下角，并提供边缘碰撞自动避让（避让象限匹配顺序：右下 -> 右上 -> 左下 -> 左上）。
7. **数据与配置驱动样式 (Dimension A)**：
   * 旋钮的**颜色**与名字（控制目标）绑定。可在 `rules.json` 规则中为不同目标配颜色（如音量为绿色，时间轴为蓝色，默认使用科技蓝）。
   * 样式（`hud`、`minimal`、`solid`）和旋转反馈类型（`ticks`、`rimDot` 等）均可配置。

---

## 详细设计

### 1. 配置模型扩展
在 `ControlRule` 模型（[ControlRule.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Model/ControlRule.swift)）中新增以下可选配置字段以支持个性化样式：
```swift
struct ControlRule: Codable {
    let key: RuleKey
    let translation: InputTranslation
    let scaleConfig: ScaleConfig
    var extra: [String: String]?
    
    // 新增样式自定义字段 (自适应兼容历史配置)
    var themeColor: String?     // 十六进制颜色字符串，例如 "#34C759"
    var overlayStyle: String?   // "hud" | "minimal" | "solid"
    var rotationStyle: String?  // "ticks" | "rimDot" | "cleanArc"
}
```
并在 `AppSettings` 中提供默认全局值：
```swift
var defaultThemeColor: String = "#0A84FF" // 科技蓝
var defaultOverlayStyle: String = "hud"
var defaultRotationStyle: String = "ticks"
```

---

### 2. OverlayController 尺寸映射与避让算法

#### 2.1 物理尺寸线性映射：
`OverlayController` 在手势开始及更新时，接收 `KnobCore.radius`（单位：毫米）。
```swift
// radius 是两指中心到手指的距离（maxDist / 2），因此两指距离（直径）为 radius * 2
let physicalDistanceMM = radius * 2
let targetDiameter = physicalDistanceMM * 10
// 夹紧范围：最小直径 80px (两指 8mm)，最大直径 400px (两指 40mm)
let diameter = min(max(targetDiameter, 80.0), 400.0)
```

#### 2.2 避让象限排序算法：
对于给定的鼠标位置 $(X_{mouse}, Y_{mouse})$ 和直径 $D$，可用显示范围为当前屏幕的 `visibleFrame`。按以下顺序匹配：
1. **右下 (Bottom-Right)**: `x = X_mouse + 15`, `y = Y_mouse - 15 - D`
2. **右上 (Top-Right)**: `x = X_mouse + 15`, `y = Y_mouse + 15`
3. **左下 (Bottom-Left)**: `x = X_mouse - 15 - D`, `y = Y_mouse - 15 - D`
4. **左上 (Top-Left)**: `x = X_mouse - 15 - D`, `y = Y_mouse + 15`

若 4 个象限均发生截断越界，强制将 Overlay 放置在右下位置，并对其 `x, y` 坐标在 `visibleFrame` 范围内进行 `clamp`，使其贴紧屏幕边缘。

---

### 3. SwiftUI 视图重构 (OverlayView)

#### 3.1 原生毛玻璃背景组件：
提供一个 `NSVisualEffectView` 包装器类，以呈现 native 毛玻璃特效：
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

#### 3.2 刻度盘绘制与旋转跟随逻辑 (方案 B)：
在 ZStack 容器边缘，利用 Canvas 绘制一圈旋转的刻度。一个主刻度（位于 `0°` 处）呈高亮的主题色，其余刻度呈暗白色。
```swift
Canvas { context, size in
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let radius = min(size.width, size.height) / 2 - 8
    
    // 应用手势旋转角度（转为弧度）
    context.rotate(by: Angle(degrees: angle))
    
    let tickCount = 24
    for i in 0..<tickCount {
        let tickAngle = Double(i) * (2 * .pi) / Double(tickCount)
        let isMainNotch = (i == 0) // 主指向标刻度
        
        let startRadius = isMainNotch ? (radius - 8) : (radius - 4)
        
        var path = Path()
        path.move(to: CGPoint(
            x: center.x + CGFloat(startRadius * cos(tickAngle)),
            y: center.y + CGFloat(startRadius * sin(tickAngle))
        ))
        path.addLine(to: CGPoint(
            x: center.x + CGFloat(radius * cos(tickAngle)),
            y: center.y + CGFloat(radius * sin(tickAngle))
        ))
        
        context.stroke(
            path,
            with: .color(isMainNotch ? (isDeadzone ? .gray : themeColor) : Color.white.opacity(0.3)),
            lineWidth: isMainNotch ? 2.0 : 1.0
        )
    }
}
```

---

## 验证方案

### 自动化单元测试
在 `OverlayControllerTests` / `ModelTests` 中：
1. **验证公式换算**：提供不同毫米手势半径，断言得到的 UI 直径是否正确（包含 Clamping 校验）。
2. **验证边缘碰撞逻辑**：模拟鼠标指针在屏幕四角（如 `(0,0)`, `(1920, 1080)`），检查计算出的 Frame 坐标是否完全包含在可视区域内，且顺序逻辑正确。
3. **验证配置解析**：读入包含自定义 `themeColor` 和 `overlayStyle` 的 json 配置，验证反序列化后字段是否正确读取。

### 手动验证
1. 打开浏览器模拟器，拖动各项 Slider 调节参数，观察刻度旋转反馈和圆形毛玻璃的外观。
2. 触发旋转手势控制音量，刻度应呈绿色（自定义音量配色）并整体旋转。
3. 将鼠标移动至屏幕极右下角、右上角等极限边缘进行手势，验证 Overlay 是否完美平移躲避，未出现显示截断。
