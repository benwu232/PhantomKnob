# 设计文档：动态修改调整步长（速度）

本设计文档详细规划了“通过手指半径及数字键动态修改调整步长（速度）”的特性实现方案。

## 目标描述

在两指旋转（Knob）手势中，用户希望根据当前手指间的半径距离或辅助键盘按键，动态调整调节的步长灵敏度。
为了支持高度的定制化与可读性，系统需同时支持：
1. **键盘数字键倍率（键盘与旋钮并存）**：在调节过程中，长按数字键 `2-9` 可临时将当前步长放大 `2-9` 倍。
2. **多档半径分段机制（Fixed Zones with Hysteresis）**：
   * 支持多档半径分段（Zones），当配置 $\ge 2$ 个环时，自动启用**迟滞缓冲区机制（Hysteresis）**。
   * 每个环由：**内界（minRadius）**、**外界（maxRadius）**、**缓冲区宽度（margin）**和**步长倍率（scale）**定义。
3. **线性渐变机制（Linear Interpolation）**：步长随半径大小在一定区间内线性平滑过渡。
4. **两级配置与个性化定制**：
   * **全局默认**：由 `settings.jsonc` 定义全局默认的步长方案及参数。
   * **单 Knob 定制**：在规则库中，每条规则可以拥有专属的 `scaleConfig` 配置，覆盖全局默认设置。
5. **配置文件支持注释 (JSONC)**：配置文件使用 `.jsonc` 后缀，支持单行 `//` 和多行 `/* */` 注释，在 Swift 加载时进行预处理过滤。

---

## 配置文件设计

### 1. 全局默认设置 (`settings.jsonc`)
存储于：`~/Library/Application Support/PhantomKnob/settings.jsonc`。
```jsonc
{
  // 默认启用的半径方案: "fixed"（环分段/固定倍率）、"linear"（线性渐变）
  "activeScheme": "fixed",
  
  // 是否允许在调节时按数字键 2-9 放大步长
  "enableKeyboardNumberMultiplier": true,
  
  // 环分段方案配置
  "fixed": {
    "zones": [
      {
        "minRadius": 0.0,
        "maxRadius": 12.0,
        "margin": 2.0,  // 迟滞宽度，防止临界点频繁抖动
        "scale": 1.0    // 捏合（小半径）时的步长倍率
      },
      {
        "minRadius": 12.0,
        "maxRadius": 100.0,
        "margin": 2.0,
        "scale": 0.2    // 张开（大半径）时的步长倍率
      }
    ]
  },
  
  // 线性渐变方案配置
  "linear": {
    "minRadius": 10.0,
    "maxRadius": 20.0,
    "minScale": 1.0,
    "maxScale": 0.2
  }
}
```

### 2. 单 Knob 规则配置 (`rules.jsonc` 或 `bundled-rules.json`)
每条规则的 `scaleConfig` 可单独配置，同样支持 JSONC 格式。

---

## 模块设计与交互流程

### 1. 数据模型与 Codable 改造
在 `ControlRule.swift` 中，对 `ScaleConfig` 进行重构，兼容旧版并支持新版：
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
```

### 2. JSONC 预处理助手
在读取 `.jsonc` 文件时，先通过正则表达式剥离注释，再进行标准的 JSON 反序列化：
```swift
struct JSONCParser {
    static func stripComments(from jsonString: String) -> String {
        // 匹配单行 // 注释和多行 /* */ 注释的正则表达式
        let pattern = #"(?:/\*(?:[^*]|\*(?!/))*\*/)|(?://.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return jsonString
        }
        let range = NSRange(jsonString.startIndex..., in: jsonString)
        return regex.stringByReplacingMatches(in: jsonString, options: [], range: range, withTemplate: "")
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard let rawString = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "无法解析为 UTF-8 字符串"))
        }
        let cleanString = stripComments(from: rawString)
        guard let cleanData = cleanString.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "清理注释后无法转换回 Data"))
        }
        return try JSONDecoder().decode(type, from: cleanData)
    }
}
```

### 3. 接口协议扩展 (`InputTranslator` 改造)
```swift
protocol InputTranslator: AnyObject {
    func apply(units: Double, direction: RotationDirection)
    var displayValue: String? { get }
    var scale: Double { get set }  // 新增：允许在手势运动中动态修改 scale
}
```

### 4. 动态步长解析流程
在手势开始时（`onMultitouchBegan`），确定采用哪套 `ScaleConfig`：
1. **策略优先级**：
   * 检查当前匹配规则的 `scaleConfig` 是否为定制版（即 `zones` 数量 $\ge 2$ 或为 `linear`）。
   * 如果是，则当前手势完全使用该规则自带的 `scaleConfig` 进行解析。
   * 如果规则不存在，或者规则为旧版 `.fixed(Double)` 且其值为 `1.0`，则**回退使用全局 `AppSettings` 中定义的 `activeScheme` 配置**。
2. **状态维护**：
   * `KnobStateManager` 内部维护一个 `var currentZoneIndex: Int = 0`。每次开始新手势时重置为 0.

### 5. 键盘数字键监控器
* 在手势开始并在 `.knobing` 时开启 `.keyDown`/`.keyUp` 全局监控。
* 若按下 `2-9`，设置全局叠加倍率乘数 `activeKeyboardMultiplier = Double(char)`。松开时还原为 `1.0`。
* `最终步长倍率 = 半径解析倍率 (baseScale) * 键盘乘数 (activeKeyboardMultiplier)`。

---

## 验证方案

### 自动化单元测试
在 `PhantomKnobDetectorTests` 目录下新增测试文件：
1. **`AppSettingsTests.swift`**：测试默认配置生成，文件读取与写入，配置校验。
2. **`JSONCParserTests.swift`**：验证 `stripComments` 能成功剥离单行/多行注释，保证解析不崩溃。
3. **`ScaleConfigCompatibilityTests.swift`**：验证 `ScaleConfig` 能够正确解码旧版 JSON 以及新版（多 zones / linear 格式）。
4. **`ScaleResolverTests.swift`**：验证解析优先级及多环迟滞逻辑。

### 手动验证
1. 在 `settings.jsonc` 中编写带注释的配置，并在旋转过程中按下键盘数字键（2-9），验证是否生效，并检查 debug.log 确认注释已被成功滤除且没有报错。
