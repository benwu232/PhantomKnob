# 动态修改调整步长（速度） 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现通过手指半径变化（支持多环迟滞和线性渐变）和辅助键盘数字键动态调整旋钮步长（速度）的特性，并支持单 Knob 专属定制。

**架构：**
1. 改造 `ScaleConfig` 及协议 `InputTranslator`，允许在手势运动中动态写入 `scale`。
2. 引入 `AppSettings` 处理 JSONC 加载与剥离注释。
3. 实现 `ScaleResolver`，提供 Hysteresis 迟滞多环状态机和 Linear 渐变解析。
4. 在 `KnobStateManager` 中，在 `.knobing` 状态下使用全局事件 tap 监听数字键 2-9 并将其与半径步长倍率进行乘数叠加。

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

在 `ControlRule.swift` 中修改 `ScaleConfig`：
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
    var linear: ScaleConfigLinear = ScaleConfigLinear(minRadius: 10.0, maxRadius: 20.0, minScale: 1.0, maxScale: 0.2)

    struct FixedSchemeConfig: Codable {
        var zones: [RadiusZone] = [
            RadiusZone(minRadius: 0.0, maxRadius: 12.0, margin: 2.0, scale: 1.0),
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

### 任务 2：实现半径步长求解器 `ScaleResolver`

**文件：**
- 创建：`PhantomKnobDetector/Service/ScaleResolver.swift`
- 测试：`PhantomKnobDetectorTests/ScaleResolverTests.swift`

- [ ] **步骤 1：编写 ScaleResolverTests 迟滞与线性测试**

```swift
// PhantomKnobDetectorTests/ScaleResolverTests.swift
import XCTest
@testable import PhantomKnobDetector

final class ScaleResolverTests: XCTestCase {
    func testHysteresisZones() {
        let zones = [
            RadiusZone(minRadius: 0.0, maxRadius: 12.0, margin: 2.0, scale: 1.0),
            RadiusZone(minRadius: 12.0, maxRadius: 100.0, margin: 2.0, scale: 0.2)
        ]
        
        var zoneIndex = 0
        
        // 初始留在 Zone 0
        XCTAssertEqual(ScaleResolver.resolveHysteresis(radius: 5.0, zones: zones, currentZoneIndex: &zoneIndex), 1.0)
        XCTAssertEqual(zoneIndex, 0)
        
        // 大于 max + margin (12 + 2 = 14) 才进入 Zone 1
        XCTAssertEqual(ScaleResolver.resolveHysteresis(radius: 13.0, zones: zones, currentZoneIndex: &zoneIndex), 1.0)
        XCTAssertEqual(zoneIndex, 0)
        
        XCTAssertEqual(ScaleResolver.resolveHysteresis(radius: 14.5, zones: zones, currentZoneIndex: &zoneIndex), 0.2)
        XCTAssertEqual(zoneIndex, 1)
        
        // 小于 min - margin (12 - 2 = 10) 才返回 Zone 0
        XCTAssertEqual(ScaleResolver.resolveHysteresis(radius: 11.0, zones: zones, currentZoneIndex: &zoneIndex), 0.2)
        XCTAssertEqual(zoneIndex, 1)
        
        XCTAssertEqual(ScaleResolver.resolveHysteresis(radius: 9.5, zones: zones, currentZoneIndex: &zoneIndex), 1.0)
        XCTAssertEqual(zoneIndex, 0)
    }

    func testLinearInterpolation() {
        let config = ScaleConfigLinear(minRadius: 10.0, maxRadius: 20.0, minScale: 1.0, maxScale: 0.2)
        
        XCTAssertEqual(ScaleResolver.resolveLinear(radius: 5.0, config: config), 1.0)
        XCTAssertEqual(ScaleResolver.resolveLinear(radius: 25.0, config: config), 0.2)
        XCTAssertEqual(ScaleResolver.resolveLinear(radius: 15.0, config: config), 0.6)
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
    static func resolveHysteresis(radius: Double, zones: [RadiusZone], currentZoneIndex: inout Int) -> Double {
        guard !zones.isEmpty else { return 1.0 }
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

    static func resolveLinear(radius: Double, config: ScaleConfigLinear) -> Double {
        if radius <= config.minRadius { return config.minScale }
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
git commit -m "feat: implement ScaleResolver hysteresis and linear resolvers with tests"
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
    var scale: Double { get set }  // 新增：动态步长缩放
}
```

在 `ArrowKeyTranslator.swift` 中修改：
```swift
final class ArrowKeyTranslator: InputTranslator {
    private let axis: Axis
    var scale: Double  // 改为 var

    init(axis: Axis = .upDown, scale: Double = 1.0) {
        self.axis = axis
        self.scale = scale
    }
    // ...其余逻辑不变
```

在 `ScrollWheelTranslator.swift` 中修改：
```swift
final class ScrollWheelTranslator: InputTranslator {
    private let axis: Axis
    var scale: Double  // 改为 var

    init(axis: Axis = .vertical, scale: Double = 1.0) {
        self.axis = axis
        self.scale = scale
    }
    // ...其余逻辑不变
```

在 `AXWriteTranslator.swift` 中修改：
```swift
final class AXWriteTranslator: InputTranslator {
    private let element: AXUIElement
    private let minValue: Double
    private let maxValue: Double
    var scale: Double  // 改为 var

    init(element: AXUIElement, minValue: Double, maxValue: Double, scale: Double = 1.0) {
        self.element = element
        self.minValue = minValue
        self.maxValue = maxValue
        self.scale = scale
    }
    // ...其余逻辑不变
```

- [ ] **步骤 4：运行所有已有测试验证通过**

运行：`swift test`
预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnobDetector/Control/InputTranslator.swift PhantomKnobDetector/Control/ArrowKeyTranslator.swift PhantomKnobDetector/Control/ScrollWheelTranslator.swift PhantomKnobDetector/Control/AXWriteTranslator.swift PhantomKnobDetectorTests/InputTranslationTests.swift
git commit -m "refactor: make scale mutable on InputTranslator protocol and implementing classes"
```

---

### 任务 4：全局键盘事件监控与 KnobStateManager 整合

**文件：**
- 修改：`PhantomKnobDetector/Service/KnobStateManager.swift`

- [ ] **步骤 1：集成配置查找与键盘事件监控**

在 `KnobStateManager.swift` 中增加以下私有属性：
```swift
    private var activeKeyboardMultiplier: Double = 1.0
    private var globalKeyboardMonitor: Any?
    private var currentZoneIndex: Int = 0
    private var activeScaleConfig: ScaleConfig = .fixed(1.0)
```

在 `onMultitouchBegan` 初始化该次手势的 ScaleConfig 与状态：
```swift
        // 查找匹配的 rule 并缓存对应的 ScaleConfig
        let rule = RuleLibrary.shared.lookup(for: target.ruleKey)
        let resolvedScaleConfig: ScaleConfig
        if let ruleScaleConfig = rule?.scaleConfig {
            switch ruleScaleConfig {
            case .fixed(let val):
                // 如果是旧版单值 fixed(1.0)，代表使用全局默认配置；否则使用单 Knob 的个性化配置
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
            // 回退全局默认
            resolvedScaleConfig = AppSettings.shared.activeScheme == "linear"
                ? .linear(AppSettings.shared.linear)
                : .zones(AppSettings.shared.fixed.zones)
        }
        self.activeScaleConfig = resolvedScaleConfig
        self.currentZoneIndex = 0
```

增加键盘监听开启与重置方法：
```swift
    private func startKeyboardMonitoring() {
        guard AppSettings.shared.enableKeyboardNumberMultiplier, globalKeyboardMonitor == nil else { return }
        
        globalKeyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self = self else { return }
            if event.type == .keyDown {
                if let chars = event.characters, chars.count == 1,
                   let num = Int(chars), num >= 2 && num <= 9 {
                    self.activeKeyboardMultiplier = Double(num)
                    writeDebugLog("[KnobStateManager] Keyboard multiplier set to: \(self.activeKeyboardMultiplier)")
                }
            } else if event.type == .keyUp {
                if let chars = event.characters, chars.count == 1,
                   let num = Int(chars), Double(num) == self.activeKeyboardMultiplier {
                    self.activeKeyboardMultiplier = 1.0
                    writeDebugLog("[KnobStateManager] Keyboard multiplier reset to 1.0")
                }
            }
        }
    }

    private func stopKeyboardMonitoring() {
        if let monitor = globalKeyboardMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyboardMonitor = nil
        }
        activeKeyboardMultiplier = 1.0
    }
```

- [ ] **步骤 2：在 transition 方法中整合监控器生命周期**

在 `transition(to newState: KnobGlobalState)` 方法中：
```swift
        state = newState
        if case .knobing = newState {
            startKeyboardMonitoring()
        } else if case .inactive = newState {
            stopKeyboardMonitoring()
        } else if case .activated = newState {
            stopKeyboardMonitoring()
        }
        // ...其余逻辑不变
```

- [ ] **步骤 3：在 onMultitouchMoved 中动态更新步长倍率**

在 `onMultitouchMoved` 获取到最新 radius 后，求解基础步长并写入 translator：
```swift
        // 🌟 在 apply 前，解析当前的 baseScale
        let radius = calculateRawRadius(points: scaledPoints)
        let baseScale: Double
        switch activeScaleConfig {
        case .fixed(let val):
            baseScale = val
        case .zones(let zones):
            baseScale = ScaleResolver.resolveHysteresis(radius: radius, zones: zones, currentZoneIndex: &currentZoneIndex)
        case .linear(let config):
            baseScale = ScaleResolver.resolveLinear(radius: radius, config: config)
        }
        
        let finalScale = baseScale * activeKeyboardMultiplier
        translator.scale = finalScale
```
其中需要添加一个辅助方法 `calculateRawRadius` 求解当前半径：
```swift
    private func calculateRawRadius(points: [Int: CGPoint]) -> Double {
        if points.count >= 2 {
            let (knobCore, _, _) = KnobAlgorithm().calKnob(points)
            return knobCore.isValid ? knobCore.radius : 0.0
        }
        return 0.0
    }
```

- [ ] **步骤 4：运行测试确认通过**

编译并运行全部已有单元测试，确认一切正常。
运行：`swift test`
预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnobDetector/Service/KnobStateManager.swift
git commit -m "feat: integrate dynamic scale resolver and keyboard multiplier monitoring in KnobStateManager"
```
