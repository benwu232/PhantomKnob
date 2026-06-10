# User Guide (使用引导) 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现独立的使用引导（User Guide）毛玻璃窗口，包含 3 步新手教学流、光标移入提示、100° 手势旋转练习与系统音量同步修改、以及每次 1° 旋转触发系统嘀嗒反馈音，并在首次启动自动呼出及状态栏菜单常驻入口。

**架构：**
1. **UserGuideWindowController**：创建独立的 `UserGuideWindow` 无边框毛玻璃 `NSPanel`（560x400）控制其生命周期及外部点击/失去焦点自动关闭。
2. **UserGuideView & UserGuideViewModel**：SwiftUI 编写三步流程视图。通过通知监听手势旋转 delta，动态计算 1° 步长播放 `AudioServicesPlaySystemSound(1104)`，并通过 `AudioControlService` 同步调节系统音量，满 100° 时解锁下一步。
3. **KnobStateManager & StatusBarController 整合**：扩展 `onMultitouchBegan` 中的可见性判断使其适配 `UserGuide` 手势；在常规状态栏菜单中插入“使用引导...”菜单项，并于首次运行冷启动时检测 `firstRunUserGuideCompleted` 标志判定自动弹出。

**技术栈：** AppKit (NSPanel, NSVisualEffectView), SwiftUI, CoreAudio (AudioServices), Combine

---

### 任务 1：创建使用引导视图模型及单元测试 (UserGuide ViewModel)

**文件：**
- 创建：`PhantomKnob/ViewModel/UserGuideViewModel.swift`
- 测试：`PhantomKnobTests/UserGuideViewModelTests.swift`

- [ ] **步骤 1：编写失败的测试**
  在 `PhantomKnobTests/UserGuideViewModelTests.swift` 中编写测试验证三步引导流程变化、嘀嗒声角度累加计算、以及累计旋转 100° 时解锁第二步的判断条件：
  ```swift
  import XCTest
  @testable import PhantomKnob

  class UserGuideViewModelTests: XCTestCase {
      func testUserGuideStepTransitionsAndRotationUnlock() {
          let vm = UserGuideViewModel(audioService: AudioControlService())
          XCTAssertEqual(vm.currentStep, 1)
          
          vm.nextStep()
          XCTAssertEqual(vm.currentStep, 2)
          XCTAssertFalse(vm.isStep2Unlocked)
          XCTAssertEqual(vm.accumulatedRotation, 0.0)
          
          // 模拟旋转 60.5°
          vm.registerRotation(60.5)
          XCTAssertFalse(vm.isStep2Unlocked)
          XCTAssertEqual(vm.accumulatedRotation, 60.5)
          
          // 模拟旋转 40.0° (累计 100.5°)
          vm.registerRotation(40.0)
          XCTAssertTrue(vm.isStep2Unlocked)
          XCTAssertEqual(vm.accumulatedRotation, 100.5)
          
          vm.nextStep()
          XCTAssertEqual(vm.currentStep, 3)
      }
      
      func testTickSoundAccumulation() {
          let vm = UserGuideViewModel(audioService: AudioControlService())
          XCTAssertEqual(vm.getTickAccumulator(), 0.0)
          
          // 累计不到 1°，不触发 Tick 消费
          let ticksPlayed1 = vm.updateTickAccumulationAndGetTicks(0.8)
          XCTAssertEqual(ticksPlayed1, 0)
          XCTAssertEqual(vm.getTickAccumulator(), 0.8)
          
          // 累计超过 1° (0.8 + 1.4 = 2.2)，触发 2 次 Tick，剩余 0.2
          let ticksPlayed2 = vm.updateTickAccumulationAndGetTicks(1.4)
          XCTAssertEqual(ticksPlayed2, 2)
          XCTAssertEqual(vm.getTickAccumulator(), 0.20, accuracy: 0.01)
      }
  }
  ```

- [ ] **步骤 2：运行测试验证失败**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
  预期：编译失败，找不到 `UserGuideViewModel` 类型。

- [ ] **步骤 3：编写最少实现代码**
  创建 `PhantomKnob/ViewModel/UserGuideViewModel.swift`：
  ```swift
  import Foundation
  import SwiftUI
  import Combine
  import AudioToolbox

  class UserGuideViewModel: ObservableObject {
      @Published var currentStep: Int = 1
      @Published var isStep2Unlocked: Bool = false
      @Published var accumulatedRotation: Double = 0.0
      @Published var volumeVal: Float = 0.5
      @Published var hovered: Bool = false
      @Published var rotationAngle: Double = 0.0
      
      private var tickAccumulator: Double = 0.0
      private let audioService: AudioControlService
      private var cancellables = Set<AnyCancellable>()
      
      init(audioService: AudioControlService = AudioControlService()) {
          self.audioService = audioService
          self.volumeVal = audioService.getVolume() ?? 0.5
          setupBindings()
      }
      
      private func setupBindings() {
          NotificationCenter.default.publisher(for: NSNotification.Name("KnobPanelDidRotate"))
              .sink { [weak self] notification in
                  guard let self = self, self.currentStep == 2, self.hovered else { return }
                  if let delta = notification.userInfo?["delta"] as? Double {
                      self.registerRotation(delta)
                  }
              }
              .store(in: &cancellables)
      }
      
      func nextStep() {
          if currentStep == 2 && !isStep2Unlocked { return }
          currentStep += 1
      }
      
      func registerRotation(_ degrees: Double) {
          guard currentStep == 2 else { return }
          
          // 更新视觉旋转角度
          rotationAngle += degrees
          
          // 累加绝对值度数
          let absDeg = abs(degrees)
          accumulatedRotation += absDeg
          if accumulatedRotation >= 100.0 {
              isStep2Unlocked = true
          }
          
          // 播放 Tick 反馈嘀嗒音
          let ticks = updateTickAccumulationAndGetTicks(absDeg)
          for _ in 0..<ticks {
              AudioServicesPlaySystemSound(1104)
          }
          
          // 实时更新并同步系统音量
          let sensitivity: Float = 0.005
          let deltaValue = Float(degrees) * sensitivity
          let newVal = max(0.0, min(1.0, volumeVal + deltaValue))
          if audioService.setVolume(newVal) {
              volumeVal = newVal
          }
      }
      
      func updateTickAccumulationAndGetTicks(_ delta: Double) -> Int {
          tickAccumulator += delta
          if tickAccumulator >= 1.0 {
              let ticks = Int(tickAccumulator)
              tickAccumulator -= Double(ticks)
              return ticks
          }
          return 0
      }
      
      func getTickAccumulator() -> Double {
          return tickAccumulator
      }
      
      func completeGuide() {
          UserDefaults.standard.set(true, forKey: "firstRunUserGuideCompleted")
          UserGuideWindowController.shared.hide()
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
              KnobPanelWindowController.shared.show()
          }
      }
  }
  ```

- [ ] **步骤 4：运行测试验证通过**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
  预期：所有测试（包含新增测试）编译并全部通过。

- [ ] **步骤 5：Commit**
  ```bash
  git add PhantomKnob/ViewModel/UserGuideViewModel.swift PhantomKnobTests/UserGuideViewModelTests.swift
  git commit -m "feat: implement UserGuideViewModel and related unit tests for user guide flow and tick beep logic"
  ```

---

### 任务 2：创建引导窗口控制器与引导视图 (UserGuide Window & View)

**文件：**
- 创建：`PhantomKnob/Service/UserGuideWindowController.swift`
- 创建：`PhantomKnob/View/UserGuideView.swift`

- [ ] **步骤 1：编写最少实现代码**
  创建 `PhantomKnob/Service/UserGuideWindowController.swift`：
  ```swift
  import AppKit
  import SwiftUI

  class UserGuideWindow: NSWindow {
      override var canBecomeKey: Bool {
          return true
      }
  }

  class UserGuideWindowController: NSObject, NSWindowDelegate {
      static let shared = UserGuideWindowController()
      
      private var window: UserGuideWindow?
      private var localClickMonitor: Any?
      
      var isVisible: Bool {
          return window?.isVisible ?? false
      }
      
      func show() {
          if window == nil {
              createWindow()
          }
          
          window?.makeKeyAndOrderFront(nil)
          NSApp.activate(ignoringOtherApps: true)
          setupClickMonitor()
          
          // 通知状态机开启临时拦截
          NotificationCenter.default.post(name: NSNotification.Name("KnobPanelDidShow"), object: nil)
      }
      
      func hide() {
          window?.orderOut(nil)
          removeClickMonitor()
          
          // 通知状态机还原拦截
          NotificationCenter.default.post(name: NSNotification.Name("KnobPanelDidHide"), object: nil)
      }
      
      private func createWindow() {
          let width: CGFloat = 560
          let height: CGFloat = 400
          let screenFrame = NSScreen.main?.visibleFrame ?? .zero
          let originX = screenFrame.origin.x + (screenFrame.width - width) / 2
          let originY = screenFrame.origin.y + (screenFrame.height - height) / 2
          
          let contentRect = NSRect(x: originX, y: originY, width: width, height: height)
          let win = UserGuideWindow(
              contentRect: contentRect,
              styleMask: [.borderless],
              backing: .buffered,
              defer: false
          )
          
          win.backgroundColor = .clear
          win.isOpaque = false
          win.level = .floating
          win.hidesOnDeactivate = true
          win.delegate = self
          
          let visualEffectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: contentRect.size))
          visualEffectView.material = .hudWindow
          visualEffectView.blendingMode = .behindWindow
          visualEffectView.state = .active
          visualEffectView.autoresizingMask = [.width, .height]
          visualEffectView.wantsLayer = true
          visualEffectView.layer?.cornerRadius = 20
          visualEffectView.layer?.masksToBounds = true
          
          win.contentView = visualEffectView
          
          let hostingView = NSHostingView(rootView: UserGuideView())
          hostingView.frame = visualEffectView.bounds
          hostingView.autoresizingMask = [.width, .height]
          visualEffectView.addSubview(hostingView)
          
          self.window = win
      }
      
      private func setupClickMonitor() {
          removeClickMonitor()
          localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
              guard let self = self, let win = self.window else { return event }
              let clickLocation = NSEvent.mouseLocation
              let windowFrame = win.frame
              if !NSPointInRect(clickLocation, windowFrame) {
                  DispatchQueue.main.async {
                      self.hide()
                  }
              }
              return event
          }
      }
      
      private func removeClickMonitor() {
          if let monitor = localClickMonitor {
              NSEvent.removeMonitor(monitor)
              localClickMonitor = nil
          }
      }
      
      func windowDidResignKey(_ notification: Notification) {
          hide()
      }
  }
  ```

  创建 `PhantomKnob/View/UserGuideView.swift`，使用拟物旋钮和光标指引动画：
  ```swift
  import SwiftUI

  struct UserGuideView: View {
      @StateObject private var viewModel = UserGuideViewModel()
      
      var body: some View {
          VStack(spacing: 20) {
              if viewModel.currentStep == 1 {
                  VStack(spacing: 20) {
                      Text("欢迎使用 PhantomKnob")
                          .font(.system(size: 24, weight: .bold))
                          .foregroundColor(.white)
                      
                      Text("这是一个革命性的音量与亮度调节工具。只需将双指放置在触控板上轻轻旋转，即可优雅地掌控您的系统变量。")
                          .font(.system(size: 14))
                          .foregroundColor(.white.opacity(0.8))
                          .multilineTextAlignment(.center)
                          .padding(.horizontal, 30)
                      
                      Button(action: {
                          viewModel.nextStep()
                      }) {
                          Text("开始练习")
                              .font(.system(size: 14, weight: .semibold))
                              .foregroundColor(.white)
                              .padding(.horizontal, 24)
                              .padding(.vertical, 8)
                              .background(Color.blue)
                              .cornerRadius(8)
                      }
                      .buttonStyle(.plain)
                  }
              } else if viewModel.currentStep == 2 {
                  VStack(spacing: 12) {
                      Text(viewModel.hovered ? "非常棒！开始在触控板上双指旋转" : "请将光标移动到音量旋钮上")
                          .font(.system(size: 16, weight: .semibold))
                          .foregroundColor(.blue)
                          .animation(.easeInOut, value: viewModel.hovered)
                      
                      ZStack {
                          RadialKnobControlView(
                              title: "音量调节练习",
                              icon: "speaker.wave.3.fill",
                              value: viewModel.volumeVal,
                              angle: viewModel.rotationAngle,
                              isFocused: viewModel.hovered,
                              isGestureActive: viewModel.hovered
                          )
                          .onHover { isHover in
                              viewModel.hovered = isHover
                          }
                          
                          if !viewModel.hovered {
                              // 手指在旋钮周围浮动指引的动画
                              CursorGuideAnimationView()
                                  .offset(x: 40, y: -40)
                                  .transition(.opacity)
                          }
                      }
                      .frame(height: 170)
                      
                      VStack(spacing: 4) {
                          ProgressView(value: min(viewModel.accumulatedRotation, 100.0), total: 100.0)
                              .progressViewStyle(.linear)
                              .frame(width: 200)
                          
                          Text("已旋转: \(Int(min(viewModel.accumulatedRotation, 100.0)))° / 100°")
                              .font(.system(size: 12, design: .monospaced))
                              .foregroundColor(.white.opacity(0.6))
                      }
                      
                      Button(action: {
                          viewModel.nextStep()
                      }) {
                          Text("下一步")
                              .font(.system(size: 14, weight: .semibold))
                              .foregroundColor(.white)
                              .padding(.horizontal, 24)
                              .padding(.vertical, 8)
                              .background(viewModel.isStep2Unlocked ? Color.blue : Color.white.opacity(0.2))
                              .cornerRadius(8)
                      }
                      .disabled(!viewModel.isStep2Unlocked)
                      .buttonStyle(.plain)
                  }
              } else {
                  VStack(spacing: 16) {
                      Text("掌握成功！")
                          .font(.system(size: 24, weight: .bold))
                          .foregroundColor(.green)
                      
                      VStack(alignment: .leading, spacing: 10) {
                          Text("您可以通过快捷键 ⌘⌥R 或状态栏菜单的“切换控制模式”开启全局旋钮控制。激活后，把鼠标悬浮在任何滑块上并双指旋转即可调整。")
                              .font(.system(size: 13))
                              .foregroundColor(.white.opacity(0.85))
                          
                          Text("注意：适配后的应用程序可以获得最完美的旋转反馈体验。")
                              .font(.system(size: 13, weight: .semibold))
                              .foregroundColor(.white)
                          
                          Text("适配列表包含：")
                              .font(.system(size: 12))
                              .foregroundColor(.white.opacity(0.7))
                          
                          HStack(spacing: 16) {
                              Text("• CapCut (剪映)")
                              Text("• QuickTime Player")
                          }
                          .font(.system(size: 13, weight: .medium))
                          .foregroundColor(.blue)
                      }
                      .padding(.horizontal, 30)
                      
                      Button(action: {
                          viewModel.completeGuide()
                      }) {
                          Text("开启体验")
                              .font(.system(size: 14, weight: .semibold))
                              .foregroundColor(.white)
                              .padding(.horizontal, 24)
                              .padding(.vertical, 8)
                              .background(Color.green)
                              .cornerRadius(8)
                      }
                      .buttonStyle(.plain)
                  }
              }
          }
          .padding(.vertical, 20)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
  }

  struct CursorGuideAnimationView: View {
      @State private var pulse = false
      
      var body: some View {
          Image(systemName: "hand.draw.fill")
              .font(.system(size: 32))
              .foregroundColor(.blue.opacity(0.8))
              .scaleEffect(pulse ? 1.2 : 0.9)
              .offset(x: pulse ? -10 : 10, y: pulse ? 10 : -10)
              .onAppear {
                  withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                      pulse = true
                  }
              }
      }
  }
  ```

- [ ] **步骤 2：测试构建是否通过**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
  预期：全部测试编译及运行通过。

- [ ] **步骤 3：Commit**
  ```bash
  git add PhantomKnob/Service/UserGuideWindowController.swift PhantomKnob/View/UserGuideView.swift
  git commit -m "feat: implement UserGuideWindowController and UserGuideView using SwiftUI with hover cursor animations"
  ```

---

### 任务 3：适配状态机手势拦截逻辑 (KnobStateManager Integration)

**文件：**
- 修改：`PhantomKnob/Service/KnobStateManager.swift:180-230`

- [ ] **步骤 1：修改代码**
  修改 `onMultitouchBegan` 在拦截判定时引入 `UserGuideWindowController.shared.isVisible` 判断：
  ```swift
  // targetContent:
          if KnobPanelWindowController.shared.isVisible {
              let target = DetectedTarget(
                  bundleID: "com.phantomknob.controlpanel",
                  axRole: "ControlPanel",
                  identifier: nil,
                  displayName: "控制面板",
                  element: nil
              )
              currentTarget = target
              currentTranslator = ScrollWheelTranslator()
  // replacementContent:
          if KnobPanelWindowController.shared.isVisible || UserGuideWindowController.shared.isVisible {
              let target = DetectedTarget(
                  bundleID: "com.phantomknob.controlpanel",
                  axRole: "ControlPanel",
                  identifier: nil,
                  displayName: "控制面板",
                  element: nil
              )
              currentTarget = target
              currentTranslator = ScrollWheelTranslator()
  ```

- [ ] **步骤 2：运行单元测试**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
  预期：全部测试通过。

- [ ] **步骤 3：Commit**
  ```bash
  git add PhantomKnob/Service/KnobStateManager.swift
  git commit -m "feat: adapt KnobStateManager to capture multitouch gestures when UserGuideWindow is visible"
  ```

---

### 任务 4：状态栏主菜单新增使用引导入口与首次运行冷启动逻辑 (Menu & Startup)

**文件：**
- 修改：`PhantomKnob/Service/StatusBarController.swift:85-115`
- 修改：`PhantomKnob/App/PhantomKnobApp.swift:45-50`

- [ ] **步骤 1：添加菜单项代码**
  修改 `StatusBarController.swift` 中的 `setupMenu()`：
  ```swift
  // targetContent:
          let statusMenuItem = NSMenuItem(title: "状态：未激活", action: nil, keyEquivalent: "")
          statusMenuItem.isEnabled = false
          menu?.addItem(statusMenuItem)
          
          menu?.addItem(NSSeparatorItem())
  // replacementContent:
          let statusMenuItem = NSMenuItem(title: "状态：未激活", action: nil, keyEquivalent: "")
          statusMenuItem.isEnabled = false
          menu?.addItem(statusMenuItem)
          
          let guideMenuItem = NSMenuItem(title: "使用引导...", action: #selector(openGuide), keyEquivalent: "")
          guideMenuItem.target = self
          menu?.addItem(guideMenuItem)
          
          menu?.addItem(NSMenuItem.separator())
  ```
  并在 `StatusBarController` 类底部添加 `@objc private func openGuide()` 方法：
  ```swift
      @objc private func openGuide() {
          UserGuideWindowController.shared.show()
      }
  ```

- [ ] **步骤 2：修改冷启动逻辑**
  在 `PhantomKnobApp.swift` 的 `onAppear` 中，检测 `firstRunUserGuideCompleted` 以决定自动呼出哪个窗口：
  ```swift
  // targetContent:
                  let tutorialCompleted = UserDefaults.standard.bool(forKey: "firstRunTutorialCompleted")
                  if !tutorialCompleted {
                      KnobPanelWindowController.shared.show()
                  }
  // replacementContent:
                  let guideCompleted = UserDefaults.standard.bool(forKey: "firstRunUserGuideCompleted")
                  if !guideCompleted {
                      UserGuideWindowController.shared.show()
                  } else {
                      let tutorialCompleted = UserDefaults.standard.bool(forKey: "firstRunTutorialCompleted")
                      if !tutorialCompleted {
                          KnobPanelWindowController.shared.show()
                      }
                  }
  ```
  *(注：我们之前在 KnobPanelView 中也渲染过嵌套的 TutorialView。由于使用了独立的 User Guide 教学，当 `firstRunUserGuideCompleted` 完成后，我们将 UserDefaults 中的 `firstRunTutorialCompleted` 在 UserGuide 完成时同步设为 `true`。我们已经在 UserGuideViewModel 触发 completeGuide() 时将 firstRunTutorialCompleted 同步标记，无需改变原本已写好的逻辑)*。

- [ ] **步骤 3：运行测试并编译 App 进行最终校验**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
  运行构建：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnob -configuration Debug build`
  预期：测试通过，App 成功构建。

- [ ] **步骤 4：Commit**
  ```bash
  git add PhantomKnob/Service/StatusBarController.swift PhantomKnob/App/PhantomKnobApp.swift
  git commit -m "feat: add User Guide status bar menu item and trigger guide on first run"
  ```
