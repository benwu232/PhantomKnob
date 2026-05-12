# PhantomKnobDetector MVP 设计文档

**版本：** 1.1  
**日期：** 2025-05-12  
**作者：** Ben Wu  
**更新说明：** 基于 CONTEXT.md 审查，补充检测生命周期、数值映射、导航状态管理等细节

---

## 1. 概览

### 1.1 产品定位

PhantomKnobDetector 是一个独立的 macOS 应用，用于：
- 检测用户的触控板是否支持 knob 手势所需的绝对坐标
- 如果支持，提供演示界面验证手势效果

**当前阶段（MVP）：** 硬件兼容性验证器  
**未来方向：** 长期生产力工具，支持系统参数控制、跨应用控制

### 1.2 核心价值

- 让用户快速了解自己的触控板是否支持 knob 手势
- 为后续生产力工具开发奠定基础
- 降低技术支持成本（用户可自行检测并导出报告）

---

## 2. 扩展路线

### 2.1 三级扩展计划

| 级别 | 范围 | 功能 | 权限 |
|------|------|------|------|
| **MVP** | 单应用内检测 | 触控板能力检测 + 演示 | 无 |
| **Level 2** | 系统参数控制 | 音量、亮度等系统参数调节 | 基本系统访问 |
| **Level 3** | 跨应用控制 | 控制其他应用的 UI 组件 | 辅助功能权限 |

### 2.2 扩展优先级

**B > A > C**：
1. 先实现生产力功能（系统参数控制）
2. 再支持跨应用控制
3. 最后跨平台（Windows Precision Touchpad）

---

## 3. 核心流程

### 3.1 用户流程

```
App 启动
    ↓
检查缓存
    ↓
    ├─ 无缓存/过期 → 欢迎页：提示用户进行兼容性检测
    │                   ↓
    │               检测页：提示用户双指触摸触控板
    │                   ↓
    │               自动检测 normalizedPosition 是否有效
    │                   ↓
    │                   缓存结果
    │
    └─ 有缓存且通过 → 直接进入演示页

检测失败 → 结果页：显示"不支持" + 详情
检测通过 → 演示页：旋钮 + 数值 + 操作提示
```

### 3.2 后续启动

- 检测结果已缓存，可跳过检测
- 设置中提供"重新检测"选项

---

## 4. 功能规格

### 4.1 兼容性检测

**检测目标：** 触控板是否支持绝对坐标（`normalizedPosition`）

**检测方法：**
1. 提示用户双指触摸触控板
2. 监听窗口内的多点触摸事件（通过 NSViewRepresentable 包装的 NSView）
3. 检查 `NSTouch.normalizedPosition` 是否有效

**有效性判断：**
```swift
// normalizedPosition 必须满足：
// 1. 非 NaN
// 2. x, y 在 0.0 - 1.0 范围内
// 3. 双指位置均有有效值
```

**检测生命周期：**
- **超时**：30 秒，带视觉倒计时 → 超时后显示"检测超时，请重试"
- **确认机制**：需要 3 次连续有效的触摸事件（每次间隔 500ms 内）才能确认支持
- **取消操作**：检测页有"取消"按钮，返回欢迎页
- **手指抬起**：如果手指在采集到 3 个样本前抬起，保持在检测模式（不判定失败）

**检测结果：**
- **支持** — 自动进入演示界面（无需用户确认）
- **不支持** — 显示结果详情页，用户可导出报告或重新检测

### 4.2 Knob 演示

**界面元素：**
- 旋钮图形（简化设计：白色圆形 + 灰色边框 + 指示线）
- 当前数值显示
- 操作提示文本："在触控板上双指旋转"
- "重新检测"按钮（替代独立设置页）

**旋钮可视化（MVP 简化版）：**
- 白色圆形背景，灰色边框
- 单条指示线从中心向外，显示当前角度
- 指示线跟随手指旋转实时转动
- 不显示手指位置（避免视觉干扰）
- 无 3D 效果或阴影
- 数值在旋钮下方显示，使用系统大号字体

**交互行为：**
1. 用户双指在触控板上旋转
2. 程序捕获触摸事件，计算旋转角度
3. 旋钮图形跟随旋转方向转动
4. 数值实时变化

**数值控制规格（DemoSliderTarget）：**
- **范围**：0-100
- **初始值**：50（居中）
- **旋转方向**：顺时针 → 增加；逆时针 → 减少
- **灵敏度**：1° 旋转 → 0.5 数值变化（完整 360° ≈ 180 数值变化）
- **持久性**：手指抬起时数值保持（模拟物理旋钮）
- **Delta 限制**：每次更新限制在 ±1°（防止抖动导致跳跃）

**手势冲突处理：**
- **MVP 阶段**：所有双指手势都视为旋钮手势，不做区分
- **未来**：通过热键切换，或通过算法分析角度变化率/位置变化率来判断手势类型

**算法核心：**
```swift
// 移植自 Flutter 版本 calKnob()
func calKnob(_ points: [Int: CGPoint]) -> (KnobCore, Int, Int) {
    // 1. 找到距离最远的两个触点
    // 2. 计算中点作为旋钮中心
    // 3. 计算连线方向作为角度
    // 4. 返回旋钮状态 + 两个触点的 ID（用于跟踪）
}
```

---

## 5. 架构设计

### 5.1 架构模式：MVVM

本项目采用 **MVVM（Model-View-ViewModel）** 架构模式，这是 SwiftUI 应用的标准模式。

**MVVM 架构图：**

```
┌─────────────────────────────────────────────────────────────────┐
│                          View Layer                              │
│  ┌──────────┐  ┌──────────────┐  ┌──────────┐  ┌──────────┐    │
│  │WelcomeView│  │DetectionView │  │ResultView│  │ DemoView │    │
│  └────┬─────┘  └──────┬───────┘  └────┬─────┘  └────┬─────┘    │
│       │               │               │              │          │
│       │  @StateObject │               │              │          │
│       ▼               ▼               ▼              ▼          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 数据绑定（@Published）
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       ViewModel Layer                            │
│  ┌──────────────────┐  ┌──────────────────┐  ┌─────────────┐  │
│  │DetectionViewModel│  │   DemoViewModel  │  │SettingsVM   │  │
│  │  - detectionState│  │  - knobAngle     │  │ - cache     │  │
│  │  - isDetecting   │  │  - displayValue  │  │             │  │
│  │  + startDetect() │  │  + handleTouches │  │ + reDetect()│  │
│  └────────┬─────────┘  └────────┬─────────┘  └──────┬──────┘  │
│           │                     │                    │         │
└───────────┼─────────────────────┼────────────────────┼─────────┘
            │                     │                    │
            ▼                     ▼                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                          Model Layer                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │   KnobCore   │  │DetectionResult│  │TouchpadEngine/KnobAlg│ │
│  │ - center     │  │ - isSupported │  │ (业务逻辑服务)        │ │
│  │ - radius     │  │ - timestamp   │  │                      │ │
│  │ - angle      │  │ - details     │  │                      │ │
│  └──────────────┘  └──────────────┘  └──────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

**为什么选择 MVVM：**

| 特点 | 说明 |
|------|------|
| SwiftUI 天然搭配 | `@ObservableObject` + `@Published` 实现自动数据绑定 |
| 可测试性 | ViewModel 独立于 View，易于单元测试 |
| 状态管理清晰 | 所有 UI 状态集中在 ViewModel，避免分散 |
| 易于扩展 | 添加新功能只需添加对应的 ViewModel |

### 5.2 模块划分

```
PhantomKnobDetector.app
│
├── View（视图层 - SwiftUI）
│   ├── WelcomeView           - 欢迎页
│   ├── DetectionView         - 检测页
│   ├── ResultView            - 结果页
│   ├── DemoView              - 演示页
│   └── Components            - 可复用 UI 组件
│       ├── KnobCircleView    - 旋钮圆形视图
│       └── TouchpadView      - NSViewRepresentable 包装（捕获触摸事件）
│
├── ViewModel（视图模型层）
│   ├── AppViewModel          - 全局状态管理（导航、检测结果）
│   ├── DetectionViewModel    - 检测流程状态管理
│   └── DemoViewModel         - 演示页状态管理
│
├── Model（模型层）
│   ├── KnobCore              - 旋钮几何模型（center, radius, angle）
│   ├── KnobState             - 旋钮状态（current, previous, deltaAngle）
│   ├── DetectionResult       - 检测结果模型
│   └── DetectionDetails      - 检测详情
│
├── Service（服务层）
│   ├── TouchpadEngine        - 触摸事件引擎（通过 delegate 转发事件）
│   ├── KnobAlgorithm         - calKnob() 算法
│   ├── TouchpadDetector      - 触控板能力检测
│   └── PermissionManager     - 权限管理（预留）
│
├── Control（控制层 - 可扩展）
│   ├── ControlTarget         - 控制目标协议
│   └── DemoSliderTarget      - MVP：控制演示数值
│   │
│   未来扩展：
│   ├── SystemVolumeTarget     - Level 2：系统音量
│   ├── SystemBrightnessTarget - Level 2：系统亮度
│   └── ExternalAppTarget      - Level 3：跨应用控制
│
└── Storage（存储层）
    └── DetectionCache        - UserDefaults 封装
```

**注意：MVP 阶段不包含独立设置页。演示页直接提供"重新检测"按钮。**

### 5.3 MVVM 角色对照

| 模块 | MVVM 角色 | 职责 |
|------|-----------|------|
| **View** | View | 纯展示，无业务逻辑，通过 `@StateObject` 持有 ViewModel |
| **ViewModel** | ViewModel | 业务逻辑，管理 `@Published` 状态，响应 View 事件 |
| **Model + Service** | Model | 数据结构 + 业务逻辑服务 |
| **Control** | - | 控制目标抽象，被 ViewModel 调用 |

### 5.4 典型示例：DemoViewModel

```swift
// MARK: - Model（纯数据）
struct KnobCore {
    let center: CGPoint
    let radius: Double
    let angle: Double
    var isValid: Bool { radius > 0 }
}

// MARK: - ViewModel（状态 + 业务逻辑）
class DemoViewModel: ObservableObject {
    // @Published 属性：View 自动响应变化
    @Published var knobAngle: Double = 0
    @Published var displayValue: Double = 50.0
    @Published var isActive: Bool = false
    
    private let touchpadEngine = TouchpadEngine()
    private let knobAlgorithm = KnobAlgorithm()
    private var controlTarget: ControlTarget
    
    init() {
        self.controlTarget = DemoSliderTarget()
        touchpadEngine.delegate = self
    }
    
    // 业务逻辑：处理触摸移动
    func handleTouchesMoved(_ touches: Set<NSTouch>) {
        let state = knobAlgorithm.process(touches)
        knobAngle = state.current.angle
        displayValue = controlTarget.applyDelta(state.deltaAngle)
        isActive = true
    }
}

// MARK: - View（纯展示）
struct DemoView: View {
    @StateObject var viewModel = DemoViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("✅ 支持检测通过")
                .font(.headline)
            
            // 旋钮图形 - 绑定 ViewModel 状态
            KnobCircleView(angle: viewModel.knobAngle)
                .frame(width: 100, height: 100)
            
            // 数值显示
            Text("\(viewModel.displayValue, specifier: "%.1f")")
                .font(.largeTitle)
            
            Text("在触控板上双指旋转以调整数值")
                .font(.caption)
        }
    }
}
```

### 5.5 关键接口

#### AppViewModel（导航状态管理）

```swift
enum AppScreen {
    case welcome
    case detection
    case result(DetectionResult)
    case demo
}

class AppViewModel: ObservableObject {
    @Published var currentScreen: AppScreen = .welcome
    @Published var detectionResult: DetectionResult?
    
    // 检查缓存，决定初始屏幕
    init(cache: DetectionCache) { ... }
    
    // 导航方法
    func startDetection() { currentScreen = .detection }
    func completeDetection(_ result: DetectionResult) {
        detectionResult = result
        currentScreen = result.isSupported ? .demo : .result(result)
    }
    func reset() { currentScreen = .welcome }
}
```

#### TouchpadEngine

```swift
protocol TouchpadEventDelegate: AnyObject {
    func onTouchesBegan(_ touches: Set<NSTouch>)
    func onTouchesMoved(_ touches: Set<NSTouch>)
    func onTouchesEnded(_ touches: Set<NSTouch>)
}

class TouchpadEngine {
    weak var delegate: TouchpadEventDelegate?
    
    // MVP: 窗口内触摸
    // 未来: 可切换为全局监听
}
```

**SwiftUI 集成方式：**

由于 SwiftUI 无法直接接收触摸事件，需要通过 `NSViewRepresentable` 包装 `NSView`：

```swift
// TouchpadView: NSView 子类，捕获触摸事件
class TouchpadView: NSView {
    weak var touchDelegate: TouchpadEventDelegate?
    
    override func touchesBegan(with event: NSEvent) {
        touchDelegate?.onTouchesBegan(event.touches(matching: .touching, in: self))
    }
    // ... touchesMoved, touchesEnded
}

// TouchpadViewWrapper: SwiftUI 包装器
struct TouchpadViewWrapper: NSViewRepresentable {
    let delegate: TouchpadEventDelegate
    
    func makeNSView(context: Context) -> TouchpadView {
        let view = TouchpadView()
        view.touchDelegate = delegate
        view.wantsRestingTouches = true  // 持续接收触摸
        return view
    }
}
```

#### ControlTarget

```swift
protocol ControlTarget {
    var value: Double { get set }
    var minValue: Double { get }
    var maxValue: Double { get }
    var displayName: String { get }
    
    func applyDelta(_ delta: Double) -> Double
}
```

#### KnobCore

```swift
struct KnobCore {
    let center: CGPoint
    let radius: Double
    let angle: Double  // 角度（度）
    
    var isValid: Bool { radius > 0 }
}
```

### 5.6 扩展点设计

| 模块 | MVP 实现 | 未来扩展点 |
|------|----------|-----------|
| TouchpadEngine | 窗口内触摸（NSView.touches*） | 全局监听（NSEvent.addGlobalMonitor） |
| ControlTarget | DemoSliderTarget | 插件式添加新目标 |
| PermissionManager | 无权限需求 | 辅助功能授权流程 |

---

## 6. 技术选型

| 层面 | 选择 | 理由 |
|------|------|------|
| 语言 | Swift | macOS 原生开发首选 |
| UI 框架 | SwiftUI | 现代、声明式、快速开发 |
| 触摸事件 | NSView + touchesBegan/moved/ended | 窗口内触摸的标准方式 |
| 算法 | 移植 Flutter 版 calKnob() | 已验证可行 |
| 存储 | UserDefaults | 轻量级缓存 |

---

## 7. 数据模型

### 7.1 DetectionResult

```swift
struct DetectionResult: Codable {
    let isSupported: Bool
    let timestamp: Date
    let deviceModel: String      // 硬件标识，如 "MacBookPro18,3"
    let macOSVersion: String
    let details: DetectionDetails
    
    struct DetectionDetails: Codable {
        let normalizedPositionAvailable: Bool
        let sampleCount: Int           // 采集的触摸事件数量
        let errorMessage: String?     // 本地化的失败原因（跟随系统语言）
    }
}
```

**字段说明：**
- `deviceModel`：通过 `sysctl` 或 `ioreg` 获取硬件标识
- `errorMessage`：面向用户的中文描述（如"无法获取触摸绝对坐标"），根据系统语言本地化
- **已移除 `samplePoints`**：无明确用途，增加存储体积

### 7.2 KnobState

```swift
struct KnobState {
    let current: KnobCore
    let previous: KnobCore
    let deltaAngle: Double  // 角度变化量
    
    var rotationDirection: RotationDirection {
        if deltaAngle > 0 { return .clockwise }
        else if deltaAngle < 0 { return .counterClockwise }
        else { return .none }
    }
}

enum RotationDirection {
    case clockwise
    case counterClockwise
    case none
}
```

---

## 8. 界面规格

### 8.1 欢迎页（WelcomeView）

```
┌─────────────────────────────────┐
│                                 │
│      PhantomKnobDetector        │
│                                 │
│   检测您的触控板是否支持         │
│   Knob 手势操作                  │
│                                 │
│      [ 开始检测 ]               │
│                                 │
└─────────────────────────────────┘
```

### 8.2 检测页（DetectionView）

```
┌─────────────────────────────────┐
│                                 │
│         正在检测...             │
│                                 │
│   请在触控板上双指触摸           │
│                                 │
│      ⚪ 等待触摸...             │
│                                 │
└─────────────────────────────────┘
```

### 8.3 结果页 - 不支持（ResultView）

```
┌─────────────────────────────────┐
│                                 │
│         ❌ 不支持               │
│                                 │
│   您的触控板不支持 Knob 手势     │
│                                 │
│   详情：                         │
│   - 设备：MacBook Pro (2020)    │
│   - 系统：macOS 14.0            │
│   - 原因：无法获取触摸绝对坐标   │
│                                 │
│   [ 导出报告 ]  [ 重新检测 ]    │
│                                 │
└─────────────────────────────────┘
```

### 8.4 演示页（DemoView）

```
┌─────────────────────────────────┐
│                                 │
│         ✅ 支持检测通过          │
│                                 │
│           ⚪                    │
│          ╱ ╲                   │
│           │                    │
│          42.5                   │
│                                 │
│   在触控板上双指旋转以调整数值   │
│                                 │
│        [ 重新检测 ]             │
│                                 │
└─────────────────────────────────┘
```

**旋钮可视化说明：**
- 白色圆形背景（约 100x100 pt）
- 灰色边框
- 单条指示线从中心向外，显示当前角度
- 数值在旋钮下方显示，使用 `.largeTitle` 字体

---

## 9. 存储与缓存

### 9.1 缓存策略

- **存储位置：** UserDefaults
- **缓存键：** `com.phantomknob.detectionResult`
- **有效期：** 永久（除非用户手动触发"重新检测"）

**硬件变更处理：**
- 缓存**不跟踪**硬件变更
- 用户更换触控板后，需手动触发"重新检测"
- 未来版本可通过菜单栏图标访问检测功能

### 9.2 报告导出（可选）

用户可选择导出详细报告：
- `compatibility_report.json` — 结构化检测结果
- `detection_summary.txt` — 人类可读摘要

---

## 10. 算法移植

### 10.1 calKnob() 核心逻辑

**来源：** Flutter 版本 `/Users/wb/work/phantom_knob/lib/src/knob.dart`

**步骤：**
1. 从多点触摸中找到距离最远的两个点
2. 计算这两点的中点作为旋钮中心
3. 计算两点连线的方向作为角度
4. 返回 KnobCore + 两个触点的 ID（用于跟踪哪两个手指是"旋钮"）

**角度坐标系：**
- 使用 macOS 原生坐标系（Y 轴向上为正）
- 0° 指向右方（+X 方向）
- 逆时针旋转为正方向
- 公式：`angle = atan2(dy, dx) * 180 / π`

**伪代码：**
```swift
func calKnob(_ points: [Int: CGPoint]) -> (KnobCore, Int, Int) {
    if points.count < 2 {
        return (KnobCore.invalid, 0, 0)
    }
    
    var maxDist: CGFloat = 0
    var fingerIdx1 = 0, fingerIdx2 = 0
    
    for (id1, p1) in points {
        for (id2, p2) in points {
            if id1 == id2 { continue }
            let dist = distance(p1, p2)
            if dist > maxDist {
                maxDist = dist
                fingerIdx1 = min(id1, id2)
                fingerIdx2 = max(id1, id2)
            }
        }
    }
    
    let knobVector = points[fingerIdx1]! - points[fingerIdx2]!
    let center = midpoint(points[fingerIdx1]!, points[fingerIdx2]!)
    let radius = maxDist / 2
    let angle = atan2(knobVector.dy, knobVector.dx) * 180 / .pi
    
    return (KnobCore(center: center, radius: radius, angle: angle), fingerIdx1, fingerIdx2)
}
```

### 10.2 角度变化计算

```swift
// 计算角度变化量，处理角度跨越 ±180° 的情况
func calculateDeltaAngle(current: Double, previous: Double) -> Double {
    var delta = current - previous
    if delta > 180 { delta -= 360 }
    if delta < -180 { delta += 360 }
    return delta.clamped(to: -1...1)  // 限制单次变化量为 ±1°
}
```

### 10.3 数值更新公式

```swift
// DemoSliderTarget 的数值更新
func applyDelta(_ deltaAngle: Double) -> Double {
    let sensitivity: Double = 0.5  // 1° → 0.5 数值变化
    let newValue = value + deltaAngle * sensitivity
    value = newValue.clamped(to: minValue...maxValue)
    return value
}
```

---

## 11. 验收标准

### 11.1 功能验收

- [ ] 检测流程完整：欢迎页 → 检测页 → 结果页/演示页
- [ ] 双指触摸时能正确识别 `normalizedPosition`
- [ ] 检测结果正确缓存，后续启动可跳过
- [ ] 演示页旋钮能跟随手指旋转实时变化
- [ ] 数值显示正确同步

### 11.2 性能验收

- [ ] 触摸响应延迟 < 20ms
- [ ] UI 更新流畅，无明显卡顿
- [ ] 内存占用 < 50MB

### 11.3 兼容性验收

- [ ] macOS 12+ 运行正常
- [ ] 不同 MacBook 型号测试（Intel / Apple Silicon）
- [ ] Magic Trackpad 外接触控板（可选）

---

## 12. 开发计划

### 12.1 MVP 开发阶段

| 阶段 | 内容 | 预估时间 |
|------|------|----------|
| 1 | 项目搭建、Core 层实现 | 2-3 天 |
| 2 | Detection 模块 + UI | 2-3 天 |
| 3 | Control 模块 + Demo UI | 2-3 天 |
| 4 | 测试与优化 | 1-2 天 |

**总计：约 1-2 周**

---

## 13. 后续规划

### 13.1 Level 2：系统参数控制

- 通过公有 API 控制系统音量/亮度
- 预估时间：+2 周

### 13.2 Level 3：跨应用控制

- 通过 Accessibility API 控制其他应用
- 需要辅助功能权限
- 预估时间：+3 周

---

## 附录

### A. 参考资料

- Flutter 源码：`/Users/wb/work/phantom_knob`
- Apple 文档：[NSTouch Class Reference](https://developer.apple.com/documentation/appkit/nstouch)
- Apple 文档：[Handling Multi-Touch Events](https://developer.apple.com/documentation/appkit/nsview/1483700-touchesbegan)

### B. 术语表

| 术语 | 定义 |
|------|------|
| normalizedPosition | NSTouch 属性，归一化的触摸坐标（0.0-1.0） |
| Knob 手势 | 双指旋转手势，模拟物理旋钮操作 |
| calKnob() | 核心算法，从双指位置计算旋钮状态 |
| ControlTarget | 控制目标协议，抽象可被 knob 控制的对象 |
| DemoSliderTarget | MVP 阶段的 ControlTarget 实现，控制 0-100 的演示数值 |
| TouchpadView | NSView 子类，捕获触摸事件并通过 delegate 转发 |
| AppViewModel | 全局状态管理器，负责屏幕导航和检测结果持有 |

### C. 设计决策记录

本节记录了规格审查过程中澄清的关键决策：

| 决策项 | 决定内容 |
|--------|----------|
| 检测确认机制 | 需 3 次连续有效触摸事件确认支持 |
| 检测超时 | 30 秒，带视觉倒计时 |
| 缓存有效期 | 永久，不跟踪硬件变更 |
| 角度坐标系 | macOS 原生坐标系，0° 向右，逆时针为正 |
| 数值灵敏度 | 1° → 0.5 数值变化，顺时针增加 |
| 手势冲突处理 | MVP 不区分，未来用热键或算法判断 |
| 导航方式 | AppViewModel 统一管理，检测成功自动跳转 |
| 设置页面 | MVP 不需要独立设置页，演示页提供重新检测按钮 |
| 旋钮可视化 | 简化设计：圆形 + 指示线，无 3D 效果 |
| SwiftUI 集成 | NSViewRepresentable 包装 NSView 捕获触摸 |
