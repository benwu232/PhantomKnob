# 快捷面板标题栏位置优化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将快捷面板的 title 移动到最上方的 Header 栏（与关闭和固定按钮水平对齐），建立标准的顶部标题栏布局。

**架构：**
- 修改 KnobPanelView 结构，将标题与 HUD 按钮整合在同一个顶部 HStack 标题栏中。
- 保证布局的呼吸感和毛玻璃面板通透感，不引入不必要的多余视图。

---

### 任务 1：重构 KnobPanelView 顶端 Header Bar

**文件：**
- 修改：`PhantomKnob/View/KnobPanelView.swift`

- [ ] **步骤 1：重构 KnobPanelView body**
  修改 `PhantomKnob/View/KnobPanelView.swift`，将 Text 标题移入顶部 HStack 中，移除底部的 overlay：
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
                      .font(.headline)
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
              
              Spacer(minLength: 16)
              
              mainControlLayout
                  .padding(.bottom, 24)
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
  git commit -m "feat: move title to top header bar alongside HUD buttons in KnobPanelView"
  ```
