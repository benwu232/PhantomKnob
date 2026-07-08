# 旋钮定制化实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现旋钮定制化功能。允许用户在 Overlay HUD 显示时，按下 `C` 键唤起毛玻璃定制面板 HUD，选择不同的模式（单旋钮、独立双旋钮、无级变速），自定义控制变化系数、方向映射、主题颜色并实时热重载生效，修改即无缝自动保存到本地 `rules.json`。

**架构：**
1. **Model 重构 (`ControlRule.swift`)**：引入 `KnobConfigType` 及不同模式下的配置子结构（`SingleKnobConfig`、`DoubleKnobConfig`、`LinearKnobConfig`），并支持旧版数据格式的后向兼容解析。
2. **本地持久化扩展 (`RuleLibrary.swift`)**：在规则库中增加 `saveRule(_ rule: ControlRule)` 方法，负责与 `rules.json` 的合并、读写以及发榜通知。
3. **状态机拦截与热更 (`KnobStateManager.swift`)**：
   - 新增 `.customizing` 状态；
   - 在 EventTap 阶段，当 Overlay 显示期间拦截按键 `C` (keycode 8) 触发定制，进入 `.customizing` 挂起态；
   - 监听配置更新通知，重构当前的 `InputTranslator` 与 `OverlayController` 视效。
   - 在手势移动时，为定制面板实时提供双指物理半径通知广播。
4. **定制 HUD 界面 (`CustomizerHUDWindowController.swift` & `CustomizerHUDView.swift`)**：构建悬浮 Glassmorphism 窗口及响应式 SwiftUI 配置表单，绑定实时半径显示，所有表单修改即刻更新模型。
5. **单元测试与手动测试验证**：提供完善的单元测试保证迟滞状态机、线性插值和 JSON 序列化准确，确保功能完全无死角。

**技术栈：** SwiftUI, AppKit CoreGraphics/Accessibility, JSON, Combine.

---

## 1. 计划涉及文件列表

### 修改文件：
* [ControlRule.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Model/ControlRule.swift) - 重构规则及配置模型
* [RuleLibrary.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Storage/RuleLibrary.swift) - 增加本地 JSON 保存与合并
* [KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/KnobStateManager.swift) - 键盘 C 拦截、挂起与手势热更新
* [KnobState.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Model/KnobState.swift) - 扩展全局状态 enum

### 新建文件：
* [CustomizerHUDWindowController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/CustomizerHUDWindowController.swift) - 悬浮定制窗口管理器
* [CustomizerHUDView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/CustomizerHUDView.swift) - 定制面板 SwiftUI 视图

---

## 2. 详细实现任务

### 任务 1：重构数据模型以支持高级定制并保持后向兼容

**文件：**
- 修改：`PhantomKnob/Model/ControlRule.swift`
- 测试：`PhantomKnobTests/ModelTests.swift`

- [ ] **步骤 1：重构 `ControlRule.swift`**
  更新 `ControlRule.swift` 为以下包含子结构与后向兼容 Decoder 的实现：
  ```swift
  import Foundation

  enum KnobConfigType: String, Codable {
      case single
      case double
      case linear
  }

  struct SingleKnobConfig: Codable, Equatable {
      var unitPerDegree: Double
      var translation: InputTranslation
      var clockwiseAction: String // 例如 "arrowUp", "scrollUp", "swipeRight" 等
  }

  struct VirtualKnobConfig: Codable, Equatable {
      var minRadius: Double
      var maxRadius: Double
      var margin: Double
      var unitPerDegree: Double
      var translation: InputTranslation
      var clockwiseAction: String
  }

  struct DoubleKnobConfig: Codable, Equatable {
      var inner: VirtualKnobConfig
      var outer: VirtualKnobConfig
  }

  struct LinearKnobConfig: Codable, Equatable {
      var minRadius: Double
      var maxRadius: Double
      var minScale: Double
      var maxScale: Double
      var translation: InputTranslation
      var clockwiseAction: String
  }

  struct ControlRule: Codable, Equatable {
      let key: RuleKey
      var themeColor: String?
      var configType: KnobConfigType
      
      var singleConfig: SingleKnobConfig?
      var doubleConfig: DoubleKnobConfig?
      var linearConfig: LinearKnobConfig?
      
      var extra: [String: String]?
      
      // 旧版后向兼容字段（声明为 Optional 以防止旧 rules 序列化失败）
      var translation: InputTranslation?
      var scaleConfig: ScaleConfig?
      var invert: Bool?
      
      enum CodingKeys: String, CodingKey {
          case key, themeColor, configType, singleConfig, doubleConfig, linearConfig, extra
          case translation, scaleConfig, invert
      }
      
      init(key: RuleKey,
           themeColor: String? = nil,
           configType: KnobConfigType = .single,
           singleConfig: SingleKnobConfig? = nil,
           doubleConfig: DoubleKnobConfig? = nil,
           linearConfig: LinearKnobConfig? = nil,
           extra: [String: String]? = nil) {
          self.key = key
          self.themeColor = themeColor
          self.configType = configType
          self.singleConfig = singleConfig
          self.doubleConfig = doubleConfig
          self.linearConfig = linearConfig
          self.extra = extra
      }
      
      init(from decoder: Decoder) throws {
          let container = try decoder.container(keyedBy: CodingKeys.self)
          self.key = try container.decode(RuleKey.self, forKey: .key)
          self.themeColor = try container.decodeIfPresent(String.self, forKey: .themeColor)
          self.extra = try container.decodeIfPresent([String: String].self, forKey: .extra)
          
          if let configTypeStr = try container.decodeIfPresent(String.self, forKey: .configType),
             let parsedType = KnobConfigType(rawValue: configTypeStr) {
              self.configType = parsedType
              self.singleConfig = try container.decodeIfPresent(SingleKnobConfig.self, forKey: .singleConfig)
              self.doubleConfig = try container.decodeIfPresent(DoubleKnobConfig.self, forKey: .doubleConfig)
              self.linearConfig = try container.decodeIfPresent(LinearKnobConfig.self, forKey: .linearConfig)
          } else {
              // 后向兼容兜底解析
              self.configType = .single
              let oldTrans = try container.decodeIfPresent(InputTranslation.self, forKey: .translation) ?? .scrollWheelVertical
              let oldScaleConfig = try container.decodeIfPresent(ScaleConfig.self, forKey: .scaleConfig) ?? .fixed(1.0)
              let oldInvert = try container.decodeIfPresent(Bool.self, forKey: .invert) ?? false
              
              var scaleValue = 1.0
              if case .fixed(let val) = oldScaleConfig {
                  scaleValue = val
              }
              
              // 映射默认方向对应的 action
              let defaultCWAction: String
              switch oldTrans {
              case .arrowKeyUpDown: defaultCWAction = oldInvert ? "arrowDown" : "arrowUp"
              case .arrowKeyLeftRight: defaultCWAction = oldInvert ? "arrowLeft" : "arrowRight"
              case .scrollWheelVertical: defaultCWAction = oldInvert ? "scrollDown" : "scrollUp"
              case .scrollWheelHorizontal: defaultCWAction = oldInvert ? "scrollRight" : "scrollLeft"
              case .swipeVertical: defaultCWAction = oldInvert ? "swipeDown" : "swipeUp"
              case .swipeHorizontal: defaultCWAction = oldInvert ? "swipeRight" : "swipeLeft"
              case .axWrite: defaultCWAction = oldInvert ? "decrease" : "increase"
              }
              
              self.singleConfig = SingleKnobConfig(
                  unitPerDegree: scaleValue,
                  translation: oldTrans,
                  clockwiseAction: defaultCWAction
              )
          }
      }
  }
  ```

- [ ] **步骤 2：运行 Model 单元测试验证新版模型解析及后向兼容**
  在终端中运行 Swift Package Manager 测试验证代码通过。
  运行：`swift test --filter ModelTests`

- [ ] **步骤 3：Commit**
  ```bash
  git add PhantomKnob/Model/ControlRule.swift
  git commit -m "feat: refactor ControlRule model to support customization structures and backwards compatibility"
  ```

---

### 任务 2：扩展本地持久化，实现修改后自动合并写入

**文件：**
- 修改：`PhantomKnob/Storage/RuleLibrary.swift`
- 测试：`PhantomKnobTests/RuleLibraryTests.swift`

- [ ] **步骤 1：增加 `saveRule` 与配置合并写入方法**
  在 `RuleLibrary.swift` 中增加以下方法，用来处理用户规则的合并及写入：
  ```swift
  // 插入到 RuleLibrary 类内部
  func saveRule(_ rule: ControlRule) {
      var loadedUserRules: [ControlRule] = []
      
      // 1. 先尝试读取本地 rules.json
      if FileManager.default.fileExists(atPath: userRulesURL.path) {
          if let data = try? Data(contentsOf: userRulesURL),
             let existing = try? JSONDecoder().decode([ControlRule].self, from: data) {
              loadedUserRules = existing
          }
      } else {
          // 确保目录存在
          let dir = userRulesURL.deletingLastPathComponent()
          try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      }
      
      // 2. 合并或追加：如果在 userRules 里有相同 key 的规则，进行替换，否则追加
      if let index = loadedUserRules.firstIndex(where: { $0.key.matches(rule.key) }) {
          loadedUserRules[index] = rule
      } else {
          loadedUserRules.insert(rule, at: 0) // 高优先级追加
      }
      
      // 3. 序列化写回本地
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      if let data = try? encoder.encode(loadedUserRules) {
          try? data.write(to: userRulesURL)
      }
      
      // 4. 重载内存规则并通知状态机更新
      self.reload()
      
      NotificationCenter.default.post(
          name: NSNotification.Name("ControlRuleDidUpdate"),
          object: nil,
          userInfo: ["rule": rule]
      )
  }
  ```

- [ ] **步骤 2：测试 RuleLibrary 自动合并写入逻辑**
  运行：`swift test --filter RuleLibraryTests`
  确保读取、合并及高优先级加载逻辑覆盖。

- [ ] **步骤 3：Commit**
  ```bash
  git add PhantomKnob/Storage/RuleLibrary.swift
  git commit -m "feat: implement saveRule with merge-and-write inside RuleLibrary"
  ```

---

### 任务 3：扩展手势状态，拦截 C 键激活定制面板并支持热更新

**文件：**
- 修改：`PhantomKnob/Model/KnobState.swift`
- 修改：`PhantomKnob/Service/KnobStateManager.swift`

- [ ] **步骤 1：更新 `KnobState.swift` 中的全局状态**
  在 `KnobGlobalState` 中增加定制中状态：
  ```swift
  // PhantomKnob/Model/KnobState.swift
  enum KnobGlobalState: Equatable {
      case inactive
      case activated
      case knobing(target: DetectedTarget)
      case cooling(target: DetectedTarget)
      case customizing // 新增
      
      var isKnobing: Bool {
          if case .knobing = self { return true }
          return false
      }
      
      var isCooling: Bool {
          if case .cooling = self { return true }
          return false
      }
  }
  ```

- [ ] **步骤 2：在 `KnobStateManager.swift` 中捕获并处理 C 键与配置热更新**
  主要包含两部分修改：
  1. 在 `handleEventTap` 拦截键盘 `C`（keycode 8）进入 `.customizing` 状态并展开 HUD。
  2. 监听 `ControlRuleDidUpdate` 通知并在当前旋转未松手时热更新 active translator/overlay。
  3. 在 `onMultitouchMoved` 里，若状态处于 `.customizing`，则广播双指当前的物理半径，为定制面板提供实时反馈。

  在 `setupBindings()` 中增加配置热重载监听：
  ```swift
  NotificationCenter.default.publisher(for: NSNotification.Name("ControlRuleDidUpdate"))
      .sink { [weak self] notification in
          guard let self = self,
                let updatedRule = notification.userInfo?["rule"] as? ControlRule else { return }
          self.handleRuleHotReload(updatedRule)
      }
      .store(in: &cancellables)
  ```

  增加热更新与按键响应的核心逻辑：
  ```swift
  private func handleRuleHotReload(_ rule: ControlRule) {
      guard let target = currentTarget, target.ruleKey == rule.key else { return }
      
      // 1. 重新实例化当前 Translator 
      let newTranslator = makeTranslator(for: target, rule: rule)
      
      // 保留当前已经累积的步长信息防止跳跃
      newTranslator.scale = currentTranslator?.scale ?? 1.0
      self.currentTranslator = newTranslator
      
      // 2. 重新解析 ScaleConfig
      switch rule.configType {
      case .single:
          if let single = rule.singleConfig {
              self.activeScaleConfig = .fixed(single.unitPerDegree)
          }
      case .double:
          if let double = rule.doubleConfig {
              self.activeScaleConfig = .zones([
                  RadiusZone(minRadius: double.inner.minRadius, maxRadius: double.inner.maxRadius, margin: double.inner.margin, scale: double.inner.unitPerDegree),
                  RadiusZone(minRadius: double.outer.minRadius, maxRadius: double.outer.maxRadius, margin: double.outer.margin, scale: double.outer.unitPerDegree)
              ])
          }
      case .linear:
          if let linear = rule.linearConfig {
              self.activeScaleConfig = .linear(ScaleConfigLinear(minRadius: linear.minRadius, maxRadius: linear.maxRadius, minScale: linear.minScale, maxScale: linear.maxScale))
          }
      }
      
      // 3. 即时刷新 Overlay UI 配色与样式
      if isInterceptingGestures {
          overlayController.show(
              at: initialTouchPosition ?? .zero,
              targetName: target.displayName.isEmpty ? nil : target.displayName,
              scale: lastResolvedBaseScale,
              themeColor: rule.themeColor,
              overlayStyle: nil,
              rotationStyle: nil
          )
      }
  }
  ```

  在 `handleEventTap` 中，拦截 `C` 键：
  ```swift
  // 在 handleEventTap 第一步解析 keyCode 后：
  let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
  
  if keyCode == 8 && type == .keyDown { // 'C' keycode
      if state.isKnobing || state == .activated || state.isCooling {
          DispatchQueue.main.async { [weak self] in
              self?.enterCustomization()
          }
          return true
      }
  }
  ```

  并在 `KnobStateManager` 类中增加进入定制函数：
  ```swift
  private func enterCustomization() {
      guard state != .inactive, let target = currentTarget else { return }
      transition(to: .customizing)
      
      // 弹出定制悬浮面板
      CustomizerHUDWindowController.shared.show(for: target)
  }
  ```

  在 `onMultitouchMoved` 第一行，加入定制状态下的实时半径广播：
  ```swift
  if state == .customizing {
      let scaledPoints = scaleCoordinates(points)
      let radius = calculateRawRadius(points: scaledPoints)
      NotificationCenter.default.post(
          name: NSNotification.Name("CustomizerRadiusDidUpdate"),
          object: nil,
          userInfo: ["radius": radius]
      )
      return
  }
  ```

- [ ] **步骤 3：Commit**
  ```bash
  git add PhantomKnob/Model/KnobState.swift PhantomKnob/Service/KnobStateManager.swift
  git commit -m "feat: implement customization state transitions, global C key intercept, and hot reloading translator"
  ```

---

### 任务 4：编写定制 HUD 窗口管理器与响应式 SwiftUI 配置表单

**文件：**
- 创建：`PhantomKnob/Service/CustomizerHUDWindowController.swift`
- 创建：`PhantomKnob/View/CustomizerHUDView.swift`

- [ ] **步骤 1：创建 `CustomizerHUDWindowController.swift`**
  ```swift
  import AppKit
  import SwiftUI

  class CustomizerWindow: NSWindow {
      override var canBecomeKey: Bool {
          return true
      }
  }

  class CustomizerHUDWindowController: NSObject, NSWindowDelegate {
      static let shared = CustomizerHUDWindowController()
      
      private var window: CustomizerWindow?
      private var localClickMonitor: Any?
      
      var isVisible: Bool {
          return window?.isVisible ?? false
      }
      
      func show(for target: DetectedTarget) {
          if window == nil {
              createWindow(for: target)
          } else {
              // 动态更新 SwiftUI RootView 的 target
              if let visualView = window?.contentView as? NSVisualEffectView,
                 let hostingView = visualView.subviews.first(where: { $0 is NSHostingView<CustomizerHUDView> }) as? NSHostingView<CustomizerHUDView> {
                  hostingView.rootView = CustomizerHUDView(target: target)
              }
          }
          
          window?.makeKeyAndOrderFront(nil)
          NSApp.activate(ignoringOtherApps: true)
          setupClickMonitor()
      }
      
      func hide() {
          window?.orderOut(nil)
          removeClickMonitor()
          
          // 通知状态机恢复激活就绪状态
          NotificationCenter.default.post(name: NSNotification.Name("KnobPanelDidHide"), object: nil)
      }
      
      private func createWindow(for target: DetectedTarget) {
          let width: CGFloat = 400
          let height: CGFloat = 520
          let mouseLoc = NSEvent.mouseLocation
          
          // 定位在光标右下方偏移处，确保不遮挡主操作区
          let contentRect = NSRect(
              x: mouseLoc.x + 30,
              y: mouseLoc.y - height - 30,
              width: width,
              height: height
          )
          
          let win = CustomizerWindow(
              contentRect: contentRect,
              styleMask: [.borderless],
              backing: .buffered,
              defer: false
          )
          
          win.backgroundColor = .clear
          win.isOpaque = false
          win.level = .statusBar
          win.hidesOnDeactivate = true
          win.delegate = self
          
          let visualEffectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: contentRect.size))
          visualEffectView.material = .hudWindow
          visualEffectView.blendingMode = .behindWindow
          visualEffectView.state = .active
          visualEffectView.autoresizingMask = [.width, .height]
          visualEffectView.wantsLayer = true
          visualEffectView.layer?.cornerRadius = 16
          visualEffectView.layer?.masksToBounds = true
          
          win.contentView = visualEffectView
          
          let hostingView = NSHostingView(rootView: CustomizerHUDView(target: target))
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
              if !NSPointInRect(clickLocation, win.frame) {
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

- [ ] **步骤 2：创建 `CustomizerHUDView.swift` 配置面板界面**
  使用 SwiftUI 构建 Glassmorphic UI 交互表单。绑定半径探测器，捕获半径变更事件：
  ```swift
  import SwiftUI

  struct CustomizerHUDView: View {
      let target: DetectedTarget
      
      @State private var themeColor: String = "#0A84FF"
      @State private var configType: KnobConfigType = .single
      
      // 单旋钮
      @State private var singleScale: Double = 1.0
      @State private var singleTranslation: InputTranslation = .scrollWheelVertical
      @State private var singleCWAction: String = "scrollUp"
      
      // 双旋钮
      @State private var doubleInnerRadiusMax: Double = 25.0
      @State private var doubleInnerScale: Double = 0.2
      @State private var doubleInnerTranslation: InputTranslation = .arrowKeyUpDown
      @State private var doubleInnerCWAction: String = "arrowUp"
      
      @State private var doubleOuterRadiusMin: Double = 27.0
      @State private var doubleOuterRadiusMax: Double = 100.0
      @State private var doubleOuterScale: Double = 1.5
      @State private var doubleOuterTranslation: InputTranslation = .scrollWheelVertical
      @State private var doubleOuterCWAction: String = "scrollUp"
      
      // 线性
      @State private var linearMinRadius: Double = 5.0
      @State private var linearMaxRadius: Double = 60.0
      @State private var linearMinScale: Double = 0.1
      @State private var linearMaxScale: Double = 3.0
      @State private var linearTranslation: InputTranslation = .scrollWheelVertical
      @State private var linearCWAction: String = "scrollUp"
      
      // 物理半径实时指示
      @State private var liveRadius: Double? = nil
      
      let colors = ["#0A84FF", "#FF9F0A", "#30D158", "#BF5AF2", "#FF453A"]
      
      var body: some View {
          VStack(alignment: .leading, spacing: 14) {
              // 头部标题
              HStack {
                  VStack(alignment: .leading, spacing: 2) {
                      Text(target.displayName.isEmpty ? "未知控件" : target.displayName)
                          .font(.system(size: 14, weight: .bold))
                          .foregroundColor(.white)
                      Text("\(target.bundleID) · \(target.axRole)")
                          .font(.system(size: 10))
                          .foregroundColor(.gray)
                  }
                  Spacer()
                  if let radius = liveRadius {
                      Text("实时半径: \(Int(radius))pt")
                          .font(.system(size: 10, weight: .semibold, design: .monospaced))
                          .padding(.horizontal, 6)
                          .padding(.vertical, 2)
                          .background(Color.orange.opacity(0.2))
                          .foregroundColor(.orange)
                          .cornerRadius(4)
                  }
              }
              .padding(.bottom, 6)
              
              Divider().background(Color.white.opacity(0.1))
              
              ScrollView(.vertical, showsIndicators: false) {
                  VStack(alignment: .leading, spacing: 16) {
                      // 1. 配色定制
                      VStack(alignment: .leading, spacing: 6) {
                          Text("主题颜色")
                              .font(.system(size: 11, weight: .bold))
                              .foregroundColor(.gray)
                          HStack(spacing: 12) {
                              ForEach(colors, id: \.self) { colorHex in
                                  Circle()
                                      .fill(Color(hex: colorHex))
                                      .frame(width: 20, height: 20)
                                      .overlay(
                                          Circle()
                                              .stroke(Color.white, lineWidth: themeColor == colorHex ? 2 : 0)
                                      )
                                      .onTapGesture {
                                          themeColor = colorHex
                                          save()
                                      }
                              }
                          }
                      }
                      
                      // 2. 模式选择
                      VStack(alignment: .leading, spacing: 6) {
                          Text("旋钮类型")
                              .font(.system(size: 11, weight: .bold))
                              .foregroundColor(.gray)
                          Picker("", selection: $configType) {
                              Text("单旋钮").tag(KnobConfigType.single)
                              Text("双旋钮").tag(KnobConfigType.double)
                              Text("无级变速").tag(KnobConfigType.linear)
                          }
                          .pickerStyle(SegmentedPickerStyle())
                          .onChange(of: configType) { _ in save() }
                      }
                      
                      // 3. 不同模式子表单
                      switch configType {
                      case .single:
                          singleSubForm
                      case .double:
                          doubleSubForm
                      case .linear:
                          linearSubForm
                      }
                  }
              }
          }
          .padding(16)
          .onAppear {
              loadExisting()
          }
          .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CustomizerRadiusDidUpdate"))) { notification in
              if let r = notification.userInfo?["radius"] as? Double {
                  self.liveRadius = r
              }
          }
      }
      
      // MARK: - 模式子表单实现
      
      private var singleSubForm: some View {
          VStack(alignment: .leading, spacing: 10) {
              VStack(alignment: .leading, spacing: 4) {
                  Text("输入映射方式")
                      .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                  Picker("", selection: $singleTranslation) {
                      ForEach(InputTranslation.allCases, id: \.self) { trans in
                          Text(transDescription(trans)).tag(trans)
                      }
                  }
                  .onChange(of: singleTranslation) { next in
                      singleCWAction = defaultAction(for: next)
                      save()
                  }
              }
              
              HStack {
                  Text("灵敏度系数")
                      .font(.system(size: 11)).foregroundColor(.white)
                  Spacer()
                  Slider(value: $singleScale, in: 0.1...5.0, step: 0.1)
                      .frame(width: 150)
                      .onChange(of: singleScale) { _ in save() }
                  Text(String(format: "%.1fx", singleScale))
                      .font(.system(size: 11, design: .monospaced)).foregroundColor(.orange)
              }
              
              VStack(alignment: .leading, spacing: 4) {
                  Text("顺时针旋转时触发")
                      .font(.system(size: 11)).foregroundColor(.white)
                  Picker("", selection: $singleCWAction) {
                      ForEach(directionOptions(for: singleTranslation), id: \.self) { opt in
                          Text(actionDescription(opt)).tag(opt)
                      }
                  }
                  .onChange(of: singleCWAction) { _ in save() }
              }
          }
      }
      
      private var doubleSubForm: some View {
          VStack(alignment: .leading, spacing: 12) {
              // 内圈
              VStack(alignment: .leading, spacing: 8) {
                  Text("🟢 内圈旋钮 (微调)")
                      .font(.system(size: 12, weight: .bold)).foregroundColor(.green)
                  HStack {
                      Text("响应半径").font(.system(size: 11))
                      Spacer()
                      Text("5.0 pt ~ \(Int(doubleInnerRadiusMax)) pt")
                          .font(.system(size: 11, design: .monospaced))
                  }
                  Slider(value: $doubleInnerRadiusMax, in: 10.0...40.0, step: 1.0)
                      .onChange(of: doubleInnerRadiusMax) { next in
                          doubleOuterRadiusMin = next + 2.0
                          save()
                      }
                  
                  Picker("映射", selection: $doubleInnerTranslation) {
                      ForEach(InputTranslation.allCases, id: \.self) { trans in
                          Text(transDescription(trans)).tag(trans)
                      }
                  }
                  .onChange(of: doubleInnerTranslation) { next in
                      doubleInnerCWAction = defaultAction(for: next)
                      save()
                  }
                  
                  HStack {
                      Text("系数: \(String(format: "%.1fx", doubleInnerScale))")
                          .font(.system(size: 11))
                      Spacer()
                      Slider(value: $doubleInnerScale, in: 0.1...2.0, step: 0.1)
                          .frame(width: 150)
                          .onChange(of: doubleInnerScale) { _ in save() }
                  }
              }
              .padding(8)
              .background(Color.white.opacity(0.05))
              .cornerRadius(8)
              
              // 外圈
              VStack(alignment: .leading, spacing: 8) {
                  Text("🟠 外圈旋钮 (粗调)")
                      .font(.system(size: 12, weight: .bold)).foregroundColor(.orange)
                  HStack {
                      Text("响应半径").font(.system(size: 11))
                      Spacer()
                      Text("\(Int(doubleOuterRadiusMin)) pt ~ 100 pt")
                          .font(.system(size: 11, design: .monospaced))
                  }
                  
                  Picker("映射", selection: $doubleOuterTranslation) {
                      ForEach(InputTranslation.allCases, id: \.self) { trans in
                          Text(transDescription(trans)).tag(trans)
                      }
                  }
                  .onChange(of: doubleOuterTranslation) { next in
                      doubleOuterCWAction = defaultAction(for: next)
                      save()
                  }
                  
                  HStack {
                      Text("系数: \(String(format: "%.1fx", doubleOuterScale))")
                          .font(.system(size: 11))
                      Spacer()
                      Slider(value: $doubleOuterScale, in: 0.5...5.0, step: 0.1)
                          .frame(width: 150)
                          .onChange(of: doubleOuterScale) { _ in save() }
                  }
              }
              .padding(8)
              .background(Color.white.opacity(0.05))
              .cornerRadius(8)
          }
      }
      
      private var linearSubForm: some View {
          VStack(alignment: .leading, spacing: 10) {
              Picker("映射", selection: $linearTranslation) {
                  ForEach(InputTranslation.allCases, id: \.self) { trans in
                      Text(transDescription(trans)).tag(trans)
                  }
              }
              .onChange(of: linearTranslation) { next in
                  linearCWAction = defaultAction(for: next)
                  save()
              }
              
              VStack(alignment: .leading, spacing: 6) {
                  Text("线性变化系数范围").font(.system(size: 11, weight: .semibold))
                  HStack {
                      Text("最小: \(String(format: "%.1f", linearMinScale))")
                      Spacer()
                      Slider(value: $linearMinScale, in: 0.05...1.0, step: 0.05)
                          .frame(width: 180)
                          .onChange(of: linearMinScale) { _ in save() }
                  }
                  HStack {
                      Text("最大: \(String(format: "%.1f", linearMaxScale))")
                      Spacer()
                      Slider(value: $linearMaxScale, in: 1.0...5.0, step: 0.1)
                          .frame(width: 180)
                          .onChange(of: linearMaxScale) { _ in save() }
                  }
              }
          }
      }
      
      // MARK: - 模型逻辑适配与加载保存
      
      private func loadExisting() {
          if let existing = RuleLibrary.shared.lookup(for: target.ruleKey) {
              self.themeColor = existing.themeColor ?? "#0A84FF"
              self.configType = existing.configType
              
              if let single = existing.singleConfig {
                  self.singleScale = single.unitPerDegree
                  self.singleTranslation = single.translation
                  self.singleCWAction = single.clockwiseAction
              }
              if let d = existing.doubleConfig {
                  self.doubleInnerRadiusMax = d.inner.maxRadius
                  self.doubleInnerScale = d.inner.unitPerDegree
                  self.doubleInnerTranslation = d.inner.translation
                  self.doubleInnerCWAction = d.inner.clockwiseAction
                  
                  self.doubleOuterRadiusMin = d.outer.minRadius
                  self.doubleOuterRadiusMax = d.outer.maxRadius
                  self.doubleOuterScale = d.outer.unitPerDegree
                  self.doubleOuterTranslation = d.outer.translation
                  self.doubleOuterCWAction = d.outer.clockwiseAction
              }
              if let l = existing.linearConfig {
                  self.linearMinRadius = l.minRadius
                  self.linearMaxRadius = l.maxRadius
                  self.linearMinScale = l.minScale
                  self.linearMaxScale = l.maxScale
                  self.linearTranslation = l.translation
                  self.linearCWAction = l.clockwiseAction
              }
          }
      }
      
      private func save() {
          var rule = ControlRule(key: target.ruleKey, themeColor: themeColor, configType: configType)
          
          switch configType {
          case .single:
              rule.singleConfig = SingleKnobConfig(
                  unitPerDegree: singleScale,
                  translation: singleTranslation,
                  clockwiseAction: singleCWAction
              )
          case .double:
              rule.doubleConfig = DoubleKnobConfig(
                  inner: VirtualKnobConfig(minRadius: 5.0, maxRadius: doubleInnerRadiusMax, margin: 2.0, unitPerDegree: doubleInnerScale, translation: doubleInnerTranslation, clockwiseAction: doubleInnerCWAction),
                  outer: VirtualKnobConfig(minRadius: doubleOuterRadiusMin, maxRadius: doubleOuterRadiusMax, margin: 2.0, unitPerDegree: doubleOuterScale, translation: doubleOuterTranslation, clockwiseAction: doubleOuterCWAction)
              )
          case .linear:
              rule.linearConfig = LinearKnobConfig(
                  minRadius: linearMinRadius,
                  maxRadius: linearMaxRadius,
                  minScale: linearMinScale,
                  maxScale: linearMaxScale,
                  translation: linearTranslation,
                  clockwiseAction: linearCWAction
              )
          }
          
          RuleLibrary.shared.saveRule(rule)
      }
      
      // MARK: - 辅助文本解析
      
      private func transDescription(_ trans: InputTranslation) -> String {
          switch trans {
          case .axWrite: return "无障碍直接写入"
          case .scrollWheelVertical: return "垂直滚轮"
          case .scrollWheelHorizontal: return "水平滚轮"
          case .arrowKeyUpDown: return "上下方向键"
          case .arrowKeyLeftRight: return "左右方向键"
          case .swipeVertical: return "双指上下滑动"
          case .swipeHorizontal: return "双指左右滑动"
          }
      }
      
      private func defaultAction(for trans: InputTranslation) -> String {
          switch trans {
          case .arrowKeyUpDown: return "arrowUp"
          case .arrowKeyLeftRight: return "arrowRight"
          case .scrollWheelVertical: return "scrollUp"
          case .scrollWheelHorizontal: return "scrollRight"
          case .swipeVertical: return "swipeUp"
          case .swipeHorizontal: return "swipeRight"
          case .axWrite: return "increase"
          }
      }
      
      private func directionOptions(for trans: InputTranslation) -> [String] {
          switch trans {
          case .arrowKeyUpDown: return ["arrowUp", "arrowDown"]
          case .arrowKeyLeftRight: return ["arrowRight", "arrowLeft"]
          case .scrollWheelVertical: return ["scrollUp", "scrollDown"]
          case .scrollWheelHorizontal: return ["scrollRight", "scrollLeft"]
          case .swipeVertical: return ["swipeUp", "swipeDown"]
          case .swipeHorizontal: return ["swipeRight", "swipeLeft"]
          case .axWrite: return ["increase", "decrease"]
          }
      }
      
      private func actionDescription(_ action: String) -> String {
          switch action {
          case "arrowUp": return "向上按键"
          case "arrowDown": return "向下按键"
          case "arrowRight": return "向右按键"
          case "arrowLeft": return "向左按键"
          case "scrollUp": return "向上滚动"
          case "scrollDown": return "向下滚动"
          case "scrollRight": return "向右滚动"
          case "scrollLeft": return "向左滚动"
          case "swipeUp": return "向上轻扫"
          case "swipeDown": return "向下轻扫"
          case "swipeRight": return "向右轻扫"
          case "swipeLeft": return "向左轻扫"
          case "increase": return "递增值"
          case "decrease": return "递减值"
          default: return action
          }
      }
  }

  extension Color {
      init(hex: String) {
          let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
          var int: UInt64 = 0
          Scanner(string: hex).scanHexInt64(&int)
          let a, r, g, b: UInt64
          switch hex.count {
          case 3: // RGB (12-bit)
              (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
          case 6: // RGB (24-bit)
              (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
          default:
              (a, r, g, b) = (255, 0, 0, 0)
          }
          self.init(
              .sRGB,
              red: Double(r) / 255,
              green: Double(g) / 255,
              blue: Double(b) / 255,
              opacity: Double(a) / 255
          )
      }
  }
  ```

- [ ] **步骤 3：Commit**
  ```bash
  git add PhantomKnob/Service/CustomizerHUDWindowController.swift PhantomKnob/View/CustomizerHUDView.swift
  git commit -m "feat: implement CustomizerHUDWindowController and responsive CustomizerHUDView SwiftUI panel"
  ```

---

## 3. 验证与回归测试

- [ ] **步骤 1：添加单元测试**
  在 `PhantomKnobTests` 下编写 `CustomKnobTests.swift` 验证双旋钮迟滞和线性模型算法的解析正确性。

- [ ] **步骤 2：编译项目并运行所有单元测试**
  运行：`swift test`
  预期：所有测试通过。

- [ ] **步骤 3：进行全流程手动测试**
  1. 启动项目，通过快捷键 `⌘⌥R` 激活手势监听。
  2. 在 QuickTime 进度条上滚动激活 HUD，在此期间按下键盘 `C`。
  3. 确认光标右侧弹出毛玻璃 Customizer HUD。
  4. 拖动灵敏度系数并点击更改配色，观察 HUD 立即发生相应的颜色变化。
  5. 再次转动手指，确认数值增幅按新设定的灵敏度比率变化。
  6. 关闭 App，检查本地 `~/Library/Application Support/PhantomKnob/rules.json` 是否包含此条新增的 `userRule` 配置。
