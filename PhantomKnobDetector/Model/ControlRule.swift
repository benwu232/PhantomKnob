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

// MARK: - ScaleConfig Codable
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
