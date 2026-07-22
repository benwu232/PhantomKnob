# 用户指南第一页引导动画重构 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在用户指南的第一页（设备检测与简单旋钮）中，为用户进入页面时增加从右下往圆心滑动并淡入的鼠标引导动画（阶段一）；当鼠标移入旋钮上方后，自动切换为双指对称旋转轨迹微动画（阶段二）；当用户手指接触触控板（手势变为 active）或检测成功时，全部动画淡出消失，以零干扰方式辅助用户学习旋钮手势。

**架构：**
1. 在 `UserGuideView.swift` 中新增 `TwoFingerRotationGuideView` 动画视图。
2. 重载 `CursorGuideAnimationView` 动画逻辑为平滑位移的循环鼠标引导。
3. 在 `UserGuideView.swift` 的 `step1View` 布局中，结合 `viewModel.hovered`、`viewModel.isGestureActive` 和 `viewModel.isTouchpadDetected`，控制这两个引导动画视图的平滑切换与淡出隐藏。

**技术栈：** Swift 5.0, SwiftUI, Xcode, xcodebuild, git

---

### 任务 1：新增双指旋转手势引导组件 `TwoFingerRotationGuideView`

**文件：**
- 修改：`PhantomKnob/View/UserGuideView.swift`

- [ ] **步骤 1：在 `UserGuideView.swift` 文件底部追加 `TwoFingerRotationGuideView` 结构体**

  在 `UserGuideView.swift` 文件末尾（与 `CursorGuideAnimationView` 结构体平级）添加如下代码：
  ```swift
  struct TwoFingerRotationGuideView: View {
      @State private var rotationAngle: Double = -25.0
      
      var body: some View {
          ZStack {
              // 旋转轨道虚线圈
              Circle()
                  .stroke(
                      Color.blue.opacity(0.2),
                      style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 6])
                  )
                  .frame(width: 90, height: 90)
              
              // 触控点 1 (位于上方)
              Circle()
                  .fill(
                      RadialGradient(
                          colors: [Color.blue, Color.blue.opacity(0.3)],
                          center: .center,
                          startRadius: 0,
                          endRadius: 8
                      )
                  )
                  .frame(width: 16, height: 16)
                  .shadow(color: .blue.opacity(0.5), radius: 4)
                  .offset(y: -45)
                  .rotationEffect(.degrees(rotationAngle))
              
              // 触控点 2 (位于下方)
              Circle()
                  .fill(
                      RadialGradient(
                          colors: [Color.blue, Color.blue.opacity(0.3)],
                          center: .center,
                          startRadius: 0,
                          endRadius: 8
                      )
                  )
                  .frame(width: 16, height: 16)
                  .shadow(color: .blue.opacity(0.5), radius: 4)
                  .offset(y: 45)
                  .rotationEffect(.degrees(rotationAngle))
              
              // 中心微旋箭头
              Image(systemName: "arrow.triangle.2.circlepath")
                  .font(.system(size: 20, weight: .semibold))
                  .foregroundColor(.blue.opacity(0.8))
                  .rotationEffect(.degrees(-rotationAngle * 0.5))
          }
          .frame(width: 120, height: 120)
          .onAppear {
              withAnimation(
                  .easeInOut(duration: 1.6)
                  .repeatForever(autoreverses: true)
              ) {
                  rotationAngle = 25.0
              }
          }
      }
  }
  ```

- [ ] **步骤 2：编译项目验证新增代码无语法错误**

  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
  预期：Build Succeeded

- [ ] **步骤 3：Commit**

  ```bash
  git add PhantomKnob/View/UserGuideView.swift
  git commit -m "feat: add TwoFingerRotationGuideView component for user guide"
  ```

---

### 任务 2：重载鼠标滑动引导组件 `CursorGuideAnimationView`

**文件：**
- 修改：`PhantomKnob/View/UserGuideView.swift`

- [ ] **步骤 1：替换 `CursorGuideAnimationView` 的实现**

  在 `UserGuideView.swift` 中，将原本的 `CursorGuideAnimationView` 结构替换为如下代码：
  ```swift
  struct CursorGuideAnimationView: View {
      @State private var isAnimating = false
      
      var body: some View {
          Image(systemName: "cursorarrow")
              .font(.system(size: 28))
              .foregroundColor(.blue)
              .shadow(color: .blue.opacity(0.4), radius: 4)
              .offset(x: isAnimating ? 25 : 85, y: isAnimating ? -25 : -85)
              .opacity(isAnimating ? 1.0 : 0.0)
              .onAppear {
                  withAnimation(
                      .easeInOut(duration: 1.5)
                      .repeatForever(autoreverses: false)
                  ) {
                      isAnimating = true
                  }
              }
      }
  }
  ```

- [ ] **步骤 2：编译项目验证成功**

  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
  预期：Build Succeeded

- [ ] **步骤 3：Commit**

  ```bash
  git add PhantomKnob/View/UserGuideView.swift
  git commit -m "feat: refactor CursorGuideAnimationView with sliding arrow animation"
  ```

---

### 任务 3：集成引导动画至练习旋钮布局并加入状态流转控制

**文件：**
- 修改：`PhantomKnob/View/UserGuideView.swift`

- [ ] **步骤 1：修改 `step1View` 中的 ZStack 层次渲染逻辑**

  在 `UserGuideView.swift` 中，找到 `step1View` (位于第 164 行左右)，将如下的 ZStack 逻辑：
  ```swift
              ZStack {
                  RadialKnobControlView(
                      title: String(localized: "guide.step1.practiceKnob", defaultValue: "Volume Practice Dial"),
                      icon: "speaker.wave.3.fill",
                      value: viewModel.volumeVal,
                      angle: viewModel.rotationAngle,
                      isFocused: viewModel.hovered,
                      isGestureActive: viewModel.isGestureActive,
                      showPercentage: true
                  )
                  .onHover { isHover in
                      viewModel.hovered = isHover
                      viewModel.hoveredKnob = isHover ? .volumeKnob : .none
                  }
                  
                  if !viewModel.hovered && !viewModel.isTouchpadDetected {
                      CursorGuideAnimationView()
                          .offset(x: 70, y: -50)
                          .transition(.opacity)
                  }
              }
  ```
  修改替换为：
  ```swift
              ZStack {
                  RadialKnobControlView(
                      title: String(localized: "guide.step1.practiceKnob", defaultValue: "Volume Practice Dial"),
                      icon: "speaker.wave.3.fill",
                      value: viewModel.volumeVal,
                      angle: viewModel.rotationAngle,
                      isFocused: viewModel.hovered,
                      isGestureActive: viewModel.isGestureActive,
                      showPercentage: true
                  )
                  .onHover { isHover in
                      viewModel.hovered = isHover
                      viewModel.hoveredKnob = isHover ? .volumeKnob : .none
                  }
                  
                  if !viewModel.isTouchpadDetected && !viewModel.isGestureActive {
                      if !viewModel.hovered {
                          CursorGuideAnimationView()
                              .transition(.opacity)
                      } else {
                          TwoFingerRotationGuideView()
                              .transition(.opacity)
                      }
                  }
              }
  ```

- [ ] **步骤 2：运行单元测试集，确保已有的检测状态及流转测试完全通过**

  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
  预期：Test Succeeded（所有测试通过）

- [ ] **步骤 3：Commit**

  ```bash
  git add PhantomKnob/View/UserGuideView.swift
  git commit -m "feat: integrate guide animations conditional routing into step1View"
  ```
