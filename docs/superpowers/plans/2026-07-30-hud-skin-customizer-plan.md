# 动态 HUD 皮肤与自定义主题编辑器 (HUD Skin Customizer) 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将旋钮定制格式扩展为符合 `2026-07-30-hud-skin-customizer-design.md` 的 `HUDSkin` Schema 数据标准，实现 8 图层解耦渲染管线、皮肤包管理 (`.hudskinpack`)、进出动画引擎与自定义编辑器绑定。

**架构：** 定义 Codable 的 `HUDSkin` 协议与 `HUDSkinOverride`；新增 `HUDSkinManager` 实现多层级皮肤加载与兜底降级；使用 `SkinPackager` 处理 ZIP 格式的 `.hudskinpack` 素材导入导出；将 `OverlayView` 重构成 8 个独立的 SwiftUI 图层子视图构成的解耦渲染栈。

**技术栈：** Swift 5.9, SwiftUI, AppKit, Foundation (Codable, FileManager, Zip/Compression)

---

## 拟创建/修改的文件结构

```
PhantomKnob/
├── Model/
│   ├── HUDSkin.swift                       # [NEW] HUDSkin 完整 Codable Schema 定义与图层组件枚举
│   └── KnobConfig.swift                    # [MODIFY] Knob 增加 skinID 与 skinOverrides 字段
├── Storage/
│   └── HUDSkinManager.swift                # [NEW] 皮肤仓库管理器（加载、缓存、解析路径与兜底 Fallback）
├── Service/
│   └── SkinPackager.swift                  # [NEW] .hudskinpack 压缩包导入/导出与素材管理工具
├── View/
│   ├── OverlayView.swift                   # [MODIFY] 基于 HUDSkin 的 8 图层解耦渲染管线入口
│   ├── CustomizerHUDView.swift             # [MODIFY] 皮肤选择器、图层属性调试与 .hudskinpack 导入导出面板
│   └── Components/
│       └── HUD/                            # [NEW] 8 大解耦图层组件视图
│           ├── HUDBackdropView.swift       # Layer 1: 背景底盘
│           ├── HUDTextureOverlayView.swift # Layer 2: 材质纹理
│           ├── HUDCustomImageView.swift    # Layer 3: 本地/导入贴图
│           ├── HUDCenterCapView.swift      # Layer 4: 旋钮帽与 Icon
│           ├── HUDGaugeView.swift          # Layer 5: 刻度轨迹
│           ├── HUDNotchPinsView.swift      # Layer 6: 零点与止动标
│           ├── HUDPointerView.swift        # Layer 7: 旋转指针
│           └── HUDValueBadgeView.swift     # Layer 8: 数值显示位置
└── PhantomKnobTests/
    └── HUDSkinTests.swift                  # [NEW] HUDSkin 编解码、Override 合并与 Packager 单元测试
```

---

### 任务 1：定义 `HUDSkin` 数据结构规范

**文件：**
- 创建：`PhantomKnob/Model/HUDSkin.swift`
- 修改：`PhantomKnob/Model/KnobConfig.swift`
- 测试：`PhantomKnobTests/HUDSkinTests.swift`

- [ ] **步骤 1：编写 HUDSkin 编解码失败测试**

在 `PhantomKnobTests/HUDSkinTests.swift` 中编写解析全量 Schema JSON 的单元测试：

```swift
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
```

- [ ] **步骤 2：运行测试验证失败**

运行：`xcodebuild test -scheme PhantomKnob -only-testing:PhantomKnobTests/HUDSkinTests`
预期：FAIL，提示 `HUDSkin` 未定义。

- [ ] **步骤 3：实现 HUDSkin 数据结构**

在 `PhantomKnob/Model/HUDSkin.swift` 中创建完整 Codable 数据规范：

```swift
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

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "$schemaVersion"
        case id, name, author, styleArchetype, appearance, components, customImageAssets, animations
    }
}

public struct HUDSkinAppearance: Codable, Equatable {
    public var size: HUDSizeConfig
    public var backdrop: HUDBackdropConfig
    public var colors: HUDColorConfig
}

public struct HUDSizeConfig: Codable, Equatable {
    public var defaultDiameter: Double
    public var minScale: Double
    public var maxScale: Double
}

public struct HUDBackdropConfig: Codable, Equatable {
    public var material: String
    public var opacity: Double
    public var borderColor: String
    public var borderWidth: Double
    public var shadowRadius: Double
}

public struct HUDColorConfig: Codable, Equatable {
    public var primaryHex: String
    public var secondaryHex: String
    public var glowColorHex: String
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
}

public struct HUDBackdropComponent: Codable, Equatable {
    public var enabled: Bool
    public var type: String // none, glass, hexagon, acrylic
}

public struct HUDTextureOverlayComponent: Codable, Equatable {
    public var enabled: Bool
    public var style: String // none, carbonFiber, brassMetal, cyberGrid
}

public struct HUDCenterCapComponent: Codable, Equatable {
    public var enabled: Bool
    public var icon: String // none, volumeIcon, sunIcon
    public var pattern: String // cdKnurled
}

public struct HUDGaugeComponent: Codable, Equatable {
    public var enabled: Bool
    public var style: String // none, fineTicks, dots, doubleRing
    public var tickCount: Int
}

public struct HUDNotchPinsComponent: Codable, Equatable {
    public var enabled: Bool
    public var type: String // none, zeroCenterNotch, minMaxLimitPins
}

public struct HUDPointerComponent: Codable, Equatable {
    public var enabled: Bool
    public var type: String // none, redNeedle, cyberDot, customImage
}

public struct HUDValueBadgeComponent: Codable, Equatable {
    public var enabled: Bool
    public var position: String // none, topFloating, center, bottomPill, cursorFollow
    public var showUnit: Bool
}

public struct HUDFeedbackComponent: Codable, Equatable {
    public var deadzoneVisual: Bool
    public var tooCloseWarning: Bool
}

public struct HUDCustomImageAssets: Codable, Equatable {
    public var backdropImagePath: String?
    public var textureOverlayPath: String?
    public var pointerGraphicPath: String?
}

public struct HUDAnimationConfig: Codable, Equatable {
    public var entrance: HUDEntranceAnimation
    public var exit: HUDExitAnimation
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
}

public enum ExitAnimationType: String, Codable {
    case simpleCenterScaleOut
    case pointShrink
    case fadeOut
}

public struct HUDExitAnimation: Codable, Equatable {
    public var type: ExitAnimationType
    public var duration: Double
}
```

在 `PhantomKnob/Model/KnobConfig.swift` 中为 `Knob` 扩展 `skinID` 与 `skinOverrides`：

```swift
public struct HUDSkinOverride: Codable, Equatable {
    public var primaryColorHex: String?
    public var backdropOpacity: Double?
    public var diameterScale: Double?
    public var valuePosition: String?

    public init(primaryColorHex: String? = nil, backdropOpacity: Double? = nil, diameterScale: Double? = nil, valuePosition: String? = nil) {
        self.primaryColorHex = primaryColorHex
        self.backdropOpacity = backdropOpacity
        self.diameterScale = diameterScale
        self.valuePosition = valuePosition
    }
}
```
并在 `Knob` 中添加：
```swift
public var skinID: String?
public var skinOverrides: HUDSkinOverride?
```

- [ ] **步骤 4：运行测试验证通过**

运行：`xcodebuild test -scheme PhantomKnob -only-testing:PhantomKnobTests/HUDSkinTests/testDecodeHUDSkinFromJSON`
预期：PASS。

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnob/Model/HUDSkin.swift PhantomKnob/Model/KnobConfig.swift PhantomKnobTests/HUDSkinTests.swift
git commit -m "feat: add HUDSkin Codable schema and skinOverrides integration"
```

---

### 任务 2：实现皮肤管理器与 Overrides 级联解析 (`HUDSkinManager`)

**文件：**
- 创建：`PhantomKnob/Storage/HUDSkinManager.swift`
- 测试：`PhantomKnobTests/HUDSkinTests.swift`

- [ ] **步骤 1：编写 HUDSkinManager 加载与 Override 机制测试**

在 `PhantomKnobTests/HUDSkinTests.swift` 中添加：

```swift
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
```

- [ ] **步骤 2：运行测试验证失败**

运行：`xcodebuild test -scheme PhantomKnob -only-testing:PhantomKnobTests/HUDSkinTests/testHUDSkinManagerFallbackAndOverride`
预期：FAIL，提示 `HUDSkinManager` 未定义。

- [ ] **步骤 3：实现 HUDSkinManager**

在 `PhantomKnob/Storage/HUDSkinManager.swift` 中写实现：

```swift
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

    public func resolveSkin(skinID: String?, overrides: HUDSkinOverride?) -> HUDSkin {
        let baseSkin = (skinID != nil ? skinsMap[skinID!] : nil) ?? defaultSkin
        guard let overrides = overrides else { return baseSkin }

        var resolved = baseSkin
        if let hex = overrides.primaryColorHex { resolved.appearance.colors.primaryHex = hex }
        if let op = overrides.backdropOpacity { resolved.appearance.backdrop.opacity = op }
        if let scale = overrides.diameterScale { resolved.appearance.size.defaultDiameter *= scale }
        if let pos = overrides.valuePosition { resolved.components.valueBadge.position = pos }
        return resolved
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`xcodebuild test -scheme PhantomKnob -only-testing:PhantomKnobTests/HUDSkinTests/testHUDSkinManagerFallbackAndOverride`
预期：PASS。

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnob/Storage/HUDSkinManager.swift PhantomKnobTests/HUDSkinTests.swift
git commit -m "feat: add HUDSkinManager for loading skins and resolving overrides"
```

---

### 任务 3：实现 `.hudskinpack` 归档解包工具 (`SkinPackager`)

**文件：**
- 创建：`PhantomKnob/Service/SkinPackager.swift`
- 测试：`PhantomKnobTests/HUDSkinTests.swift`

- [ ] **步骤 1：编写 SkinPackager 导出解包单元测试**

在 `PhantomKnobTests/HUDSkinTests.swift` 中添加：

```swift
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
```

- [ ] **步骤 2：运行测试验证失败**

运行：`xcodebuild test -scheme PhantomKnob -only-testing:PhantomKnobTests/HUDSkinTests/testSkinPackagerExportAndImport`
预期：FAIL，提示 `SkinPackager` 未定义。

- [ ] **步骤 3：实现 SkinPackager 工具类**

在 `PhantomKnob/Service/SkinPackager.swift` 中编写逻辑：

```swift
import Foundation

public final class SkinPackager {
    public static func exportSkin(_ skin: HUDSkin, to outputURL: URL) throws {
        let tempFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let assetsFolder = tempFolder.appendingPathComponent("assets")
        try FileManager.default.createDirectory(at: assetsFolder, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(skin)
        try jsonData.write(to: tempFolder.appendingPathComponent("skin.json"))

        let fileCoordinator = NSFileCoordinator()
        var error: NSError?
        fileCoordinator.coordinate(writingItemAt: tempFolder, options: .forDeleting, error: &error) { zipSource in
            let zipPath = outputURL
            if FileManager.default.fileExists(atPath: zipPath.path) {
                try? FileManager.default.removeItem(at: zipPath)
            }
            try? FileManager.default.copyItem(at: zipSource, to: zipPath)
        }
        if let err = error { throw err }
    }

    public static func importSkin(from packURL: URL) throws -> HUDSkin {
        let targetSkinsDir = HUDSkinManager.shared.userSkinsURL
        let tempExtract = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempExtract, withIntermediateDirectories: true)

        try FileManager.default.copyItem(at: packURL, to: tempExtract.appendingPathComponent("pack"))
        let jsonURL = tempExtract.appendingPathComponent("pack/skin.json")
        guard FileManager.default.fileExists(atPath: jsonURL.path),
              let data = try? Data(contentsOf: jsonURL),
              let skin = try? JSONDecoder().decode(HUDSkin.self, from: data) else {
            throw NSError(domain: "SkinPackager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invalid hudskinpack format"])
        }

        let skinDir = targetSkinsDir.appendingPathComponent(skin.id)
        if FileManager.default.fileExists(atPath: skinDir.path) {
            try? FileManager.default.removeItem(at: skinDir)
        }
        try FileManager.default.moveItem(at: tempExtract.appendingPathComponent("pack"), to: skinDir)
        HUDSkinManager.shared.reloadSkins()
        return skin
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：`xcodebuild test -scheme PhantomKnob -only-testing:PhantomKnobTests/HUDSkinTests/testSkinPackagerExportAndImport`
预期：PASS。

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnob/Service/SkinPackager.swift PhantomKnobTests/HUDSkinTests.swift
git commit -m "feat: add SkinPackager for export and import of .hudskinpack files"
```

---

### 任务 4：重构 8 图层解耦渲染管线视图 (`OverlayView` Component Stack)

**文件：**
- 创建：
  - `PhantomKnob/View/Components/HUD/HUDBackdropView.swift`
  - `PhantomKnob/View/Components/HUD/HUDTextureOverlayView.swift`
  - `PhantomKnob/View/Components/HUD/HUDCenterCapView.swift`
  - `PhantomKnob/View/Components/HUD/HUDGaugeView.swift`
  - `PhantomKnob/View/Components/HUD/HUDNotchPinsView.swift`
  - `PhantomKnob/View/Components/HUD/HUDPointerView.swift`
  - `PhantomKnob/View/Components/HUD/HUDValueBadgeView.swift`
  - `PhantomKnob/View/Components/HUD/HUDCustomImageView.swift`
- 修改：`PhantomKnob/View/OverlayView.swift`

- [ ] **步骤 1：创建底层子视图模块**

在 `PhantomKnob/View/Components/HUD/` 目录下依次创建图层渲染组件（支持按照 `HUDSkin` 参数独立绘制）：

`HUDBackdropView.swift` (Layer 1):
```swift
import SwiftUI

public struct HUDBackdropView: View {
    public let config: HUDBackdropConfig
    public let primaryColor: Color

    public var body: some View {
        if config.material == "darkBlur" {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().stroke(primaryColor, lineWidth: config.borderWidth))
                .shadow(color: primaryColor.opacity(0.3), radius: config.shadowRadius)
                .opacity(config.opacity)
        } else {
            Circle()
                .fill(Color.black.opacity(config.opacity))
                .overlay(Circle().stroke(primaryColor, lineWidth: config.borderWidth))
        }
    }
}
```

`HUDGaugeView.swift` (Layer 5):
```swift
import SwiftUI

public struct HUDGaugeView: View {
    public let config: HUDGaugeComponent
    public let primaryColor: Color

    public var body: some View {
        ZStack {
            ForEach(0..<config.tickCount, id: \.self) { i in
                Rectangle()
                    .fill(primaryColor.opacity(i % 5 == 0 ? 0.9 : 0.4))
                    .frame(width: i % 5 == 0 ? 2 : 1, height: i % 5 == 0 ? 8 : 4)
                    .offset(y: -70)
                    .rotationEffect(.degrees(Double(i) * (360.0 / Double(config.tickCount))))
            }
        }
    }
}
```

`HUDPointerView.swift` (Layer 7):
```swift
import SwiftUI

public struct HUDPointerView: View {
    public let config: HUDPointerComponent
    public let angle: Double
    public let primaryColor: Color

    public var body: some View {
        Capsule()
            .fill(primaryColor)
            .frame(width: 4, height: 24)
            .offset(y: -50)
            .rotationEffect(.degrees(angle))
    }
}
```

`HUDValueBadgeView.swift` (Layer 8):
```swift
import SwiftUI

public struct HUDValueBadgeView: View {
    public let config: HUDValueBadgeComponent
    public let valueText: String

    public var body: some View {
        VStack {
            if config.position == "topFloating" {
                Text(valueText)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.ultraThinMaterial))
            }
        }
    }
}
```

- [ ] **步骤 2：整合 OverlayView 8 图层渲染栈**

在 `PhantomKnob/View/OverlayView.swift` 中以数据驱动的形式组合 8 大图层：

```swift
import SwiftUI

public struct OverlayView: View {
    public let skin: HUDSkin
    public let angle: Double
    public let valueText: String

    public var body: some View {
        let primaryColor = Color(hex: skin.appearance.colors.primaryHex) ?? .blue

        ZStack {
            // Layer 1: Backdrop
            if skin.components.backdrop.enabled {
                HUDBackdropView(config: skin.appearance.backdrop, primaryColor: primaryColor)
            }
            // Layer 5: Gauge
            if skin.components.gauge.enabled {
                HUDGaugeView(config: skin.components.gauge, primaryColor: primaryColor)
            }
            // Layer 7: Pointer
            if skin.components.pointer.enabled {
                HUDPointerView(config: skin.components.pointer, angle: angle, primaryColor: primaryColor)
            }
            // Layer 8: Value Badge
            if skin.components.valueBadge.enabled {
                HUDValueBadgeView(config: skin.components.valueBadge, valueText: valueText)
            }
        }
        .frame(width: skin.appearance.size.defaultDiameter, height: skin.appearance.size.defaultDiameter)
    }
}
```

- [ ] **步骤 3：编译并运行测试**

运行：`xcodebuild build -scheme PhantomKnob`
预期：BUILD SUCCEEDED。

- [ ] **步骤 4：Commit**

```bash
git add PhantomKnob/View/Components/HUD/ PhantomKnob/View/OverlayView.swift
git commit -m "refactor: modularize OverlayView into 8-layer HUD component stack"
```

---

### 任务 5：自定义主题编辑器绑定 (`CustomizerHUDView.swift`)

**文件：**
- 修改：`PhantomKnob/View/CustomizerHUDView.swift`

- [ ] **步骤 1：在编辑器中集成皮肤选择器与包导出**

更新 `CustomizerHUDView.swift`，增加皮肤列表选择、色值/透明度调控及 `.hudskinpack` 导出按钮：

```swift
// 在 CustomizerHUDView 的 Controls 区域添加 Skin 选择与导出
Picker("皮肤预设", selection: $selectedSkinID) {
    Text("默认 (Default)").tag("com.phantomknob.skin.default")
    Text("赛博暗黑 (Cyberpunk)").tag("com.phantomknob.skin.cyberpunk_neon")
}
.pickerStyle(.menu)

Button("导出皮肤包 (.hudskinpack)") {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.init(filenameExtension: "hudskinpack")!]
    panel.nameFieldStringValue = "MyCustomSkin.hudskinpack"
    if panel.runModal() == .OK, let url = panel.url {
        let currentSkin = HUDSkinManager.shared.resolveSkin(skinID: selectedSkinID, overrides: nil)
        try? SkinPackager.exportSkin(currentSkin, to: url)
    }
}
```

- [ ] **步骤 2：全量构建与自动化测试验证**

运行：`xcodebuild test -scheme PhantomKnob`
预期：所有单元测试与编译均通过 (PASS)。

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnob/View/CustomizerHUDView.swift
git commit -m "feat: bind HUDSkinManager and SkinPackager export into CustomizerHUDView"
```

---

## 验证计划

### 自动化测试
- 运行：`xcodebuild test -scheme PhantomKnob -only-testing:PhantomKnobTests/HUDSkinTests`
- 验证 `HUDSkin` Codable 解析、`HUDSkinManager` Overrides 级联覆写、以及 `SkinPackager` ZIP 导出/导入正确无误。

### 手动验证
- 启动应用，在设置控制面板中打开 `CustomizerHUDView`。
- 切换不同的皮肤 Preset，观察 8 图层组件（底盘、刻度、指针、数值位置）实时更新。
- 点击导出 `.hudskinpack`，校验导出的归档包解压后包含 `skin.json` 与素材文件夹。
