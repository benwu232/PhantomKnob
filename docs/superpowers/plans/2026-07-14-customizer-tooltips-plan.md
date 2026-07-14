# 旋钮定制面板参数说明 Tooltip 与智能交互实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标**：在旋钮定制面板（Customizer HUD）中，为旋钮类型和核心参数添加就近的 `(i)` 帮助提示气泡，支持 0.5s Hover 延迟自动显示和点击强制显示，且支持中英双语。

**架构**：在 `CustomizerHUDView.swift` 中封装通用 `HUDHelpButton` 子组件，利用 SwiftUI 的 `.popover` 并配合 `DispatchWorkItem` 进行延时展示与取消；并在 `Localizable.xcstrings` 中配置相应的多语言键值。

**技术栈**：SwiftUI, macOS SDK (AppKit/SwiftUI)

---

## 拟修改/创建文件

- [MODIFY] [Localizable.xcstrings](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Localizable.xcstrings)
- [MODIFY] [CustomizerHUDView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/CustomizerHUDView.swift)

---

## 任务结构

### 任务 1：在本地化字符目录中添加帮助文本

**文件：**
- 修改：`PhantomKnob/Localizable.xcstrings`

- [ ] **步骤 1：在 `Localizable.xcstrings` 的 `"strings"` 节点中添加新的本地化键值对**。添加以下文本的键值：
  - `hud.knobType.help.single` (单旋钮简述)
  - `hud.knobType.help.double` (双环旋钮简述)
  - `hud.knobType.help.linear` (无级变速简述)
  - `hud.minRadius.help` (最小响应半径详情)
  - `hud.doubleInnerRadius.help` (内外环分界详情)
  - `hud.linearMaxRadius.help` (最大显示半径详情)

  中英文翻译对照：
  - **Single help**:
    - EN: "Standard single touch mode, simulating a traditional physical knob with constant sensitivity."
    - ZH: "传统的单点触控模式，模拟标准的物理旋钮，灵敏度恒定。"
  - **Double help**:
    - EN: "Automatic dual-gear mode. Rotating inside the inner ring uses normal sensitivity, while rotating outside automatically switches to fine tuning."
    - ZH: "自动双档模式。手指在内环旋转为正常灵敏度，在外环旋转自动切换为精细微调。"
  - **Linear help**:
    - EN: "Dynamic sensitivity mode. Rotation speed scales continuously based on finger distance from the center; pulling further increases speed."
    - ZH: "动态灵敏度模式。旋转速度根据手指离旋钮中心的距离连续平滑变化，拉得越远，旋转速度越快。"
  - **Min Radius help**:
    - EN: "The minimum effective radius (in mm) for gesture activation. Slight finger movements inside this range are ignored to prevent sudden value jumps near the center."
    - ZH: "手指触发旋转的最小距离阈值（单位：mm）。小于该半径的微小晃动不会被识别，能有效防止在旋钮中心附近的指针抖动或突变。"
  - **Inner Radius help**:
    - EN: "The boundary radius dividing the normal inner ring and the fine-tuning outer ring. Exceeding this radius automatically activates fine tuning (usually 0.1x speed)."
    - ZH: "划分“高灵敏度内环”与“低灵敏度外环”的半径分界线。手指旋划半径超过此值时，自动切换为精细调节（通常为 0.1 倍速）。"
  - **Max Radius help**:
    - EN: "The maximum radius for sensitivity scaling. Beyond this radius, the sensitivity stays at the maximum multiplier and does not increase further."
    - ZH: "无级变速灵敏度随距离线性增长的上限边界。当手指拉到该半径之外时，旋划速度达到最大倍率，不再继续随距离增加。"

- [ ] **步骤 2：Commit 本地化配置**
  ```bash
  git add PhantomKnob/Localizable.xcstrings
  git commit -m "chore: add localization strings for customizer tooltips"
  ```

---

### 任务 2：实现 `HUDHelpButton` 组件

**文件：**
- 修改：`PhantomKnob/View/CustomizerHUDView.swift`

- [ ] **步骤 1：在 `CustomizerHUDView.swift` 文件末尾（但在 `CustomizerHUDView` 之外的同一文件内）增加 `HUDHelpButton` struct**。
  - 逻辑包括：
    1. 用 `hoverWorkItem` 保存当前延迟展示的任务。
    2. `.onHover` 进入时设置 `DispatchWorkItem` 延迟 0.5s 触发 `isPresented = true`。
    3. `.onHover` 离开时 `hoverWorkItem?.cancel()`，并设 `isPresented = false`。
    4. `.onTapGesture` 直接立即切换 `isPresented` 的值，同时取消当前任何待执行的 `hoverWorkItem`。
    5. `.popover` 内层容器要配有毛玻璃背景 `VisualEffectView` 以确保视觉档次。

  实现参考：
  ```swift
  struct HUDHelpButton: View {
      let content: String
      
      @State private var isPresented = false
      @State private var hoverWorkItem: DispatchWorkItem?
      
      var body: some View {
          Image(systemName: "info.circle")
              .font(.system(size: 11))
              .foregroundColor(.white)
              .opacity(isPresented ? 0.8 : 0.4)
              .contentShape(Rectangle()) // 扩大交互热区
              .onHover { isHovering in
                  if isHovering {
                      let item = DispatchWorkItem {
                          withAnimation(.easeOut(duration: 0.15)) {
                              self.isPresented = true
                          }
                      }
                      self.hoverWorkItem = item
                      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
                  } else {
                      self.hoverWorkItem?.cancel()
                      self.hoverWorkItem = nil
                      withAnimation(.easeOut(duration: 0.15)) {
                          self.isPresented = false
                      }
                  }
              }
              .onTapGesture {
                  self.hoverWorkItem?.cancel()
                  self.hoverWorkItem = nil
                  self.isPresented.toggle()
              }
              .popover(isPresented: $isPresented, arrowEdge: .trailing) {
                  VStack(alignment: .leading, spacing: 6) {
                      Text(content)
                          .font(.system(size: 11))
                          .foregroundColor(.white)
                          .multilineTextAlignment(.leading)
                  }
                  .padding(10)
                  .frame(width: 220)
                  .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow).cornerRadius(8))
              }
      }
  }
  ```

- [ ] **步骤 2：编译项目验证语法**。
  在终端中验证 `HUDHelpButton` 无语法错误。

- [ ] **步骤 3：Commit 帮助按钮组件**
  ```bash
  git add PhantomKnob/View/CustomizerHUDView.swift
  git commit -m "feat: implement HUDHelpButton component with hover delay and click toggle"
  ```

---

### 任务 3：在定制面板各字段整合帮助提示

**文件：**
- 修改：`PhantomKnob/View/CustomizerHUDView.swift`

- [ ] **步骤 1：将 `HUDHelpButton` 添加 to “旋钮类型”标题右侧**。
  - 需要在 `Text(String(localized: "hud.knobType", defaultValue: "旋钮类型"))` 这一行外面套一个 `HStack`，并在其右侧附上 `HUDHelpButton`。
  - 需要根据当前的 `configType` 传入不同的多语言说明：
    - `configType == .single` 传入 `String(localized: "hud.knobType.help.single", defaultValue: "Standard single touch mode...")`
    - `configType == .double` 传入 `String(localized: "hud.knobType.help.double", defaultValue: "Automatic dual-gear mode...")`
    - `configType == .linear` 传入 `String(localized: "hud.knobType.help.linear", defaultValue: "Dynamic sensitivity mode...")`

- [ ] **步骤 2：将 `HUDHelpButton` 添加 to 各个参数标签右侧**。
  - **最小响应半径**：在 `Text(String(localized: "hud.minRadius", defaultValue: "最小响应半径"))` 右侧放入 `HUDHelpButton(content: String(localized: "hud.minRadius.help", defaultValue: "..."))`
  - **内外环分界**：在 `Text(String(localized: "hud.doubleInnerRadiusLabel", defaultValue: "内外环分界:"))` 右侧放入 `HUDHelpButton(content: String(localized: "hud.doubleInnerRadius.help", defaultValue: "..."))`
  - **最大显示半径**：在 `Text(String(localized: "hud.maxRadiusTitle", defaultValue: "最大显示半径"))` 右侧放入 `HUDHelpButton(content: String(localized: "hud.linearMaxRadius.help", defaultValue: "..."))`

- [ ] **步骤 3：确认布局紧凑并编译运行**。
  确保加上 `HStack` 和 `HUDHelpButton` 后界面对齐整洁，无约束冲突。

- [ ] **步骤 4：Commit 面板整合代码**
  ```bash
  git add PhantomKnob/View/CustomizerHUDView.swift
  git commit -m "feat: integrate tooltips next to knob type and parameters in CustomizerHUDView"
  ```

---

## 验证计划

### 手动交互验证
1. **呼出定制面板**：启动 PhantomKnob 并定位到可编辑旋钮，按下 `C` 键呼出 Customizer HUD 窗口。
2. **Hover 响应验证**：
   - 鼠标悬停在“旋钮类型”右侧的 `(i)` 图标上，等待 0.5 秒左右，确认能弹出气泡。
   - 鼠标快速划过该 `(i)` 图标（不超过 0.3 秒），气泡应该不会弹出（证明延时消抖逻辑正常）。
   - 鼠标离开 `(i)` 图标，气泡在短延迟后自动隐去。
3. **点击响应验证**：
   - 点击 `(i)` 图标，气泡立即显示；再次点击，气泡消失。
4. **动态文字更新验证**：
   - 在类型 Segmented Picker 中，分别切换为“单旋钮”、“双环”、“无级变速”。
   - 悬停或点击“旋钮类型”的帮助按钮，验证显示内容是否随当前选择动态更替为对应的解释。
5. **本地化测试**：
   - 将系统语言分别设为“简体中文”与“英文”，观察气泡内的中英文表达是否准确呈现。
