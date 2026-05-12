# PhantomKnobDetector MVP 设计文档

**版本：** 1.0  
**日期：** 2025-05-12  
**作者：** Ben Wu

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
2. 监听窗口内的多点触摸事件
3. 检查 `NSTouch.normalizedPosition` 是否有效

**有效性判断：**
```swift
// normalizedPosition 必须满足：
// 1. 非 NaN
// 2. x, y 在 0.0 - 1.0 范围内
// 3. 双指位置均有有效值
```

**检测结果：**
- **支持** — 进入演示界面
- **不支持** — 显示结果详情，用户可导出报告

### 4.2 Knob 演示

**界面元素：**
- 旋钮图形（圆形）
- 当前数值显示
- 操作提示文本："在触控板上双指旋转"

**交互行为：**
1. 用户双指在触控板上旋转
2. 程序捕获触摸事件，计算旋转角度
3. 旋钮图形跟随旋转方向转动
4. 数值实时变化

**算法核心：**
```swift
// 移植自 Flutter 版本 calKnob()
func calKnob(_ points: [Int: CGPoint]) -> (KnobCore, Int, Int) {
    // 1. 找到距离最远的两个触点
    // 2. 计算中点作为旋钮中心
    // 3. 计算连线方向作为角度
    // 4. 返回旋钮状态
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
│   ├── SettingsView          - 设置页
│   └── Components            - 可复用 UI 组件
│       └── KnobCircleView    - 旋钮圆形视图
│
├── ViewModel（视图模型层）
│   ├── DetectionViewModel    - 检测流程状态管理
│   ├── DemoViewModel         - 演示页状态管理
│   └── SettingsViewModel     - 设置页状态管理
│
├── Model（模型层）
│   ├── KnobCore              - 旋钮几何模型（center, radius, angle）
│   ├── KnobState             - 旋钮状态（current, previous, deltaAngle）
│   ├── DetectionResult       - 检测结果模型
│   └── DetectionDetails      - 检测详情
│
├── Service（服务层）
│   ├── TouchpadEngine        - 触摸事件引擎
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
    let deviceModel: String
    let macOSVersion: String
    let details: DetectionDetails
    
    struct DetectionDetails: Codable {
        let normalizedPositionAvailable: Bool
        let samplePoints: [CGPoint]?  // 采样点（可选）
        let errorMessage: String?
    }
}
```

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
│        [ 返回设置 ]             │
│                                 │
└─────────────────────────────────┘
```

---

## 9. 存储与缓存

### 9.1 缓存策略

- **存储位置：** UserDefaults
- **缓存键：** `com.phantomknob.detectionResult`
- **有效期：** 永久（除非用户手动清除或重新检测）

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
4. 返回 KnobCore + 两个触点的 ID

**伪代码：**
```
func calKnob(points: Map<Int, CGPoint>) -> (KnobCore, Int, Int) {
    if points.count < 2 {
        return (KnobCore.invalid, 0, 0)
    }
    
    maxDist = 0
    fingerIdx1, fingerIdx2 = 0, 0
    
    for (id1, p1) in points {
        for (id2, p2) in points {
            if id1 == id2 { continue }
            dist = distance(p1, p2)
            if dist > maxDist {
                maxDist = dist
                fingerIdx1, fingerIdx2 = sorted(id1, id2)
            }
        }
    }
    
    knobVector = points[fingerIdx1] - points[fingerIdx2]
    center = midpoint(points[fingerIdx1], points[fingerIdx2])
    radius = maxDist / 2
    angle = atan2(knobVector.dy, knobVector.dx) * 180 / π
    
    return (KnobCore(center, radius, angle), fingerIdx1, fingerIdx2)
}
```

### 10.2 角度变化计算

```swift
// 计算角度变化量，处理角度跨越 ±180° 的情况
func calculateDeltaAngle(current: Double, previous: Double) -> Double {
    var delta = current - previous
    if delta > 180 { delta -= 360 }
    if delta < -180 { delta += 360 }
    return delta.clamped(to: -1...1)  // 限制单次变化量
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
