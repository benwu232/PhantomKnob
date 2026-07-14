# 旋钮定制面板行为项层级层叠与缩进优化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标**：在行为配置模块中实现对“映射方向 (Clockwise Action)”的右侧缩进 `12pt` 与 `↳` 引导前缀，明确其作为“映射方式 (Output Translation)”子项的层级关系。

**架构**：修改 `CustomizerHUDView.swift` 中的三个行为表单，使对应“映射方向”的 `VStack` 进行左侧 Padding，并利用 `HStack` 在 Label 前方增加带有低透明度的引导字符 `Text("↳")`。

**技术栈**：SwiftUI, macOS SDK

---

## 拟修改/创建文件

- [MODIFY] [CustomizerHUDView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/CustomizerHUDView.swift)

---

## 任务结构

### 任务 1：重构三个行为属性表单的层级布局

**文件：**
- 修改：`PhantomKnob/View/CustomizerHUDView.swift`

- [ ] **步骤 1：重构 `singleBehaviorForm` 中的“映射方向”布局**。
  - 在 Label HStack 前方添加 `Text("↳")` 并设置其 opacity 为 `0.5`。
  - 为整个“映射方向”的 `VStack` 添加 `.padding(.leading, 12)`。

  代码变更参考：
  ```swift
              VStack(alignment: .leading, spacing: 4) {
                  HStack(spacing: 6) {
                      Text("↳")
                          .font(.hudLabel)
                          .foregroundColor(.hudSecondary.opacity(0.5))
                      Text(String(localized: "hud.clockwiseAction", defaultValue: "Clockwise Action"))
                          .font(.hudLabel)
                          .foregroundColor(.hudSecondary)
                      HUDHelpButton(content: String(localized: "hud.clockwiseAction.help", defaultValue: "Event triggered when rotating the knob clockwise."))
                  }
                  Picker("", selection: $singleCWAction) {
                      ForEach(directionOptions(for: singleTranslation), id: \.self) { opt in
                          Text(actionDescription(opt)).tag(opt)
                      }
                  }
                  .onChange(of: singleCWAction) { _ in save() }
              }
              .padding(.leading, 12)
  ```

- [ ] **步骤 2：重构 `doubleBehaviorForm` 中的“映射方向”布局**。
  - 同样为 Label HStack 前方添加 `Text("↳")`。
  - 同样为整个 `VStack` 添加 `.padding(.leading, 12)`。

  代码变更参考：
  ```swift
              VStack(alignment: .leading, spacing: 4) {
                  HStack(spacing: 6) {
                      Text("↳")
                          .font(.hudLabel)
                          .foregroundColor(.hudSecondary.opacity(0.5))
                      Text(String(localized: "hud.clockwiseActionPicker", defaultValue: "Clockwise Action"))
                          .font(.hudLabel)
                          .foregroundColor(.hudSecondary)
                      HUDHelpButton(content: String(localized: "hud.clockwiseAction.help", defaultValue: "Event triggered when rotating the knob clockwise."))
                  }
                  Picker("", selection: $doubleInnerCWAction) {
                      ForEach(directionOptions(for: doubleInnerTranslation), id: \.self) { opt in
                          Text(actionDescription(opt)).tag(opt)
                      }
                  }
                  .onChange(of: doubleInnerCWAction) { _ in save() }
              }
              .padding(.leading, 12)
  ```

- [ ] **步骤 3：重构 `linearBehaviorForm` 中的“映射方向”布局**。
  - 同样为 Label HStack 前方添加 `Text("↳")`。
  - 同样为整个 `VStack` 添加 `.padding(.leading, 12)`。

  代码变更参考：
  ```swift
              VStack(alignment: .leading, spacing: 4) {
                  HStack(spacing: 6) {
                      Text("↳")
                          .font(.hudLabel)
                          .foregroundColor(.hudSecondary.opacity(0.5))
                      Text(String(localized: "hud.clockwiseActionPicker", defaultValue: "Clockwise Action"))
                          .font(.hudLabel)
                          .foregroundColor(.hudSecondary)
                      HUDHelpButton(content: String(localized: "hud.clockwiseAction.help", defaultValue: "Event triggered when rotating the knob clockwise."))
                  }
                  Picker("", selection: $linearCWAction) {
                      ForEach(directionOptions(for: linearTranslation), id: \.self) { opt in
                          Text(actionDescription(opt)).tag(opt)
                      }
                  }
                  .onChange(of: linearCWAction) { _ in save() }
              }
              .padding(.leading, 12)
  ```

- [ ] **步骤 4：编译运行确保布局对齐整洁**。

- [ ] **步骤 5：Commit 变更**
  ```bash
  git add PhantomKnob/View/CustomizerHUDView.swift
  git commit -m "feat: indent and add ↳ hierarchy indicator to Clockwise Action labels in HUD customizer"
  ```

---

## 验证计划

### 手动交互验证
1. **启动并呼出面板**：按下 `C` 键呼出定制面板。
2. **验证“映射方向”层级布局**：
   - 确认单旋钮、双环旋钮和无级变速旋钮的行为表单中，的“映射方向”输入框和 Label 缩进了 `12pt`。
   - 确认在 Label 前方有浅灰半透明的 `↳` 连接符。
3. **验证功能正常**：
   - 切换“映射方向”参数，确认设置可以正确保存并在重新呼出时恢复。
