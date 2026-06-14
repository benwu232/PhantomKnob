# 双旋钮独立配色与配置实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现双旋钮手势独立配置（包括内圈/外圈的各自配色、输出映射、变化量），重组 HUD 配色定制面板为三个精美的 Tab 标签，并在跨越圈边界时支持 Overlay 圆环颜色动态热切换。

**架构：** 在 `VirtualKnobConfig` 数据模型中增加可选的 `themeColor` 属性以保持后向兼容。优化 `CustomizerHUDView` 界面为三标签式 Tab（单旋钮、双旋钮、线性半径），在双旋钮模式下将大旋钮（外圈）放在上方，并各自独立包含单行 16 色预设配色区。更新 `KnobStateManager` 和 `OverlayController` 以便在手势移动切换内/外圈时实时动态切换 Overlay UI 颜色。

**技术栈：** Swift 5.9, SwiftUI, AppKit, XCTest

---

### 任务 1：扩展数据模型以支持 VirtualKnobConfig 独立配色

**文件：**
- 修改：`PhantomKnob/Model/ControlRule.swift`
- 修改：`PhantomKnob/PhantomKnobTests/CustomKnobTests.swift`

- [ ] **步骤 1：在 `CustomKnobTests.swift` 中添加失败测试，验证 VirtualKnobConfig 色彩读写与兼容性**
  
  在 `CustomKnobTests.swift` 的末尾添加测试函数：
  ```swift
  func testVirtualKnobConfigThemeColorCodable() throws {
      // 1. 测试能正确编码和解码 themeColor
      let configWithColor = VirtualKnobConfig(
          minRadius: 5.0, maxRadius: 25.0, margin: 2.0,
          unitPerDegree: 0.5, translation: .arrowKeyUpDown, clockwiseAction: "arrowUp",
          themeColor: "#30D158"
      )
      let encoder = JSONEncoder()
      let decoder = JSONDecoder()
      let data = try encoder.encode(configWithColor)
      let decoded = try decoder.decode(VirtualKnobConfig.self, from: data)
      XCTAssertEqual(decoded.themeColor, "#30D158")
      
      // 2. 测试后向兼容性：缺少 themeColor 字段时能成功解码为 nil
      let jsonWithoutColor = """
      {
          "minRadius": 5.0,
          "maxRadius": 25.0,
          "margin": 2.0,
          "unitPerDegree": 0.5,
          "translation": "arrowKeyUpDown",
          "clockwiseAction": "arrowUp"
      }
      """.data(using: .utf8)!
      let decodedCompatible = try decoder.decode(VirtualKnobConfig.self, from: jsonWithoutColor)
      XCTAssertNil(decodedCompatible.themeColor)
  }
  ```

- [ ] **步骤 2：运行单元测试验证失败**
  
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' -only-testing PhantomKnobTests/CustomKnobTests/testVirtualKnobConfigThemeColorCodable`
  预期：编译失败，因为 `VirtualKnobConfig` 还没有 `themeColor` 属性。

- [ ] **步骤 3：在 `ControlRule.swift` 中为 `VirtualKnobConfig` 结构体添加 `themeColor` 属性**
  
  修改 `PhantomKnob/Model/ControlRule.swift` 中的 `VirtualKnobConfig` 结构体：
  ```swift
  struct VirtualKnobConfig: Codable, Equatable {
      var minRadius: Double
      var maxRadius: Double
      var margin: Double
      var unitPerDegree: Double
      var translation: InputTranslation
      var clockwiseAction: String
      var themeColor: String? // 新增：支持独立配色
  }
  ```

- [ ] **步骤 4：运行测试验证通过**
  
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' -only-testing PhantomKnobTests/CustomKnobTests/testVirtualKnobConfigThemeColorCodable`
  预期：PASS，所有兼容性测试通过。

- [ ] **步骤 5：Commit**
  
  ```bash
  git add PhantomKnob/Model/ControlRule.swift PhantomKnob/PhantomKnobTests/CustomKnobTests.swift
  git commit -m "feat: add themeColor property to VirtualKnobConfig with full backward compatibility"
  ```

---

### 任务 2：扩展 Overlay 动态配色切换接口

**文件：**
- 修改：`PhantomKnob/Service/OverlayController.swift:95-103`
- 修改：`PhantomKnob/PhantomKnobTests/OverlayControllerTests.swift`

- [ ] **步骤 1：在 `OverlayControllerTests.swift` 中编写测试，验证 update 时更新颜色效果**
  
  在 `OverlayControllerTests.swift` 的末尾添加测试函数：
  ```swift
  func testOverlayUpdateThemeColor() {
      let controller = OverlayController()
      controller.show(at: .zero, targetName: "Test", scale: 1.0, themeColor: "#000000")
      XCTAssertEqual(controller.themeColor, "#000000")
      
      controller.update(angle: 90.0, radius: 20.0, isDeadzone: false, scale: 1.2, themeColor: "#FF9F0A")
      XCTAssertEqual(controller.themeColor, "#FF9F0A")
  }
  ```

- [ ] **步骤 2：运行单元测试验证失败**
  
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' -only-testing PhantomKnobTests/OverlayControllerTests/testOverlayUpdateThemeColor`
  预期：编译失败，因为 `update` 没有 `themeColor` 属性。

- [ ] **步骤 3：在 `OverlayController.swift` 中为 `update` 方法添加可选 `themeColor` 参数并更新状态**
  
  修改 `PhantomKnob/Service/OverlayController.swift` 中的 `update` 方法：
  ```swift
      func update(angle: Double, radius: Double, isDeadzone: Bool = false, scale: Double? = nil, themeColor: String? = nil) {
          self.angle = angle
          self.isDeadzone = isDeadzone
          self.scale = scale
          if let themeColor = themeColor {
              self.themeColor = themeColor
          }
          self.diameter = Self.calculateDiameter(for: radius)
          
          updatePanelFrame()
          updateOverlayView()
      }
  ```

- [ ] **步骤 4：运行测试验证通过**
  
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' -only-testing PhantomKnobTests/OverlayControllerTests/testOverlayUpdateThemeColor`
  预期：PASS。

- [ ] **步骤 5：Commit**
  
  ```bash
  git add PhantomKnob/Service/OverlayController.swift PhantomKnob/PhantomKnobTests/OverlayControllerTests.swift
  git commit -m "feat: extend OverlayController.update to support dynamic theme color switches"
  ```

---

### 任务 3：在手势移动中实现双旋钮独立颜色切换

**文件：**
- 修改：`PhantomKnob/Service/KnobStateManager.swift`
- 修改：`PhantomKnob/PhantomKnobTests/CustomKnobTests.swift`

- [ ] **步骤 1：在 `CustomKnobTests.swift` 中编写测试，模拟手势移动切换区域时的配色刷新**
  
  在 `CustomKnobTests.swift` 中添加测试函数：
  ```swift
  func testKnobStateManagerResolvesZoneThemeColor() {
      let key = RuleKey(bundleID: "test.zone.app", axRole: "AXSlider", identifier: "test", displayName: "Test")
      let inner = VirtualKnobConfig(minRadius: 5.0, maxRadius: 20.0, margin: 2.0, unitPerDegree: 0.5, translation: .arrowKeyUpDown, clockwiseAction: "arrowUp", themeColor: "#30D158")
      let outer = VirtualKnobConfig(minRadius: 22.0, maxRadius: 100.0, margin: 2.0, unitPerDegree: 2.0, translation: .scrollWheelVertical, clockwiseAction: "scrollUp", themeColor: "#FF9F0A")
      let rule = ControlRule(key: key, themeColor: "#0A84FF", configType: .double, doubleConfig: DoubleKnobConfig(inner: inner, outer: outer))
      
      RuleLibrary.shared.saveRule(rule)
      
      let manager = KnobStateManager.shared
      manager.currentTarget = DetectedTarget(bundleID: key.bundleID, axRole: key.axRole, identifier: key.identifier, displayName: key.displayName ?? "", element: nil)
      
      // 触发规则重载
      NotificationCenter.default.post(name: NSNotification.Name("ControlRuleDidUpdate"), object: nil, userInfo: ["rule": rule])
      
      // 验证在 inner zone (zoneIndex = 0) 时解析为绿色
      let colorInner = manager.resolveThemeColor(for: rule, zoneIndex: 0)
      XCTAssertEqual(colorInner, "#30D158")
      
      // 验证在 outer zone (zoneIndex = 1) 时解析为橙色
      let colorOuter = manager.resolveThemeColor(for: rule, zoneIndex: 1)
      XCTAssertEqual(colorOuter, "#FF9F0A")
  }
  ```

- [ ] **步骤 2：运行单元测试验证失败**
  
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' -only-testing PhantomKnobTests/CustomKnobTests/testKnobStateManagerResolvesZoneThemeColor`
  预期：编译失败，因为 `KnobStateManager` 缺少 `resolveThemeColor` 方法。

- [ ] **步骤 3：在 `KnobStateManager.swift` 中新增 `resolveThemeColor` 辅助方法**
  
  在 `KnobStateManager.swift` 内添加：
  ```swift
      func resolveThemeColor(for rule: ControlRule?, zoneIndex: Int) -> String? {
          guard let rule = rule else { return nil }
          if rule.configType == .double, let doubleConfig = rule.doubleConfig {
              if zoneIndex == 0 {
                  return doubleConfig.inner.themeColor ?? "#30D158"
              } else {
                  return doubleConfig.outer.themeColor ?? "#FF9F0A"
              }
          }
          return rule.themeColor
      }
  ```

- [ ] **步骤 4：在 `KnobStateManager.swift` 的手势开始与更新位置替换为动态配色逻辑**
  
  修改 `KnobStateManager.swift:478-485`：
  ```swift
              if let mouseLoc = initialTouchPosition {
                  overlayController.show(
                      at: mouseLoc,
                      targetName: target.displayName.isEmpty ? nil : target.displayName,
                      scale: self.lastResolvedBaseScale,
                      themeColor: resolveThemeColor(for: rule, zoneIndex: currentZoneIndex),
                      overlayStyle: rule?.overlayStyle,
                      rotationStyle: rule?.rotationStyle
                  )
              }
  ```
  修改 `KnobStateManager.swift:525-532`：
  ```swift
                      overlayController.show(
                          at: mouseLoc,
                          targetName: target.displayName.isEmpty ? nil : target.displayName,
                          scale: self.lastResolvedBaseScale,
                          themeColor: resolveThemeColor(for: rule, zoneIndex: currentZoneIndex),
                          overlayStyle: rule?.overlayStyle,
                          rotationStyle: rule?.rotationStyle
                      )
  ```
  修改 `KnobStateManager.swift:588-592`，在 zoneIndex 改变时主动更新 Overlay 颜色：
  ```swift
                  if resolvedZoneIndex != currentZoneIndex {
                      currentZoneIndex = resolvedZoneIndex
                      if let target = currentTarget,
                         let rule = RuleLibrary.shared.lookup(for: target.ruleKey),
                         rule.configType == .double {
                          let newTranslator = makeTranslator(for: target, rule: rule, radius: radius)
                          self.currentTranslator = newTranslator
                          translator = newTranslator
                          
                          let activeColor = resolveThemeColor(for: rule, zoneIndex: currentZoneIndex)
                          overlayController.update(
                              angle: currentAngle,
                              radius: radius,
                              isDeadzone: false,
                              scale: activeBaseScale,
                              themeColor: activeColor
                          )
                      }
                  }
  ```
  修改 `KnobStateManager.swift:621` 和 `656`，在通用移动和死区事件中下传配色：
  ```swift
                  let activeColor = resolveThemeColor(for: currentTarget.flatMap { RuleLibrary.shared.lookup(for: $0.ruleKey) }, zoneIndex: currentZoneIndex)
                  overlayController.update(angle: currentAngle, radius: radius, isDeadzone: true, scale: self.lastResolvedBaseScale, themeColor: activeColor)
  ```
  以及：
  ```swift
              let activeColor = resolveThemeColor(for: currentTarget.flatMap { RuleLibrary.shared.lookup(for: $0.ruleKey) }, zoneIndex: currentZoneIndex)
              overlayController.update(angle: currentAngle, radius: radius, isDeadzone: false, scale: activeBaseScale, themeColor: activeColor)
  ```

- [ ] **步骤 5：运行测试验证通过**
  
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' -only-testing PhantomKnobTests/CustomKnobTests/testKnobStateManagerResolvesZoneThemeColor`
  预期：PASS。

- [ ] **步骤 6：Commit**
  
  ```bash
  git add PhantomKnob/Service/KnobStateManager.swift PhantomKnob/PhantomKnobTests/CustomKnobTests.swift
  git commit -m "feat: dynamically switch overlay theme color based on active zone in KnobStateManager"
  ```

---

### 任务 4：定制面板 UI 重组为三 Tab 交互模式

**文件：**
- 修改：`PhantomKnob/View/CustomizerHUDView.swift`
- 修改：`PhantomKnob/PhantomKnobTests/CustomKnobTests.swift`

- [ ] **步骤 1：重构 `CustomizerHUDView.swift` 中的模式选择、配色方案与双旋钮布局**
  
  - 移出全局的“主题颜色”配色栏。
  - 在顶端放置精美标签栏控制 `configType`：
    ```swift
    // 在 CustomizerHUDView 的 body 最顶部：
    HStack(spacing: 0) {
        tabButton("单旋钮", type: .single, icon: "circle")
        tabButton("双旋钮", type: .double, icon: "circle.circle")
        tabButton("线性半径", type: .linear, icon: "arrow.up.and.down.circle")
    }
    .padding(3)
    .background(Color.white.opacity(0.06))
    .cornerRadius(8)
    .padding(.horizontal, 16)
    ```
    实现 `tabButton` 方法：
    ```swift
    private func tabButton(_ label: String, type: KnobConfigType, icon: String) -> some View {
        Button(action: {
            self.configType = type
            save()
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 11, weight: configType == type ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(configType == type ? Color(hex: activeTabColor).opacity(0.15) : Color.clear)
            .foregroundColor(configType == type ? Color(hex: activeTabColor) : .gray)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var activeTabColor: String {
        switch configType {
        case .single: return themeColor
        case .double: return doubleOuterThemeColor
        case .linear: return themeColor
        }
    }
    ```
  
  - 在 `CustomizerHUDView` 中增加独立的配色状态、调色源枚举：
    ```swift
    @State private var doubleInnerThemeColor: String = "#30D158"
    @State private var doubleOuterThemeColor: String = "#FF9F0A"
    @State private var activeColorTarget: ColorTarget = .global
    
    enum ColorTarget {
        case global
        case doubleInner
        case doubleOuter
    }
    ```
  
  - 在 `loadExisting()` 中读取子配色：
    ```swift
            if let d = existing.doubleConfig {
                self.doubleInnerRadiusMax = d.inner.maxRadius
                self.doubleInnerScale = d.inner.unitPerDegree
                self.doubleInnerScaleText = String(format: "%.4g", d.inner.unitPerDegree)
                self.doubleInnerTranslation = d.inner.translation
                self.doubleInnerCWAction = d.inner.clockwiseAction
                self.doubleInnerThemeColor = d.inner.themeColor ?? "#30D158"
                
                self.doubleMargin = d.inner.margin
                
                self.doubleOuterRadiusMin = d.outer.minRadius
                self.doubleOuterRadiusMax = d.outer.maxRadius
                self.doubleOuterScale = d.outer.unitPerDegree
                self.doubleOuterScaleText = String(format: "%.4g", d.outer.unitPerDegree)
                self.doubleOuterTranslation = d.outer.translation
                self.doubleOuterCWAction = d.outer.clockwiseAction
                self.doubleOuterThemeColor = d.outer.themeColor ?? "#FF9F0A"
            }
    ```
  
  - 在 `save()` 中储存子配色：
    ```swift
        case .double:
            rule.doubleConfig = DoubleKnobConfig(
                inner: VirtualKnobConfig(minRadius: 5.0, maxRadius: doubleInnerRadiusMax, margin: doubleMargin, unitPerDegree: doubleInnerScale, translation: doubleInnerTranslation, clockwiseAction: doubleInnerCWAction, themeColor: doubleInnerThemeColor),
                outer: VirtualKnobConfig(minRadius: doubleInnerRadiusMax + doubleMargin, maxRadius: doubleOuterRadiusMax, margin: doubleMargin, unitPerDegree: doubleOuterScale, translation: doubleOuterTranslation, clockwiseAction: doubleOuterCWAction, themeColor: doubleOuterThemeColor)
            )
    ```

  - 设计通用单行配色子组件 `colorPickerSection`，限制为小尺寸单行：
    ```swift
    private func colorPickerSection(title: String, bindingColor: Binding<String>, target: ColorTarget) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
            
            HStack(spacing: 5) {
                ForEach(colors, id: \.self) { colorHex in
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: bindingColor.wrappedValue == colorHex ? 1.5 : 0)
                        )
                        .onTapGesture {
                            bindingColor.wrappedValue = colorHex
                            save()
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(action: {
                self.activeColorTarget = target
                NSColorPanel.shared.color = NSColor(Color(hex: bindingColor.wrappedValue))
                NSColorPanel.shared.orderFront(nil)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: bindingColor.wrappedValue))
                    Text("自定义颜色...")
                        .font(.system(size: 10))
                    Spacer()
                    Text(bindingColor.wrappedValue)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.05))
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 2)
        }
    }
    ```
  
  - 调整 `onReceive(NSColorPanel.colorDidChangeNotification)`：
    ```swift
        .onReceive(NotificationCenter.default.publisher(for: NSColorPanel.colorDidChangeNotification)) { notification in
            if let panel = notification.object as? NSColorPanel {
                let color = panel.color
                if let hex = color.toHex() {
                    switch self.activeColorTarget {
                    case .global:
                        self.themeColor = hex
                    case .doubleInner:
                        self.doubleInnerThemeColor = hex
                    case .doubleOuter:
                        self.doubleOuterThemeColor = hex
                    }
                    save()
                }
            }
        }
    ```

  - 重构各子表单：
    - `singleSubForm` 与 `linearSubForm` 的顶部增加 `colorPickerSection(title: "主题颜色", bindingColor: $themeColor, target: .global)`。
    - `doubleSubForm` 重新排版：外圈卡片（置顶） Margin 中介，内圈卡片在后。并在两卡片中注入各自的配色网格组件：
      ```swift
      private var doubleSubForm: some View {
          VStack(alignment: .leading, spacing: 12) {
              // 外圈
              VStack(alignment: .leading, spacing: 8) {
                  Text("🟠 外圈旋钮 (粗调)")
                      .font(.system(size: 12, weight: .bold)).foregroundColor(.orange)
                  
                  colorPickerSection(title: "外圈颜色", bindingColor: $doubleOuterThemeColor, target: .doubleOuter)
                  
                  // 其余外圈滑块和 Picker 选项...
              }
              .padding(8)
              .background(Color.white.opacity(0.05))
              .cornerRadius(8)
              
              // 保护带 Margin...
              
              // 内圈
              VStack(alignment: .leading, spacing: 8) {
                  Text("🟢 内圈旋钮 (微调)")
                      .font(.system(size: 12, weight: .bold)).foregroundColor(.green)
                      
                  colorPickerSection(title: "内圈颜色", bindingColor: $doubleInnerThemeColor, target: .doubleInner)
                  
                  // 其余内圈滑块和 Picker 选项...
              }
              .padding(8)
              .background(Color.white.opacity(0.05))
              .cornerRadius(8)
          }
      }
      ```

- [ ] **步骤 2：在 `CustomKnobTests.swift` 中更新 `testNSColorPanelColorChangeUpdatesRule()` 并测试**
  
  ```swift
  func testNSColorPanelColorChangeUpdatesRule() {
      let key = RuleKey(bundleID: "test.color.app", axRole: "test.role", identifier: "test.id", displayName: "test.display")
      let target = DetectedTarget(bundleID: key.bundleID, axRole: key.axRole, identifier: key.identifier, displayName: key.displayName ?? "", element: nil)
      
      let initialRule = ControlRule(key: key, themeColor: "#000000", configType: .single, singleConfig: SingleKnobConfig(unitPerDegree: 1.0, translation: .scrollWheelVertical, clockwiseAction: "scrollUp"))
      RuleLibrary.shared.saveRule(initialRule)
      
      let view = CustomizerHUDView(target: target)
      let hostingController = NSHostingController(rootView: view)
      
      let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 520), styleMask: [.borderless], backing: .buffered, defer: false)
      window.contentView = hostingController.view
      window.orderFront(nil)
      
      let expectation = self.expectation(description: "Wait for color update and library save")
      
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          let panel = NSColorPanel.shared
          panel.color = NSColor.red
          NotificationCenter.default.post(name: NSColorPanel.colorDidChangeNotification, object: panel)
          
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
              window.orderOut(nil)
              expectation.fulfill()
          }
      }
      
      self.waitForExpectations(timeout: 1.0, handler: nil)
      
      let updatedRule = RuleLibrary.shared.lookup(for: key)
      XCTAssertEqual(updatedRule?.themeColor, "#FF0000")
  }
  ```

- [ ] **步骤 3：运行全部单元测试验证通过**
  
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS'`
  预期：PASS，全部 119 项测试无一失败。

- [ ] **步骤 4：Commit**
  
  ```bash
  git add PhantomKnob/View/CustomizerHUDView.swift PhantomKnob/PhantomKnobTests/CustomKnobTests.swift
  git commit -m "feat: implement Tab-based switcher and separate outer/inner knob configurations in HUD panel"
  ```
