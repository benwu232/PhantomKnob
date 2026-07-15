# 快捷面板标题大小与旋钮垂直居中优化计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 增大标题字号为 title3 并使旋钮在面板剩余空间垂直居中。

**架构：**
- 修改 KnobPanelView 结构，改用 title3 字号，并在主布局上下配置 Spacer() 实现垂直居中。

---

### 任务 1：调整 KnobPanelView 细节样式与间距

**文件：**
- 修改：`PhantomKnob/View/KnobPanelView.swift`

- [ ] **步骤 1：调整样式代码**
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
                      .font(.title3)
                      .bold()
                      .foregroundColor(.white)
                  
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
              
              mainControlLayout
              
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
  预期：所有单元测试依然编译并通过。

- [ ] **步骤 3：Commit**
  运行：
  ```bash
  git add PhantomKnob/View/KnobPanelView.swift
  git commit -m "feat: increase panel title size to title3 and center knobs vertically"
  ```
