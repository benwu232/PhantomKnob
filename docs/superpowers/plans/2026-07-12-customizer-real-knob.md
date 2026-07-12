# 旋钮定制面板原地锁定真实操作 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 
移除定制面板（`CustomizerHUDView`）的虚拟预览区，改为原地锁定并直接对屏幕上的真实旋钮进行物理操作调试。通过避让计算防止面板阻挡旋钮，并为面板 ScrollView 底部增加滚动淡出提示。

**架构：**
1. 在 `KnobStateManager` 处于 `customizing` 状态时，固定 Overlay 的屏幕中心，并穿透允许正常的物理两指旋转计算及 `Translator` 系统级事件发送，实现“边调边试”。
2. 面板 `onChange` 触发热重载时，实时调用 `overlayController.update()` 同步刷新屏幕上已锁定的真实 Overlay。
3. 精简 `CustomizerHUDView` 移去预览区及手势模拟；增加顶栏显式关闭按钮与底栏滚动淡出蒙层。

---

## 涉及文件变更

- 修改：`PhantomKnob/Service/CustomizerHUDWindowController.swift`
- 修改：`PhantomKnob/Service/KnobStateManager.swift`
- 修改：`PhantomKnob/View/CustomizerHUDView.swift`

---

## 实施步骤

### 任务 1：升级 CustomizerHUDWindowController 支持避让锁定与高度调整

**文件：**
- 修改：[CustomizerHUDWindowController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/CustomizerHUDWindowController.swift)

- [ ] **步骤 1：引入 overlayFixedCenter 属性并在 show 中接收参数**
  在 `CustomizerHUDWindowController` 增加 `overlayFixedCenter` 变量用于缓存旋钮中心。
  ```swift
  private var overlayFixedCenter: CGPoint? = nil
  ```
  修改 `show(for:overlayCenter:)` 接收该参数：
  ```swift
  func show(for target: DetectedTarget, overlayCenter: CGPoint? = nil) {
      self.overlayFixedCenter = overlayCenter
      if window == nil {
          createWindow(for: target)
      } else {
          if let visualView = window?.contentView as? NSVisualEffectView,
             let hostingView = visualView.subviews.first(where: { $0 is NSHostingView<AnyView> }) as? NSHostingView<AnyView> {
              hostingView.rootView = AnyView(CustomizerHUDView(target: target).id(UUID()))
          }
          updateWindowPosition()
      }
      ...
  ```

- [ ] **步骤 2：在 calculateWindowFrame 中重构避让算法，高度精简为 480px**
  如果 `overlayFixedCenter` 有值，则在旋钮的左右两侧（间距 130px）寻找安全位置进行窗口排布，并与 Overlay 垂直对齐。
  ```swift
  private func calculateWindowFrame() -> NSRect {
      let width: CGFloat = 440
      let height: CGFloat = 480
      let screens = NSScreen.screens
      
      if let overlayCenter = overlayFixedCenter {
          let screen = screens.first(where: { NSMouseInRect(overlayCenter, $0.frame, false) }) ?? NSScreen.main ?? screens.first
          let screenFrame = screen?.visibleFrame ?? .zero
          
          let gap: CGFloat = 130
          var originX = overlayCenter.x + gap
          
          if originX + width > screenFrame.maxX {
              originX = overlayCenter.x - gap - width
          }
          
          var originY = overlayCenter.y - height / 2
          
          originX = max(screenFrame.minX, min(originX, screenFrame.maxX - width))
          originY = max(screenFrame.minY, min(originY, screenFrame.maxY - height))
          
          return NSRect(x: originX, y: originY, width: width, height: height)
      }
      
      // Fallback
      let mouseLoc = NSEvent.mouseLocation
      let screen = screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? screens.first
      let screenFrame = screen?.visibleFrame ?? .zero
      var originX = mouseLoc.x + 30
      var originY = mouseLoc.y - height - 30
      if originX + width > screenFrame.maxX {
          originX = mouseLoc.x - width - 30
      }
      if originY < screenFrame.minY {
          originY = mouseLoc.y + 30
      }
      originX = max(screenFrame.minX, min(originX, screenFrame.maxX - width))
      originY = max(screenFrame.minY, min(originY, screenFrame.maxY - height))
      return NSRect(x: originX, y: originY, width: width, height: height)
  }
  ```

- [ ] **步骤 3：运行测试并 commit**
  运行：`swift build` 验证编译。
  ```bash
  git add PhantomKnob/Service/CustomizerHUDWindowController.swift
  git commit -m "feat: customize window controller support layout avoidance and resize to 480px"
  ```

---

### 任务 2：重构 KnobStateManager 手势穿透与即时重载刷新

**文件：**
- 修改：[KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/KnobStateManager.swift)

- [ ] **步骤 1：在 enterCustomization 处传递 fixedCenter**
  ```swift
  private func enterCustomization() {
      guard state != .inactive, let target = currentTarget else { return }
      isInterceptingGestures = false
      gestureClassifier.processTouchesEnded()
      initialTouchPositionCarbon = nil
      overlayController.hide()
      
      transition(to: .customizing)
      
      CustomizerHUDWindowController.shared.show(for: target, overlayCenter: self.fixedCenter)
  }
  ```

- [ ] **步骤 2：在 onMultitouchMoved 移除 customizing 阻断，支持手势物理穿透**
  在 customizing 时，允许物理角度计算，在 currentTranslator 为 nil 时防御性创建，并投递真实事件，然后通过 `overlayController.update()` 刷新常驻的 Overlay。
  ```swift
  func onMultitouchMoved(points: [Int: CGPoint]) {
      if state == .customizing {
          let scaledPoints = scaleCoordinates(points)
          let radius = calculateRawRadius(points: scaledPoints)
          NotificationCenter.default.post(
              name: NSNotification.Name("CustomizerRadiusDidUpdate"),
              object: nil,
              userInfo: ["radius": radius]
          )
          
          if points.count >= 2 {
              let scaledPointsForCalc = scaleCoordinates(points)
              if let currentAngle = calculateRawAngle(points: scaledPointsForCalc) {
                  let rule = currentTarget.flatMap { RuleLibrary.shared.lookup(for: $0.ruleKey) }
                  let nextVal: Double?
                  if let r = radius {
                      nextVal = rule.flatMap { ScaleResolver.resolve(rule: $0, radius: r, zoneIndex: currentZoneIndex) }
                  } else {
                      nextVal = nil
                  }
                  
                  if currentTranslator == nil, let t = currentTarget {
                      currentTranslator = rule.flatMap { makeTranslator(for: t, rule: $0, radius: radius ?? 20.0) }
                  }
                  
                  if let activeScale = nextVal, let translator = currentTranslator {
                      translator.scale = activeScale
                      let deltaAngle = abs(currentAngle - previousAngle)
                      var correctedDelta = deltaAngle
                      while correctedDelta < -180 { correctedDelta += 360 }
                      while correctedDelta > 180 { correctedDelta -= 360 }
                      
                      let direction: RotationDirection = (currentAngle - previousAngle) >= 0 ? .clockwise : .counterClockwise
                      translator.apply(units: abs(correctedDelta), direction: direction)
                      
                      let color = rule.flatMap { resolveThemeColor(for: $0, zoneIndex: currentZoneIndex, radius: radius) }
                      overlayController.update(
                          angle: currentAngle,
                          radius: radius,
                          isDeadzone: false,
                          scale: activeScale,
                          themeColor: color,
                          outerThemeColor: rule?.linearConfig?.outerThemeColor,
                          innerThemeColor: rule?.linearConfig?.innerThemeColor,
                          configType: rule?.configType ?? .single
                      )
                  }
                  self.currentAngle = currentAngle
                  previousAngle = currentAngle
              }
          }
          return
      }
      ...
  ```

- [ ] **步骤 3：在 handleRuleHotReload 中热刷新常驻 Overlay 的视觉**
  当 customizing 时，立刻调用 update 重绘 Overlay。
  ```swift
  private func handleRuleHotReload(_ rule: ControlRule) {
      guard let target = currentTarget, target.ruleKey == rule.key else { return }
      
      let newTranslator = makeTranslator(for: target, rule: rule, radius: self.currentRadius)
      self.currentTranslator = newTranslator
      
      if state == .customizing {
          let color = resolveThemeColor(for: rule, zoneIndex: currentZoneIndex, radius: self.currentRadius)
          overlayController.update(
              angle: self.currentAngle,
              radius: self.currentRadius,
              isDeadzone: false,
              scale: self.lastResolvedBaseScale,
              themeColor: color,
              outerThemeColor: rule.linearConfig?.outerThemeColor,
              innerThemeColor: rule.linearConfig?.innerThemeColor,
              configType: rule.configType
          )
      }
  }
  ```

- [ ] **步骤 4：运行测试并 commit**
  运行：`swift build` 验证编译。
  ```bash
  git add PhantomKnob/Service/KnobStateManager.swift
  git commit -m "feat: state manager support physical event translation and overlay reload under customizing state"
  ```

---

### 任务 3：精简配置面板 UI，增加顶栏关闭按钮及底栏滚动淡出蒙层

**文件：**
- 修改：[CustomizerHUDView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/CustomizerHUDView.swift)

- [ ] **步骤 1：移除所有虚拟预览变量和相关的手势与类声明**
  在 `CustomizerHUDView.swift` 中删除：
  - `previewAngle`、`previewRadius`、`activeRingIndex`、`isInteracting`、`lastPreviewAngle`、`touchpadCoordinator`、`linearOuterColor`、`linearInnerColor`
  - `mmToPx`
  - `previewDragGesture` 属性计算
  - `previewArea` 属性计算
  - `triggerTranslation(deltaAngle:)` 方法
  - 尾部的 `PreviewEventSender` 类定义。
  - 在 `.onAppear` 中删除 touchpadCoordinator 相关的更新闭包绑定。

- [ ] **步骤 2：重构 body 添加顶栏 Header 关闭按钮与底部滚动渐变蒙层**
  ```swift
  var body: some View {
      VStack(alignment: .leading, spacing: 12) {
          // 顶栏 Header
          HStack {
              Button(action: {
                  CustomizerHUDWindowController.shared.hide()
              }) {
                  Image(systemName: "xmark.circle.fill")
                      .font(.system(size: 20))
                      .foregroundColor(.gray)
              }
              .buttonStyle(PlainButtonStyle())
              
              Spacer()
              
              Text(String(localized: "hud.title.edit", defaultValue: "Edit Control Rule"))
                  .font(.system(size: 13, weight: .bold))
                  .foregroundColor(.white)
              
              Spacer()
              Spacer().frame(width: 20) // 对齐占位
          }
          .padding(.top, 4)
          
          Divider().background(Color.white.opacity(0.1))
          
          VStack(spacing: 0) {
              ScrollView(.vertical, showsIndicators: false) {
                  VStack(alignment: .leading, spacing: 16) {
                      // ① 旋钮类型
                      VStack(alignment: .leading, spacing: 6) {
                          Text(String(localized: "hud.knobType", defaultValue: "Knob Type"))
                              .font(.system(size: 11, weight: .bold))
                              .foregroundColor(.gray)
                          Picker("", selection: $configType) {
                              Text(String(localized: "hud.single", defaultValue: "Single Knob")).tag(KnobConfigType.single)
                              Text(String(localized: "hud.double", defaultValue: "Double-Ring")).tag(KnobConfigType.double)
                              Text(String(localized: "hud.linear", defaultValue: "Variable Speed")).tag(KnobConfigType.linear)
                          }
                          .pickerStyle(SegmentedPickerStyle())
                          .onChange(of: configType) { _ in save() }
                      }
                      
                      Divider().background(Color.white.opacity(0.08))
                      
                      // ② 🎨 外观定制
                      VStack(alignment: .leading, spacing: 8) {
                          Text("🎨 \(String(localized: "hud.section.appearance", defaultValue: "Appearance"))")
                              .font(.system(size: 11, weight: .bold))
                              .foregroundColor(.gray)
                          
                          switch configType {
                          case .single:
                              singleAppearanceForm
                          case .double:
                              doubleAppearanceForm
                          case .linear:
                              linearAppearanceForm
                          }
                      }
                      
                      Divider().background(Color.white.opacity(0.08))
                      
                      // ③ ⚡ 行为定制
                      VStack(alignment: .leading, spacing: 8) {
                          Text("⚡ \(String(localized: "hud.section.behavior", defaultValue: "Behavior"))")
                              .font(.system(size: 11, weight: .bold))
                              .foregroundColor(.gray)
                          
                          switch configType {
                          case .single:
                              singleBehaviorForm
                          case .double:
                              doubleBehaviorForm
                          case .linear:
                              linearBehaviorForm
                          }
                      }
                      
                      Divider().background(Color.white.opacity(0.08))
                      
                      // ④ ▶ 高级定位信息 (默认折叠)
                      DisclosureGroup(isExpanded: $isAdvancedExpanded) {
                          VStack(alignment: .leading, spacing: 12) {
                              VStack(alignment: .leading, spacing: 6) {
                                  Text(String(localized: "hud.locatingIdentifier", defaultValue: "Element Locating Identifier"))
                                      .font(.system(size: 10, weight: .bold))
                                      .foregroundColor(.gray)
                                  
                                  VStack(spacing: 4) {
                                      metadataRow(label: String(localized: "hud.bundleID", defaultValue: "Bundle ID"), value: target.bundleID)
                                      metadataRow(label: String(localized: "hud.axRole", defaultValue: "AXRole"), value: target.axRole)
                                      metadataRow(label: String(localized: "hud.axIdentifier", defaultValue: "AXIdentifier"), value: target.identifier ?? String(localized: "hud.globalMatch", defaultValue: "Global match"))
                                  }
                                  .padding(8)
                                  .background(Color.black.opacity(0.2))
                                  .cornerRadius(8)
                              }
                              
                              if !target.parentChain.isEmpty {
                                  VStack(alignment: .leading, spacing: 6) {
                                      Text(hasConflict 
                                           ? String(localized: "hud.conflictDetected", defaultValue: "⚠️ Element conflict detected (Hierarchy match enabled)") 
                                           : String(localized: "hud.hierarchyFeatures", defaultValue: "Hierarchy features (Check to enable precise targeting)"))
                                          .font(.system(size: 10, weight: .bold))
                                          .foregroundColor(hasConflict ? .yellow : .gray)
                                      
                                      VStack(alignment: .leading, spacing: 4) {
                                          ForEach(0..<target.parentChain.count, id: \.self) { idx in
                                              let parent = target.parentChain[idx]
                                              HStack(spacing: 6) {
                                                  Toggle("", isOn: Binding(
                                                      get: { self.selectedParents.contains(idx) },
                                                      set: { isCheck in
                                                          if idx == lockedDiffIndex { return }
                                                          if isCheck {
                                                              self.selectedParents.insert(idx)
                                                          } else {
                                                              self.selectedParents.remove(idx)
                                                          }
                                                          loadExisting()
                                                      }
                                                  ))
                                                  .toggleStyle(.checkbox)
                                                  .disabled(idx == lockedDiffIndex)
                                                  
                                                  Text("\(parent.displayName ?? String(localized: "hud.unnamedControl", defaultValue: "Unnamed Control")) (\(parent.axRole))")
                                                      .font(.system(size: 10))
                                                      .foregroundColor(idx == lockedDiffIndex ? .green : .white)
                                                  
                                                  if idx == lockedDiffIndex {
                                                      Text(String(localized: "hud.splitDifference", defaultValue: "💡 Split difference point"))
                                                          .font(.system(size: 8))
                                                          .foregroundColor(.green)
                                                          .padding(.horizontal, 4)
                                                          .background(Color.green.opacity(0.1))
                                                          .cornerRadius(4)
                                                  }
                                              }
                                              .padding(.vertical, 2)
                                          }
                                      }
                                      .padding(8)
                                      .background(Color.black.opacity(0.2))
                                      .cornerRadius(8)
                                  }
                              }
                          }
                          .padding(.top, 4)
                      } label: {
                          HStack {
                              Image(systemName: isAdvancedExpanded ? "chevron.down" : "chevron.right")
                                  .font(.system(size: 10, weight: .bold))
                              Text(String(localized: "hud.section.advanced", defaultValue: "Advanced Positioning Options"))
                                  .font(.system(size: 11, weight: .bold))
                          }
                          .foregroundColor(.gray)
                      }
                  }
              }
              
              // 底部滚动淡出羽化渐变阴影蒙层，提示用户下方还有未展示内容
              LinearGradient(
                  gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.4)]),
                  startPoint: .top,
                  endPoint: .bottom
              )
              .frame(height: 12)
              .padding(.top, -12)
              .allowsHitTesting(false)
          }
      }
      .padding(16)
  }
  ```

- [ ] **步骤 3：运行测试并 commit**
  运行：`swift build` 验证编译。
  ```bash
  git add PhantomKnob/View/CustomizerHUDView.swift
  git commit -m "refactor: simplify customizer hud view layout and add scroll gradient shadow"
  ```

---

## 验证与集成测试计划

### 1. 编译验证
在项目路径下运行命令确认无 Swift 语法问题：
```bash
swift build
```

### 2. 手工功能与避让逻辑测试
1. 打开应用，聚焦于任一目标旋钮（DaVinci Resolve 或测试旋钮）。
2. 在旋钮激活时按下键盘上的 `C` 键：
   - 验证真实 Overlay 停在原地锁定。
   - 验证定制配置面板避开 Overlay（通常位于右侧或左侧 130px）弹出，不再遮挡。
   - 验证定制面板高度精炼，且由于高级选项处于折叠状态，面板底部出现淡淡的渐变黑影蒙层（滚动时能看出文字隐入蒙层，提示下方可滚动）。
3. 保持面板显示，直接用两指在触控板上旋转物理旋钮：
   - 验证 Overlay 的指示角度跟随你的手指完美转动，且外部音量或功能会被真实控制。
   - 验证拉动半径滑块时，屏幕上的 Overlay 大小跟着实时收缩。
4. 点击面板左上角的关闭按钮或再次按 `C`/`Esc` 键：
   - 验证定制面板消失，且真实的 Overlay 隐退淡出。
