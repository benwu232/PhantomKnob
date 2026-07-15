# 聚焦旋钮动态放大优化计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`） syntax 来跟踪进度。

**目标：** 在聚焦时将旋钮 ZStack 图形弹性放大至 1.15 倍。

**架构：**
- 修改 KnobPanelView 里的 RadialKnobControlView，为 ZStack 容器添加 scaleEffect 和 spring 动画。

---

### 任务 1：为 RadialKnobControlView 添加聚焦缩放

**文件：**
- 修改：`PhantomKnob/View/KnobPanelView.swift`

- [ ] **步骤 1：添加缩放动画代码**
  修改 `PhantomKnob/View/KnobPanelView.swift` 中的 `RadialKnobControlView` body：
  ```swift
      var body: some View {
          VStack(spacing: 12) {
              ZStack {
                  // Glow circle
                  Circle()
                      .stroke(Color.blue.opacity(isFocused ? 0.3 : 0.05), lineWidth: 8)
                      .frame(width: 120, height: 120)
                      .blur(radius: isFocused ? 4 : 0)
                  
                  // Progress arc
                  Circle()
                      .trim(from: 0.0, to: CGFloat(value))
                      .stroke(
                          LinearGradient(
                              colors: [Color.blue, Color.cyan],
                              startPoint: .top,
                              endPoint: .bottom
                          ),
                          style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                      .frame(width: 104, height: 104)
                      .rotationEffect(Angle(degrees: -90))
                  
                  // Inner dial circle
                  Circle()
                      .fill(Color.black.opacity(0.4))
                      .frame(width: 90, height: 90)
                      .shadow(radius: isFocused ? 8 : 2)
                  
                  // Indicator dot
                  if isFocused && isGestureActive {
                      Circle()
                          .fill(Color.white.opacity(0.8))
                          .frame(width: 6, height: 6)
                          .offset(y: -38)
                          .rotationEffect(Angle(degrees: angle))
                  }
                  
                  // Icon
                  Image(systemName: icon)
                      .font(.system(size: 28))
                      .foregroundColor(isFocused ? .blue : .white.opacity(0.8))
              }
              .scaleEffect(isFocused ? 1.15 : 1.0)
              .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFocused)
              
              Text(title)
  ```

- [ ] **步骤 2：运行测试验证**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnob -destination 'platform=macOS' test`
  预期：所有单元测试依然编译并通过。

- [ ] **步骤 3：Commit**
  运行：
  ```bash
  git add PhantomKnob/View/KnobPanelView.swift
  git commit -m "feat: apply spring-based scaleEffect to focused radial knobs"
  ```
