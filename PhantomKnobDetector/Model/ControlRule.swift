// PhantomKnobDetector/Model/ControlRule.swift
import Foundation

/// 规则库中唯一标识一条规则的 key。
/// 结构：bundleID · axRole · identifier?
struct RuleKey: Codable, Hashable {
    let bundleID: String    // "com.apple.QuickTimePlayerX"
    let axRole: String      // "AXSlider"
    let identifier: String? // AXIdentifier，nil 表示匹配该 app 下所有同类控件
    let displayName: String? // AXTitle 或 AXDescription，可为 nil

    init(bundleID: String, axRole: String, identifier: String? = nil, displayName: String? = nil) {
        self.bundleID = bundleID
        self.axRole = axRole
        self.identifier = identifier
        self.displayName = displayName
    }

    // 精确匹配（bundleID + axRole + identifier 全部相等）
    func matches(_ other: RuleKey) -> Bool {
        bundleID == other.bundleID &&
        axRole == other.axRole &&
        (identifier == nil || identifier == other.identifier) &&
        (displayName == nil || displayName == other.displayName)
    }
}

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

/// 旋转角度到 InputTranslation 单位数的映射配置。
/// 默认：fixed(1.0)，即 1° = 1 最小单位。
enum ScaleConfig: Codable {
    case fixed(Double)
    case zones([RadiusZone])
    case linear(ScaleConfigLinear)
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

// MARK: - ScaleConfig Codable
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
