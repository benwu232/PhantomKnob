import XCTest
@testable import PhantomKnob

final class HUDSkinTests: XCTestCase {
    func testDecodeHUDSkinFromJSON() throws {
        let json = """
        {
          "$schemaVersion": "1.0",
          "id": "com.phantomknob.skin.cyberpunk_neon",
          "name": "极客暗黑霓虹",
          "author": "PhantomKnob Team",
          "styleArchetype": "cyberpunk",
          "appearance": {
            "size": { "defaultDiameter": 160, "minScale": 0.8, "maxScale": 1.5 },
            "backdrop": { "material": "darkBlur", "opacity": 0.75, "borderColor": "#00FFCC", "borderWidth": 2.0, "shadowRadius": 15 },
            "colors": { "primaryHex": "#00FFCC", "secondaryHex": "#FF007F", "glowColorHex": "#00FFCC66" }
          },
          "components": {
            "backdrop": { "enabled": true, "type": "glass" },
            "textureOverlay": { "enabled": true, "style": "carbonFiber" },
            "centerCap": { "enabled": true, "icon": "volumeIcon", "pattern": "cdKnurled" },
            "gauge": { "enabled": true, "style": "fineTicks", "tickCount": 60 },
            "notchPins": { "enabled": true, "type": "zeroCenterNotch" },
            "pointer": { "enabled": true, "type": "redNeedle" },
            "valueBadge": { "enabled": true, "position": "topFloating", "showUnit": true },
            "feedback": { "deadzoneVisual": true, "tooCloseWarning": true }
          },
          "customImageAssets": {
            "backdropImagePath": "assets/my_custom_dial.png",
            "textureOverlayPath": "assets/carbon_texture.png",
            "pointerGraphicPath": "assets/custom_needle.svg"
          },
          "animations": {
            "entrance": { "type": "simpleCenterScaleIn", "duration": 0.30, "springBounciness": 0.3 },
            "exit": { "type": "simpleCenterScaleOut", "duration": 0.25 }
          }
        }
        """.data(using: .utf8)!

        let skin = try JSONDecoder().decode(HUDSkin.self, from: json)
        XCTAssertEqual(skin.id, "com.phantomknob.skin.cyberpunk_neon")
        XCTAssertEqual(skin.appearance.colors.primaryHex, "#00FFCC")
        XCTAssertEqual(skin.components.gauge.tickCount, 60)
        XCTAssertEqual(skin.animations.entrance.type, .simpleCenterScaleIn)
    }

    func testHUDSkinManagerFallbackAndOverride() {
        let manager = HUDSkinManager.shared
        let defaultSkin = manager.defaultSkin
        XCTAssertEqual(defaultSkin.id, "com.phantomknob.skin.default")

        var override = HUDSkinOverride()
        override.primaryColorHex = "#FF0000"
        override.backdropOpacity = 0.9

        let resolved = manager.resolveSkin(skinID: nil, overrides: override)
        XCTAssertEqual(resolved.appearance.colors.primaryHex, "#FF0000")
        XCTAssertEqual(resolved.appearance.backdrop.opacity, 0.9)
    }

    func testResolveSkinAnimationMode() {
        let manager = HUDSkinManager.shared

        // 1. Fade mode
        let fadeOverride = HUDSkinOverride(animationMode: .fade, entranceAnimationType: .simpleCenterScaleIn, exitAnimationType: .simpleCenterScaleOut)
        let resolvedFade = manager.resolveSkin(skinID: nil, overrides: fadeOverride)
        XCTAssertEqual(resolvedFade.animations.entrance.type, .fadeInOnly, "Fade 模式入口类型必须为 fadeInOnly")
        XCTAssertEqual(resolvedFade.animations.exit.type, .fadeOut, "Fade 模式出口类型必须为 fadeOut")

        // 2. Scale mode
        let scaleOverride = HUDSkinOverride(animationMode: .scale)
        let resolvedScale = manager.resolveSkin(skinID: nil, overrides: scaleOverride)
        XCTAssertEqual(resolvedScale.animations.entrance.type, .simpleCenterScaleIn, "Scale 模式入口类型必须为 simpleCenterScaleIn")
        XCTAssertEqual(resolvedScale.animations.exit.type, .simpleCenterScaleOut, "Scale 模式出口类型必须为 simpleCenterScaleOut")

        // 3. None mode
        let noneOverride = HUDSkinOverride(animationMode: HUDAnimationMode.none)
        let resolvedNone = manager.resolveSkin(skinID: nil, overrides: noneOverride)
        XCTAssertEqual(resolvedNone.animations.entrance.duration, 0.0, "None 模式入口时长必须为 0")
        XCTAssertEqual(resolvedNone.animations.exit.duration, 0.0, "None 模式出口时长必须为 0")
    }

    func testResolveSkinCleansZeroDurationForAnimationModes() {
        let manager = HUDSkinManager.shared

        // 历史脏数据：scale 模式但时长为 0 → 应回退默认 0.30/0.50，保证有动画
        let scaleOverride = HUDSkinOverride(animationMode: .scale, entranceDuration: 0, exitDuration: 0)
        let resolvedScale = manager.resolveSkin(skinID: nil, overrides: scaleOverride)
        XCTAssertEqual(resolvedScale.animations.entrance.type, .simpleCenterScaleIn)
        XCTAssertEqual(resolvedScale.animations.exit.type, .simpleCenterScaleOut)
        XCTAssertEqual(resolvedScale.animations.entrance.duration, 0.30, "Scale 模式 0 时长应回退默认 0.30")
        XCTAssertEqual(resolvedScale.animations.exit.duration, 0.50, "Scale 模式 0 时长应回退默认 0.50")

        // fade 模式同理
        let fadeOverride = HUDSkinOverride(animationMode: .fade, entranceDuration: 0, exitDuration: 0)
        let resolvedFade = manager.resolveSkin(skinID: nil, overrides: fadeOverride)
        XCTAssertEqual(resolvedFade.animations.entrance.duration, 0.30)
        XCTAssertEqual(resolvedFade.animations.exit.duration, 0.50)

        // none 模式必须保持 0（无动画语义不变）
        let noneOverride = HUDSkinOverride(animationMode: HUDAnimationMode.none, entranceDuration: 0, exitDuration: 0)
        let resolvedNone = manager.resolveSkin(skinID: nil, overrides: noneOverride)
        XCTAssertEqual(resolvedNone.animations.entrance.duration, 0.0)
        XCTAssertEqual(resolvedNone.animations.exit.duration, 0.0)

        // 用户显式指定的时长必须保留（不被默认值覆盖）
        let explicitOverride = HUDSkinOverride(animationMode: .scale, entranceDuration: 0.1, exitDuration: 0.8)
        let resolvedExplicit = manager.resolveSkin(skinID: nil, overrides: explicitOverride)
        XCTAssertEqual(resolvedExplicit.animations.entrance.duration, 0.1)
        XCTAssertEqual(resolvedExplicit.animations.exit.duration, 0.8)
    }

    func testSkinPackagerExportAndImport() throws {
        let manager = HUDSkinManager.shared
        let skin = manager.defaultSkin
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let packURL = tempDir.appendingPathComponent("test.hudskinpack")
        try SkinPackager.exportSkin(skin, to: packURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: packURL.path))
        let importedSkin = try SkinPackager.importSkin(from: packURL)
        XCTAssertEqual(importedSkin.id, skin.id)
    }
}
