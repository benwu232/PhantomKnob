# PhantomKnobDetector MVP 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 构建一个 macOS 原生应用,检测触控板是否支持 Knob 手势所需的绝对坐标,并提供演示界面验证手势效果。

**架构：** 采用 MVVM 架构模式。Model 层包含 KnobCore、DetectionResult 等数据模型;ViewModel 层管理应用状态和业务逻辑;View 层使用 SwiftUI 构建界面;Service 层处理触摸事件和算法计算;Control 层提供可扩展的控制目标抽象。

**技术栈：** Swift 5.9+, SwiftUI, AppKit (NSView/NSViewRepresentable), UserDefaults

---

## 文件结构总览

```
PhantomKnobDetector/
├── App/
│   └── PhantomKnobDetectorApp.swift          - 应用入口
│
├── Model/
│   ├── KnobCore.swift                         - 旋钮几何模型
│   ├── KnobState.swift                        - 旋钮状态(当前/前一/变化量)
│   ├── DetectionResult.swift                  - 检测结果模型
│   └── RotationDirection.swift                - 旋转方向枚举
│
├── ViewModel/
│   ├── AppViewModel.swift                     - 全局导航状态
│   ├── DetectionViewModel.swift               - 检测流程状态
│   └── DemoViewModel.swift                    - 演示页状态
│
├── View/
│   ├── WelcomeView.swift                      - 欢迎页
│   ├── DetectionView.swift                    - 检测页
│   ├── ResultView.swift                       - 结果页
│   ├── DemoView.swift                         - 演示页
│   └── Components/
│       ├── KnobCircleView.swift               - 旋钮圆形视图
│       └── TouchpadView.swift                 - NSViewRepresentable 触摸捕获
│
├── Service/
│   ├── TouchpadEngine.swift                   - 触摸事件引擎
│   ├── KnobAlgorithm.swift                    - calKnob() 算法
│   └── TouchpadDetector.swift                 - 触控板能力检测
│
├── Control/
│   ├── ControlTarget.swift                    - 控制目标协议
│   └── DemoSliderTarget.swift                 - MVP: 演示数值控制
│
└── Storage/
    └── DetectionCache.swift                   - UserDefaults 封装
```

---

## TODOs

### 任务 1：创建 Xcode 项目和基础配置

**文件：**
- 创建：`PhantomKnobDetector.xcodeproj`
- 创建：`PhantomKnobDetector/App/PhantomKnobDetectorApp.swift`

- [ ] **步骤 1：创建 Xcode 项目**

使用 Xcode 创建 macOS App 项目:
```bash
# 在项目根目录执行
mkdir -p PhantomKnobDetector
cd PhantomKnobDetector
# 通过 Xcode GUI 创建:
# 1. File → New → Project
# 2. macOS → App
# 3. Product Name: PhantomKnobDetector
# 4. Interface: SwiftUI
# 5. Language: Swift
# 6. 保存到: /Users/wb/work/phantom_knob_mac/PhantomKnobDetector
```

- [ ] **步骤 2：配置项目信息**

修改 `PhantomKnobDetectorApp.swift`:
```swift
import SwiftUI

@main
struct PhantomKnobDetectorApp: App {
    @StateObject private var appViewModel = AppViewModel(cache: DetectionCache())
    
    var body: some Scene {
        WindowGroup {
            switch appViewModel.currentScreen {
            case .welcome:
                WelcomeView()
                    .environmentObject(appViewModel)
            case .detection:
                DetectionView()
                    .environmentObject(appViewModel)
            case .result(let result):
                ResultView(result: result)
                    .environmentObject(appViewModel)
            case .demo:
                DemoView()
                    .environmentObject(appViewModel)
            }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .defaultSize(width: 500, height: 400)
    }
}
```

- [ ] **步骤 3：提交基础项目**

```bash
cd /Users/wb/work/phantom_knob_mac
git add PhantomKnobDetector/
git commit -m "chore: 初始化 Xcode 项目"
```

---

### 任务 2：实现 Model 层基础数据结构

**文件：**
- 创建：`PhantomKnobDetector/Model/RotationDirection.swift`
- 创建：`PhantomKnobDetector/Model/KnobCore.swift`
- 创建：`PhantomKnobDetector/Model/KnobState.swift`
- 创建：`PhantomKnobDetector/Model/DetectionResult.swift`

- [ ] **步骤 1：创建 RotationDirection 枚举**

```swift
// PhantomKnobDetector/Model/RotationDirection.swift
import Foundation

enum RotationDirection {
    case clockwise
    case counterClockwise
    case none
}
```

- [ ] **步骤 2：创建 KnobCore 模型**

```swift
// PhantomKnobDetector/Model/KnobCore.swift
import Foundation
import CoreGraphics

struct KnobCore {
    let center: CGPoint
    let radius: Double
    let angle: Double  // 角度(度)
    
    init(center: CGPoint = .zero, radius: Double = 0, angle: Double = 0) {
        self.center = center
        self.radius = radius
        self.angle = angle
    }
    
    var isValid: Bool { radius > 0 }
    
    static let invalid = KnobCore(center: .zero, radius: 0, angle: 0)
}
```

- [ ] **步骤 3：创建 KnobState 模型**

```swift
// PhantomKnobDetector/Model/KnobState.swift
import Foundation

struct KnobState {
    let current: KnobCore
    let previous: KnobCore
    let deltaAngle: Double
    
    init(current: KnobCore = .invalid, previous: KnobCore = .invalid) {
        self.current = current
        self.previous = previous
        
        // 计算角度变化量,处理跨越 ±180° 的情况
        var delta = current.angle - previous.angle
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        self.deltaAngle = delta.clamped(to: -1...1)  // 限制单次变化量为 ±1°
    }
    
    var rotationDirection: RotationDirection {
        if deltaAngle > 0 { return .clockwise }
        else if deltaAngle < 0 { return .counterClockwise }
        else { return .none }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
```

- [ ] **步骤 4：创建 DetectionResult 模型**

```swift
// PhantomKnobDetector/Model/DetectionResult.swift
import Foundation

struct DetectionResult: Codable {
    let isSupported: Bool
    let timestamp: Date
    let deviceModel: String
    let macOSVersion: String
    let details: DetectionDetails
    
    struct DetectionDetails: Codable {
        let normalizedPositionAvailable: Bool
        let sampleCount: Int
        let errorMessage: String?
    }
}
```

- [ ] **步骤 5：提交 Model 层**

```bash
git add PhantomKnobDetector/Model/
git commit -m "feat: 添加 Model 层基础数据结构"
```

---

### 任务 3：实现 Storage 层 - 检测结果缓存

**文件：**
- 创建：`PhantomKnobDetector/Storage/DetectionCache.swift`

- [ ] **步骤 1：实现 DetectionCache**

```swift
// PhantomKnobDetector/Storage/DetectionCache.swift
import Foundation

class DetectionCache {
    private let cacheKey = "com.phantomknob.detectionResult"
    private let userDefaults = UserDefaults.standard
    
    func save(_ result: DetectionResult) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(result) {
            userDefaults.set(data, forKey: cacheKey)
        }
    }
    
    func load() -> DetectionResult? {
        guard let data = userDefaults.data(forKey: cacheKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(DetectionResult.self, from: data)
    }
    
    func clear() {
        userDefaults.removeObject(forKey: cacheKey)
    }
}
```

- [ ] **步骤 2：提交 Storage 层**

```bash
git add PhantomKnobDetector/Storage/
git commit -m "feat: 实现 DetectionCache 缓存系统"
```

---

### 任务 4：实现 Service 层 - KnobAlgorithm 核心算法

**文件：**
- 创建：`PhantomKnobDetector/Service/KnobAlgorithm.swift`

- [ ] **步骤 1：实现 calKnob 核心算法**

```swift
// PhantomKnobDetector/Service/KnobAlgorithm.swift
import Foundation
import CoreGraphics

class KnobAlgorithm {
    
    /// 从多点触摸数据计算旋钮状态
    /// - Parameter points: 触点ID -> 归一化坐标的映射
    /// - Returns: (旋钮核心数据, 触点1的ID, 触点2的ID)
    func calKnob(_ points: [Int: CGPoint]) -> (KnobCore, Int, Int) {
        if points.count < 2 {
            return (KnobCore.invalid, 0, 0)
        }
        
        var maxDist: CGFloat = 0
        var fingerIdx1 = 0, fingerIdx2 = 0
        
        // 找到距离最远的两个触点
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
        
        guard let point1 = points[fingerIdx1],
              let point2 = points[fingerIdx2] else {
            return (KnobCore.invalid, 0, 0)
        }
        
        // 计算中点作为旋钮中心
        let center = CGPoint(
            x: (point1.x + point2.x) / 2,
            y: (point1.y + point2.y) / 2
        )
        
        // 计算半径
        let radius = maxDist / 2
        
        // 计算角度 (macOS 坐标系: Y轴向上为正, 0° 指向右方, 逆时针为正)
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        let angle = atan2(dy, dx) * 180 / .pi
        
        return (KnobCore(center: center, radius: radius, angle: angle), fingerIdx1, fingerIdx2)
    }
    
    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        return sqrt(dx * dx + dy * dy)
    }
}
```

- [ ] **步骤 2：提交算法实现**

```bash
git add PhantomKnobDetector/Service/KnobAlgorithm.swift
git commit -m "feat: 移植 calKnob 核心算法"
```

---

### 任务 5：实现 Service 层 - TouchpadEngine 触摸事件引擎

**文件：**
- 创建：`PhantomKnobDetector/Service/TouchpadEngine.swift`
- 创建：`PhantomKnobDetector/View/Components/TouchpadView.swift`

- [ ] **步骤 1：定义 TouchpadEventDelegate 协议**

```swift
// PhantomKnobDetector/Service/TouchpadEngine.swift
import AppKit

protocol TouchpadEventDelegate: AnyObject {
    func onTouchesBegan(_ touches: Set<NSTouch>)
    func onTouchesMoved(_ touches: Set<NSTouch>)
    func onTouchesEnded(_ touches: Set<NSTouch>)
}

class TouchpadEngine {
    weak var delegate: TouchpadEventDelegate?
    
    init() {}
    
    func processTouchesBegan(_ touches: Set<NSTouch>) {
        delegate?.onTouchesBegan(touches)
    }
    
    func processTouchesMoved(_ touches: Set<NSTouch>) {
        delegate?.onTouchesMoved(touches)
    }
    
    func processTouchesEnded(_ touches: Set<NSTouch>) {
        delegate?.onTouchesEnded(touches)
    }
}
```

- [ ] **步骤 2：实现 TouchpadView (NSView 子类)**

```swift
// PhantomKnobDetector/View/Components/TouchpadView.swift
import AppKit
import SwiftUI

class TouchpadView: NSView {
    weak var touchDelegate: TouchpadEventDelegate?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsRestingTouches = true  // 持续接收触摸事件
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsRestingTouches = true
    }
    
    override func touchesBegan(with event: NSEvent) {
        let touches = event.touches(matching: .touching, in: self)
        touchDelegate?.onTouchesBegan(touches)
    }
    
    override func touchesMoved(with event: NSEvent) {
        let touches = event.touches(matching: .touching, in: self)
        touchDelegate?.onTouchesMoved(touches)
    }
    
    override func touchesEnded(with event: NSEvent) {
        let touches = event.touches(matching: .touching, in: self)
        touchDelegate?.onTouchesEnded(touches)
    }
    
    override func touchesCancelled(with event: NSEvent) {
        let touches = event.touches(matching: .touching, in: self)
        touchDelegate?.onTouchesEnded(touches)
    }
}

// SwiftUI 包装器
struct TouchpadViewWrapper: NSViewRepresentable {
    let delegate: TouchpadEventDelegate
    
    func makeNSView(context: Context) -> TouchpadView {
        let view = TouchpadView()
        view.touchDelegate = delegate
        return view
    }
    
    func updateNSView(_ nsView: TouchpadView, context: Context) {
        nsView.touchDelegate = delegate
    }
}
```

- [ ] **步骤 3：提交触摸事件系统**

```bash
git add PhantomKnobDetector/Service/TouchpadEngine.swift
git add PhantomKnobDetector/View/Components/TouchpadView.swift
git commit -m "feat: 实现触摸事件捕获系统"
```

---

### 任务 6：实现 Service 层 - TouchpadDetector 触控板能力检测

**文件：**
- 创建：`PhantomKnobDetector/Service/TouchpadDetector.swift`

- [ ] **步骤 1：实现 TouchpadDetector**

```swift
// PhantomKnobDetector/Service/TouchpadDetector.swift
import AppKit
import Foundation

class TouchpadDetector: NSObject, TouchpadEventDelegate {
    private(set) var isSupported: Bool?
    private var sampleCount: Int = 0
    private let requiredSamples = 3
    private var lastSampleTime: Date?
    private let sampleInterval: TimeInterval = 0.5  // 500ms
    
    var onDetectionComplete: ((DetectionResult) -> Void)?
    var onProgress: ((Int) -> Void)?
    
    override init() {
        super.init()
    }
    
    // MARK: - TouchpadEventDelegate
    
    func onTouchesBegan(_ touches: Set<NSTouch>) {
        checkNormalizedPosition(touches)
    }
    
    func onTouchesMoved(_ touches: Set<NSTouch>) {
        checkNormalizedPosition(touches)
    }
    
    func onTouchesEnded(_ touches: Set<NSTouch>) {
        // 手指抬起时不判定失败,保持在检测模式
    }
    
    // MARK: - Private Methods
    
    private func checkNormalizedPosition(_ touches: Set<NSTouch>) {
        guard touches.count >= 2 else { return }
        
        let now = Date()
        
        // 检查采样间隔
        if let lastTime = lastSampleTime {
            guard now.timeIntervalSince(lastTime) < sampleInterval else {
                // 超时,重置采样
                sampleCount = 0
            }
        }
        
        // 验证 normalizedPosition 有效性
        var allValid = true
        for touch in touches {
            let pos = touch.normalizedPosition
            let isValid = !pos.x.isNaN && !pos.y.isNaN &&
                          pos.x >= 0 && pos.x <= 1 &&
                          pos.y >= 0 && pos.y <= 1
            if !isValid {
                allValid = false
                break
            }
        }
        
        if allValid {
            sampleCount += 1
            lastSampleTime = now
            onProgress?(sampleCount)
            
            if sampleCount >= requiredSamples {
                // 检测成功
                let result = createResult(isSupported: true, normalizedAvailable: true)
                onDetectionComplete?(result)
            }
        }
    }
    
    func createResult(isSupported: Bool, normalizedAvailable: Bool) -> DetectionResult {
        let deviceModel = getDeviceModel()
        let macOSVersion = ProcessInfo.processInfo.operatingSystemVersionString
        
        return DetectionResult(
            isSupported: isSupported,
            timestamp: Date(),
            deviceModel: deviceModel,
            macOSVersion: macOSVersion,
            details: DetectionResult.DetectionDetails(
                normalizedPositionAvailable: normalizedAvailable,
                sampleCount: sampleCount,
                errorMessage: isSupported ? nil : "无法获取触摸绝对坐标"
            )
        )
    }
    
    private func getDeviceModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }
    
    func reset() {
        sampleCount = 0
        lastSampleTime = nil
        isSupported = nil
    }
}
```

- [ ] **步骤 2：提交检测服务**

```bash
git add PhantomKnobDetector/Service/TouchpadDetector.swift
git commit -m "feat: 实现触控板能力检测服务"
```

---

### 任务 7：实现 Control 层 - 控制目标抽象

**文件：**
- 创建：`PhantomKnobDetector/Control/ControlTarget.swift`
- 创建：`PhantomKnobDetector/Control/DemoSliderTarget.swift`

- [ ] **步骤 1：定义 ControlTarget 协议**

```swift
// PhantomKnobDetector/Control/ControlTarget.swift
import Foundation

protocol ControlTarget {
    var value: Double { get set }
    var minValue: Double { get }
    var maxValue: Double { get }
    var displayName: String { get }
    
    func applyDelta(_ deltaAngle: Double) -> Double
}
```

- [ ] **步骤 2：实现 DemoSliderTarget**

```swift
// PhantomKnobDetector/Control/DemoSliderTarget.swift
import Foundation

class DemoSliderTarget: ControlTarget {
    var value: Double = 50.0  // 初始值居中
    let minValue: Double = 0
    let maxValue: Double = 100
    let displayName: String = "演示数值"
    
    private let sensitivity: Double = 0.5  // 1° → 0.5 数值变化
    
    func applyDelta(_ deltaAngle: Double) -> Double {
        let newValue = value + deltaAngle * sensitivity
        value = newValue.clamped(to: minValue...maxValue)
        return value
    }
}
```

- [ ] **步骤 3：提交 Control 层**

```bash
git add PhantomKnobDetector/Control/
git commit -m "feat: 实现控制目标抽象和演示数值控制"
```

---

### 任务 8：实现 ViewModel 层 - AppViewModel 全局状态管理

**文件：**
- 创建：`PhantomKnobDetector/ViewModel/AppViewModel.swift`

- [ ] **步骤 1：定义屏幕枚举和 AppViewModel**

```swift
// PhantomKnobDetector/ViewModel/AppViewModel.swift
import Foundation
import SwiftUI

enum AppScreen {
    case welcome
    case detection
    case result(DetectionResult)
    case demo
}

class AppViewModel: ObservableObject {
    @Published var currentScreen: AppScreen = .welcome
    @Published var detectionResult: DetectionResult?
    
    private let cache: DetectionCache
    
    init(cache: DetectionCache) {
        self.cache = cache
        
        // 检查缓存,决定初始屏幕
        if let cachedResult = cache.load(), cachedResult.isSupported {
            self.detectionResult = cachedResult
            self.currentScreen = .demo
        }
    }
    
    // MARK: - Navigation Methods
    
    func startDetection() {
        currentScreen = .detection
    }
    
    func completeDetection(_ result: DetectionResult) {
        detectionResult = result
        cache.save(result)
        
        if result.isSupported {
            currentScreen = .demo
        } else {
            currentScreen = .result(result)
        }
    }
    
    func reset() {
        cache.clear()
        detectionResult = nil
        currentScreen = .welcome
    }
    
    func goToWelcome() {
        currentScreen = .welcome
    }
}
```

- [ ] **步骤 2：提交全局状态管理**

```bash
git add PhantomKnobDetector/ViewModel/AppViewModel.swift
git commit -m "feat: 实现全局导航状态管理"
```

---

### 任务 9：实现 ViewModel 层 - DetectionViewModel 检测流程状态

**文件：**
- 创建：`PhantomKnobDetector/ViewModel/DetectionViewModel.swift`

- [ ] **步骤 1：实现 DetectionViewModel**

```swift
// PhantomKnobDetector/ViewModel/DetectionViewModel.swift
import Foundation
import SwiftUI
import Combine

class DetectionViewModel: ObservableObject {
    @Published var isDetecting: Bool = false
    @Published var progress: Int = 0
    @Published var remainingTime: Int = 30
    @Published var statusMessage: String = "请在触控板上双指触摸"
    
    private let detector = TouchpadDetector()
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    let timeout: TimeInterval = 30
    
    init() {
        setupDetector()
    }
    
    private func setupDetector() {
        detector.onProgress = { [weak self] count in
            DispatchQueue.main.async {
                self?.progress = count
                self?.statusMessage = "检测中... (\(count)/3)"
            }
        }
        
        detector.onDetectionComplete = { [weak self] result in
            DispatchQueue.main.async {
                self?.stopDetection()
                NotificationCenter.default.post(
                    name: Notification.Name("DetectionComplete"),
                    object: nil,
                    userInfo: ["result": result]
                )
            }
        }
    }
    
    func startDetection() {
        isDetecting = true
        progress = 0
        remainingTime = Int(timeout)
        statusMessage = "请在触控板上双指触摸"
        
        // 启动倒计时
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingTime -= 1
            if self.remainingTime <= 0 {
                self.handleTimeout()
            }
        }
    }
    
    func stopDetection() {
        timer?.invalidate()
        timer = nil
        isDetecting = false
    }
    
    func cancelDetection() {
        stopDetection()
        NotificationCenter.default.post(name: Notification.Name("DetectionCancelled"), object: nil)
    }
    
    private func handleTimeout() {
        stopDetection()
        statusMessage = "检测超时,请重试"
        
        let result = detector.createResult(isSupported: false, normalizedAvailable: false)
        NotificationCenter.default.post(
            name: Notification.Name("DetectionComplete"),
            object: nil,
            userInfo: ["result": result]
        )
    }
    
    // MARK: - Touch Event Processing
    
    func handleTouchesBegan(_ touches: Set<NSTouch>) {
        detector.onTouchesBegan(touches)
    }
    
    func handleTouchesMoved(_ touches: Set<NSTouch>) {
        detector.onTouchesMoved(touches)
    }
    
    func handleTouchesEnded(_ touches: Set<NSTouch>) {
        detector.onTouchesEnded(touches)
    }
}
```

- [ ] **步骤 2：提交检测状态管理**

```bash
git add PhantomKnobDetector/ViewModel/DetectionViewModel.swift
git commit -m "feat: 实现检测流程状态管理"
```

---

### 任务 10：实现 ViewModel 层 - DemoViewModel 演示页状态

**文件：**
- 创建：`PhantomKnobDetector/ViewModel/DemoViewModel.swift`

- [ ] **步骤 1：实现 DemoViewModel**

```swift
// PhantomKnobDetector/ViewModel/DemoViewModel.swift
import Foundation
import SwiftUI
import AppKit

class DemoViewModel: ObservableObject, TouchpadEventDelegate {
    @Published var knobAngle: Double = 0
    @Published var displayValue: Double = 50.0
    @Published var isActive: Bool = false
    
    private let touchpadEngine = TouchpadEngine()
    private let knobAlgorithm = KnobAlgorithm()
    private var controlTarget: ControlTarget
    private var previousKnob: KnobCore = .invalid
    
    init() {
        self.controlTarget = DemoSliderTarget()
        touchpadEngine.delegate = self
    }
    
    // MARK: - TouchpadEventDelegate
    
    func onTouchesBegan(_ touches: Set<NSTouch>) {
        handleTouchUpdate(touches)
    }
    
    func onTouchesMoved(_ touches: Set<NSTouch>) {
        handleTouchUpdate(touches)
    }
    
    func onTouchesEnded(_ touches: Set<NSTouch>) {
        if touches.count < 2 {
            isActive = false
        }
    }
    
    private func handleTouchUpdate(_ touches: Set<NSTouch>) {
        guard touches.count >= 2 else { return }
        
        // 提取归一化坐标
        var points: [Int: CGPoint] = [:]
        for touch in touches {
            let pos = touch.normalizedPosition
            guard !pos.x.isNaN && !pos.y.isNaN else { continue }
            points[Int(touch.identity)] = CGPoint(x: pos.x, y: pos.y)
        }
        
        guard points.count >= 2 else { return }
        
        // 计算旋钮状态
        let (currentKnob, _, _) = knobAlgorithm.calKnob(points)
        guard currentKnob.isValid else { return }
        
        // 计算状态变化
        let state = KnobState(current: currentKnob, previous: previousKnob)
        
        // 更新 UI
        knobAngle = currentKnob.angle
        displayValue = controlTarget.applyDelta(state.deltaAngle)
        isActive = true
        
        previousKnob = currentKnob
    }
    
    func getTouchpadEngine() -> TouchpadEngine {
        return touchpadEngine
    }
}
```

- [ ] **步骤 2：提交演示状态管理**

```bash
git add PhantomKnobDetector/ViewModel/DemoViewModel.swift
git commit -m "feat: 实现演示页状态管理"
```

---

### 任务 11：实现 View 层 - WelcomeView 欢迎页

**文件：**
- 创建：`PhantomKnobDetector/View/WelcomeView.swift`

- [ ] **步骤 1：实现 WelcomeView**

```swift
// PhantomKnobDetector/View/WelcomeView.swift
import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text("PhantomKnobDetector")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("检测您的触控板是否支持 Knob 手势操作")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("开始检测") {
                appViewModel.startDetection()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AppViewModel(cache: DetectionCache()))
}
```

- [ ] **步骤 2：提交欢迎页**

```bash
git add PhantomKnobDetector/View/WelcomeView.swift
git commit -m "feat: 实现欢迎页"
```

---

### 任务 12：实现 View 层 - DetectionView 检测页

**文件：**
- 创建：`PhantomKnobDetector/View/DetectionView.swift`

- [ ] **步骤 1：实现 DetectionView**

```swift
// PhantomKnobDetector/View/DetectionView.swift
import SwiftUI

struct DetectionView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @StateObject private var viewModel = DetectionViewModel()
    
    var body: some View {
        ZStack {
            // 触摸捕获层
            TouchpadViewWrapper(delegate: TouchDelegate(viewModel: viewModel))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // UI 层
            VStack(spacing: 30) {
                Text("正在检测...")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text(viewModel.statusMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                // 进度指示器
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(index < viewModel.progress ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 16, height: 16)
                    }
                }
                
                // 倒计时
                Text("剩余时间: \(viewModel.remainingTime)秒")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("取消") {
                    viewModel.cancelDetection()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding()
        }
        .onAppear {
            viewModel.startDetection()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DetectionComplete"))) { notification in
            if let result = notification.userInfo?["result"] as? DetectionResult {
                appViewModel.completeDetection(result)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DetectionCancelled"))) { _ in
            appViewModel.goToWelcome()
        }
    }
}

// TouchpadEventDelegate 包装器
class TouchDelegate: TouchpadEventDelegate {
    private let viewModel: DetectionViewModel
    
    init(viewModel: DetectionViewModel) {
        self.viewModel = viewModel
    }
    
    func onTouchesBegan(_ touches: Set<NSTouch>) {
        viewModel.handleTouchesBegan(touches)
    }
    
    func onTouchesMoved(_ touches: Set<NSTouch>) {
        viewModel.handleTouchesMoved(touches)
    }
    
    func onTouchesEnded(_ touches: Set<NSTouch>) {
        viewModel.handleTouchesEnded(touches)
    }
}

#Preview {
    DetectionView()
        .environmentObject(AppViewModel(cache: DetectionCache()))
}
```

- [ ] **步骤 2：提交检测页**

```bash
git add PhantomKnobDetector/View/DetectionView.swift
git commit -m "feat: 实现检测页"
```

---

### 任务 13：实现 View 层 - ResultView 结果页

**文件：**
- 创建：`PhantomKnobDetector/View/ResultView.swift`

- [ ] **步骤 1：实现 ResultView**

```swift
// PhantomKnobDetector/View/ResultView.swift
import SwiftUI

struct ResultView: View {
    let result: DetectionResult
    @EnvironmentObject var appViewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // 结果图标
            Image(systemName: result.isSupported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(result.isSupported ? .green : .red)
            
            // 结果标题
            Text(result.isSupported ? "✅ 支持" : "❌ 不支持")
                .font(.title)
                .fontWeight(.bold)
            
            // 结果描述
            Text(result.isSupported ?
                 "您的触控板支持 Knob 手势" :
                 "您的触控板不支持 Knob 手势")
                .font(.body)
                .foregroundColor(.secondary)
            
            // 详情 (仅在不支持时显示)
            if !result.isSupported {
                VStack(alignment: .leading, spacing: 10) {
                    Text("详情:")
                        .font(.headline)
                    
                    Text("• 设备: \(result.deviceModel)")
                        .font(.caption)
                    Text("• 系统: \(result.macOSVersion)")
                        .font(.caption)
                    if let error = result.details.errorMessage {
                        Text("• 原因: \(error)")
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 20) {
                if !result.isSupported {
                    Button("导出报告") {
                        exportReport()
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("重新检测") {
                    appViewModel.startDetection()
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
        .padding()
    }
    
    private func exportReport() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(result),
           let json = String(data: data, encoding: .utf8) {
            let savePanel = NSSavePanel()
            savePanel.title = "导出检测报告"
            savePanel.nameFieldStringValue = "compatibility_report.json"
            savePanel.allowedContentTypes = [.json]
            
            if savePanel.runModal() == .OK {
                try? json.write(to: savePanel.url!, atomically: true, encoding: .utf8)
            }
        }
    }
}

#Preview {
    ResultView(result: DetectionResult(
        isSupported: false,
        timestamp: Date(),
        deviceModel: "MacBookPro18,3",
        macOSVersion: "macOS 14.0",
        details: DetectionResult.DetectionDetails(
            normalizedPositionAvailable: false,
            sampleCount: 0,
            errorMessage: "无法获取触摸绝对坐标"
        )
    ))
    .environmentObject(AppViewModel(cache: DetectionCache()))
}
```

- [ ] **步骤 2：提交结果页**

```bash
git add PhantomKnobDetector/View/ResultView.swift
git commit -m "feat: 实现结果页"
```

---

### 任务 14：实现 View 层 - Components/KnobCircleView 旋钮可视化

**文件：**
- 创建：`PhantomKnobDetector/View/Components/KnobCircleView.swift`

- [ ] **步骤 1：实现 KnobCircleView**

```swift
// PhantomKnobDetector/View/Components/KnobCircleView.swift
import SwiftUI

struct KnobCircleView: View {
    let angle: Double
    let size: CGFloat = 100
    
    var body: some View {
        ZStack {
            // 白色圆形背景
            Circle()
                .fill(Color.white)
                .frame(width: size, height: size)
            
            // 灰色边框
            Circle()
                .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                .frame(width: size, height: size)
            
            // 指示线
            GeometryReader { geometry in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let lineLength = size / 2 - 10
                
                Path { path in
                    path.move(to: center)
                    let endX = center.x + CGFloat(cos(angle * .pi / 180)) * lineLength
                    let endY = center.y - CGFloat(sin(angle * .pi / 180)) * lineLength
                    path.addLine(to: CGPoint(x: endX, y: endY))
                }
                .stroke(Color.black, lineWidth: 3)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack {
        KnobCircleView(angle: 0)
        KnobCircleView(angle: 45)
        KnobCircleView(angle: 90)
        KnobCircleView(angle: 180)
        KnobCircleView(angle: -45)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
```

- [ ] **步骤 2：提交旋钮可视化组件**

```bash
git add PhantomKnobDetector/View/Components/KnobCircleView.swift
git commit -m "feat: 实现旋钮圆形可视化组件"
```

---

### 任务 15：实现 View 层 - DemoView 演示页

**文件：**
- 创建：`PhantomKnobDetector/View/DemoView.swift`

- [ ] **步骤 1：实现 DemoView**

```swift
// PhantomKnobDetector/View/DemoView.swift
import SwiftUI

struct DemoView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @StateObject private var viewModel = DemoViewModel()
    
    var body: some View {
        ZStack {
            // 触摸捕获层
            TouchpadViewWrapper(delegate: viewModel.getTouchpadEngine())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // UI 层
            VStack(spacing: 30) {
                Text("✅ 支持检测通过")
                    .font(.headline)
                    .foregroundColor(.green)
                
                // 旋钮图形
                KnobCircleView(angle: viewModel.knobAngle)
                
                // 数值显示
                Text("\(viewModel.displayValue, specifier: "%.1f")")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // 操作提示
                Text("在触控板上双指旋转以调整数值")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 重新检测按钮
                Button("重新检测") {
                    appViewModel.reset()
                    appViewModel.startDetection()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .padding()
        }
    }
}

#Preview {
    DemoView()
        .environmentObject(AppViewModel(cache: DetectionCache()))
}
```

- [ ] **步骤 2：提交演示页**

```bash
git add PhantomKnobDetector/View/DemoView.swift
git commit -m "feat: 实现演示页"
```

---

### 任务 16：项目配置和 Info.plist 设置

**文件：**
- 修改：`PhantomKnobDetector/Info.plist`

- [ ] **步骤 1：配置 Info.plist**

在 Info.plist 中添加:
```xml
<key>NSHumanReadableCopyright</key>
<string>Copyright © 2025 Ben Wu. All rights reserved.</string>
<key>LSMinimumSystemVersion</key>
<string>12.0</string>
<key>NSHighResolutionCapable</key>
<true/>
<key>LSApplicationCategoryType</key>
<string>public.app-category.utilities</string>
```

- [ ] **步骤 2：提交配置**

```bash
git add PhantomKnobDetector/Info.plist
git commit -m "chore: 配置项目信息"
```

---

### 任务 17：功能验收测试

- [ ] **步骤 1：编译并运行应用**

```bash
# 在 Xcode 中按 Cmd+R 运行应用
# 或使用命令行:
xcodebuild -scheme PhantomKnobDetector -configuration Debug run
```

- [ ] **步骤 2：验收功能检查清单**

按照规格文档 §11.1 功能验收标准验证:

**检测流程:**
- [ ] App 启动 → 显示欢迎页
- [ ] 点击"开始检测" → 进入检测页
- [ ] 检测页显示倒计时和进度指示器
- [ ] 双指触摸触控板 → 进度增加
- [ ] 收集 3 个样本 → 自动跳转到演示页

**检测失败场景:**
- [ ] 30 秒超时 → 显示超时提示
- [ ] 点击"取消" → 返回欢迎页
- [ ] 触控板不支持 → 显示结果页(含详情)

**演示页功能:**
- [ ] 旋钮图形正确渲染
- [ ] 双指旋转 → 指示线跟随转动
- [ ] 数值实时更新
- [ ] 手指抬起 → 数值保持不变
- [ ] 点击"重新检测" → 返回检测流程

**缓存机制:**
- [ ] 检测成功后退出应用
- [ ] 重新启动 → 直接进入演示页(跳过检测)
- [ ] UserDefaults 中存在缓存数据

- [ ] **步骤 3：性能验收**

按照规格文档 §11.2 性能验收标准验证:
- [ ] 触摸响应无明显延迟
- [ ] UI 更新流畅,无卡顿
- [ ] 内存占用合理(使用 Activity Monitor 检查)

- [ ] **步骤 4：提交验收完成标记**

```bash
git tag -a v1.0-mvp -m "MVP 验收完成"
git push origin v1.0-mvp
```

---

## 自检清单

### 1. 规格覆盖度检查

对照规格文档逐项检查:

**§3 核心流程**
- [x] 欢迎页 → 检测页 → 结果/演示页导航流程
- [x] 缓存检查逻辑
- [x] 后续启动跳过检测

**§4.1 兼容性检测**
- [x] 检测 normalizedPosition 有效性
- [x] 30 秒超时 + 视觉倒计时
- [x] 3 次连续有效样本确认机制
- [x] 取消按钮
- [x] 手指抬起不判定失败
- [x] 缓存检测结果

**§4.2 Knob 演示**
- [x] 旋钮图形(简化设计)
- [x] 数值显示(0-100, 初始值 50)
- [x] 操作提示文本
- [x] 重新检测按钮
- [x] calKnob() 算法移植
- [x] 数值控制规格(灵敏度、Delta限制)
- [x] 手势冲突处理(MVP: 不区分)

**§5 架构设计**
- [x] MVVM 模式
- [x] 所有模块都已实现(View/ViewModel/Model/Service/Control/Storage)
- [x] 关键接口定义

**§7 数据模型**
- [x] DetectionResult 结构
- [x] KnobState 结构
- [x] 已移除无用的 samplePoints

**§8 界面规格**
- [x] WelcomeView 布局
- [x] DetectionView 布局
- [x] ResultView 布局
- [x] DemoView 布局
- [x] 旋钮可视化规格

**§9 存储与缓存**
- [x] UserDefaults 缓存
- [x] 缓存键: com.phantomknob.detectionResult
- [x] 永久有效期
- [x] 报告导出功能

**§10 算法移植**
- [x] calKnob() 核心逻辑
- [x] 角度坐标系(macOS 原生)
- [x] 角度变化计算
- [x] 数值更新公式

### 2. 占位符扫描

检查是否包含以下反模式:
- [x] 无"待定"、"TODO"、"后续实现"等占位符
- [x] 无"添加适当的错误处理"等模糊描述
- [x] 所有代码步骤都有完整实现
- [x] 无重复引用(如"类似任务N")

### 3. 类型一致性检查

- [x] `KnobCore` 在所有任务中定义一致
- [x] `DetectionResult` 字段名一致
- [x] `ControlTarget` 协议方法签名一致
- [x] 坐标系使用 macOS 原生(Y轴向上)
- [x] 角度计算使用相同公式(`atan2(dy, dx) * 180 / .pi`)

---

## 执行交接

**计划已完成并保存到 `.sisyphus/plans/2025-05-12-phantom-knob-mvp.md`。**

**两种执行方式:**

**1. 子代理驱动(推荐)** - 每个任务调度一个新的子代理,任务间进行审查,快速迭代
   - **必需子技能:** 使用 superpowers:subagent-driven-development
   - 每个任务一个新子代理 + 两阶段审查

**2. 内联执行** - 在当前会话中使用 executing-plans 执行任务,批量执行并设有检查点
   - **必需子技能:** 使用 superpowers:executing-plans
   - 批量执行并设有检查点供审查

**选哪种方式?**
