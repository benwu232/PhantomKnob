# 全局 HUD 及定制面板 UI/UX 视觉重构实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：**
1. 建立独立的全局设计系统 Token 文件 `DesignSystem.swift`，包含 Color、Font 的扩展以及微凹凸 Modifier 卡片样式；
2. 重构 `CustomizerHUDView.swift`，将所有的前景色、字号、圆角、背景色、卡片描边及间距系统完全替换为设计系统规范。
3. 规范对齐网格：锁定滑块与输入框的固定宽度，确保一致的视觉中轴线。

---

### 任务 1：创建 DesignSystem.swift 设计系统资产文件

**文件：**
- **[NEW]** [DesignSystem.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/DesignSystem.swift)

- [ ] **步骤 1：创建新文件 DesignSystem.swift**

在 `PhantomKnob/View` 目录下创建新文件，并实现以下 Swift 代码：
```swift
import SwiftUI

extension Color {
    static let hudTitle = Color.white
    static let hudSecondary = Color.white.opacity(0.60)
    static let hudMetadata = Color.white.opacity(0.45)
    static let hudCardBg = Color.white.opacity(0.04)
    static let hudCardBorder = Color.white.opacity(0.08)
    static let hudInputBg = Color.black.opacity(0.25)
    static let hudInputBorder = Color.white.opacity(0.10)
}

extension Font {
    static let hudTitle = Font.system(size: 12, weight: .bold)
    static let hudLabel = Font.system(size: 11, weight: .medium)
    static let hudValue = Font.system(size: 11, weight: .bold, design: .monospaced)
    static let hudCode = Font.system(size: 10, design: .monospaced)
}

extension View {
    /// 统一的微凸悬浮毛玻璃卡片风格
    func hudCardStyle() -> some View {
        self.padding(10)
            .background(Color.hudCardBg)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.hudCardBorder, lineWidth: 1)
            )
    }
    
    /// 统一的微凹下陷输入框/选择器风格
    func hudInputStyle() -> some View {
        self.background(Color.hudInputBg)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.hudInputBorder, lineWidth: 1)
            )
    }
}
```

- [ ] **步骤 2：编译验证**

运行：`swift build`
确认该设计 Token 文件正常参与项目编译，无任何警告与错误。

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnob/View/DesignSystem.swift
git commit -m "feat: create DesignSystem.swift to provide global colors, fonts and view styles"
```

---

### 任务 2：重构 CustomizerHUDView 样式与间距对齐

**文件：**
- 修改：`PhantomKnob/View/CustomizerHUDView.swift`

- [ ] **步骤 1：重构一级大分类标题、间距与全局内边距**

- 将外层大滚动条 `ScrollView` 的 `padding(.horizontal)` 统一设为 `14`。
- 将每个大分类（如“旋钮类型”、“旋钮外观”、“旋钮行为”、“辅助信息”）的标题字体设为 `Font.hudTitle`，前景色设为 `Color.hudTitle`，一级分类之间使用模块间距 `16` px。

- [ ] **步骤 2：重构 singleAppearanceForm、doubleAppearanceForm、linearAppearanceForm 里的卡片与滑块宽度**

- **卡片容器重构**：
  将表单组卡片替换为调用 `.hudCardStyle()`（删除原本手写硬编码的 padding, background, cornerRadius, overlay(stroke)）。
- **Slider 宽度重构**：
  将各个滑块（包括内外环边界、最大最小半径等 Slider）的宽度一律统合锁死为 `.frame(width: 331)`。
- **自定义颜色 Button 宽度**：
  确保 5 处 `paintpalette.fill` 按钮在 `.buttonStyle(PlainButtonStyle())` 之后全数设为 `.frame(width: 331)`。

- [ ] **步骤 3：重构输入框 TextField 与 Picker 凹陷质感**

- 检查所有的 `TextField` 与 `Picker` 模块，为它们的外围/底色框套用 `.hudInputStyle()` 样式。
- 将属性文本标签（如“内外环边界”、“外环灵敏度”等）的字体设为 `Font.hudLabel`，前景色设为 `Color.hudSecondary`。

- [ ] **步骤 4：编译检查**

在 `PhantomKnob` 路径下执行 `swift build`，确保没有发生任何大括号嵌套或者缺少组件的编译错误。

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnob/View/CustomizerHUDView.swift
git commit -m "refactor: apply DesignSystem tokens to CustomizerHUDView layout and spacing"
```

---

### 任务 3：系统集成与功能测试

**文件：**
- 修改：`/Users/wb/.gemini/antigravity-ide/brain/5eadebab-19df-4d33-9374-34d87cbe072c/walkthrough.md`

- [ ] **步骤 1：整体编译项目**

- [ ] **步骤 2：测试验证**
   - 呼出面板。
   - 切换不同旋钮类型及外观行为。
   - 验证圆角、背景卡片、描边、对齐宽度、文字对比度和下陷输入框完全处于同一设计系统体系。

- [ ] **步骤 3：更新 walkthrough.md 归档并完成**
