# 交互式使用引导与 Onboarding 流程重塑 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将 App 转换为纯菜单栏后台常驻程序，移除主界面的检测窗口，并在交互式新手引导（UserGuide）中集成触控板绝对坐标的测试检验、多旋钮对比与练习、键盘倍率微调和按 `C` 键一键定制。

**架构：**
1. 设置 `LSUIElement: true` 使 Dock 栏不显示图标；移除 `WindowGroup`，改从 `AppState.init()` 中直接初始化并触发新手引导弹窗。
2. 物理删除无用的 `WelcomeView`, `DetectionView`, `ResultView`, `DemoView`, `AppViewModel`, `DetectionViewModel`, `DetectionCache`, `TouchpadDetector`, `DetectionResult` 及其对应测试。
3. 重塑新手引导：
   - **Step 1**：展示欢迎文本，添加“自绘音量旋钮”。后台监听多点绝对坐标，成功捕获后打勾提示并解锁下一步。
   - **Step 2**：并排展示“双旋钮”与“无极变速旋钮”的自绘视图，实时显示数值。添加键盘方向键/数字键微调倍率的视觉反馈。支持悬停按下 `C` 键弹出现有的“旋钮定制面板”。
   - **Step 3**：全局热键与完成设置页。

**技术栈：** Swift 5.0, SwiftUI, XcodeGen, xcodebuild, git

---

### 任务 1：删除冗余文件与清理工程配置

**文件：**
- 修改：`PhantomKnob/project.yml`
- 删除：`PhantomKnob/View/WelcomeView.swift`
- 删除：`PhantomKnob/View/DetectionView.swift`
- 删除：`PhantomKnob/View/ResultView.swift`
- 删除：`PhantomKnob/View/DemoView.swift`
- 删除：`PhantomKnob/ViewModel/AppViewModel.swift`
- 删除：`PhantomKnob/ViewModel/DetectionViewModel.swift`
- 删除：`PhantomKnob/Storage/DetectionCache.swift`
- 删除：`PhantomKnob/Service/TouchpadDetector.swift`
- 删除：`PhantomKnob/Model/DetectionResult.swift`
- 删除：`PhantomKnob/PhantomKnobTests/StorageTests.swift`

- [ ] **步骤 1：物理删除无用的视图、ViewModel、Cache 以及检测类文件**
  运行：
  ```bash
  rm PhantomKnob/View/WelcomeView.swift
  rm PhantomKnob/View/DetectionView.swift
  rm PhantomKnob/View/ResultView.swift
  rm PhantomKnob/View/DemoView.swift
  rm PhantomKnob/ViewModel/AppViewModel.swift
  rm PhantomKnob/ViewModel/DetectionViewModel.swift
  rm PhantomKnob/Storage/DetectionCache.swift
  rm PhantomKnob/Service/TouchpadDetector.swift
  rm PhantomKnob/Model/DetectionResult.swift
  rm PhantomKnob/PhantomKnobTests/StorageTests.swift
  ```

- [ ] **步骤 2：在 ModelTests.swift 中移除已废弃的 DetectionResultTests**
  修改：[ModelTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnobTests/ModelTests.swift)
  定位到第 149 行起的 `final class DetectionResultTests: XCTestCase` 整个测试类，并整段物理删除。

- [ ] **步骤 3：修改 project.yml 工程配置文件**
  修改：[project.yml](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/project.yml)
  在 `targets -> PhantomKnob -> info -> properties` 下增加 `LSUIElement: true`。同时移除对 Model/DetectionResult.swift 等文件的排他配置（若有相关 explicit references）。由于 project.yml 主要使用通配文件夹路径，我们只需要加入 `LSUIElement`：
  ```yaml
      info:
        path: Info.plist
        properties:
          CFBundleDisplayName: PhantomKnob
          CFBundleShortVersionString: "1.0"
          CFBundleVersion: "1"
          LSMinimumSystemVersion: "12.0"
          NSHighResolutionCapable: true
          LSApplicationCategoryType: public.app-category.utilities
          NSHumanReadableCopyright: "Copyright © 2025 Ben Wu. All rights reserved."
          LSUIElement: true
  ```

- [ ] **步骤 4：运行 XcodeGen 重新生成项目**
  运行：
  ```bash
  cd PhantomKnob
  xcodegen generate
  cd ..
  ```
  预期：工程文件生成成功，不再报错缺少删除的类文件。

- [ ] **步骤 5：Commit 任务 1 变更**
  运行：
  ```bash
  git add PhantomKnob/project.yml PhantomKnob/PhantomKnobTests/ModelTests.swift PhantomKnob/PhantomKnob.xcodeproj/project.pbxproj
  git rm PhantomKnob/View/WelcomeView.swift PhantomKnob/View/DetectionView.swift PhantomKnob/View/ResultView.swift PhantomKnob/View/DemoView.swift PhantomKnob/ViewModel/AppViewModel.swift PhantomKnob/ViewModel/DetectionViewModel.swift PhantomKnob/Storage/DetectionCache.swift PhantomKnob/Service/TouchpadDetector.swift PhantomKnob/Model/DetectionResult.swift PhantomKnob/PhantomKnobTests/StorageTests.swift
  git commit -m "refactor: delete redundant detection views and set LSUIElement to true in project.yml"
  ```

---

### 任务 2：重构 App 启动和生命周期逻辑

**文件：**
- 修改：[PhantomKnobApp.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/App/PhantomKnobApp.swift)

- [ ] **步骤 1：移除 WindowGroup，将启动移入 AppState.init()**
  修改 `PhantomKnobApp.swift`。
  1. 修改 `AppState` 的 `init()`：
  ```swift
  class AppState: ObservableObject {
      let knobStateManager: KnobStateManager
      let statusBarController: StatusBarController
      
      init() {
          let targetDetector = TargetDetector()
          let gestureClassifier = GestureClassifier()
          let overlayController = OverlayController()
          let statusBarController = StatusBarController()
          let touchHandler = GlobalTouchHandler()
          
          self.statusBarController = statusBarController
          self.knobStateManager = KnobStateManager(
              targetDetector: targetDetector,
              gestureClassifier: gestureClassifier,
              overlayController: overlayController,
              statusBarController: statusBarController,
              touchHandler: touchHandler
          )
          
          self.knobStateManager.start()
          
          let skipGuide = UserDefaults.standard.bool(forKey: "skipUserGuideOnStartup")
          if !skipGuide {
              UserGuideWindowController.shared.show()
          } else {
              let tutorialCompleted = UserDefaults.standard.bool(forKey: "firstRunTutorialCompleted")
              if !tutorialCompleted {
                  KnobPanelWindowController.shared.show()
              }
          }
          
          NSLog("[AppState] Initialized and touch monitoring started")
      }
      
      func toggleKnobMode() {
          knobStateManager.toggleMode()
      }
  }
  ```
  2. 简化 `PhantomKnobApp` 的 `body` 声明，移除 `WindowGroup` 和 `ContentView` 的定义：
  ```swift
  #if !TESTING
  @main
  struct PhantomKnobApp: App {
      @StateObject private var appState = AppState()
      
      var body: some Scene {
          Settings {
              SettingsView()
          }
      }
  }
  #endif
  ```

- [ ] **步骤 2：编译测试验证**
  运行：
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
  ```
  预期：BUILD SUCCEEDED，测试顺利通过。

- [ ] **步骤 3：Commit 任务 2 变更**
  运行：
  ```bash
  git add PhantomKnob/App/PhantomKnobApp.swift
  git commit -m "feat: rewrite app startup to run entirely from AppState init and remove WindowGroup scene"
  ```

---

### 任务 3：在新手引导 Step 1 中融合触控板设备检测与练习

**文件：**
- 修改：[KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/KnobStateManager.swift)
- 修改：[UserGuideViewModel.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/ViewModel/UserGuideViewModel.swift)
- 修改：[UserGuideView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/UserGuideView.swift)

- [ ] **步骤 1：在 KnobStateManager 中发出触控板绝对坐标验证成功通知**
  在 `KnobStateManager.swift` 类的 `onMultitouchBegan` (以及 `onMultitouchMoved`) 方法内，只要 `points.count >= 2`，且任一点的 x/y 轴不为 NaN 且在 0.0 - 1.0 范围内，即抛出通知：
  ```swift
          // 在 scaleCoordinates 后执行
          let allValid = points.values.allSatisfy { !$0.x.isNaN && !$0.y.isNaN }
          if allValid && points.count >= 2 {
              NotificationCenter.default.post(name: NSNotification.Name("TouchpadCoordinatesValidated"), object: nil)
          }
  ```

- [ ] **步骤 2：更新 UserGuideViewModel 支持设备检测状态及第一步数值**
  修改 `UserGuideViewModel.swift`：
  - 新增 `@Published var isTouchpadDetected = false`
  - 新增 `@Published var step1Value: Float = 0.5`
  - 新增绑定，在 `setupBindings()` 中接收 `"TouchpadCoordinatesValidated"` 通知并更新 `isTouchpadDetected = true`：
  ```swift
          NotificationCenter.default.publisher(for: NSNotification.Name("TouchpadCoordinatesValidated"))
              .receive(on: RunLoop.main)
              .sink { [weak self] _ in
                  self?.isTouchpadDetected = true
              }
              .store(in: &cancellables)
  ```
  - 修改 `registerRotation(_ degrees: Double)` 方法：当 `currentStep == 1` 且鼠标悬停时，计算 `step1Value` 并使其触发数值反馈。

- [ ] **步骤 3：重构 UserGuideView 的 Step 1 视图**
  修改 `UserGuideView.swift`：
  - 顶部显示：“PhantomKnob把旋钮手势引入触控板。”
  - 检测区域文字：“您可以通过以下操作测试您的触控板是否支持并练习使用旋钮手势。把鼠标移动到需要调整的旋钮上，然后在触控板上用两指做旋转的动作。”
  - 渲染一个自绘旋钮，上方显示：音量百分比数（如 `\(Int(viewModel.step1Value * 100))%`）。
  - 下方显示检测状态提示：如果 `viewModel.isTouchpadDetected` 为真，显示绿色 `✅ 触控板检测成功！您的设备支持旋钮手势操作。`；如果为假，则显示等待检测提示。
  - 下方的“下一步”按钮需要 `viewModel.isTouchpadDetected` 和 `viewModel.isStep2Unlocked` (我们第一步也可以直接把旋转积累 100° 做为下一步解锁标志) 满足后才能点击。

- [ ] **步骤 4：运行测试验证**
  运行：
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
  ```

- [ ] **步骤 5：Commit 任务 3 变更**
  运行：
  ```bash
  git add PhantomKnob/Service/KnobStateManager.swift PhantomKnob/ViewModel/UserGuideViewModel.swift PhantomKnob/View/UserGuideView.swift
  git commit -m "feat: integrate touchpad absolute coordinate validation and step 1 practice into onboarding guide"
  ```

---

### 任务 4：重构 Step 2 展现多旋钮对比、键盘倍率微调和定制面板呼出

**文件：**
- 修改：[UserGuideViewModel.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/ViewModel/UserGuideViewModel.swift)
- 修改：[UserGuideView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/UserGuideView.swift)

- [ ] **步骤 1：在 UserGuideViewModel 中添加多旋钮数值路由与键盘倍数监听**
  1. 添加以下状态变量：
  ```swift
  @Published var step2DoubleVal: Double = 50.0
  @Published var step2LinearVal: Double = 50.0
  @Published var step2HoveredType: OnboardingKnobType = .none // 定义枚举：.none, .double, .linear
  @Published var currentMultiplierText: String = "1.0x"
  ```
  2. 监听 `KnobStateManager` 抛出的 `lastResolvedBaseScale` 变化，实时更新 `currentMultiplierText` 并在界面上显示。
  3. 修改 `registerRotation(_ degrees: Double)`：根据当前悬停的 `step2HoveredType` 将旋转 deltas 应用到不同的变量。
     - 若为 `.double`：根据当前旋转的物理半径（我们可以在 notification 的 userInfo 中把当前 radius 传递过来，或者从 `KnobStateManager.shared` 直接读取），应用双旋钮内外圈的不同步长比。
     - 若为 `.linear`：根据半径大小线性改变步长调节。

- [ ] **步骤 2：重写 UserGuideView 的 Step 2 视图**
  修改 `UserGuideView.swift`。
  1. 顶部展示：“刚才您练习的是最简单的「单旋钮」。PhantomKnob 还支持另外两类更强大的旋钮控制器，它们可以在不同的操作半径下获得不一样的调参手感。”
  2. 横向并排渲染两个自绘旋钮，旋钮顶部大字号实时显示当前的数字：
     - **左侧：双旋钮**（视觉上以清晰的内、外双环表示）。悬停时 `step2HoveredType = .double`。下方附带说明：“双区控制：内圈微调，外圈粗调。支持单指接续滑动。”
     - **右侧：无极变速旋钮**（视觉上以渐变射线表示）。悬停时 `step2HoveredType = .linear`。下方附带说明：“线性变速：步长随半径大小无极变速。”
  3. 并在下方中央显示**倍率动态状态**：`当前倍率: \(viewModel.currentMultiplierText)`。提示用户可以使用方向键加减 `1.0x` / `0.1x` 调节速度。
  4. 底部增加一段提示：“您可以对任何可调节数值的控件（滑块 Slider、步进器 Stepper、滚动条 Scrollbar 等）配置自定义的旋钮控制。”，并提供一个模拟滑块和一个“按 C 键定制”的测试区，当用户按下 `C` 键或点击按钮时，唤起内置定制界面。

- [ ] **步骤 3：运行测试验证**
  运行：
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
  ```

- [ ] **步骤 4：Commit 任务 4 变更**
  运行：
  ```bash
  git add PhantomKnob/ViewModel/UserGuideViewModel.swift PhantomKnob/View/UserGuideView.swift
  git commit -m "feat: implement step 2 onboarding view with double/linear knobs comparison, key multipliers and customization cues"
  ```

---

### 任务 5：重写 Step 3 欢迎并完成 Onboarding

**文件：**
- 修改：[UserGuideView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/UserGuideView.swift)

- [ ] **步骤 1：修改 Step 3 最终确认页面**
  修改 `UserGuideView.swift` 中的 `viewModel.currentStep == 3` 对应分支（原本的 `else` 分支）：
  - 介绍全局热键 `⌘⌥R` 和 `Option` 键临时关闭。
  - 包含“下次启动不再显示”勾选框，以及“开启体验”按钮。

- [ ] **步骤 2：运行全部单元测试确保 100% 通过**
  运行：
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
  ```
  预期：TEST SUCCEEDED，所有用例完美 Passed。

- [ ] **步骤 3：Commit 任务 5 变更**
  运行：
  ```bash
  git add PhantomKnob/View/UserGuideView.swift
  git commit -m "feat: complete step 3 of onboarding guide and verify all tests pass"
  ```
