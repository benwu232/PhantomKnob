import Foundation

public struct HUDSkin: Codable, Equatable, Identifiable {
    public let schemaVersion: String
    public let id: String
    public var name: String
    public var author: String
    public var styleArchetype: String

    public var appearance: HUDSkinAppearance
    public var components: HUDSkinComponents
    public var customImageAssets: HUDCustomImageAssets?
    public var animations: HUDAnimationConfig

    public init(
        schemaVersion: String,
        id: String,
        name: String,
        author: String,
        styleArchetype: String,
        appearance: HUDSkinAppearance,
        components: HUDSkinComponents,
        customImageAssets: HUDCustomImageAssets? = nil,
        animations: HUDAnimationConfig
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.author = author
        self.styleArchetype = styleArchetype
        self.appearance = appearance
        self.components = components
        self.customImageAssets = customImageAssets
        self.animations = animations
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "$schemaVersion"
        case id, name, author, styleArchetype, appearance, components, customImageAssets, animations
    }
}

public struct HUDSkinAppearance: Codable, Equatable {
    public var size: HUDSizeConfig
    public var backdrop: HUDBackdropConfig
    public var colors: HUDColorConfig

    public init(size: HUDSizeConfig, backdrop: HUDBackdropConfig, colors: HUDColorConfig) {
        self.size = size
        self.backdrop = backdrop
        self.colors = colors
    }
}

public struct HUDSizeConfig: Codable, Equatable {
    public var defaultDiameter: Double
    public var minScale: Double
    public var maxScale: Double

    public init(defaultDiameter: Double, minScale: Double, maxScale: Double) {
        self.defaultDiameter = defaultDiameter
        self.minScale = minScale
        self.maxScale = maxScale
    }
}

public struct HUDBackdropConfig: Codable, Equatable {
    public var material: String
    public var opacity: Double
    public var borderColor: String
    public var borderWidth: Double
    public var shadowRadius: Double

    public init(material: String, opacity: Double, borderColor: String, borderWidth: Double, shadowRadius: Double) {
        self.material = material
        self.opacity = opacity
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.shadowRadius = shadowRadius
    }
}

public struct HUDColorConfig: Codable, Equatable {
    public var primaryHex: String
    public var secondaryHex: String
    public var glowColorHex: String

    public init(primaryHex: String, secondaryHex: String, glowColorHex: String) {
        self.primaryHex = primaryHex
        self.secondaryHex = secondaryHex
        self.glowColorHex = glowColorHex
    }
}

public struct HUDSkinComponents: Codable, Equatable {
    public var backdrop: HUDBackdropComponent
    public var textureOverlay: HUDTextureOverlayComponent
    public var centerCap: HUDCenterCapComponent
    public var gauge: HUDGaugeComponent
    public var notchPins: HUDNotchPinsComponent
    public var pointer: HUDPointerComponent
    public var valueBadge: HUDValueBadgeComponent
    public var feedback: HUDFeedbackComponent

    public init(
        backdrop: HUDBackdropComponent,
        textureOverlay: HUDTextureOverlayComponent,
        centerCap: HUDCenterCapComponent,
        gauge: HUDGaugeComponent,
        notchPins: HUDNotchPinsComponent,
        pointer: HUDPointerComponent,
        valueBadge: HUDValueBadgeComponent,
        feedback: HUDFeedbackComponent
    ) {
        self.backdrop = backdrop
        self.textureOverlay = textureOverlay
        self.centerCap = centerCap
        self.gauge = gauge
        self.notchPins = notchPins
        self.pointer = pointer
        self.valueBadge = valueBadge
        self.feedback = feedback
    }
}

public struct HUDBackdropComponent: Codable, Equatable {
    public var enabled: Bool
    public var type: String // none, glass, hexagon, acrylic

    public init(enabled: Bool, type: String) {
        self.enabled = enabled
        self.type = type
    }
}

public struct HUDTextureOverlayComponent: Codable, Equatable {
    public var enabled: Bool
    public var style: String // none, carbonFiber, brassMetal, cyberGrid

    public init(enabled: Bool, style: String) {
        self.enabled = enabled
        self.style = style
    }
}

public struct HUDCenterCapComponent: Codable, Equatable {
    public var enabled: Bool
    public var icon: String // none, volumeIcon, sunIcon
    public var pattern: String // cdKnurled

    public init(enabled: Bool, icon: String, pattern: String) {
        self.enabled = enabled
        self.icon = icon
        self.pattern = pattern
    }
}

public struct HUDGaugeComponent: Codable, Equatable {
    public var enabled: Bool
    public var style: String // none, fineTicks, dots, doubleRing
    public var tickCount: Int

    public init(enabled: Bool, style: String, tickCount: Int) {
        self.enabled = enabled
        self.style = style
        self.tickCount = tickCount
    }
}

public struct HUDNotchPinsComponent: Codable, Equatable {
    public var enabled: Bool
    public var type: String // none, zeroCenterNotch, minMaxLimitPins

    public init(enabled: Bool, type: String) {
        self.enabled = enabled
        self.type = type
    }
}

public struct HUDPointerComponent: Codable, Equatable {
    public var enabled: Bool
    public var type: String // none, redNeedle, cyberDot, customImage

    public init(enabled: Bool, type: String) {
        self.enabled = enabled
        self.type = type
    }
}

public struct HUDValueBadgeComponent: Codable, Equatable {
    public var enabled: Bool
    public var position: String // none, topFloating, center, bottomPill, cursorFollow
    public var showUnit: Bool

    public init(enabled: Bool, position: String, showUnit: Bool) {
        self.enabled = enabled
        self.position = position
        self.showUnit = showUnit
    }
}

public struct HUDFeedbackComponent: Codable, Equatable {
    public var deadzoneVisual: Bool
    public var tooCloseWarning: Bool

    public init(deadzoneVisual: Bool, tooCloseWarning: Bool) {
        self.deadzoneVisual = deadzoneVisual
        self.tooCloseWarning = tooCloseWarning
    }
}

public struct HUDCustomImageAssets: Codable, Equatable {
    public var backdropImagePath: String?
    public var textureOverlayPath: String?
    public var pointerGraphicPath: String?

    public init(backdropImagePath: String? = nil, textureOverlayPath: String? = nil, pointerGraphicPath: String? = nil) {
        self.backdropImagePath = backdropImagePath
        self.textureOverlayPath = textureOverlayPath
        self.pointerGraphicPath = pointerGraphicPath
    }
}

public struct HUDAnimationConfig: Codable, Equatable {
    public var entrance: HUDEntranceAnimation
    public var exit: HUDExitAnimation

    public init(entrance: HUDEntranceAnimation, exit: HUDExitAnimation) {
        self.entrance = entrance
        self.exit = exit
    }
}

public enum EntranceAnimationType: String, Codable {
    case simpleCenterScaleIn
    case pointExpand
    case glitchPop
    case spinIn
}

public struct HUDEntranceAnimation: Codable, Equatable {
    public var type: EntranceAnimationType
    public var duration: Double
    public var springBounciness: Double?

    public init(type: EntranceAnimationType, duration: Double, springBounciness: Double? = nil) {
        self.type = type
        self.duration = duration
        self.springBounciness = springBounciness
    }
}

public enum ExitAnimationType: String, Codable {
    case simpleCenterScaleOut
    case pointShrink
    case fadeOut
}

public struct HUDExitAnimation: Codable, Equatable {
    public var type: ExitAnimationType
    public var duration: Double

    public init(type: ExitAnimationType, duration: Double) {
        self.type = type
        self.duration = duration
    }
}
