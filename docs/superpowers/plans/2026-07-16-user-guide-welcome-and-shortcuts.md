# 用户指南：新增欢迎页与快捷键/操作速查页 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在用户指南中新增第 1 页（欢迎与介绍页）和第 5 页（快捷键与操作速查页），支持在状态栏菜单中直接跳转到第 5 页，并实现全面的本地化支持和单元测试验证。

**架构：**
1. 扩展 `UserGuideViewModel` 的步骤范围至 `1...5`，并允许在接收到显示窗口通知时根据控制器传递的目标步数重置状态。
2. 在 `UserGuideView` 中新增 `welcomeView` (Step 1) 与 `shortcutsView` (Step 5)，调整现有的 Step 2-4 的渲染逻辑与底部导航控制。
3. 更新 `UserGuideWindowController` 支持 `show(step:)` 调用。
4. 在 `StatusBarController` 中新增快捷菜单项，并在此及 `UserGuideView` 中补充中英文本地化字符串。

**技术栈：** Swift 5.0, SwiftUI, Xcode, xcodebuild, git

---

### 任务 1：升级 ViewModel 与测试用例

**文件：**
- 修改：`PhantomKnob/ViewModel/UserGuideViewModel.swift`
- 修改：`PhantomKnob/PhantomKnobTests/UserGuideViewModelTests.swift`

- [ ] **步骤 1：编写失败的测试**

  修改 `PhantomKnob/PhantomKnobTests/UserGuideViewModelTests.swift` 中的测试，验证 5 步状态流转以及从通知重置到指定步数的能力。
  ```swift
      func testFiveStepTransitionsAndTargetStepReset() {
          let vm = UserGuideViewModel(audioService: AudioControlService())
          XCTAssertEqual(vm.currentStep, 1)

          // 初始状态，Step 1 跳转到 Step 2 不需要检测
          vm.nextStep()
          XCTAssertEqual(vm.currentStep, 2)

          // Step 2 必须通过检测才能下一步
          vm.nextStep()
          XCTAssertEqual(vm.currentStep, 2) // 被拦截

          // 模拟通过检测
          vm.isTouchpadDetected = true
          vm.nextStep()
          XCTAssertEqual(vm.currentStep, 3)

          vm.nextStep()
          XCTAssertEqual(vm.currentStep, 4)

          vm.nextStep()
          XCTAssertEqual(vm.currentStep, 5)

          // 模拟再次显示窗口并重置到第 5 步
          UserGuideWindowController.shared.initialStep = 5
          NotificationCenter.default.post(name: NSNotification.Name("UserGuideWindowDidShow"), object: nil)
          XCTAssertEqual(vm.currentStep, 5)
      }
  ```

- [ ] **步骤 2：运行测试验证失败**

  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO -only-testing PhantomKnobTests/UserGuideViewModelTests/testFiveStepTransitionsAndTargetStepReset`
  预期：编译失败或测试 FAIL（因为 `currentStep` 流程仍为 1...3，且 `initialStep` 尚未加入）。

- [ ] **步骤 3：编写最少实现代码**

  修改 `PhantomKnob/ViewModel/UserGuideViewModel.swift`：
  1. 将所有原本关联 Step 1 的逻辑改为 Step 2，原本 Step 2 改为 Step 3，原本 Step 3 改为 Step 4。
  2. 修改 `resetState(targetStep: Int = 1)` 方法，使其支持接收参数并重置 `currentStep`。
  3. 修改 `setupBindings` 中监听 `UserGuideWindowDidShow` 处的逻辑，获取 `UserGuideWindowController.shared.initialStep` 并传递给 `resetState`。
  4. 修改 `nextStep` 范围。

  ```swift
  // -- Line 77-83 in setupBindings() --
          NotificationCenter.default.publisher(for: NSNotification.Name("TouchpadCoordinatesValidated"))
              .sink { [weak self] notification in
                  guard let self = self else { return }
                  if self.currentStep == 2 { // Shifting Step 1 to Step 2
                      self.touchpadSamplesCount += 1
                  } else if self.currentStep == 3 { // Shifting Step 2 to Step 3
                      if let points = notification.userInfo?["points"] as? [Int: CGPoint] {
                          self.processTouchPoints(points)
                      }
                  }
              }
              .store(in: &cancellables)

  // -- Line 98 in setupBindings() --
          NotificationCenter.default.publisher(for: NSNotification.Name("KnobBaseScaleDidUpdate"))
              .sink { [weak self] notification in
                  guard let self = self, self.currentStep == 3 else { return } // Shifting Step 2 to Step 3
                  if let scale = notification.userInfo?["scale"] as? Double {
                      self.currentMultiplier = scale
                  }
              }
              .store(in: &cancellables)

  // -- Line 127 in setupBindings() --
          NotificationCenter.default.publisher(for: NSNotification.Name("UserGuideWindowDidShow"))
              .sink { [weak self] _ in
                  let targetStep = UserGuideWindowController.shared.initialStep
                  self?.resetState(targetStep: targetStep)
              }
              .store(in: &cancellables)

  // -- Line 134 nextStep() --
      func nextStep() {
          if currentStep == 2 && !isTouchpadDetected { return }
          if currentStep < 5 {
              currentStep += 1
          }
      }

  // -- Line 143 registerRotation() --
      func registerRotation(_ degrees: Double) {
          let absDeg = abs(degrees)
          accumulatedRotation += absDeg
          
          if currentStep == 2 { // Shifted
              guard hovered else { return }
              // ... 原 volume 旋转代码 ...
              if accumulatedRotation >= 30.0 && !isTouchpadDetected {
                  isTouchpadDetected = true
                  UserDefaults.app.set(true, forKey: "userGuideTouchpadPracticed")
              }
          } else if currentStep == 3 { // Shifted
              if hoveredKnob == .doubleKnob {
                  // ... 原 doubleKnob 旋转代码 ...
              } else if hoveredKnob == .linearKnob {
                  // ... 原 linearKnob 旋转代码 ...
              }
          }
      }

  // -- Line 264 resetState() --
      func resetState(targetStep: Int = 1) {
          currentStep = targetStep
          isTouchpadDetected = UserDefaults.app.bool(forKey: "userGuideTouchpadPracticed")
          touchpadSamplesCount = 0
          volumeVal = audioService.getVolume() ?? 0.5
          rotationAngle = 0.0
          accumulatedRotation = 0.0
          hovered = false
          hoveredKnob = .none
          doubleKnobVal = 50.0
          linearKnobVal = 50.0
          doubleKnobAngle = 0.0
          linearKnobAngle = 0.0
          doubleKnobDiameter = 120.0
          linearKnobDiameter = 120.0
      }
  ```

- [ ] **步骤 4：运行测试验证通过**

  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO -only-testing PhantomKnobTests/UserGuideViewModelTests`
  预期：所有 UserGuideViewModelTests 均通过（PASS）。

- [ ] **步骤 5：Commit**

  ```bash
  git add PhantomKnob/ViewModel/UserGuideViewModel.swift PhantomKnob/PhantomKnobTests/UserGuideViewModelTests.swift
  git commit -m "feat: upgrade UserGuideViewModel to support 5 steps and deep-link step reset"
  ```

---

### 任务 2：升级 Window Controller 以支持直接跳转

**文件：**
- 修改：`PhantomKnob/Service/UserGuideWindowController.swift`

- [ ] **步骤 1：编写最少实现代码**

  修改 `PhantomKnob/Service/UserGuideWindowController.swift`，增加 `initialStep` 变量并更新 `show(step:)` 方法。
  ```swift
  // -- Inside UserGuideWindowController class --
      var isPinned: Bool = false
      var initialStep: Int = 1 // Added
      
      var isVisible: Bool {
          return window?.isVisible ?? false
      }
      
      func show(step: Int? = nil) {
          self.initialStep = step ?? 1 // Added
          
          if window == nil {
              createWindow()
          }
          
          window?.makeKeyAndOrderFront(nil)
          NSApp.activate(ignoringOtherApps: true)
          // ... 其它原有 show 逻辑 ...
          NotificationCenter.default.post(name: NSNotification.Name("UserGuideWindowDidShow"), object: nil)
          NotificationCenter.default.post(name: NSNotification.Name("KnobPanelDidShow"), object: nil)
      }
  ```

- [ ] **步骤 2：运行测试验证通过**

  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO -only-testing PhantomKnobTests/UserGuideViewModelTests`
  预期：PASS。

- [ ] **步骤 3：Commit**

  ```bash
  git add PhantomKnob/Service/UserGuideWindowController.swift
  git commit -m "feat: add support for initialStep in UserGuideWindowController"
  ```

---

### 任务 3：升级 UserGuideView UI 布局（新增第 1 页与第 5 页）

**文件：**
- 修改：`PhantomKnob/View/UserGuideView.swift`

- [ ] **步骤 1：编写最少实现代码**

  修改 `PhantomKnob/View/UserGuideView.swift`，增加欢迎视图与速查视图，以及重构页头标题和页脚导航：
  1. 在 Header 更新标题和副标题支持 5 步：
     - Step 1: `guide.stepWelcome.title` ("Welcome to PhantomKnob"), subtitle: `guide.stepWelcome.subtitle` ("Discover how to use trackpad gestures to control sliders")
     - Step 2: `guide.step1.title` ("Step 1: Detect & Rotate"), subtitle: `guide.step1.subtitle` ("Verify your trackpad and practice the rotation gesture")
     - Step 3: `guide.step2.title` ("Step 2: Advanced Knobs"), subtitle: `guide.step2.subtitle` ("Practice double-ring and variable speed knobs, adjust speed, and try customizer")
     - Step 4: `guide.step3.title` ("Step 3: Go Global"), subtitle: `guide.step3.subtitle` ("Master shortcuts and discover supported apps")
     - Step 5: `guide.stepShortcuts.title` ("Shortcuts & Operations Guide"), subtitle: `guide.stepShortcuts.subtitle` ("Quick reference manual for system gestures and shortcuts")
  2. 实现 `welcomeView` 与 `shortcutsView`；重写主 Content 的渲染分支（`1` 为 `welcomeView`，`2` 为 `step1View`，`3` 为 `step2View`，`4` 为 `step3View`，`5` 为 `shortcutsView`）。
  3. 更改 `Footer` 导航按钮判断：
     - 上一步按钮条件：`viewModel.currentStep > 1`
     - 下一步按钮条件：`viewModel.currentStep < 5`
     - 退出按钮条件：`viewModel.currentStep == 5`
     - 下一步按钮的 `disabled` 状态：仅在 `viewModel.currentStep == 2 && !viewModel.isTouchpadDetected` 时禁用。
  4. 实现 `shortcutsView` 里的详细内容，遵循 C 键在最顶部的辅助键排序规则。

  ```swift
  // -- Headers update --
  // Update header logic based on currentStep 1...5
  
  // -- Content update --
  Group {
      if viewModel.currentStep == 1 {
          welcomeView
      } else if viewModel.currentStep == 2 {
          step1View
      } else if viewModel.currentStep == 3 {
          step2View
      } else if viewModel.currentStep == 4 {
          step3View
      } else {
          shortcutsView
      }
  }

  // -- welcomeView --
  private var welcomeView: some View {
      VStack(spacing: 24) {
          Spacer()
          Image(nsImage: NSImage(named: "NSApplicationIcon") ?? NSImage())
              .resizable()
              .frame(width: 80, height: 80)
              .cornerRadius(18)
              .shadow(color: Color.black.opacity(0.2), radius: 6, y: 3)
          
          VStack(spacing: 8) {
              Text(String(localized: "guide.welcome.headline", defaultValue: "Welcome to PhantomKnob"))
                  .font(.system(size: 22, weight: .bold))
                  .foregroundColor(.white)
              
              Text(String(localized: "guide.welcome.intro", defaultValue: "Use natural two-finger rotation gestures to precisely control\nsliders and dials in video or audio editors, just like a physical dial."))
                  .font(.system(size: 13))
                  .foregroundColor(.white.opacity(0.75))
                  .multilineTextAlignment(.center)
                  .lineSpacing(5)
                  .padding(.horizontal, 40)
          }
          
          Spacer()
          
          Button(action: {
              withAnimation {
                  viewModel.nextStep()
              }
          }) {
              Text(String(localized: "guide.welcome.start", defaultValue: "Start Onboarding Guide"))
                  .font(.system(size: 13, weight: .semibold))
                  .foregroundColor(.white)
                  .padding(.horizontal, 24)
                  .padding(.vertical, 10)
                  .background(
                      LinearGradient(
                          colors: [Color.blue, Color.cyan],
                          startPoint: .leading,
                          endPoint: .trailing
                      )
                  )
                  .cornerRadius(8)
                  .shadow(color: Color.blue.opacity(0.3), radius: 4, y: 2)
          }
          .buttonStyle(.plain)
          
          Spacer()
      }
  }

  // -- shortcutsView --
  private var shortcutsView: some View {
      ScrollView(showsIndicators: true) {
          VStack(alignment: .leading, spacing: 20) {
              
              // 状态栏图标操作
              VStack(alignment: .leading, spacing: 8) {
                  Text(String(localized: "guide.shortcuts.section.statusbar", defaultValue: "Status Bar Icon Operations"))
                      .font(.system(size: 13, weight: .bold))
                      .foregroundColor(.blue)
                  
                  shortcutRow(key: String(localized: "guide.shortcuts.statusbar.click", defaultValue: "Single Click"), desc: String(localized: "guide.shortcuts.statusbar.click.desc", defaultValue: "Toggle global gesture control mode (activate/deactivate)"))
                  shortcutRow(key: String(localized: "guide.shortcuts.statusbar.doubleClick", defaultValue: "Double Click"), desc: String(localized: "guide.shortcuts.statusbar.doubleClick.desc", defaultValue: "Show/hide the shortcut button panel (Control Panel)"))
                  shortcutRow(key: String(localized: "guide.shortcuts.statusbar.rightClick", defaultValue: "Right Click / Ctrl+Click"), desc: String(localized: "guide.shortcuts.statusbar.rightClick.desc", defaultValue: "Open app system menu (Settings, User Guide, etc.)"))
              }
              .padding(12)
              .background(Color.white.opacity(0.03))
              .cornerRadius(8)
              
              // 键盘快捷键
              VStack(alignment: .leading, spacing: 8) {
                  Text(String(localized: "guide.shortcuts.section.keyboard", defaultValue: "Keyboard Shortcuts"))
                      .font(.system(size: 13, weight: .bold))
                      .foregroundColor(.orange)
                  
                  shortcutRow(key: "⌘ ⌥ K", desc: String(localized: "guide.shortcuts.keyboard.toggle", defaultValue: "Global control switch shortcut — toggle active state instantly"))
                  shortcutRow(key: String(localized: "guide.shortcuts.keyboard.bypass", defaultValue: "Hold Option Key"), desc: String(localized: "guide.shortcuts.keyboard.bypass.desc", defaultValue: "Temporarily bypass gestures to use native trackpad scroll or zoom"))
              }
              .padding(12)
              .background(Color.white.opacity(0.03))
              .cornerRadius(8)

              // 旋转辅助按键 (C 键排第一)
              VStack(alignment: .leading, spacing: 8) {
                  Text(String(localized: "guide.shortcuts.section.auxiliary", defaultValue: "Auxiliary Keys (Active During Rotation)"))
                      .font(.system(size: 13, weight: .bold))
                      .foregroundColor(.green)
                  
                  shortcutRow(key: "C", desc: String(localized: "guide.shortcuts.auxiliary.cKey", defaultValue: "Press during gesture rotation to directly show the Customizer panel"))
                  shortcutRow(key: "1", desc: String(localized: "guide.shortcuts.auxiliary.key1", defaultValue: "Reset rotation speed to 1.0x of the base speed setting"))
                  shortcutRow(key: "2 - 9", desc: String(localized: "guide.shortcuts.auxiliary.key2to9", defaultValue: "Set rotation speed multiplier to 2.0x ~ 9.0x of the base speed setting"))
                  shortcutRow(key: "↑ / ↓", desc: String(localized: "guide.shortcuts.auxiliary.arrowsVertical", defaultValue: "Increase/decrease rotation speed multiplier by 1.0x"))
                  shortcutRow(key: "← / →", desc: String(localized: "guide.shortcuts.auxiliary.arrowsHorizontal", defaultValue: "Increase/decrease rotation speed multiplier by 0.1x"))
              }
              .padding(12)
              .background(Color.white.opacity(0.03))
              .cornerRadius(8)
          }
          .padding(.horizontal, 24)
          .padding(.vertical, 16)
      }
  }

  private func shortcutRow(key: String, desc: String) -> some View {
      HStack(alignment: .top, spacing: 12) {
          Text(key)
              .font(.system(size: 11, weight: .semibold, design: .monospaced))
              .foregroundColor(.white)
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(Color.white.opacity(0.12))
              .cornerRadius(4)
              .frame(width: 140, alignment: .leading)
          
          Text(desc)
              .font(.system(size: 12))
              .foregroundColor(.white.opacity(0.7))
              .fixedSize(horizontal: false, vertical: true)
          
          Spacer()
      }
  }
  ```

- [ ] **步骤 2：运行测试验证通过**

  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
  预期：所有编译与单元测试成功。

- [ ] **步骤 3：Commit**

  ```bash
  git add PhantomKnob/View/UserGuideView.swift
  git commit -m "feat: implement UserGuideView layout for Step 1 (Welcome) and Step 5 (Shortcuts Reference)"
  ```

---

### 任务 4：在系统菜单中添加直接入口与本地化文件升级

**文件：**
- 修改：`PhantomKnob/Service/StatusBarController.swift`
- 修改：`PhantomKnob/Localizable.xcstrings`

- [ ] **步骤 1：编写最少实现代码**

  1. 修改 `PhantomKnob/Service/StatusBarController.swift`：
     在 `setupMenu()` 的 `guideMenuItem` 下方增加“快捷键与操作速查…”入口。
     ```swift
             // -- Below guideMenuItem in setupMenu() --
             let shortcutsMenuItem = NSMenuItem(
                 title: String(localized: "menu.shortcutsGuide", defaultValue: "Shortcuts & Operations…"),
                 action: #selector(openShortcutsGuide),
                 keyEquivalent: ""
             )
             shortcutsMenuItem.target = self
             menu?.addItem(shortcutsMenuItem)
     ```
     实现对应的 selector：
     ```swift
         @objc private func openShortcutsGuide() {
             PKLogger.statusBar.info("openShortcutsGuide menu item clicked")
             UserGuideWindowController.shared.show(step: 5)
         }
     ```

  2. 修改 `PhantomKnob/Localizable.xcstrings`。
     用 JSON 的编辑方式，添加以下英中对照翻译 key：
     - `"menu.shortcutsGuide"`: `Shortcuts & Operations…` -> `快捷键与操作速查…`
     - `"guide.welcome.headline"`: `Welcome to PhantomKnob` -> `欢迎使用 PhantomKnob`
     - `"guide.welcome.intro"`: `Use natural two-finger rotation gestures to precisely control\nsliders and dials in video or audio editors, just like a physical dial.` -> `利用自然的手势双指旋转，像使用物理旋钮一样精确控制\n视频或音频编辑器中的滑块和表盘。`
     - `"guide.welcome.start"`: `Start Onboarding Guide` -> `开始新手引导`
     - `"guide.stepWelcome.title"`: `Welcome` -> `欢迎使用`
     - `"guide.stepWelcome.subtitle"`: `Discover how to use trackpad gestures to control sliders` -> `了解如何使用触控板手势控制滑块`
     - `"guide.stepShortcuts.title"`: `Shortcuts & Operations` -> `快捷键与操作速查`
     - `"guide.stepShortcuts.subtitle"`: `Quick reference manual for system gestures and shortcuts` -> `触控板手势交互与键盘辅助键快速参考手册`
     - `"guide.shortcuts.section.statusbar"`: `Status Bar Icon Operations` -> `状态栏图标操作`
     - `"guide.shortcuts.statusbar.click"`: `Single Click` -> `单 击`
     - `"guide.shortcuts.statusbar.click.desc"`: `Toggle global gesture control mode (activate/deactivate)` -> `开启 / 关闭全局手势控制（切换旋钮状态）`
     - `"guide.shortcuts.statusbar.doubleClick"`: `Double Click` -> `双 击`
     - `"guide.shortcuts.statusbar.doubleClick.desc"`: `Show/hide the shortcut button panel (Control Panel)` -> `显示 / 隐藏快捷按钮面板`
     - `"guide.shortcuts.statusbar.rightClick"`: `Right Click / Ctrl+Click` -> `右 键`
     - `"guide.shortcuts.statusbar.rightClick.desc"`: `Open app system menu (Settings, User Guide, etc.)` -> `打开系统菜单（包含设置、使用引导等）`
     - `"guide.shortcuts.section.keyboard"`: `Keyboard Shortcuts` -> `键盘快捷键`
     - `"guide.shortcuts.keyboard.toggle"`: `Global Control Toggle` -> `全局控制开关`
     - `"guide.shortcuts.keyboard.bypass"`: `Hold Option Key` -> `按住 Option 键`
     - `"guide.shortcuts.keyboard.bypass.desc"`: `Temporarily bypass gestures to use native trackpad scroll or zoom` -> `临时旁路手势，恢复系统原生的双指滚动或缩放`
     - `"guide.shortcuts.section.auxiliary"`: `Auxiliary Keys (Active During Rotation)` -> `手势旋转时的辅助按键`
     - `"guide.shortcuts.auxiliary.cKey"`: `Press during gesture rotation to directly show the Customizer panel` -> `手势旋转中按下，直接呼出自定义（Customizer）面板`
     - `"guide.shortcuts.auxiliary.key1"`: `Reset rotation speed to 1.0x of the base speed setting` -> `重置旋转速度为基本设置的 1.0 倍`
     - `"guide.shortcuts.auxiliary.key2to9"`: `Set rotation speed multiplier to 2.0x ~ 9.0x of the base speed setting` -> `设定旋转速度为基本设置的 2.0 倍 - 9.0 倍`
     - `"guide.shortcuts.auxiliary.arrowsVertical"`: `Increase/decrease rotation speed multiplier by 1.0x` -> `以 1.0 倍为步长调整（增加 / 减少）旋转速度`
     - `"guide.shortcuts.auxiliary.arrowsHorizontal"`: `Increase/decrease rotation speed multiplier by 0.1x` -> `以 0.1 倍为步长调整（增加 / 减少）旋转速度`

- [ ] **步骤 2：运行完整编译与单元测试验证**

  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
  预期：测试全部 PASS，应用正常编译成功。

- [ ] **步骤 3：Commit**

  ```bash
  git add PhantomKnob/Service/StatusBarController.swift PhantomKnob/Localizable.xcstrings
  git commit -m "feat: add status bar shortcuts guide entry and update localization strings"
  ```
