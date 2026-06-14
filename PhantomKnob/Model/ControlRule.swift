// PhantomKnob/Model/ControlRule.swift
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

struct RadiusZone: Codable, Equatable {
    let minRadius: Double
    let maxRadius: Double
    let margin: Double
    let scale: Double
}

struct ScaleConfigLinear: Codable, Equatable {
    let minRadius: Double
    let maxRadius: Double
    let minScale: Double
    let maxScale: Double
}

/// 旋转角度到 InputTranslation 单位数的映射配置。
/// 默认：fixed(1.0)，即 1° = 1 最小单位。
enum ScaleConfig: Codable, Equatable {
    case fixed(Double)
    case zones([RadiusZone])
    case linear(ScaleConfigLinear)
}

enum KnobConfigType: String, Codable {
    case single
    case double
    case linear
}

struct SingleKnobConfig: Codable, Equatable {
    var unitPerDegree: Double
    var translation: InputTranslation
    var clockwiseAction: String
}

struct VirtualKnobConfig: Codable, Equatable {
    var minRadius: Double
    var maxRadius: Double
    var margin: Double
    var unitPerDegree: Double
    var translation: InputTranslation
    var clockwiseAction: String
    var themeColor: String? // 支持独立配色
}

struct DoubleKnobConfig: Codable, Equatable {
    var inner: VirtualKnobConfig
    var outer: VirtualKnobConfig
}

struct LinearKnobConfig: Codable, Equatable {
    var minRadius: Double
    var maxRadius: Double
    var minScale: Double
    var maxScale: Double
    var translation: InputTranslation
    var clockwiseAction: String
}

/// RuleLibrary 中存储的一条规则。
struct ControlRule: Codable, Equatable {
    let key: RuleKey
    var themeColor: String?
    var configType: KnobConfigType
    
    var singleConfig: SingleKnobConfig?
    var doubleConfig: DoubleKnobConfig?
    var linearConfig: LinearKnobConfig?
    
    var extra: [String: String]?
    
    // 兼容旧字段
    var translation: InputTranslation?
    var scaleConfig: ScaleConfig?
    var invert: Bool?
    var overlayStyle: String?
    var rotationStyle: String?

    enum CodingKeys: String, CodingKey {
        case key, themeColor, configType, singleConfig, doubleConfig, linearConfig, extra
        case translation, scaleConfig, invert, overlayStyle, rotationStyle
    }

    init(key: RuleKey,
         themeColor: String? = nil,
         configType: KnobConfigType = .single,
         singleConfig: SingleKnobConfig? = nil,
         doubleConfig: DoubleKnobConfig? = nil,
         linearConfig: LinearKnobConfig? = nil,
         extra: [String: String]? = nil) {
        self.key = key
        self.themeColor = themeColor
        self.configType = configType
        self.singleConfig = singleConfig
        self.doubleConfig = doubleConfig
        self.linearConfig = linearConfig
        self.extra = extra
        
        // 自动映射兼容旧字段
        if configType == .single, let single = singleConfig {
            self.translation = single.translation
            self.scaleConfig = .fixed(single.unitPerDegree)
            self.invert = (single.clockwiseAction == "arrowDown" || single.clockwiseAction == "arrowLeft" || single.clockwiseAction == "scrollDown" || single.clockwiseAction == "scrollLeft" || single.clockwiseAction == "swipeDown" || single.clockwiseAction == "swipeLeft" || single.clockwiseAction == "decrease")
        }
    }

    // 兼容原有测试与代码初始化签名
    init(key: RuleKey,
         translation: InputTranslation,
         scaleConfig: ScaleConfig = .fixed(1.0),
         themeColor: String? = nil,
         overlayStyle: String? = nil,
         rotationStyle: String? = nil,
         invert: Bool? = false,
         extra: [String: String]? = nil) {
        self.key = key
        self.themeColor = themeColor
        self.overlayStyle = overlayStyle
        self.rotationStyle = rotationStyle
        self.extra = extra
        
        // 解析旧模式
        let oldInvert = invert ?? false
        let defaultCWAction: String
        switch translation {
        case .arrowKeyUpDown: defaultCWAction = oldInvert ? "arrowDown" : "arrowUp"
        case .arrowKeyLeftRight: defaultCWAction = oldInvert ? "arrowLeft" : "arrowRight"
        case .scrollWheelVertical: defaultCWAction = oldInvert ? "scrollDown" : "scrollUp"
        case .scrollWheelHorizontal: defaultCWAction = oldInvert ? "scrollRight" : "scrollLeft"
        case .swipeVertical: defaultCWAction = oldInvert ? "swipeDown" : "swipeUp"
        case .swipeHorizontal: defaultCWAction = oldInvert ? "swipeRight" : "swipeLeft"
        case .axWrite: defaultCWAction = oldInvert ? "decrease" : "increase"
        }
        
        // scaleValue is unused, deleted
        
        self.translation = translation
        self.scaleConfig = scaleConfig
        self.invert = invert
        
        switch scaleConfig {
        case .zones(let zones):
            self.configType = .double
            let innerZone = zones.count > 0 ? zones[0] : RadiusZone(minRadius: 5.0, maxRadius: 25.0, margin: 2.0, scale: 1.0)
            let outerZone = zones.count > 1 ? zones[1] : RadiusZone(minRadius: 27.0, maxRadius: 100.0, margin: 2.0, scale: 1.0)
            self.doubleConfig = DoubleKnobConfig(
                inner: VirtualKnobConfig(minRadius: innerZone.minRadius, maxRadius: innerZone.maxRadius, margin: innerZone.margin, unitPerDegree: innerZone.scale, translation: translation, clockwiseAction: defaultCWAction),
                outer: VirtualKnobConfig(minRadius: outerZone.minRadius, maxRadius: outerZone.maxRadius, margin: outerZone.margin, unitPerDegree: outerZone.scale, translation: translation, clockwiseAction: defaultCWAction)
            )
        case .linear(let config):
            self.configType = .linear
            self.linearConfig = LinearKnobConfig(minRadius: config.minRadius, maxRadius: config.maxRadius, minScale: config.minScale, maxScale: config.maxScale, translation: translation, clockwiseAction: defaultCWAction)
        case .fixed(let val):
            self.configType = .single
            self.singleConfig = SingleKnobConfig(unitPerDegree: val, translation: translation, clockwiseAction: defaultCWAction)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try container.decode(RuleKey.self, forKey: .key)
        self.themeColor = try container.decodeIfPresent(String.self, forKey: .themeColor)
        self.extra = try container.decodeIfPresent([String: String].self, forKey: .extra)
        self.overlayStyle = try container.decodeIfPresent(String.self, forKey: .overlayStyle)
        self.rotationStyle = try container.decodeIfPresent(String.self, forKey: .rotationStyle)
        
        if let configTypeStr = try container.decodeIfPresent(String.self, forKey: .configType),
           let parsedType = KnobConfigType(rawValue: configTypeStr) {
            self.configType = parsedType
            self.singleConfig = try container.decodeIfPresent(SingleKnobConfig.self, forKey: .singleConfig)
            self.doubleConfig = try container.decodeIfPresent(DoubleKnobConfig.self, forKey: .doubleConfig)
            self.linearConfig = try container.decodeIfPresent(LinearKnobConfig.self, forKey: .linearConfig)
            
            // 还原向下兼容字段给旧调用者使用
            self.translation = try container.decodeIfPresent(InputTranslation.self, forKey: .translation)
            self.scaleConfig = try container.decodeIfPresent(ScaleConfig.self, forKey: .scaleConfig)
            self.invert = try container.decodeIfPresent(Bool.self, forKey: .invert)
        } else {
            // 后向兼容解析
            self.configType = .single
            let oldTrans = try container.decodeIfPresent(InputTranslation.self, forKey: .translation) ?? .scrollWheelVertical
            let oldScaleConfig = try container.decodeIfPresent(ScaleConfig.self, forKey: .scaleConfig) ?? .fixed(1.0)
            let oldInvertOpt = try container.decodeIfPresent(Bool.self, forKey: .invert)
            let oldInvert = oldInvertOpt ?? false
            
            self.translation = oldTrans
            self.scaleConfig = oldScaleConfig
            self.invert = oldInvertOpt
            
            var scaleValue = 1.0
            if case .fixed(let val) = oldScaleConfig {
                scaleValue = val
            }
            
            let defaultCWAction: String
            switch oldTrans {
            case .arrowKeyUpDown: defaultCWAction = oldInvert ? "arrowDown" : "arrowUp"
            case .arrowKeyLeftRight: defaultCWAction = oldInvert ? "arrowLeft" : "arrowRight"
            case .scrollWheelVertical: defaultCWAction = oldInvert ? "scrollDown" : "scrollUp"
            case .scrollWheelHorizontal: defaultCWAction = oldInvert ? "scrollRight" : "scrollLeft"
            case .swipeVertical: defaultCWAction = oldInvert ? "swipeDown" : "swipeUp"
            case .swipeHorizontal: defaultCWAction = oldInvert ? "swipeRight" : "swipeLeft"
            case .axWrite: defaultCWAction = oldInvert ? "decrease" : "increase"
            }
            
            self.singleConfig = SingleKnobConfig(
                unitPerDegree: scaleValue,
                translation: oldTrans,
                clockwiseAction: defaultCWAction
            )
        }
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
