# 旋钮定制面板类型项独立 Tooltip 交互实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标**：将旋钮定制面板 (Customizer HUD) 中的“旋钮类型”原生 Segmented Picker 替换为自定义 SwiftUI HStack 分段选择器。在每个选项（单旋钮、双环、无级变速）文本后方加入感叹号 `(i)` 或 `(!)` 图标按钮，并在悬浮/点击时弹出专属的本地化帮助信息气泡。

**架构**：
1. 扩展 `HUDHelpButton` 组件以支持配置自定义系统图标（默认为 `"info.circle"`，可传入 `"exclamationmark.circle"`）。
2. 在 `CustomizerHUDView.swift` 中，移除原生的 `Picker` 与标题旁的 `HUDHelpButton`。
3. 新增 `typeDisplayName` 与 `typeHelpContent` 辅助函数。
4. 用自定义的 `HStack` 分段选择器实现原本的选择和切换逻辑，并在每个选项内部集成带 `exclamationmark.circle` 图标的 `HUDHelpButton`。

**技术栈**：SwiftUI, macOS SDK

---

## 拟修改/创建文件

- [MODIFY] [CustomizerHUDView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/CustomizerHUDView.swift)

---

## 任务结构

### 任务 1：升级 `HUDHelpButton` 支持自定义图标

**文件：**
- 修改：`PhantomKnob/View/CustomizerHUDView.swift`

- [ ] **步骤 1：为 `HUDHelpButton` 结构体添加 `iconName: String` 属性**。
  - 默认值设为 `"info.circle"`。
  - 在 `Image(systemName:)` 中使用该属性动态渲染图标。

  代码变更参考：
  ```swift
  struct HUDHelpButton: View {
      let content: String
      var iconName: String = "info.circle"
      
      @State private var isPresented = false
      @State private var hoverWorkItem: DispatchWorkItem?
      
      var body: some View {
          Image(systemName: iconName)
              .font(.system(size: 11))
              .foregroundColor(.white)
              .opacity(isPresented ? 0.8 : 0.45)
              .contentShape(Rectangle()) // 扩大点击/悬浮热区
              // ... 以下保持不变 ...
  ```

- [ ] **步骤 2：编译项目验证语法**
  在终端中验证 `HUDHelpButton` 无语法错误。

---

### 任务 2：实现自定义分段选择器与字段整合

**文件：**
- 修改：`PhantomKnob/View/CustomizerHUDView.swift`

- [ ] **步骤 1：移除 `knobTypeHelpContent` 属性，添加辅助函数 `typeDisplayName(_:)` 和 `typeHelpContent(_:)`**。
  - 在 `CustomizerHUDView` 中增加这两个私有函数，返回选项显示文本和对应的提示气泡文本。

  代码变更参考：
  ```swift
  private func typeDisplayName(_ type: KnobConfigType) -> String {
      switch type {
      case .single:
          return String(localized: "hud.single", defaultValue: "Single Knob")
      case .double:
          return String(localized: "hud.double", defaultValue: "Double-Ring")
      case .linear:
          return String(localized: "hud.linear", defaultValue: "Variable Speed")
      }
  }
  
  private func typeHelpContent(_ type: KnobConfigType) -> String {
      switch type {
      case .single:
          return String(localized: "hud.knobType.help.single", defaultValue: "Basic knob mode, simulating a physical knob.")
      case .double:
          return String(localized: "hud.knobType.help.double", defaultValue: "The knob's color, speed, etc. are divided into two levels, corresponding to different radius ranges.")
      case .linear:
          return String(localized: "hud.knobType.help.linear", defaultValue: "The knob is no longer graded, and the speed changes smoothly with the radius of the knob.")
      }
  }
  ```

- [ ] **步骤 2：重构“旋钮类型”区域布局**。
  - 去掉标题右侧 the `HUDHelpButton`，使标题回复普通 `Text`。
  - 将原生的 `Picker` 替换为自定义的 `HStack`，并为每个类型选项后方添加感叹号 `exclamationmark.circle` 图标和对应的 Tooltip。

  代码变更参考：
  ```swift
  // ① 旋钮类型
  VStack(alignment: .leading, spacing: 6) {
      Text(String(localized: "hud.knobType", defaultValue: "旋钮类型"))
          .font(.hudTitle)
          .foregroundColor(.hudTitle)
      
      HStack(spacing: 2) {
          ForEach([KnobConfigType.single, .double, .linear], id: \.self) { type in
              let isSelected = configType == type
              HStack(spacing: 4) {
                  Text(typeDisplayName(type))
                      .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                      .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                  
                  HUDHelpButton(
                      content: typeHelpContent(type),
                      iconName: "exclamationmark.circle"
                  )
              }
              .frame(maxWidth: .infinity)
              .frame(height: 24)
              .background(
                  RoundedRectangle(cornerRadius: 4)
                      .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
              )
              .contentShape(Rectangle())
              .onTapGesture {
                  if configType != type {
                      withAnimation(.easeInOut(duration: 0.15)) {
                          configType = type
                          save()
                      }
                  }
              }
          }
      }
      .padding(2)
      .background(Color.white.opacity(0.06))
      .cornerRadius(6)
  }
  ```

- [ ] **步骤 3：编译运行并确保无功能及样式缺陷**。

- [ ] **步骤 4：Commit 面板整合代码**
  ```bash
  git add PhantomKnob/View/CustomizerHUDView.swift
  git commit -m "feat: custom segmented control for knob types with type-specific exclamation tooltips"
  ```

---

## 验证计划

### 手动交互验证
1. **启动并呼出面板**：按下 `C` 键呼出定制面板。
2. **验证选择器样式**：
   - 确认原生的 segmented control 被替换为自定义的微暗毛玻璃分段选择器。
   - 选中项有白色的背景圆角高亮。
   - 每个分段后有感叹号图标 `(!)`。
3. **验证 Hover 自动显示**：
   - 悬停在“单旋钮”后的感叹号图标上，确认 0.5s 后弹出气泡，气泡内容为：“基本旋钮模式，模拟实体旋钮。”
   - 悬停在“双环”后的感叹号图标上，确认弹出：“旋钮的颜色、速度等分为两档，对应不同的半径范围。”
   - 悬停在“无级变速”后的感叹号图标上，确认弹出：“旋钮不再分级，速度随旋钮的半径平滑变化。”
4. **验证点击切换与保存**：
   - 点击选项（如“双环”），能正常选中并切换下方对应的外观与行为参数。
   - 关闭面板后重新呼出，验证切换的选项被正确持久化。
