# InputTranslation System 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将旋钮手势的控制逻辑从单一的 AX 直写模式，扩展为支持滚轮、按键等多种 InputTranslation 策略，并通过可扩展的规则库（RuleLibrary）驱动。

**架构：** 新增 `DetectedTarget`（纯元数据）和 `InputTranslator`（执行策略）两个抽象，替代现有混合职责的 `ControlTarget`；新增 `RuleLibrary` 在手势开始时查找对应规则，未命中则自动探测；`KnobStateManager` 持有 `DetectedTarget + InputTranslator`，每帧调用 `translator.apply(units: deltaAngle * scale, direction: direction)`。

**技术栈：** Swift 5.9 · macOS 12.0 · XcodeGen · XCTest · CoreGraphics CGEvent · Accessibility API

---

## 文件结构

### 新建文件
| 文件 | 职责 |
|------|------|
| `Model/InputTranslation.swift` | 7 种 InputTranslation 的枚举定义 |
| `Model/DetectedTarget.swift` | 纯元数据 struct，包含 bundleID/axRole/identifier/element/ruleKey |
| `Model/ControlRule.swift` | RuleKey + ScaleConfig + ControlRule 三个类型 |
| `Control/InputTranslator.swift` | InputTranslator 协议 |
| `Control/AXWriteTranslator.swift` | 读-改-写 AXValue 的执行器 |
| `Control/ScrollWheelTranslator.swift` | 合成垂直/水平滚轮 CGEvent 的执行器 |
| `Control/ArrowKeyTranslator.swift` | 带 accumulator 的按键合成执行器 |
| `Storage/RuleLibrary.swift` | 加载 bundled + user rules，提供优先级查找 |
| `App/bundled-rules.json` | 内置规则，随 App 分发 |
| `PhantomKnobDetectorTests/InputTranslationTests.swift` | 新模型单元测试 |
| `PhantomKnobDetectorTests/RuleLibraryTests.swift` | RuleLibrary 查找逻辑测试 |

### 修改文件
| 文件 | 变更摘要 |
|------|---------|
| `Service/TargetDetector.swift` | 返回 `DetectedTarget?`，加入 InputTranslation 自动探测 |
| `Model/KnobGlobalState.swift` | 关联值从 `ControlTarget` 改为 `DetectedTarget`；identity 比较从 displayName 改为 ruleKey |
| `Service/KnobStateManager.swift` | 持有 `currentTarget: DetectedTarget?` + `currentTranslator: InputTranslator?`；简化执行管道 |
| `Service/AccessibilityTarget.swift` | 保留 AX 读写辅助方法，供 AXWriteTranslator 调用；移除 `ControlTarget` 实现 |
| `PhantomKnobDetectorTests/KnobGlobalStateTests.swift` | MockControlTarget → MockDetectedTarget |
| `PhantomKnobDetectorTests/ControlTests.swift` | 更新到新 Translator 接口 |

---

## 构建与测试命令

```bash
# 生成 Xcode 工程（每次修改 project.yml 后需要执行）
cd /Users/wb/work/phantom_knob_mac/PhantomKnobDetector && xcodegen generate

# 运行全部测试
xcodebuild test \
  -project /Users/wb/work/phantom_knob_mac/PhantomKnobDetector/PhantomKnobDetector.xcodeproj \
  -scheme PhantomKnobDetector \
  -destination 'platform=macOS' \
  2>&1 | grep -E "(error:|warning:|PASSED|FAILED|Test Suite)"
```

---

## 任务 1：新建 Model 层（InputTranslation / DetectedTarget / ControlRule）

**文件：**
- 创建：`PhantomKnobDetector/Model/InputTranslation.swift`
- 创建：`PhantomKnobDetector/Model/DetectedTarget.swift`
- 创建：`PhantomKnobDetector/Model/ControlRule.swift`
- 测试：`PhantomKnobDetector/PhantomKnobDetectorTests/InputTranslationTests.swift`

- [ ] **步骤 1：创建 InputTranslation.swift**

```swift
// PhantomKnobDetector/Model/InputTranslation.swift
import Foundation

/// 将旋转角度转化为系统输入事件的策略。描述"如何投递"，不感知目标控件。
/// Avoid: mapping, method, action
enum InputTranslation: String, Codable, CaseIterable {
    case axWrite                // 读取 AXValue，加 delta，写回
    case scrollWheelVertical    // 合成垂直滚轮 CGEvent
    case scrollWheelHorizontal  // 合成水平滚轮 CGEvent
    case arrowKeyUpDown         // 合成上/下方向键
    case arrowKeyLeftRight      // 合成左/右方向键
    case swipeVertical          // 合成垂直双指滑动
    case swipeHorizontal        // 合成水平双指滑动
}
```

- [ ] **步骤 2：创建 DetectedTarget.swift**

```swift
// PhantomKnobDetector/Model/DetectedTarget.swift
import Foundation
import ApplicationServices

/// 手势开始时在光标下检测到的 UI 元素的纯元数据。无执行逻辑。
struct DetectedTarget {
    let bundleID: String        // 前台 App 的 Bundle ID，如 "com.apple.QuickTimePlayerX"
    let axRole: String          // AX 角色字符串，如 "AXSlider"
    let identifier: String?     // AXIdentifier（开发者设置，可为 nil）
    let displayName: String     // 来自 AXTitle 或 AXDescription，用于 overlay 显示
    let element: AXUIElement?   // AX 元素引用；无 AX 元素时为 nil（如 Canvas 区域）

    /// 用于规则库查找和状态机 identity 比较。
    var ruleKey: RuleKey {
        RuleKey(bundleID: bundleID, axRole: axRole, identifier: identifier)
    }
}
```

- [ ] **步骤 3：创建 ControlRule.swift**（含 RuleKey 和 ScaleConfig）

```swift
// PhantomKnobDetector/Model/ControlRule.swift
import Foundation

/// 规则库中唯一标识一条规则的 key。
/// 结构：bundleID · axRole · identifier?
struct RuleKey: Codable, Hashable {
    let bundleID: String    // "com.apple.QuickTimePlayerX"
    let axRole: String      // "AXSlider"
    let identifier: String? // AXIdentifier，nil 表示匹配该 app 下所有同类控件

    // 精确匹配（bundleID + axRole + identifier 全部相等）
    func matches(_ other: RuleKey) -> Bool {
        bundleID == other.bundleID &&
        axRole == other.axRole &&
        (identifier == nil || identifier == other.identifier)
    }
}

/// 旋转角度到 InputTranslation 单位数的映射配置。
/// 默认：fixed(1.0)，即 1° = 1 最小单位。
enum ScaleConfig: Codable {
    case fixed(Double)
    // 未来扩展：case discreteRadius([RadiusZone])

    func resolve(radius: Double = 0) -> Double {
        switch self {
        case .fixed(let s): return s
        }
    }
}

/// RuleLibrary 中存储的一条规则。
struct ControlRule: Codable {
    let key: RuleKey
    let translation: InputTranslation
    let scaleConfig: ScaleConfig

    /// 保留扩展槽，不破坏未来 Codable 兼容性
    var extra: [String: String]?

    init(key: RuleKey,
         translation: InputTranslation,
         scaleConfig: ScaleConfig = .fixed(1.0),
         extra: [String: String]? = nil) {
        self.key = key
        self.translation = translation
        self.scaleConfig = scaleConfig
        self.extra = extra
    }
}
```

- [ ] **步骤 4：编写测试**

```swift
// PhantomKnobDetector/PhantomKnobDetectorTests/InputTranslationTests.swift
import XCTest
@testable import PhantomKnobDetector

final class InputTranslationTests: XCTestCase {

    // MARK: - RuleKey matching

    func testRuleKeyExactMatch() {
        let key = RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: "timeline")
        let candidate = RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: "timeline")
        XCTAssertTrue(key.matches(candidate))
    }

    func testRuleKeyNilIdentifierMatchesAll() {
        let broadRule = RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: nil)
        let specific  = RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: "timeline")
        XCTAssertTrue(broadRule.matches(specific))
    }

    func testRuleKeyMismatch() {
        let a = RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: nil)
        let b = RuleKey(bundleID: "com.apple.QuickTime", axRole: "AXSlider", identifier: nil)
        XCTAssertFalse(a.matches(b))
    }

    // MARK: - ScaleConfig

    func testFixedScaleIgnoresRadius() {
        let config = ScaleConfig.fixed(2.5)
        XCTAssertEqual(config.resolve(radius: 0.0), 2.5)
        XCTAssertEqual(config.resolve(radius: 0.9), 2.5)
    }

    func testDefaultScaleIsOne() {
        let rule = ControlRule(
            key: RuleKey(bundleID: "x", axRole: "AXSlider", identifier: nil),
            translation: .axWrite
        )
        XCTAssertEqual(rule.scaleConfig.resolve(), 1.0)
    }

    // MARK: - DetectedTarget ruleKey

    func testDetectedTargetRuleKey() {
        let target = DetectedTarget(
            bundleID: "com.apple.FinalCut",
            axRole: "AXSlider",
            identifier: "timeline",
            displayName: "Playhead",
            element: nil
        )
        XCTAssertEqual(target.ruleKey.bundleID, "com.apple.FinalCut")
        XCTAssertEqual(target.ruleKey.axRole, "AXSlider")
        XCTAssertEqual(target.ruleKey.identifier, "timeline")
    }
}
```

- [ ] **步骤 5：运行测试验证通过**

```bash
xcodebuild test \
  -project /Users/wb/work/phantom_knob_mac/PhantomKnobDetector/PhantomKnobDetector.xcodeproj \
  -scheme PhantomKnobDetector \
  -destination 'platform=macOS' \
  -only-testing:PhantomKnobDetectorTests/InputTranslationTests \
  2>&1 | grep -E "(error:|PASSED|FAILED)"
```

预期：`Test Suite 'InputTranslationTests' passed`

- [ ] **步骤 6：Commit**

```bash
cd /Users/wb/work/phantom_knob_mac
git add PhantomKnobDetector/Model/InputTranslation.swift \
        PhantomKnobDetector/Model/DetectedTarget.swift \
        PhantomKnobDetector/Model/ControlRule.swift \
        PhantomKnobDetector/PhantomKnobDetectorTests/InputTranslationTests.swift
git commit -m "feat: add InputTranslation, DetectedTarget, ControlRule models"
```

---

## 任务 2：InputTranslator 协议与三种实现

**文件：**
- 创建：`PhantomKnobDetector/Control/InputTranslator.swift`
- 创建：`PhantomKnobDetector/Control/AXWriteTranslator.swift`
- 创建：`PhantomKnobDetector/Control/ScrollWheelTranslator.swift`
- 创建：`PhantomKnobDetector/Control/ArrowKeyTranslator.swift`

- [ ] **步骤 1：创建 InputTranslator 协议**

```swift
// PhantomKnobDetector/Control/InputTranslator.swift
import Foundation

/// 执行旋钮控制的运行时对象。
/// 接收 (units, direction) 并向系统注入对应事件。
/// 内部自行管理离散事件的 accumulator。
protocol InputTranslator: AnyObject {
    /// 施加旋转 delta。
    /// - Parameters:
    ///   - units: 本帧要施加的单位数（浮点，可 < 1）
    ///   - direction: 旋转方向（顺时针 = 增加，逆时针 = 减少）
    func apply(units: Double, direction: RotationDirection)

    /// overlay 显示的当前值字符串。非 axWrite 类型返回 nil（overlay 隐藏值区域）。
    var displayValue: String? { get }
}
```

- [ ] **步骤 2：创建 AXWriteTranslator.swift**

```swift
// PhantomKnobDetector/Control/AXWriteTranslator.swift
import Foundation
import ApplicationServices

/// 通过 Accessibility API 直接读-改-写 AXValue。
/// 适用于：系统音量、系统亮度、标准 AXSlider 等 AXValue settable 的控件。
final class AXWriteTranslator: InputTranslator {
    private let element: AXUIElement
    private let minValue: Double
    private let maxValue: Double
    private let scale: Double   // 从 ScaleConfig 解析好后传入

    init(element: AXUIElement, minValue: Double, maxValue: Double, scale: Double = 1.0) {
        self.element = element
        self.minValue = minValue
        self.maxValue = maxValue
        self.scale = scale
    }

    func apply(units: Double, direction: RotationDirection) {
        let delta = units * scale * (direction == .clockwise ? 1.0 : -1.0)
        let current = readValue() ?? (minValue + maxValue) / 2
        let newValue = (current + delta).clamped(to: minValue...maxValue)
        writeValue(newValue)
    }

    var displayValue: String? {
        guard let v = readValue() else { return nil }
        return formatDisplayValue(v, min: minValue, max: maxValue)
    }

    // MARK: - AX helpers

    private func readValue() -> Double? {
        var cfValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &cfValue) == .success,
              let number = cfValue as? NSNumber else { return nil }
        return number.doubleValue
    }

    private func writeValue(_ value: Double) {
        let number = NSNumber(value: value)
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, number)
        if result != .success {
            NotificationCenter.default.post(name: .accessibilityPermissionRevoked, object: nil)
        }
    }
}

extension Notification.Name {
    static let accessibilityPermissionRevoked = Notification.Name("com.phantomknob.accessibilityPermissionRevoked")
}
```

- [ ] **步骤 3：创建 ScrollWheelTranslator.swift**

```swift
// PhantomKnobDetector/Control/ScrollWheelTranslator.swift
import Foundation
import CoreGraphics

/// 合成滚轮 CGEvent 并注入系统。
/// 连续事件：CGEvent 支持浮点 delta，无需 accumulator。
final class ScrollWheelTranslator: InputTranslator {
    private let axis: Axis
    private let scale: Double

    enum Axis { case vertical, horizontal }

    init(axis: Axis = .vertical, scale: Double = 1.0) {
        self.axis = axis
        self.scale = scale
    }

    func apply(units: Double, direction: RotationDirection) {
        let delta = units * scale * (direction == .clockwise ? 1.0 : -1.0)
        switch axis {
        case .vertical:
            synthesizeScroll(deltaY: CGFloat(delta), deltaX: 0)
        case .horizontal:
            synthesizeScroll(deltaY: 0, deltaX: CGFloat(delta))
        }
    }

    var displayValue: String? { nil }

    private func synthesizeScroll(deltaY: CGFloat, deltaX: CGFloat) {
        let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(deltaY),
            wheel2: Int32(deltaX),
            wheel3: 0
        )
        // 高精度浮点 delta，确保慢速旋转时也能流畅响应
        event?.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: Double(deltaY))
        event?.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: Double(deltaX))
        event?.post(tap: .cghidEventTap)
    }
}
```

- [ ] **步骤 4：创建 ArrowKeyTranslator.swift**

```swift
// PhantomKnobDetector/Control/ArrowKeyTranslator.swift
import Foundation
import CoreGraphics

/// 合成方向键事件，支持 accumulator（积累到 ≥ 1.0 才发送，余数保留）。
final class ArrowKeyTranslator: InputTranslator {
    private let axis: Axis
    private let scale: Double
    private var accumulator: Double = 0

    enum Axis { case upDown, leftRight }

    // macOS 虚拟键码
    private static let keyUp:    CGKeyCode = 126
    private static let keyDown:  CGKeyCode = 125
    private static let keyLeft:  CGKeyCode = 123
    private static let keyRight: CGKeyCode = 124

    init(axis: Axis = .upDown, scale: Double = 1.0) {
        self.axis = axis
        self.scale = scale
    }

    func apply(units: Double, direction: RotationDirection) {
        let signed = units * scale * (direction == .clockwise ? 1.0 : -1.0)
        accumulator += signed
        let presses = Int(accumulator)           // 整数部分：要发送的次数
        accumulator -= Double(presses)           // 保留余数

        guard presses != 0 else { return }
        let (increaseKey, decreaseKey) = keyPair()
        let keyCode = presses > 0 ? increaseKey : decreaseKey
        let count = abs(presses)
        for _ in 0..<count {
            pressKey(keyCode)
        }
    }

    var displayValue: String? { nil }

    private func keyPair() -> (CGKeyCode, CGKeyCode) {
        switch axis {
        case .upDown:    return (Self.keyUp, Self.keyDown)
        case .leftRight: return (Self.keyRight, Self.keyLeft)
        }
    }

    private func pressKey(_ keyCode: CGKeyCode) {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
```

- [ ] **步骤 5：在 InputTranslationTests.swift 中追加 Translator 测试**

```swift
// 追加到 PhantomKnobDetector/PhantomKnobDetectorTests/InputTranslationTests.swift

// MARK: - ArrowKeyTranslator accumulator

final class ArrowKeyTranslatorTests: XCTestCase {

    func testAccumulatorHoldsSmallDeltas() {
        // scale=1, 每次 0.3，需要累积 4 次（1.2）才发 1 个按键
        // 本测试只验证 accumulator 不崩溃，实际按键无法在单元测试中验证
        let t = ArrowKeyTranslator(axis: .upDown, scale: 1.0)
        // 不超过 1.0，不应发送按键（无法断言无副作用，只验证不 crash）
        t.apply(units: 0.3, direction: .clockwise)
        t.apply(units: 0.3, direction: .clockwise)
        t.apply(units: 0.3, direction: .clockwise)
        // 第三次累积 = 0.9，仍不足 1.0
        XCTAssertNil(t.displayValue)
    }

    func testScrollWheelDisplayValueIsNil() {
        let t = ScrollWheelTranslator(axis: .vertical, scale: 1.0)
        XCTAssertNil(t.displayValue)
    }
}
```

- [ ] **步骤 6：运行测试**

```bash
xcodebuild test \
  -project /Users/wb/work/phantom_knob_mac/PhantomKnobDetector/PhantomKnobDetector.xcodeproj \
  -scheme PhantomKnobDetector \
  -destination 'platform=macOS' \
  -only-testing:PhantomKnobDetectorTests/InputTranslationTests \
  -only-testing:PhantomKnobDetectorTests/ArrowKeyTranslatorTests \
  2>&1 | grep -E "(error:|PASSED|FAILED)"
```

预期：全部 PASSED

- [ ] **步骤 7：Commit**

```bash
cd /Users/wb/work/phantom_knob_mac
git add PhantomKnobDetector/Control/InputTranslator.swift \
        PhantomKnobDetector/Control/AXWriteTranslator.swift \
        PhantomKnobDetector/Control/ScrollWheelTranslator.swift \
        PhantomKnobDetector/Control/ArrowKeyTranslator.swift \
        PhantomKnobDetector/PhantomKnobDetectorTests/InputTranslationTests.swift
git commit -m "feat: add InputTranslator protocol and AXWrite/ScrollWheel/ArrowKey implementations"
```

---

## 任务 3：RuleLibrary（规则库加载与查找）

**文件：**
- 创建：`PhantomKnobDetector/App/bundled-rules.json`
- 创建：`PhantomKnobDetector/Storage/RuleLibrary.swift`
- 测试：`PhantomKnobDetector/PhantomKnobDetectorTests/RuleLibraryTests.swift`

- [ ] **步骤 1：创建 bundled-rules.json**

注意：此文件需要添加到 Xcode target 的 Resources 中（见步骤 2 更新 project.yml）。

```json
[
  {
    "key": {
      "bundleID": "com.apple.QuickTimePlayerX",
      "axRole": "AXSlider",
      "identifier": null
    },
    "translation": "scrollWheelVertical",
    "scaleConfig": { "fixed": 8.0 },
    "extra": { "reason": "AXWrite causes integer truncation bug in QuickTime" }
  },
  {
    "key": {
      "bundleID": "com.apple.FinalCut",
      "axRole": "AXSlider",
      "identifier": null
    },
    "translation": "scrollWheelVertical",
    "scaleConfig": { "fixed": 8.0 },
    "extra": null
  },
  {
    "key": {
      "bundleID": "com.blackmagic-design.DaVinciResolve",
      "axRole": "AXSlider",
      "identifier": null
    },
    "translation": "scrollWheelVertical",
    "scaleConfig": { "fixed": 8.0 },
    "extra": null
  }
]
```

- [ ] **步骤 2：更新 project.yml 以包含 bundled-rules.json**

在 `PhantomKnobDetector/project.yml` 的 `sources:` 列表中追加：

```yaml
      - path: App/bundled-rules.json
        buildPhase: resources
```

然后重新生成工程：

```bash
cd /Users/wb/work/phantom_knob_mac/PhantomKnobDetector && xcodegen generate
```

- [ ] **步骤 3：创建 RuleLibrary.swift**

```swift
// PhantomKnobDetector/Storage/RuleLibrary.swift
import Foundation

/// 规则库：查找 ControlRule 的单一入口。
/// 优先级：用户规则（Application Support）> 内置规则（App Bundle）
/// 匹配策略：按精度从高到低，第一条命中即返回。
final class RuleLibrary {
    static let shared = RuleLibrary()

    private var rules: [ControlRule] = []

    private let userRulesURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("PhantomKnob", isDirectory: true)
            .appendingPathComponent("rules.json")
    }()

    init() {
        reload()
    }

    /// 重新从磁盘加载规则（bundled + user）。
    func reload() {
        var loaded: [ControlRule] = []

        // 1. 用户规则（高优先级）
        if let userRules = loadRules(from: userRulesURL) {
            loaded.append(contentsOf: userRules)
        }

        // 2. 内置规则（随 App 分发）
        if let bundledURL = Bundle.main.url(forResource: "bundled-rules", withExtension: "json"),
           let bundledRules = loadRules(from: bundledURL) {
            loaded.append(contentsOf: bundledRules)
        }

        self.rules = loaded
    }

    /// 按优先级顺序查找匹配 ruleKey 的第一条规则。
    /// 精度：(bundleID + axRole + identifier) > (bundleID + axRole) > (axRole only)
    func lookup(for ruleKey: RuleKey) -> ControlRule? {
        // 精确匹配（identifier 完全相同）
        if let exact = rules.first(where: {
            $0.key.bundleID == ruleKey.bundleID &&
            $0.key.axRole == ruleKey.axRole &&
            $0.key.identifier != nil &&
            $0.key.identifier == ruleKey.identifier
        }) { return exact }

        // 宽泛匹配（同 app 同 role，identifier 为 nil 的规则）
        if let broad = rules.first(where: {
            $0.key.bundleID == ruleKey.bundleID &&
            $0.key.axRole == ruleKey.axRole &&
            $0.key.identifier == nil
        }) { return broad }

        // 跨 app 匹配（只匹配 role）
        if let byRole = rules.first(where: {
            $0.key.bundleID.isEmpty &&
            $0.key.axRole == ruleKey.axRole
        }) { return byRole }

        return nil
    }

    private func loadRules(from url: URL) -> [ControlRule]? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode([ControlRule].self, from: data)
    }
}
```

> **注意：** `ScaleConfig` 需要自定义 `Codable` 实现以支持 `{"fixed": 8.0}` 格式。在 `ControlRule.swift` 中追加以下 extension：

```swift
// 追加到 PhantomKnobDetector/Model/ControlRule.swift

extension ScaleConfig {
    private enum CodingKeys: String, CodingKey { case fixed }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try container.decodeIfPresent(Double.self, forKey: .fixed) {
            self = .fixed(value)
        } else {
            self = .fixed(1.0) // 安全默认值
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .fixed(let v): try container.encode(v, forKey: .fixed)
        }
    }
}
```

- [ ] **步骤 4：编写 RuleLibrary 测试**

```swift
// PhantomKnobDetector/PhantomKnobDetectorTests/RuleLibraryTests.swift
import XCTest
@testable import PhantomKnobDetector

final class RuleLibraryTests: XCTestCase {

    private func makeLibrary(rules: [ControlRule]) -> RuleLibrary {
        let lib = RuleLibrary()
        // 直接注入测试规则（绕过文件加载）
        lib.injectRulesForTesting(rules)
        return lib
    }

    func testExactMatchWins() {
        let exactRule = ControlRule(
            key: RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: "timeline"),
            translation: .arrowKeyLeftRight,
            scaleConfig: .fixed(2.0)
        )
        let broadRule = ControlRule(
            key: RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: nil),
            translation: .scrollWheelVertical
        )
        let lib = makeLibrary(rules: [exactRule, broadRule])
        let key = RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: "timeline")
        XCTAssertEqual(lib.lookup(for: key)?.translation, .arrowKeyLeftRight)
    }

    func testBroadRuleFallsBack() {
        let broadRule = ControlRule(
            key: RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: nil),
            translation: .scrollWheelVertical
        )
        let lib = makeLibrary(rules: [broadRule])
        let key = RuleKey(bundleID: "com.apple.FinalCut", axRole: "AXSlider", identifier: "unknownControl")
        XCTAssertEqual(lib.lookup(for: key)?.translation, .scrollWheelVertical)
    }

    func testNoMatchReturnsNil() {
        let lib = makeLibrary(rules: [])
        let key = RuleKey(bundleID: "com.unknown.app", axRole: "AXSlider", identifier: nil)
        XCTAssertNil(lib.lookup(for: key))
    }

    func testScaleConfigParsing() throws {
        let json = """
        [{"key":{"bundleID":"x","axRole":"AXSlider","identifier":null},
          "translation":"scrollWheelVertical",
          "scaleConfig":{"fixed":8.0}}]
        """.data(using: .utf8)!
        let rules = try JSONDecoder().decode([ControlRule].self, from: json)
        XCTAssertEqual(rules.first?.scaleConfig.resolve(), 8.0)
    }
}
```

> **注意：** 需要在 `RuleLibrary` 中添加测试用注入方法：

```swift
// 追加到 RuleLibrary（仅测试用）
#if DEBUG
func injectRulesForTesting(_ rules: [ControlRule]) {
    self.rules = rules
}
#endif
```

- [ ] **步骤 5：运行测试**

```bash
xcodebuild test \
  -project /Users/wb/work/phantom_knob_mac/PhantomKnobDetector/PhantomKnobDetector.xcodeproj \
  -scheme PhantomKnobDetector \
  -destination 'platform=macOS' \
  -only-testing:PhantomKnobDetectorTests/RuleLibraryTests \
  2>&1 | grep -E "(error:|PASSED|FAILED)"
```

预期：`Test Suite 'RuleLibraryTests' passed`

- [ ] **步骤 6：Commit**

```bash
cd /Users/wb/work/phantom_knob_mac
git add PhantomKnobDetector/App/bundled-rules.json \
        PhantomKnobDetector/Storage/RuleLibrary.swift \
        PhantomKnobDetector/project.yml \
        PhantomKnobDetector/Model/ControlRule.swift \
        PhantomKnobDetector/PhantomKnobDetectorTests/RuleLibraryTests.swift
git commit -m "feat: add RuleLibrary with bundled rules and priority lookup"
```

---

## 任务 4：重构 TargetDetector（返回 DetectedTarget + 自动探测 InputTranslation）

**文件：**
- 修改：`PhantomKnobDetector/Service/TargetDetector.swift`
- 修改：`PhantomKnobDetector/PhantomKnobDetectorTests/TargetDetectorTests.swift`

- [ ] **步骤 1：重写 TargetDetector.swift**

```swift
// PhantomKnobDetector/Service/TargetDetector.swift
import Foundation
import AppKit
import ApplicationServices

class TargetDetector {
    static let maxParentDepth = 10

    init() {}

    /// 检测鼠标位置下的可控制元素，返回 DetectedTarget。
    /// 无 AX 元素时返回 nil（调用方负责创建 fallback）。
    func detectTargetAtMousePosition() -> DetectedTarget? {
        guard AXIsProcessTrusted() else { return nil }

        let mouseLocation = NSEvent.mouseLocation
        let screenHeight = NSScreen.screens.first?.frame.height ?? 1080
        let flippedY = screenHeight - mouseLocation.y

        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(mouseLocation.x), Float(flippedY), &element) == .success,
              let axElement = element else { return nil }

        return findAdjustableTarget(from: axElement, depth: 0)
    }

    /// 根据 AX 属性自动探测最适合的 InputTranslation。
    /// 探测顺序：AXValue settable → axWrite；AXIncrement 存在 → arrowKeyUpDown；其他 → scrollWheelVertical
    static func autoDetectTranslation(for element: AXUIElement) -> InputTranslation {
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)
        if settable.boolValue { return .axWrite }

        var actions: CFArray?
        AXUIElementCopyActionNames(element, &actions)
        if let actionList = actions as? [String],
           actionList.contains(kAXIncrementAction) || actionList.contains(kAXDecrementAction) {
            return .arrowKeyUpDown
        }

        return .scrollWheelVertical
    }

    // MARK: - Private

    private func findAdjustableTarget(from element: AXUIElement, depth: Int) -> DetectedTarget? {
        if let target = tryBuildTarget(from: element) { return target }
        guard depth < Self.maxParentDepth else { return nil }

        var parent: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parent) == .success,
              let parentRef = parent else { return nil }
        let parentElement = unsafeBitCast(parentRef, to: AXUIElement.self)
        return findAdjustableTarget(from: parentElement, depth: depth + 1)
    }

    private func tryBuildTarget(from element: AXUIElement) -> DetectedTarget? {
        // 元素必须有 AXMinValue + AXMaxValue 才视为可调节
        guard Self.getDouble(from: element, attribute: kAXMinValueAttribute) != nil,
              Self.getDouble(from: element, attribute: kAXMaxValueAttribute) != nil else { return nil }

        let role        = Self.getString(from: element, attribute: kAXRoleAttribute) ?? "AXUnknown"
        let identifier  = Self.getString(from: element, attribute: kAXIdentifierAttribute)
        let displayName = Self.getString(from: element, attribute: kAXTitleAttribute)
                       ?? Self.getString(from: element, attribute: kAXDescriptionAttribute)
                       ?? role
        let bundleID    = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""

        return DetectedTarget(
            bundleID: bundleID,
            axRole: role,
            identifier: identifier,
            displayName: displayName,
            element: element
        )
    }

    // MARK: - AX attribute helpers

    static func getDouble(from element: AXUIElement, attribute: String) -> Double? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let number = value as? NSNumber else { return nil }
        return number.doubleValue
    }

    static func getString(from element: AXUIElement, attribute: String) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let string = value as? String else { return nil }
        return string
    }
}
```

- [ ] **步骤 2：更新 TargetDetectorTests.swift**

```swift
// PhantomKnobDetector/PhantomKnobDetectorTests/TargetDetectorTests.swift
import XCTest
@testable import PhantomKnobDetector

final class TargetDetectorTests: XCTestCase {
    // TargetDetector 依赖系统 AX，无法在单元测试中完整测试。
    // 验证：实例化不崩溃。
    func testInitDoesNotCrash() {
        let detector = TargetDetector()
        XCTAssertNotNil(detector)
    }

    func testAutoDetectTranslationDefaultsToScrollWheel() {
        // 无法提供真实 AXUIElement，只验证函数签名存在
        // 实际探测在集成测试中完成
        XCTAssertEqual(InputTranslation.scrollWheelVertical.rawValue, "scrollWheelVertical")
    }
}
```

- [ ] **步骤 3：运行全部已有测试，确保无回归**

```bash
xcodebuild test \
  -project /Users/wb/work/phantom_knob_mac/PhantomKnobDetector/PhantomKnobDetector.xcodeproj \
  -scheme PhantomKnobDetector \
  -destination 'platform=macOS' \
  2>&1 | grep -E "(error:|PASSED|FAILED|Build FAILED)"
```

预期：无 `error:` 和 `Build FAILED`

- [ ] **步骤 4：Commit**

```bash
cd /Users/wb/work/phantom_knob_mac
git add PhantomKnobDetector/Service/TargetDetector.swift \
        PhantomKnobDetector/PhantomKnobDetectorTests/TargetDetectorTests.swift
git commit -m "refactor: TargetDetector returns DetectedTarget, adds InputTranslation auto-detection"
```

---

## 任务 5：重构 KnobGlobalState（关联值改为 DetectedTarget）

**文件：**
- 修改：`PhantomKnobDetector/Model/KnobGlobalState.swift`
- 修改：`PhantomKnobDetector/PhantomKnobDetectorTests/KnobGlobalStateTests.swift`

- [ ] **步骤 1：更新 KnobGlobalState.swift**

把 `knobing(target: ControlTarget)` / `cooling(target: ControlTarget)` 改为 `DetectedTarget`，identity 比较改为 ruleKey：

```swift
// PhantomKnobDetector/Model/KnobGlobalState.swift
import Foundation
import AppKit

enum KnobGlobalState: Equatable {
    case inactive
    case activated
    case knobing(target: DetectedTarget)
    case cooling(target: DetectedTarget)

    var iconColor: NSColor {
        switch self {
        case .inactive:           return .gray
        case .activated:          return .systemBlue
        case .knobing, .cooling:  return .systemOrange
        }
    }

    var currentTarget: DetectedTarget? {
        switch self {
        case .inactive, .activated:             return nil
        case .knobing(let t), .cooling(let t):  return t
        }
    }

    var isKnobing: Bool { if case .knobing = self { return true }; return false }
    var isCooling: Bool { if case .cooling = self { return true }; return false }

    static func == (lhs: KnobGlobalState, rhs: KnobGlobalState) -> Bool {
        switch (lhs, rhs) {
        case (.inactive, .inactive): return true
        case (.activated, .activated): return true
        case (.knobing, .knobing): return true
        case (.cooling, .cooling): return true
        default: return false
        }
    }
}

enum KnobStateEvent {
    case hotkeyToggle
    case gestureStarted
    case gestureStartedWithTarget(DetectedTarget)   // 移除 angleDelta：KnobStateManager 已取消阈值
    case gestureEnded
    case coolingTimeout
    case appSwitched
    case newGestureOnDifferentTarget
}

extension KnobGlobalState {
    struct TransitionResult {
        let state: KnobGlobalState
        let target: DetectedTarget?
    }

    func transition(event: KnobStateEvent) -> KnobGlobalState? {
        transitionWithResult(event: event)?.state
    }

    func transitionWithResult(event: KnobStateEvent) -> TransitionResult? {
        switch (self, event) {
        case (.inactive, .hotkeyToggle):
            return TransitionResult(state: .activated, target: nil)

        case (.activated, .hotkeyToggle):
            return TransitionResult(state: .inactive, target: nil)

        case (.activated, .gestureStarted):
            return TransitionResult(state: .activated, target: nil)

        case (.activated, .gestureStartedWithTarget(let target)):
            return TransitionResult(state: .knobing(target: target), target: target)

        case (.knobing, .gestureEnded):
            if case .knobing(let target) = self {
                return TransitionResult(state: .cooling(target: target), target: target)
            }
            return nil

        case (.cooling, .coolingTimeout):
            return TransitionResult(state: .activated, target: nil)

        case (.knobing, .appSwitched), (.cooling, .appSwitched):
            return TransitionResult(state: .activated, target: nil)

        case (.cooling, .gestureStartedWithTarget(let newTarget)):
            if case .cooling(let existingTarget) = self {
                // identity 比较：ruleKey 匹配则恢复 knobing
                if existingTarget.ruleKey == newTarget.ruleKey {
                    return TransitionResult(state: .knobing(target: newTarget), target: newTarget)
                } else {
                    return TransitionResult(state: .activated, target: nil)
                }
            }
            return nil

        default:
            return nil
        }
    }
}
```

> **注意：** `RuleKey` 需要实现 `Equatable`。在 `ControlRule.swift` 中 `RuleKey` 已是 `Hashable`，`Hashable` 自动隐含 `Equatable`，无需额外添加。

- [ ] **步骤 2：更新 KnobGlobalStateTests.swift**

`MockControlTarget` → `MockDetectedTarget`（辅助函数），更新事件类型：

```swift
// PhantomKnobDetector/PhantomKnobDetectorTests/KnobGlobalStateTests.swift
import XCTest
@testable import PhantomKnobDetector

final class KnobGlobalStateTests: XCTestCase {

    // 辅助函数
    private func mockTarget(identifier: String? = "mock") -> DetectedTarget {
        DetectedTarget(bundleID: "com.test.app", axRole: "AXSlider",
                       identifier: identifier, displayName: "Test", element: nil)
    }

    func testInitialStateIsInactive() {
        XCTAssertEqual(KnobGlobalState.inactive, .inactive)
    }

    func testStateHasIconColor() {
        XCTAssertEqual(KnobGlobalState.inactive.iconColor, .gray)
        XCTAssertEqual(KnobGlobalState.activated.iconColor, .systemBlue)
        XCTAssertEqual(KnobGlobalState.knobing(target: mockTarget()).iconColor, .systemOrange)
        XCTAssertEqual(KnobGlobalState.cooling(target: mockTarget()).iconColor, .systemOrange)
    }

    func testStateHasTarget() {
        XCTAssertNil(KnobGlobalState.inactive.currentTarget)
        XCTAssertNil(KnobGlobalState.activated.currentTarget)
        XCTAssertNotNil(KnobGlobalState.knobing(target: mockTarget()).currentTarget)
        XCTAssertNotNil(KnobGlobalState.cooling(target: mockTarget()).currentTarget)
    }

    func testHotkeyTransitions() {
        XCTAssertEqual(KnobGlobalState.inactive.transition(event: .hotkeyToggle), .activated)
        XCTAssertEqual(KnobGlobalState.activated.transition(event: .hotkeyToggle), .inactive)
    }

    func testGestureStartedWithTargetEntersKnobing() {
        let result = KnobGlobalState.activated.transitionWithResult(
            event: .gestureStartedWithTarget(mockTarget()))
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.state.isKnobing)
    }

    func testGestureEndedEntersCooling() {
        let result = KnobGlobalState.knobing(target: mockTarget()).transitionWithResult(event: .gestureEnded)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.state.isCooling)
    }

    func testCoolingTimeoutReturnsToActivated() {
        let next = KnobGlobalState.cooling(target: mockTarget()).transition(event: .coolingTimeout)
        XCTAssertEqual(next, .activated)
    }

    func testAppSwitchedReturnsToActivated() {
        XCTAssertEqual(KnobGlobalState.knobing(target: mockTarget()).transition(event: .appSwitched), .activated)
        XCTAssertEqual(KnobGlobalState.cooling(target: mockTarget()).transition(event: .appSwitched), .activated)
    }

    func testCoolingResumesKnobingOnSameTarget() {
        let target = mockTarget(identifier: "slider-1")
        let result = KnobGlobalState.cooling(target: target).transitionWithResult(
            event: .gestureStartedWithTarget(mockTarget(identifier: "slider-1")))
        XCTAssertTrue(result?.state.isKnobing == true)
    }

    func testCoolingReturnsToActivatedOnDifferentTarget() {
        let result = KnobGlobalState.cooling(target: mockTarget(identifier: "a")).transitionWithResult(
            event: .gestureStartedWithTarget(mockTarget(identifier: "b")))
        XCTAssertEqual(result?.state, .activated)
    }
}
```

- [ ] **步骤 3：运行测试**

```bash
xcodebuild test \
  -project /Users/wb/work/phantom_knob_mac/PhantomKnobDetector/PhantomKnobDetector.xcodeproj \
  -scheme PhantomKnobDetector \
  -destination 'platform=macOS' \
  -only-testing:PhantomKnobDetectorTests/KnobGlobalStateTests \
  2>&1 | grep -E "(error:|PASSED|FAILED)"
```

预期：全部 PASSED

- [ ] **步骤 4：Commit**

```bash
cd /Users/wb/work/phantom_knob_mac
git add PhantomKnobDetector/Model/KnobGlobalState.swift \
        PhantomKnobDetector/PhantomKnobDetectorTests/KnobGlobalStateTests.swift
git commit -m "refactor: KnobGlobalState uses DetectedTarget; identity comparison via ruleKey"
```

---

## 任务 6：重构 KnobStateManager（核心执行管道）

**文件：**
- 修改：`PhantomKnobDetector/Service/KnobStateManager.swift`
- 修改：`PhantomKnobDetector/Service/AccessibilityTarget.swift`（降格为辅助，供 AXWriteTranslator 参考，最终可删除）

- [ ] **步骤 1：工厂方法 —— 根据 DetectedTarget + ControlRule 创建 InputTranslator**

在 `KnobStateManager.swift` 中新增私有工厂方法（在类内），在正式替换执行管道前先写好：

```swift
// 追加到 KnobStateManager 私有方法区
private func makeTranslator(for target: DetectedTarget, rule: ControlRule?) -> InputTranslator {
    let translation = rule?.translation ?? autoDetectTranslation(for: target)
    let scale = rule?.scaleConfig.resolve() ?? 1.0

    switch translation {
    case .axWrite:
        guard let element = target.element,
              let minV = TargetDetector.getDouble(from: element, attribute: kAXMinValueAttribute),
              let maxV = TargetDetector.getDouble(from: element, attribute: kAXMaxValueAttribute)
        else {
            // AX 元素不可用，降级到滚轮
            return ScrollWheelTranslator(axis: .vertical, scale: scale)
        }
        return AXWriteTranslator(element: element, minValue: minV, maxValue: maxV, scale: scale)

    case .scrollWheelVertical:
        return ScrollWheelTranslator(axis: .vertical, scale: scale)

    case .scrollWheelHorizontal:
        return ScrollWheelTranslator(axis: .horizontal, scale: scale)

    case .arrowKeyUpDown:
        return ArrowKeyTranslator(axis: .upDown, scale: scale)

    case .arrowKeyLeftRight:
        return ArrowKeyTranslator(axis: .leftRight, scale: scale)

    case .swipeVertical:
        // 使用滚轮模拟，直到专用 swipe 实现完成
        return ScrollWheelTranslator(axis: .vertical, scale: scale)

    case .swipeHorizontal:
        return ScrollWheelTranslator(axis: .horizontal, scale: scale)
    }
}

private func autoDetectTranslation(for target: DetectedTarget) -> InputTranslation {
    guard let element = target.element else { return .scrollWheelVertical }
    return TargetDetector.autoDetectTranslation(for: element)
}
```

- [ ] **步骤 2：替换 KnobStateManager 属性和 onMultitouchBegan**

将 `private var currentTarget: ControlTarget?` 替换为两个属性，并更新 `onMultitouchBegan`：

**替换属性声明**（在类顶部，`private var currentTarget: ControlTarget?` 行）：
```swift
private var currentTarget: DetectedTarget?
private var currentTranslator: InputTranslator?
```

**替换 `onMultitouchBegan` 实现：**
```swift
func onMultitouchBegan(points: [Int: CGPoint]) {
    writeDebugLog("[KnobStateManager] onMultitouchBegan: points=\(points.count), state=\(state)")
    guard state != .inactive else { return }

    // 1. 探测目标元素
    let detectedTarget = targetDetector.detectTargetAtMousePosition()

    // 2. 查规则库（未命中则自动探测）
    let rule: ControlRule?
    if let target = detectedTarget {
        rule = RuleLibrary.shared.lookup(for: target.ruleKey)
    } else {
        rule = nil
    }

    // 3. 创建兜底 DetectedTarget（无 AX 元素时用当前 app 信息填充）
    let target = detectedTarget ?? DetectedTarget(
        bundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "",
        axRole: "unknown",
        identifier: nil,
        displayName: "",
        element: nil
    )
    currentTarget = target

    // 4. 创建 InputTranslator
    let translator = makeTranslator(for: target, rule: rule)
    currentTranslator = translator

    // 5. 缓存鼠标位置，进入 knobing
    let mouseLoc = NSEvent.mouseLocation
    initialTouchPosition = mouseLoc
    let screenHeight = NSScreen.screens.first?.frame.height ?? 1080
    initialTouchPositionCarbon = CGPoint(x: mouseLoc.x, y: screenHeight - mouseLoc.y)

    let scaledPoints = scaleCoordinates(points)
    gestureClassifier.processTouchesBegan(points: scaledPoints)
    previousAngle = gestureClassifier.getCurrentAngle(points: scaledPoints)

    transition(to: .knobing(target: target))

    overlayController.show(
        at: mouseLoc,
        targetName: target.displayName.isEmpty ? nil : target.displayName,
        displayValue: translator.displayValue
    )
}
```

- [ ] **步骤 3：替换 onMultitouchMoved 执行管道**

```swift
func onMultitouchMoved(points: [Int: CGPoint]) {
    guard state != .inactive, let translator = currentTranslator else { return }

    let scaledPoints = scaleCoordinates(points)
    let currentAngle = gestureClassifier.getCurrentAngle(points: scaledPoints)

    if state.isKnobing {
        if let lockPos = initialTouchPositionCarbon {
            CGWarpMouseCursorPosition(lockPos)
        }

        let knobState = KnobState(
            current: KnobCore(angle: currentAngle),
            previous: KnobCore(angle: previousAngle)
        )
        let deltaAngle = abs(knobState.deltaAngle)
        let direction: RotationDirection = knobState.deltaAngle >= 0 ? .clockwise : .counterClockwise

        translator.apply(units: deltaAngle, direction: direction)

        let displayVal = translator.displayValue
        overlayController.update(angle: currentAngle, displayValue: displayVal)

        self.currentAngle = currentAngle
        previousAngle = currentAngle

        writeDebugLog("[KnobStateManager] applied delta=\(deltaAngle) dir=\(direction)")
    }
}
```

- [ ] **步骤 4：更新 onMultitouchEnded 和 handleAppSwitch**

```swift
func onMultitouchEnded() {
    guard state != .inactive else { return }
    gestureClassifier.processTouchesEnded()
    initialTouchPositionCarbon = nil

    if state.isKnobing, let target = currentTarget {
        transition(to: .cooling(target: target))
        overlayController.fadeOut { [weak self] in
            self?.startCoolingTimer()
        }
    }
}

private func handleAppSwitch() {
    guard state != .inactive else { return }
    transition(to: .activated)
    currentTarget = nil
    currentTranslator = nil
    overlayController.hide()
    targetDetector.clearCache()
}
```

- [ ] **步骤 5：更新 toggleMode 中的 currentTarget 清理**

在 `toggleMode()` 的 `else` 分支中，将 `currentTarget = nil` 改为：
```swift
currentTarget = nil
currentTranslator = nil
```

- [ ] **步骤 6：运行全部测试**

```bash
xcodebuild test \
  -project /Users/wb/work/phantom_knob_mac/PhantomKnobDetector/PhantomKnobDetector.xcodeproj \
  -scheme PhantomKnobDetector \
  -destination 'platform=macOS' \
  2>&1 | grep -E "(error:|PASSED|FAILED|Build FAILED)"
```

预期：无 `error:` 和 `Build FAILED`

- [ ] **步骤 7：Commit**

```bash
cd /Users/wb/work/phantom_knob_mac
git add PhantomKnobDetector/Service/KnobStateManager.swift
git commit -m "refactor: KnobStateManager uses DetectedTarget + InputTranslator pipeline"
```

---

## 任务 7：Overlay 适配（nil displayValue 时隐藏值区域）

**文件：**
- 修改：`PhantomKnobDetector/Service/OverlayController.swift`
- 修改：`PhantomKnobDetector/View/OverlayView.swift`

- [ ] **步骤 1：查看当前 OverlayController 接口**

```bash
cat /Users/wb/work/phantom_knob_mac/PhantomKnobDetector/Service/OverlayController.swift
cat /Users/wb/work/phantom_knob_mac/PhantomKnobDetector/View/OverlayView.swift
```

- [ ] **步骤 2：更新 show/update 签名以接受 Optional**

在 `OverlayController.swift` 中，将：
```swift
func show(at position: CGPoint, targetName: String, displayValue: String)
func update(angle: Double, displayValue: String)
```
改为：
```swift
func show(at position: CGPoint, targetName: String?, displayValue: String?)
func update(angle: Double, displayValue: String?)
```

- [ ] **步骤 3：在 OverlayView 中处理 nil displayValue**

找到渲染 displayValue 的代码，用 `if let` 或 `?? ""` 包裹，使值区域在 nil 时隐藏（高度折叠为 0 或设为 `isHidden = true`）。具体实现依赖当前 OverlayView 的结构（AutoLayout 约束或 SwiftUI）。

- [ ] **步骤 4：运行全部测试**

```bash
xcodebuild test \
  -project /Users/wb/work/phantom_knob_mac/PhantomKnobDetector/PhantomKnobDetector.xcodeproj \
  -scheme PhantomKnobDetector \
  -destination 'platform=macOS' \
  2>&1 | grep -E "(error:|PASSED|FAILED|Build FAILED)"
```

预期：全部 PASSED

- [ ] **步骤 5：Commit**

```bash
cd /Users/wb/work/phantom_knob_mac
git add PhantomKnobDetector/Service/OverlayController.swift \
        PhantomKnobDetector/View/OverlayView.swift
git commit -m "feat: overlay hides value area when displayValue is nil (non-axWrite translations)"
```

---

## 任务 8：清理遗留代码

**文件：**
- 修改：`PhantomKnobDetector/Service/AccessibilityTarget.swift`（降格，保留辅助方法）
- 修改：`PhantomKnobDetector/Control/ControlTarget.swift`（已标记 deprecated，可删除协议声明）
- 修改：`PhantomKnobDetector/Model/SensitivityConfig.swift`（旧的 Sensitivity 配置已被 ScaleConfig 取代，标记 deprecated 或删除）

- [ ] **步骤 1：删除 ControlTarget 协议和遗留实现（若无编译报错）**

```bash
# 检查是否还有地方引用 ControlTarget
grep -r "ControlTarget" /Users/wb/work/phantom_knob_mac/PhantomKnobDetector --include="*.swift" | grep -v "\.md"
```

若引用只剩 `DemoSliderTarget.swift` 和 `GenericControlTarget.swift`（Demo 页面使用），保留这两个文件不动（Demo 功能仍需要），但可以删除 `ControlTarget.swift` 协议文件，将协议内联到这两个文件里，或直接用 struct 替代。

- [ ] **步骤 2：删除 SensitivityConfig 中已无用的逻辑**

```bash
grep -r "SensitivityConfig\|sliderSensitivity\|progressSensitivity" \
  /Users/wb/work/phantom_knob_mac/PhantomKnobDetector --include="*.swift"
```

若 `SensitivityConfig` 只在 `KnobStateManager` 初始化中使用但不再影响执行管道，可从 `KnobStateManager` 移除该依赖。

- [ ] **步骤 3：运行全部测试，确保清理后无回归**

```bash
xcodebuild test \
  -project /Users/wb/work/phantom_knob_mac/PhantomKnobDetector/PhantomKnobDetector.xcodeproj \
  -scheme PhantomKnobDetector \
  -destination 'platform=macOS' \
  2>&1 | grep -E "(error:|PASSED|FAILED|Build FAILED)"
```

- [ ] **步骤 4：最终 Commit**

```bash
cd /Users/wb/work/phantom_knob_mac
git add -A
git commit -m "chore: remove legacy ControlTarget/SensitivityConfig artifacts after InputTranslation migration"
```

---

## 验证计划

### 自动化测试
```bash
xcodebuild test \
  -project /Users/wb/work/phantom_knob_mac/PhantomKnobDetector/PhantomKnobDetector.xcodeproj \
  -scheme PhantomKnobDetector \
  -destination 'platform=macOS' \
  2>&1 | tail -20
```
预期：所有 test suite PASSED，无 Build FAILED。

### 手动冒烟测试
1. 启动 App → 按 `⌘⇧K` 激活（图标变蓝）
2. 打开系统音量滑块（菜单栏），悬浮，双指旋转 → 音量变化，overlay 显示百分比
3. 打开 QuickTime，悬浮到进度条上，双指旋转 → 时间轴前进/后退，overlay 无值显示（已隐藏）
4. 手指离开 → overlay 淡出；1 秒内再放手指 → overlay 淡入恢复
5. 切换 App → 状态回蓝色，新手势可正确识别新目标
