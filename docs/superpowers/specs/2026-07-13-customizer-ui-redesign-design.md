# 旋钮定制面板及全局 HUD 视觉重构设计规范

## 1. 业务目标
基于对 PhantomKnob 全局界面美观度、视觉一致性和信息层级清晰度的极致追求，特制定本套全局 UI/UX 设计系统。
本规范将定制面板重构的优秀设计（字体、颜色、微凹凸毛玻璃卡片、网格间距系统）提炼为全局通用的 SwiftUI Extension 资产，以便在定制面板首批落地，并在未来无缝推广应用到 **用户指南 (UserGuideView)** 与 **系统快捷控制面板 (KnobPanelView)** 中，从而建立极具奢华感和统一专业感的 macOS 品牌视觉体验。

---

## 2. 全局设计系统 Token (Design System Tokens)

我们统一在独立的公共文件 [DesignSystem.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/DesignSystem.swift) 中为 SwiftUI 扩展以下视觉 Token。

### 2.1 调色 Token (`Color` Extension)
- `Color.hudTitle` = `Color.white`（主前景字色）
- `Color.hudSecondary` = `Color.white.opacity(0.60)`（二级标签色）
- `Color.hudMetadata` = `Color.white.opacity(0.45)`（三级等宽辅助字色）
- `Color.hudCardBg` = `Color.white.opacity(0.04)`（微凸悬浮卡片底色）
- `Color.hudCardBorder` = `Color.white.opacity(0.08)`（微凸悬浮卡片细边框描边色）
- `Color.hudInputBg` = `Color.black.opacity(0.25)`（输入框凹陷底色）
- `Color.hudInputBorder` = `Color.white.opacity(0.10)`（输入框/Picker 细边框色）

### 2.2 字体 Token (`Font` Extension)
- `Font.hudTitle` = `.system(size: 12, weight: .bold)`（大分类一级标题）
- `Font.hudLabel` = `.system(size: 11, weight: .medium)`（子属性二级标签）
- `Font.hudValue` = `.system(size: 11, weight: .bold, design: .monospaced)`（数值和指示）
- `Font.hudCode` = `.system(size: 10, design: .monospaced)`（高级辅助技术元数据）

### 2.3 几何与网格 Token (Metrics)
- **卡片圆角**: `8.0` px
- **输入框圆角**: `5.0` px
- **网格宽度对齐端点**: 全局所有设置项滑块、Picker 及自定义颜色 Button 宽度固定锁死为 `331` px。
- **三级网格间距**:
  - 外层内缩 (Horizontal Padding): `14` px
  - 模块间距 (Section Spacing): `16` px
  - 行内间距 (Row Spacing): `10` px

---

## 3. 界面卡片与微凸凹模型

在重构中引入全局统一的边框与背景 Modifier：

- **微凸悬浮卡片背景 (Floating Card Modifier)**：
  对表单组应用 `.background(Color.hudCardBg)` 加上 `.cornerRadius(8)` 且 `.overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.hudCardBorder, lineWidth: 1))`，体现悬浮微立体卡片质感。
- **微凹输入框背景 (Sunken Input Modifier)**：
  对 TextField 和 Picker 应用 `.background(Color.hudInputBg)` 加上 `.cornerRadius(5)` 且 `.overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.hudInputBorder, lineWidth: 1))`，实现向下凹陷的物理刻画感。

---

## 4. 全系统推广蓝图

### 4.1 用户指南 (UserGuideView) 接入方案
- **标题统合**：主标题“Step 1: Detect & Rotate”提升为 20pt Bold 纯白，副标题升级为 `Color.hudSecondary`（白 60%）。
- **流程说明卡片**：各步骤下的指引卡片、快捷键提示背景由原来的 `Color.white.opacity(0.1)` 替换为标准微凸卡片背景（White 4% 背景 + White 8% 边框），圆角统合为 8px。
- **导航按钮**：Previous/Next 按钮采用统一的微凹或微凸底色描边规范，彻底融入系统视觉。

### 4.2 系统控制面板 (KnobPanelView) 接入方案
- **三环控制旋钮排布**：保持 40px 的模块呼吸间距。
- **旋钮控制文字**：“System Volume” 等文字由 `Color.white.opacity(0.6)` 提升为 `Color.hudTitle` 与 `Color.hudSecondary` 等级。
- **新手引导卡片 (TutorialView)**：顶部浮动的引导框统合为微凸悬浮毛玻璃卡片（White 4% 背景 + 8% 细实线边框），与下方的控制区域实现视觉完美咬合。

---

## 5. 验证计划
- **编译检查**：跑 `swift build`，通过编译。
- **界面对比**：呼出定制面板，重点观察各行文本对比度、行间距的几何韵律美感、圆角的规范应用、输入框的黑色质感下陷以及卡片边框的一致性，确保无任何局部突兀样式。
