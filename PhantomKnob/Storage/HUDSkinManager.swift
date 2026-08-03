import Foundation
import os

public final class HUDSkinManager {
    public static let shared = HUDSkinManager()

    private var skinsMap: [String: HUDSkin] = [:]

    public var userSkinsURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("PhantomKnob", isDirectory: true).appendingPathComponent("Skins", isDirectory: true)
    }()

    public var defaultSkin: HUDSkin {
        return HUDSkin(
            schemaVersion: "1.0",
            id: "com.phantomknob.skin.default",
            name: "Default Glass",
            author: "PhantomKnob",
            styleArchetype: "minimal",
            appearance: HUDSkinAppearance(
                size: HUDSizeConfig(defaultDiameter: 160, minScale: 0.8, maxScale: 1.5),
                backdrop: HUDBackdropConfig(material: "darkBlur", opacity: 0.7, borderColor: "#FFFFFF", borderWidth: 1.0, shadowRadius: 10),
                colors: HUDColorConfig(primaryHex: "#007AFF", secondaryHex: "#5AC8FA", glowColorHex: "#007AFF44")
            ),
            components: HUDSkinComponents(
                backdrop: HUDBackdropComponent(enabled: true, type: "glass"),
                textureOverlay: HUDTextureOverlayComponent(enabled: false, style: "none"),
                centerCap: HUDCenterCapComponent(enabled: true, icon: "volumeIcon", pattern: "none"),
                gauge: HUDGaugeComponent(enabled: true, style: "fineTicks", tickCount: 60),
                notchPins: HUDNotchPinsComponent(enabled: true, type: "zeroCenterNotch"),
                pointer: HUDPointerComponent(enabled: true, type: "redNeedle"),
                valueBadge: HUDValueBadgeComponent(enabled: true, position: "topFloating", showUnit: true),
                feedback: HUDFeedbackComponent(deadzoneVisual: true, tooCloseWarning: true)
            ),
            customImageAssets: nil,
            animations: HUDAnimationConfig(
                entrance: HUDEntranceAnimation(type: .simpleCenterScaleIn, duration: 0.25, springBounciness: 0.2),
                exit: HUDExitAnimation(type: .simpleCenterScaleOut, duration: 0.20)
            )
        )
    }

    public init() {
        reloadSkins()
    }

    public func reloadSkins() {
        var map: [String: HUDSkin] = [:]
        map[defaultSkin.id] = defaultSkin

        // 1. Bundle 预置皮肤
        if let bundleSkinsDir = Bundle.main.resourceURL?.appendingPathComponent("Skins") {
            loadSkins(from: bundleSkinsDir, into: &map)
        }

        // 2. Application Support 用户目录皮肤
        if !FileManager.default.fileExists(atPath: userSkinsURL.path) {
            try? FileManager.default.createDirectory(at: userSkinsURL, withIntermediateDirectories: true)
        }
        loadSkins(from: userSkinsURL, into: &map)

        self.skinsMap = map
        NotificationCenter.default.post(name: NSNotification.Name("HUDSkinLibraryDidUpdate"), object: nil)
    }

    private func loadSkins(from dir: URL, into map: inout [String: HUDSkin]) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for subDir in files where subDir.hasDirectoryPath {
            let jsonURL = subDir.appendingPathComponent("skin.json")
            if let data = try? Data(contentsOf: jsonURL),
               let skin = try? JSONDecoder().decode(HUDSkin.self, from: data) {
                map[skin.id] = skin
            }
        }
    }

    public var allSkins: [HUDSkin] {
        return Array(skinsMap.values).sorted { $0.name < $1.name }
    }

    public func resolveSkin(skinID: String?, overrides: HUDSkinOverride?) -> HUDSkin {
        let baseSkin: HUDSkin
        if let id = skinID, let found = skinsMap[id] {
            baseSkin = found
        } else {
            baseSkin = defaultSkin
        }
        
        guard let overrides = overrides else { return baseSkin }

        var resolved = baseSkin
        if let hex = overrides.primaryColorHex { resolved.appearance.colors.primaryHex = hex }
        if let op = overrides.backdropOpacity { resolved.appearance.backdrop.opacity = op }
        if let scale = overrides.diameterScale { resolved.appearance.size.defaultDiameter *= scale }
        if let pos = overrides.valuePosition { resolved.components.valueBadge.position = pos }
        if let mode = overrides.animationMode {
            switch mode {
            case .none:
                resolved.animations.entrance.type = .fadeInOnly
                resolved.animations.entrance.duration = 0.0
                resolved.animations.exit.type = .fadeOut
                resolved.animations.exit.duration = 0.0
            case .fade:
                resolved.animations.entrance.type = .fadeInOnly
                resolved.animations.exit.type = .fadeOut
                resolved.animations.entrance.duration = Self.effectiveDuration(overrides.entranceDuration, default: 0.30)
                resolved.animations.exit.duration = Self.effectiveDuration(overrides.exitDuration, default: 0.50)
            case .scale:
                resolved.animations.entrance.type = .simpleCenterScaleIn
                resolved.animations.exit.type = .simpleCenterScaleOut
                resolved.animations.entrance.duration = Self.effectiveDuration(overrides.entranceDuration, default: 0.30)
                resolved.animations.exit.duration = Self.effectiveDuration(overrides.exitDuration, default: 0.50)
            }
        } else {
            if let entType = overrides.entranceAnimationType { resolved.animations.entrance.type = entType }
            if let exitType = overrides.exitAnimationType { resolved.animations.exit.type = exitType }
            if let entDur = overrides.entranceDuration, entDur > 0 { resolved.animations.entrance.duration = entDur }
            if let exitDur = overrides.exitDuration, exitDur > 0 { resolved.animations.exit.duration = exitDur }
        }
        return resolved
    }

    /// 动画时长兜底：明确指定 > 0 的时长则使用，否则使用默认时长。
    /// 防止历史脏数据（animationMode 非 none 但时长为 0）导致 HUD 无动画。
    private static func effectiveDuration(_ value: Double?, default defaultValue: Double) -> Double {
        guard let v = value, v > 0 else { return defaultValue }
        return v
    }
}
