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
}
