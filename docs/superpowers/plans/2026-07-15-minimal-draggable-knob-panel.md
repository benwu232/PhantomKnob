# 标题与引导提示语优化对齐计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 依照 /grill-me 决策，进一步将标题调大为 title2 并下移 6pt，同时在旋钮下方添加 caption 引导说明。

**架构：**
- 修改 KnobPanelView 顶端 Text 样式。
- 在主布局下方堆叠 caption 操作说明文案。

---

### 任务 1：微调标题并添加操作说明文案

**文件：**
- 修改：`PhantomKnob/View/KnobPanelView.swift`

- [ ] **步骤 1：重构 KnobPanelView**
  修改 `PhantomKnob/View/KnobPanelView.swift`：
  ```swift
      var body: some View {
          VStack(spacing: 0) {
              // 顶部标题栏
              HStack {
                  HUDCircleButton(icon: "xmark", color: .white.opacity(0.7)) {
                      KnobPanelWindowController.shared.hide()
                  }
                  
                  Spacer()
                  
                  Text(String(localized: "panel.title", defaultValue: "PhantomKnob 快捷面板"))
                      .font(.title2)
                      .bold()
                      .foregroundColor(.white)
                      .padding(.top, 6)
                  
                  Spacer()
                  
                  HUDCircleButton(
                      icon: viewModel.isPinned ? "pin.fill" : "pin",
                      color: viewModel.isPinned ? .orange : .white.opacity(0.6)
                  ) {
                      viewModel.isPinned.toggle()
                  }
              }
              .padding(.horizontal, 16)
              .padding(.top, 16)
              
              Spacer()
              
              VStack(spacing: 20) {
                  mainControlLayout
                  
                  Text(String(localized: "panel.usage.hint", defaultValue: "提示：可通过鼠标悬停、键盘左右键或两指左右滑动来切换选择旋钮"))
                      .font(.caption)
                      .foregroundColor(.white.opacity(0.45))
                      .multilineTextAlignment(.center)
                      .padding(.horizontal, 32)
              }
              
              Spacer()
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .onAppear {
              if !firstRunTutorialCompleted {
                  firstRunTutorialCompleted = true
              }
          }
      }
  ```

- [ ] **步骤 2：运行测试验证**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnob -destination 'platform=macOS' test`
  预期：测试编译通过并全部通过。

- [ ] **步骤 3：Commit**
  运行：
  ```bash
  git add PhantomKnob/View/KnobPanelView.swift
  git commit -m "feat: make title font title2 with top offset and add instruction hint under knobs"
  ```
