# 动态 HUD 皮肤与自定义主题编辑器 (HUD Skin Customizer) 设计规格说明书

## 1. 概述与设计目标

PhantomKnob 目前仅支持简单的单色主调 (`themeColor`) 和基本渲染样式 (`overlayStyle`)。为了提供更丰富精致的视觉体验（如赛博暗黑 Cyberpunk、瑞士极简 Swiss Minimal、复古仪表盘 Retro Dial 等），并支持用户在 HUD Skin Customizer 中自由定制 HUD 尺寸、毛玻璃透明度、主色调、数值位置、材质纹理与进出动画，本项目旨在设计一套**高扩展性、数据驱动 (Data-Driven UI) 的 HUD 皮肤格式协议与组件化架构 (HUDSkin Schema Standard)**。

### 核心目标
1. **完全解耦与数据驱动**：将 HUD 皮肤元数据解耦为独立的 `HUDSkin` 格式结构（JSON / Codable），与特定控件手势映射解耦。
2. **7 层图层组件拆解**：支持背景底盘、材质纹理、中心帽 Icon、刻度轨迹、止动标、指针与数值胶囊 7 大模块的自由组装。
3. **支持外部素材与材质导入**：支持引用内置系统材质（碳纤维/黄铜磨砂/赛博光栅）以及用户导入的本地 PNG/SVG/JPG 贴图素材。
4. **丰富的进出动画支持**：支持最简圆心缩放 (`simpleCenterScaleIn / Out`)、赛博点放大/缩小 (`pointExpand / Shrink`)、赛博故障 (`glitchPop`) 等多种特效。
5. **向下兼容与覆盖机制**：主配置 `KnobConfig` 仅需保存 `skinID` 及局部 `skinOverrides`。

---

## 2. 皮肤 Schema 数据结构规范 (JSON Spec)

皮肤元数据标准采用 JSON 格式定义，Swift 端映射为 `HUDSkin` 结构体，遵循 `Codable` 协议。

```json
{
  "$schemaVersion": "1.0",
  "id": "com.phantomknob.skin.cyberpunk_neon",
  "name": "极客暗黑霓虹 (Cyberpunk Neon)",
  "author": "PhantomKnob Team",
  "styleArchetype": "cyberpunk",

  "appearance": {
    "size": {
      "defaultDiameter": 160,
      "minScale": 0.8,
      "maxScale": 1.5
    },
    "backdrop": {
      "material": "darkBlur",
      "opacity": 0.75,
      "borderColor": "#00FFCC",
      "borderWidth": 2.0,
      "shadowRadius": 15
    },
    "colors": {
      "primaryHex": "#00FFCC",
      "secondaryHex": "#FF007F",
      "glowColorHex": "#00FFCC66"
    }
  },

  "components": {
    "backdrop": {
      "enabled": true,
      "type": "glass"
    },
    "textureOverlay": {
      "enabled": true,
      "style": "carbonFiber"
    },
    "centerCap": {
      "enabled": true,
      "icon": "volumeIcon",
      "pattern": "cdKnurled"
    },
    "gauge": {
      "enabled": true,
      "style": "fineTicks",
      "tickCount": 60
    },
    "notchPins": {
      "enabled": true,
      "type": "zeroCenterNotch"
    },
    "pointer": {
      "enabled": true,
      "type": "redNeedle"
    },
    "valueBadge": {
      "enabled": true,
      "position": "topFloating",
      "showUnit": true
    },
    "feedback": {
      "deadzoneVisual": true,
      "tooCloseWarning": true
    }
  },

  "customImageAssets": {
    "backdropImagePath": "assets/my_custom_dial.png",
    "textureOverlayPath": "assets/carbon_texture.png",
    "pointerGraphicPath": "assets/custom_needle.svg"
  },

  "animations": {
    "entrance": {
      "type": "simpleCenterScaleIn",
      "duration": 0.30,
      "springBounciness": 0.3
    },
    "exit": {
      "type": "simpleCenterScaleOut",
      "duration": 0.25
    }
  }
}
```

---

## 3. 核心解构组件详细说明 (Modular Component Layers)

| 图层编号 | 图层名称 | 标识符 (`type` / `style`) | 功能与渲染说明 |
| :--- | :--- | :--- | :--- |
| **Layer 1** | **背景底盘 (Backdrop)** | `none`, `glass`, `hexagon`, `acrylic` | 控制底盘形状（圆形毛玻璃、极客六角形、无底盘），透明度与边框发光 |
| **Layer 2** | **材质纹理 (Texture Overlay)** | `none`, `carbonFiber`, `brassMetal`, `cyberGrid` | 叠置在底盘上的材质滤镜（碳纤维编织网格、拟真黄铜磨砂、赛博光栅） |
| **Layer 3** | **导入素材 (Custom Image Assets)** | `backdropImagePath`, `textureOverlayPath`, `pointerGraphicPath` | 支持用户上传本地 PNG/SVG 贴图作为底盘、材质或指针 |
| **Layer 4** | **旋钮帽与 Icon (Center Cap)** | `none`, `volumeIcon`, `sunIcon`, `cdKnurled` | 中心金属帽、唱片纹路、音量/亮度/对比度功能图标 |
| **Layer 5** | **刻度轨迹 (Gauge & Ticks)** | `none`, `fineTicks`, `dots`, `doubleRing` | 60 细线刻度、点阵刻度、粗精调双圈分层环 (`DoubleKnob` / `CVKKnob`) |
| **Layer 6** | **零点/止动标 (Notch Pins)** | `none`, `zeroCenterNotch`, `minMaxLimitPins` | EQ/平衡中点凹槽 (Notch)、最小/最大极值点标 (Pins) |
| **Layer 7** | **旋转指针 (Pointer & Needle)** | `none`, `redNeedle`, `cyberDot`, `customImage` | 旋转探针、发光圆点指示头、自定义 SVG 图像指针 |
| **Layer 8** | **数值位置 (Value Badge)** | `none`, `topFloating`, `center`, `bottomPill`, `cursorFollow` | 数值与目标名称显示位置（顶部悬浮牌、中心数字、底部胶囊） |

---

## 4. 动画系统规范 (Animation Specifications)

动画定义分为进入动画 (`entrance`) 与退出动画 (`exit`)。

### 4.1 进入动画枚举 (`EntranceAnimationType`)
1. **`simpleCenterScaleIn` (最简圆心放大)**：
   * 动画路径：`scale(0.0 -> 1.0)`
   * 特点：纯粹从圆心放大进入，无旋转无失真，简洁顺滑。
2. **`pointExpand` (赛博点放大)**：
   * 动画路径：`scale(0.01 -> 1.1 -> 1.0)`，带有轻微旋转与过冲弹性。
3. **`glitchPop` (赛博故障)**：
   * 带有 X 轴倾斜 `skewX` 与色差抖动的故障闪现进入。
4. **`spinIn` (旋入放大)**：
   * `rotate(-270° -> 0°)` 配合 `scale(0.2 -> 1.0)` 旋入。

### 4.2 退出动画枚举 (`ExitAnimationType`)
1. **`simpleCenterScaleOut` (最简缩小到圆心)**：
   * 动画路径：`scale(1.0 -> 0.0)`
   * 特点：纯粹缩回圆心隐去。
2. **`pointShrink` (旋钮缩小到一点)**：
   * 动画路径：`scale(1.0 -> 1.1 -> 0.01)` 伴随快速旋出与微模糊。
3. **`fadeOut` (淡出)**：
   * 透明度 `opacity(1.0 -> 0.0)` 淡出。

---

## 5. 配置集成与覆盖机制 (KnobConfig Integration)

在 `KnobConfig.swift` 中增加对 `HUDSkin` 的关联引用与增量覆写支持：

```swift
struct KnobConfig: Codable {
    let key: KnobKey
    var skinID: String?              // 关联皮肤 ID，如 "com.phantomknob.skin.cyberpunk_neon"
    var skinOverrides: HUDSkinOverride? // 用户在主题编辑器中修改的增量覆盖参数
}

struct HUDSkinOverride: Codable {
    var primaryColorHex: String?
    var backdropOpacity: Double?
    var diameterScale: Double?
    var valuePosition: String?
}
```

### 运行时解析逻辑
1. 查找是否存在对应的 `HUDSkin` 定义（优先使用自定义皮肤包，其次使用内置预设）。
2. 若存在 `skinOverrides`，使用覆写参数替换 `HUDSkin` 中的对应字段。
3. 若皮肤文件缺失，自动降级至原生默认 HUD 样式 (Fallback)。

---

## 6. 自定义主题编辑器 (HUD Skin Customizer) 模块设计

主题编辑器为 App 内置的可视化交互面板，主要包含：
1. **WYSIWYG 实时预览舞台**：响应所有图层勾选与参数调整。
2. **图层选择与属性控制面板**：提供 7 大图层开关、颜色选择器、透明度滑块、动画下拉框。
3. **素材导入模块**：支持选取本地文件并打包入皮肤资源文件夹。
4. **导出与分享 (Import / Export)**：将皮肤配置与其附带的 PNG/SVG 素材导出为 `.hudskinpack` 压缩包。

---

## 7. 规格自检 (Self-Check)

- [x] **占位符检查**：无 TODO 或待定事项，数据格式与参数范围均明确标注。
- [x] **内部一致性**：图层编号（Layer 1~8）、动画名称与代码 JSON 结构完全一致。
- [x] **范围控制**：本文档专注于数据协议、解构图层与动画规范，暂不涉及工程逻辑实现。
