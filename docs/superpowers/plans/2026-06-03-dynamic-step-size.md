# 动态修改调整步长（速度） 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现通过手指半径变化（支持多环迟滞和线性渐变）和辅助键盘数字键动态调整旋钮步长（速度）的特性，并支持单 Knob 专属定制。

**架构：**
1. 改造 `ScaleConfig` 及协议 `InputTranslator`，允许在手势运动中动态写入 `scale`。
2. 引入 `AppSettings` 处理 JSONC 加载与剥离注释。
3. 实现 `ScaleResolver`，提供 Hysteresis 迟滞多环状态机和 Linear 渐变解析，并在 `radius < minRadius` 时返回 `nil` 进入死区状态。
4. 改造 `OverlayView` / `OverlayController` 以支持死区变灰的视觉反馈。
5. 在 `KnobStateManager.onMultitouchMoved` 每帧事件中整合逻辑：
   - 轮询 `CGEventSource.keyState` 探测当前是否有数字键 2-9 被按下。
   - 若检测到被按下的键且之前未锁定，锁定当前基础步长为 `lockedBaseScale`，并在按键期间保持该倍率乘积。松开时解锁恢复动态计算。
   - 计算当前 `radius` 并通过 `ScaleResolver` 求解。如果处于死区（返回 `nil`），丢弃该帧旋转量且将 Overlay UI 设为变灰状态。
   - 读取 UserDefaults 中的系统设置灵敏度，应用公式：`finalScale = baseScale * activeKeyboardMultiplier * settingsSensitivity` 动态写入 translator。

**技术栈：** Swift 5.9, Foundation, ApplicationServices, AppKit, XCTest

---

### 任务 1：Codable 重构与 JSONC 预处理支持

**文件：**
- 修改：`PhantomKnobDetector/Model/ControlRule.swift`
- 创建：`PhantomKnobDetector/Model/AppSettings.swift`
- 测试：`PhantomKnobDetectorTests/JSONCParserTests.swift`
- 测试：`PhantomKnobDetectorTests/ScaleConfigCompatibilityTests.swift`

- [ ] **步骤 1：编写 ScaleConfig 兼容性与 JSONC 预处理测试**

```swift
// PhantomKnobDetectorTests/JSONCParserTests.swift
import XCTest
@testable import PhantomKnobDetector

final class JSONCParserTests: XCTestCase {
    func testStripComments() {
        let jsonc = """
        {
            // 单行注释
            "key": "value", /* 多行
            注释 */
            "number": 123
        }
        """
        let cleaned = JSONCParser.stripComments(from: jsonc)
        XCTAssertFalse(cleaned.contains("单行注释"))
        XCTAssertFalse(cleaned.contains("多行"))
        XCTAssertTrue(cleaned.contains("\"key\": \"value\""))
    }
}
```

```swift
// PhantomKnobDetectorTests/ScaleConfigCompatibilityTests.swift
import XCTest
@testable import PhantomKnobDetector

final class ScaleConfigCompatibilityTests: XCTestCase {
    func testDecodeLegacyFixedScale() throws {
        let json = "{\"fixed\": 2.5}"
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(ScaleConfig.self, from: data)
        if case .fixed(let val) = config {
            XCTAssertEqual(val, 2.5)
        } else {
            XCTFail("Expected .fixed")
        }
    }

    func testDecodeZonesScale() throws {
        let json = """
        {
            "zones": [
                {"minRadius": 0.0, "maxRadius": 10.0, "margin": 1.5, "scale": 1.5},
                {"minRadius": 10.0, "maxRadius": 100.0, "margin": 1.5, "scale": 0.3}
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let config = try JSONDecoder().decode(ScaleConfig.self, from: data)
        if case .zones(let zones) = config {
            XCTAssertEqual(zones.count, 2)
            XCTAssertEqual(zones[0].scale, 1.5)
            XCTAssertEqual(zones[1].margin, 1.5)
        } else {
            XCTFail("Expected .zones")
        }
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift test --filter JSONCParserTests` 和 `swift test --filter ScaleConfigCompatibilityTests`
预期：编译失败，因为 `JSONCParser`、`ScaleConfig.zones` 未定义。

- [ ] **步骤 3：重构 ScaleConfig 并实现 JSONCParser**

在 `ControlRule.swift` 中修改 `ScaleConfig` :
```swift
struct RadiusZone: Codable {
    let minRadius: Double
    let maxRadius: Double
    let margin: Double
    let scale: Double
}

struct ScaleConfigLinear: Codable {
    let minRadius: Double
    let maxRadius: Double
    let minScale: Double
    let maxScale: Double
}

enum ScaleConfig: Codable {
    case fixed(Double)
    case zones([RadiusZone])
    case linear(ScaleConfigLinear)
}

extension ScaleConfig {
    private enum CodingKeys: String, CodingKey {
        case fixed
        case zones
        case linear
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let val = try? container.decode(Double.self, forKey: .fixed) {
            self = .fixed(val)
        } else if let zones = try? container.decode([RadiusZone].self, forKey: .zones) {
            self = .zones(zones)
        } else if let linear = try? container.decode(ScaleConfigLinear.self, forKey: .linear) {
            self = .linear(linear)
        } else {
            self = .fixed(1.0)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .fixed(let val):
            try container.encode(val, forKey: .fixed)
        case .zones(let zones):
            try container.encode(zones, forKey: .zones)
        case .linear(let linear):
            try container.encode(linear, forKey: .linear)
        }
    }

    func resolve(radius: Double = 0) -> Double {
        switch self {
        case .fixed(let s): return s
        case .zones(let zones): return zones.first?.scale ?? 1.0
        case .linear(let linear): return linear.minScale
        }
    }
}
```

在 `PhantomKnobDetector/Model/AppSettings.swift` 中创建：
```swift
import Foundation

struct AppSettings: Codable {
    var activeScheme: String = "fixed"
    var enableKeyboardNumberMultiplier: Bool = true
    var fixed: FixedSchemeConfig = FixedSchemeConfig()
    var linear: ScaleConfigLinear = ScaleConfigLinear(minRadius: 5.0, maxRadius: 20.0, minScale: 1.0, maxScale: 0.2)

    struct FixedSchemeConfig: Codable {
        var zones: [RadiusZone] = [
            RadiusZone(minRadius: 5.0, maxRadius: 12.0, margin: 2.0, scale: 1.0),
            RadiusZone(minRadius: 12.0, maxRadius: 100.0, margin: 2.0, scale: 0.2)
        ]
    }

    static var shared: AppSettings = {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PhantomKnob")
        let fileURL = folder.appendingPathComponent("settings.jsonc")
        
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let defaults = AppSettings()
            if let data = try? JSONEncoder().encode(defaults) {
                try? data.write(to: fileURL)
            }
            return defaults
        }
        
        guard let data = try? Data(contentsOf: fileURL),
              let config = try? JSONCParser.decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return config
    }()
}

struct JSONCParser {
    static func stripComments(from jsonString: String) -> String {
        let pattern = #"(?:/\*(?:[^*]|\*(?!/))*\*/)|(?://.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return jsonString
        }
        let range = NSRange(jsonString.startIndex..., in: jsonString)
        return regex.stringByReplacingMatches(in: jsonString, options: [], range: range, withTemplate: "")
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard let rawString = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Invalid UTF-8"))
        }
        let cleanString = stripComments(from: rawString)
        guard let cleanData = cleanString.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "UTF-8 conversion failed"))
        }
        return try JSONDecoder().decode(type, from: cleanData)
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`swift test --filter JSONCParserTests` 和 `swift test --filter ScaleConfigCompatibilityTests`
预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnobDetector/Model/ControlRule.swift PhantomKnobDetector/Model/AppSettings.swift PhantomKnobDetectorTests/JSONCParserTests.swift PhantomKnobDetectorTests/ScaleConfigCompatibilityTests.swift
git commit -m "feat: add ScaleConfig zones/linear models and JSONCParser with tests"
```

---

### 任务 2：实现半径步长求解器 `ScaleResolver`（支持死区检测）

**文件：**
- 创建：`PhantomKnobDetector/Service/ScaleResolver.swift`
- 测试：`PhantomKnobDetectorTests/ScaleResolverTests.swift`

- [ ] **步骤 1：编写 ScaleResolverTests 迟滞、线性及死区测试**

```swift
// PhantomKnobDetectorTests/ScaleResolverTests.swift
import XCTest
@testable import PhantomKnobDetector

final class ScaleResolverTests: XCTestCase {
    func testHysteresisZonesAndDeadzone() {
        let zones = [
            RadiusZone(minRadius: 5.0, maxRadius: 12.0, margin: 2.0, scale: 1.0),
            RadiusZone(minRadius: 12.0, maxRadius: 100.0, margin: 2.0, scale: 0.2)
        ]
        
        var zoneIndex = 0
        
        // 低于 5.0 触发死区返回 nil
        XCTAssertNil(ScaleResolver.resolveHysteresis(radius: 4.5, zones: zones, currentZoneIndex: &zoneIndex))
        
        // 初始留在 Zone 0
        XCTAssertEqual(ScaleResolver.resolveHysteresis(radius: 6.0, zones: zones, currentZoneIndex: &zoneIndex), 1.0)
        XCTAssertEqual(zoneIndex, 0)
        
        // 大于 max + margin (12 + 2 = 14) 才进入 Zone 1
        XCTAssertEqual(ScaleResolver.resolveHysteresis(radius: 13.0, zones: zones, currentZoneIndex: &zoneIndex), 1.0)
        XCTAssertEqual(ScaleResolver.resolveHysteresis(radius: 14.5, zones: zones, currentZoneIndex: &zoneIndex), 0.2)
        XCTAssertEqual(zoneIndex, 1)
        
        // 小于 min - margin (12 - 2 = 10) 才返回 Zone 0
        XCTAssertEqual(ScaleResolver.resolveHysteresis(radius: 11.0, zones: zones, currentZoneIndex: &zoneIndex), 0.2)
        XCTAssertEqual(ScaleResolver.resolveHysteresis(radius: 9.5, zones: zones, currentZoneIndex: &zoneIndex), 1.0)
        XCTAssertEqual(zoneIndex, 0)
    }

    func testLinearInterpolationAndDeadzone() {
        let config = ScaleConfigLinear(minRadius: 5.0, maxRadius: 20.0, minScale: 1.0, maxScale: 0.2)
        
        XCTAssertNil(ScaleResolver.resolveLinear(radius: 4.5, config: config))
        XCTAssertEqual(ScaleResolver.resolveLinear(radius: 5.0, config: config), 1.0)
        XCTAssertEqual(ScaleResolver.resolveLinear(radius: 25.0, config: config), 0.2)
        XCTAssertEqual(ScaleResolver.resolveLinear(radius: 12.5, config: config), 0.6)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift test --filter ScaleResolverTests`
预期：编译失败，`ScaleResolver` 未定义。

- [ ] **步骤 3：实现 ScaleResolver 逻辑**

创建 `PhantomKnobDetector/Service/ScaleResolver.swift`：
```swift
import Foundation

struct ScaleResolver {
    static func resolveHysteresis(radius: Double, zones: [RadiusZone], currentZoneIndex: inout Int) -> Double? {
        guard !zones.isEmpty else { return 1.0 }
        
        // 校验死区限制
        if radius < zones[0].minRadius {
            return nil
        }
        
        if zones.count == 1 { return zones[0].scale }
        
        let i = currentZoneIndex
        if i >= 0 && i < zones.count {
            let effectiveMin = zones[i].minRadius - zones[i].margin
            let effectiveMax = zones[i].maxRadius + zones[i].margin
            
            if radius >= effectiveMin && radius <= effectiveMax {
                return zones[i].scale
            }
        }
        
        // 超出缓冲区，寻找落入标准区间的 Zone
        for j in 0..<zones.count {
            if radius >= zones[j].minRadius && radius <= zones[j].maxRadius {
                currentZoneIndex = j
                return zones[j].scale
            }
        }
        
        // 若完全不落入任何区间，返回最近的边界
        if radius < zones[0].minRadius {
            currentZoneIndex = 0
            return zones[0].scale
        } else {
            currentZoneIndex = zones.count - 1
            return zones[currentZoneIndex].scale
        }
    }

    static func resolveLinear(radius: Double, config: ScaleConfigLinear) -> Double? {
        if radius < config.minRadius { return nil }
        if radius >= config.maxRadius { return config.maxScale }
        let ratio = (radius - config.minRadius) / (config.maxRadius - config.minRadius)
        return config.minScale + ratio * (config.maxScale - config.minScale)
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`swift test --filter ScaleResolverTests`
预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnobDetector/Service/ScaleResolver.swift PhantomKnobDetectorTests/ScaleResolverTests.swift
git commit -m "feat: implement ScaleResolver hysteresis and linear resolvers with deadzone detection"
```

---

### 任务 3：InputTranslator 协议改造与实现更新

**文件：**
- 修改：`PhantomKnobDetector/Control/InputTranslator.swift`
- 修改：`PhantomKnobDetector/Control/ArrowKeyTranslator.swift`
- 修改：`PhantomKnobDetector/Control/ScrollWheelTranslator.swift`
- 修改：`PhantomKnobDetector/Control/AXWriteTranslator.swift`
- 测试：`PhantomKnobDetectorTests/InputTranslationTests.swift`

- [ ] **步骤 1：编写 InputTranslator 动态 scale 测试**

在 `PhantomKnobDetectorTests/InputTranslationTests.swift` 中新增：
```swift
    func testTranslatorDynamicScaleChange() {
        let t = ArrowKeyTranslator(axis: .upDown, scale: 1.0)
        XCTAssertEqual(t.scale, 1.0)
        t.scale = 0.5
        XCTAssertEqual(t.scale, 0.5)
    }
```

- [ ] **步骤 2：运行测试验证失败**

运行：`swift test --filter InputTranslationTests`
预期：编译失败，因为 `InputTranslator` 不具备 `scale` 属性的 get/set 接口。

- [ ] **步骤 3：修改协议与具体实现**

在 `InputTranslator.swift` 中更新协议：
```swift
protocol InputTranslator: AnyObject {
    func apply(units: Double, direction: RotationDirection)
    var displayValue: String? { get }
    var scale: Double { get set }
}
```

改造 ArrowKeyTranslator.swift, ScrollWheelTranslator.swift, AXWriteTranslator.swift（将 `private let scale` 修改为 `var scale`）。

- [ ] **步骤 4：运行所有已有测试验证通过**

运行：`swift test`
预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnobDetector/Control/InputTranslator.swift PhantomKnobDetector/Control/ArrowKeyTranslator.swift PhantomKnobDetector/Control/ScrollWheelTranslator.swift PhantomKnobDetector/Control/AXWriteTranslator.swift PhantomKnobDetectorTests/InputTranslationTests.swift
git commit -m "refactor: make scale mutable on InputTranslator protocol and implementing classes"
```

---

### 任务 4：Overlay UI 死区状态改造

**文件：**
- 修改：`PhantomKnobDetector/View/OverlayView.swift`
- 修改：`PhantomKnobDetector/Service/OverlayController.swift`

- [ ] **步骤 1：修改 OverlayView 添加 isDeadzone 样式**

在 `OverlayView.swift` 中添加 `isDeadzone` 属性并在 body 中控制颜色显示（变灰）。

- [ ] **步骤 2：在 OverlayController 中提供 isDeadzone 的更新接口**

在 `OverlayController.swift` 中：
```swift
class OverlayController: ObservableObject {
    @Published var isDeadzone: Bool = false
    
    func update(angle: Double, displayValue: String?, isDeadzone: Bool = false) {
        self.angle = angle
        self.displayValue = displayValue
        self.isDeadzone = isDeadzone
        updateOverlayView()
    }
    
    private func updateOverlayView() {
        guard let hostingView = hostingView else { return }
        hostingView.rootView = OverlayView(
            targetName: targetName,
            angle: angle,
            displayValue: displayValue,
            isDeadzone: isDeadzone
        )
    }
}
```

- [ ] **步骤 3：运行测试验证通过**

运行：`swift test`
预期：PASS

- [ ] **步骤 4：Commit**

```bash
git add PhantomKnobDetector/View/OverlayView.swift PhantomKnobDetector/Service/OverlayController.swift
git commit -m "feat: add deadzone support and visual style (grayed out) to OverlayView and OverlayController"
```

---

### 任务 5：KnobStateManager 整合每帧按键轮询与系统灵敏度合成

**文件：**
- 修改：`PhantomKnobDetector/Service/KnobStateManager.swift`

- [ ] **步骤 1：集成状态变量维护与 MultitouchBegan 初始化**

在 `KnobStateManager.swift` 中增加以下私有属性：
```swift
    private var activeKeyboardMultiplier: Double = 1.0
    private var currentZoneIndex: Int = 0
    private var activeScaleConfig: ScaleConfig = .fixed(1.0)
    private var lastResolvedBaseScale: Double = 1.0
    private var lockedBaseScale: Double? = nil
```

在 `onMultitouchBegan` 初始化该次手势的 ScaleConfig 与状态：
```swift
        // 查找匹配的 rule 并缓存对应的 ScaleConfig
        let rule = RuleLibrary.shared.lookup(for: target.ruleKey)
        let resolvedScaleConfig: ScaleConfig
        if let ruleScaleConfig = rule?.scaleConfig {
            switch ruleScaleConfig {
            case .fixed(let val):
                if val == 1.0 {
                    resolvedScaleConfig = AppSettings.shared.activeScheme == "linear"
                        ? .linear(AppSettings.shared.linear)
                        : .zones(AppSettings.shared.fixed.zones)
                } else {
                    resolvedScaleConfig = .fixed(val)
                }
            default:
                resolvedScaleConfig = ruleScaleConfig
            }
        } else {
            resolvedScaleConfig = AppSettings.shared.activeScheme == "linear"
                ? .linear(AppSettings.shared.linear)
                : .zones(AppSettings.shared.fixed.zones)
        }
        self.activeScaleConfig = resolvedScaleConfig
        self.currentZoneIndex = 0
        self.lastResolvedBaseScale = 1.0
        self.lockedBaseScale = nil
```

- [ ] **步骤 2：在 transition 方法中重置键盘锁定变量**

在 `transition(to newState: KnobGlobalState)` 中：
```swift
        state = newState
        if case .activated = newState {
            lockedBaseScale = nil
            activeKeyboardMultiplier = 1.0
        } else if case .inactive = newState {
            lockedBaseScale = nil
            activeKeyboardMultiplier = 1.0
        }
```

- [ ] **步骤 3：在 onMultitouchMoved 中增加每帧按键轮询与最终步长合成**

在 `onMultitouchMoved` 触发时：
```swift
        if state.isKnobing {
            if let lockPos = initialTouchPositionCarbon {
                CGWarpMouseCursorPosition(lockPos)
            }

            // 1. 轮询 CGEventSource.keyState 探测当前是否有数字键 2-9 被物理按住
            var activeNum: Int? = nil
            if AppSettings.shared.enableKeyboardNumberMultiplier {
                let keyMapping: [Int: CGKeyCode] = [
                    2: 19, 3: 20, 4: 21, 5: 23, 6: 22, 7: 26, 8: 28, 9: 25
                ]
                for (num, keyCode) in keyMapping {
                    if CGEventSource.keyState(.combinedSessionState, key: keyCode) {
                        activeNum = num
                        break
                    }
                }
            }

            // 2. 根据按键状态执行步长锁定或动态解析
            let baseScale: Double?
            if let num = activeNum {
                if lockedBaseScale == nil {
                    lockedBaseScale = lastResolvedBaseScale
                }
                activeKeyboardMultiplier = Double(num)
                baseScale = lockedBaseScale
            } else {
                lockedBaseScale = nil
                activeKeyboardMultiplier = 1.0
                
                let radius = calculateRawRadius(points: scaledPoints)
                switch activeScaleConfig {
                case .fixed(let val):
                    baseScale = val
                case .zones(let zones):
                    baseScale = ScaleResolver.resolveHysteresis(radius: radius, zones: zones, currentZoneIndex: &currentZoneIndex)
                case .linear(let config):
                    baseScale = ScaleResolver.resolveLinear(radius: radius, config: config)
                }
                if let resolved = baseScale {
                    self.lastResolvedBaseScale = resolved
                }
            }

            // 3. 检查死区判定
            guard let activeBaseScale = baseScale else {
                // radius < minRadius, 进入死区：丢弃本帧变化，Overlay UI 变灰
                let displayVal = translator.displayValue
                overlayController.update(angle: currentAngle, displayValue: displayVal, isDeadzone: true)
                self.currentAngle = currentAngle
                previousAngle = currentAngle
                return
            }

            // 4. 读取系统面板灵敏度并合成最终步长倍率
            let globalSens = UserDefaults.standard.object(forKey: "globalSensitivity") as? Double ?? 0.5
            let settingsSensitivity: Double
            if let target = currentTarget {
                switch target.axRole {
                case "AXSlider":
                    settingsSensitivity = UserDefaults.standard.object(forKey: "sliderSensitivity") as? Double ?? globalSens
                case "AXProgressIndicator":
                    settingsSensitivity = UserDefaults.standard.object(forKey: "progressSensitivity") as? Double ?? globalSens
                default:
                    settingsSensitivity = globalSens
                }
            } else {
                settingsSensitivity = globalSens
            }

            let finalScale = activeBaseScale * activeKeyboardMultiplier * settingsSensitivity
            translator.scale = finalScale

            // 5. 注入翻译事件
            let knobState = KnobState(
                current: KnobCore(angle: currentAngle),
                previous: KnobCore(angle: previousAngle)
            )
            let deltaAngle = abs(knobState.deltaAngle)
            let direction: RotationDirection = knobState.deltaAngle >= 0 ? .clockwise : .counterClockwise

            translator.apply(units: deltaAngle, direction: direction)

            let displayVal = translator.displayValue
            overlayController.update(angle: currentAngle, displayValue: displayVal, isDeadzone: false)

            self.currentAngle = currentAngle
            previousAngle = currentAngle
        }
```
新增 `calculateRawRadius` 辅助方法并在末尾整合。

- [ ] **步骤 4:: 运行测试确认通过**

编译并运行全部已有单元测试，确认一切正常。
运行：`swift test`
预期：PASS

- [ ] **步骤 5:: Commit**

```bash
git add PhantomKnobDetector/Service/KnobStateManager.swift
git commit -m "feat: implement per-frame key polling via CGEventSource.keyState with scale-locking and settings sensitivity multiplier"
```
