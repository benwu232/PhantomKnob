# 用户指南第一页布局与文案重构实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将用户指南第一页的练习旋钮移到顶部，文字说明移到旋钮下方并采用结构化列表展现，同步更新中英双语本地化。

**架构：** 在 `UserGuideView.swift` 中调整 `step1View` 内部组件的 VStack 垂直流，新增卡片式列表子视图 `bulletItem`；修改 `Localizable.xcstrings` 资源文件以提供中英文对应的步骤描述项。

**技术栈：** SwiftUI, iOS/macOS Localization (.xcstrings)

---

## 计划变更文件

- 修改：`PhantomKnob/View/UserGuideView.swift`
- 修改：`PhantomKnob/Localizable.xcstrings`

---

### 任务 1：更新本地化资源文件

**文件：**
- 修改：`PhantomKnob/Localizable.xcstrings`

- [ ] **步骤 1：添加新的中英文本地化字符串**
  打开 `PhantomKnob/Localizable.xcstrings`，移除 `guide.step1.description` 键，新增 `guide.step1.intro`、`guide.step1.step1`、`guide.step1.step2`、`guide.step1.step3`、`guide.step1.footer` 新键对。
  * `guide.step1.intro`:
    - 中文："请在触控板上练习使用旋钮手势："
    - 英文："Please practice using the knob gesture on your trackpad:"
  * `guide.step1.step1`:
    - 中文："在系统设置 / 隐私与安全 / 辅助功能里为 PhantomKnob 授权"
    - 英文："Grant accessibility permission to PhantomKnob in System Settings > Privacy & Security > Accessibility."
  * `guide.step1.step2`:
    - 中文："移动鼠标到音量练习旋钮上"
    - 英文："Move the cursor onto the volume practice dial."
  * `guide.step1.step3`:
    - 中文："用两指接触触控板，并做旋转动作"
    - 英文："Touch the trackpad with two fingers and perform a rotation gesture."
  * `guide.step1.footer`:
    - 中文："系统将检测硬件是否支持旋钮手势；如果支持，执行旋钮手势，您将看到旋钮旋转并听到音量变化。"
    - 英文："The system will detect whether your hardware supports knob gestures; if supported, you will see the dial rotate and hear the volume change."

- [ ] **步骤 2：验证 JSON 格式有效性**
  确认 `.xcstrings` 依然是合法的 JSON 格式。

- [ ] **步骤 3：Commit 变更**
  ```bash
  git add PhantomKnob/Localizable.xcstrings
  git commit -m "chore: update user guide step 1 localization keys"
  ```

---

### 任务 2：重构 SwiftUI 用户指南视图

**文件：**
- 修改：`PhantomKnob/View/UserGuideView.swift`

- [ ] **步骤 1：在 UserGuideView 中添加 bulletItem 私有辅助视图**
  在 `UserGuideView` 的 `extension` 或主体中新增：
  ```swift
  private func bulletItem(text: String) -> some View {
      HStack(alignment: .top, spacing: 6) {
          Text("•")
              .foregroundColor(.blue)
              .font(.system(size: 13, weight: .bold))
          Text(text)
              .font(.system(size: 12))
              .foregroundColor(.white.opacity(0.8))
              .fixedSize(horizontal: false, vertical: true)
      }
  }
  ```

- [ ] **步骤 2：重构成新版 `step1View` 布局流**
  修改 `step1View` 属性：
  1. 移去顶部的 `Text(String(localized: "guide.step1.description", ...))`。
  2. 保持 `ZStack` 旋钮区在顶部：
     ```swift
     ZStack {
         RadialKnobControlView(...)
         if !viewModel.hovered && !viewModel.isTouchpadDetected { ... }
     }
     .frame(height: 140)
     ```
  3. 在 `ZStack` 下方新增引导卡片视图 `VStack`，展示列表项和页脚提示：
     ```swift
     VStack(alignment: .leading, spacing: 6) {
         Text(String(localized: "guide.step1.intro", defaultValue: "Please practice using the knob gesture on your trackpad:"))
             .font(.system(size: 13, weight: .semibold))
             .foregroundColor(.white)
             .padding(.bottom, 2)
         
         VStack(alignment: .leading, spacing: 4) {
             bulletItem(text: String(localized: "guide.step1.step1", defaultValue: "Grant accessibility permission to PhantomKnob in System Settings > Privacy & Security > Accessibility."))
             bulletItem(text: String(localized: "guide.step1.step2", defaultValue: "Move the cursor onto the volume practice dial."))
             bulletItem(text: String(localized: "guide.step1.step3", defaultValue: "Touch the trackpad with two fingers and perform a rotation gesture."))
         }
         
         Text(String(localized: "guide.step1.footer", defaultValue: "The system will detect whether your hardware supports knob gestures; if supported, you will see the dial rotate and hear the volume change."))
             .font(.system(size: 11))
             .foregroundColor(.white.opacity(0.6))
             .padding(.top, 4)
             .fixedSize(horizontal: false, vertical: true)
     }
     .padding(.horizontal, 24)
     .padding(.vertical, 12)
     .background(Color.white.opacity(0.03))
     .cornerRadius(8)
     .overlay(
         RoundedRectangle(cornerRadius: 8)
             .stroke(Color.white.opacity(0.05), lineWidth: 1)
     )
     .padding(.horizontal, 32)
     ```
  4. 随后是 `HStack` 触控板检测状态指示器和 `Spacer()`。

- [ ] **步骤 3：构建并运行项目验证编译正常**
  运行：`xcodebuild -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -configuration Debug build`
  预期：Build Succeeded.

- [ ] **步骤 4：运行现有单元测试**
  运行：`xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination "platform=macOS"`
  预期：Tests Succeeded.

- [ ] **步骤 5：Commit 变更**
  ```bash
  git add PhantomKnob/View/UserGuideView.swift
  git commit -m "feat: adjust user guide step 1 layout and view components"
  ```
