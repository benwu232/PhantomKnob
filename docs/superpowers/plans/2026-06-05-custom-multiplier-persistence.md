# 旋钮手势个性化倍率记忆与按键调速优化 (CGEventTap) 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现 CGEventTap 全局键盘拦截（仅在 Knobing 时启用），使用户无需组合 Option 键、直接按下 `1-9` 或方向键微调速度，并且该事件 100% 被拦截吞掉，前台 App（如 QuickTime）无按键冲突。倍率按 Zone 独立保存与安全重置（按 1 设为 1.0），新旋钮缺省为单半径。

**架构：**
1. 在 `KnobStateManager` 中创建一个 `CGEventTap` 并挂载到主 RunLoop，初始为 disabled。
2. 在手势进入 `knobing` 时调用 `CGEvent.tapEnable(tap: tap, enable: true)`。
3. 手势结束（`cooling`、`activated` 或 `inactive`）时调用 `CGEvent.tapEnable(tap: tap, enable: false)`。
4. EventTap 监听到感兴趣键码（1-9、方向键）时，将 keyUp / keyDown 事件吞掉（返回 `nil`）。
5. 针对 `keyDown` 事件，在主线程触发修改，在当前 Zone 独立读写覆盖值，上限不设，下限 0.1，浮点数四舍五入。
6. 按下 `1` 时将当前 Zone 的倍率覆盖值设为 `1.0`。
7. 在手势中传入倍率并更新 Overlay UI 视图的显示文本。

---

### 任务 1：更新 AppSettings 全局默认值为单半径模式

**文件：**
- 修改：`PhantomKnobDetector/Model/AppSettings.swift:11-13`
- 测试：`PhantomKnobDetector/PhantomKnobDetectorTests/AppSettingsTests.swift`

- [ ] **步骤 1：修改 AppSettings.swift 全局默认值为单半径**
  将 `FixedSchemeConfig` 里的默认 `zones` 修改为只有一个 Zone（范围 5.0 至 100.0，倍率 1.0）。
  ```swift
  struct FixedSchemeConfig: Codable {
      var zones: [RadiusZone] = [
          RadiusZone(minRadius: 5.0, maxRadius: 100.0, margin: 2.0, scale: 1.0)
      ]
  }
  ```

- [ ] **步骤 2：创建单元测试文件验证 AppSettings 默认值**
  ```swift
  import XCTest
  @testable import PhantomKnobDetector

  final class AppSettingsTests: XCTestCase {
      func testDefaultSettingsIsSingleRadius() {
          let settings = AppSettings()
          XCTAssertEqual(settings.fixed.zones.count, 1)
          XCTAssertEqual(settings.fixed.zones[0].scale, 1.0)
          XCTAssertEqual(settings.fixed.zones[0].minRadius, 5.0)
          XCTAssertEqual(settings.fixed.zones[0].maxRadius, 100.0)
      }
  }
  ```

- [ ] **步骤 3：在本地运行测试以验证新建测试通过**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnobDetector -project PhantomKnobDetector/PhantomKnobDetector.xcodeproj -destination 'platform=macOS' test`
  预期：PASS

- [ ] **步骤 4：Commit**
  ```bash
  git add PhantomKnobDetector/Model/AppSettings.swift PhantomKnobDetector/PhantomKnobDetectorTests/AppSettingsTests.swift
  git commit -m "feat: default AppSettings to single radius (Task 1)"
  ```

---

### 任务 2：创建 CGEventTap 全局拦截键盘事件

**文件：**
- 修改：`PhantomKnobDetector/Service/KnobStateManager.swift`

- [ ] **步骤 1：在 KnobStateManager 中定义 EventTap 成员变量**
  ```swift
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var previousKeysState: Set<CGKeyCode> = [] // 保留用于其它键盘缓存逻辑
  ```

- [ ] **步骤 2：编写 setupEventTap() 函数并在 init 时调用**
  ```swift
  private func setupEventTap() {
      let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
      let selfPtr = Unmanaged.passUnretained(self).toOpaque()
      
      guard let tap = CGEvent.tapCreate(
          tap: .cgSessionEventTap,
          place: .headInsertEventTap,
          options: .defaultTap,
          eventsOfInterest: CGEventMask(eventMask),
          callback: { proxy, type, event, refcon in
              guard let refcon = refcon else { return Unmanaged.passRetained(event) }
              let manager = Unmanaged<KnobStateManager>.fromOpaque(refcon).takeUnretainedValue()
              if manager.handleEventTap(proxy: proxy, type: type, event: event) {
                  return nil // 拦截并吞掉事件
              }
              return Unmanaged.passRetained(event)
          },
          userInfo: selfPtr
      ) else {
          writeDebugLog("[KnobStateManager] Failed to create CGEventTap")
          return
      }
      
      self.eventTap = tap
      let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
      self.runLoopSource = source
      CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
      CGEvent.tapEnable(tap: tap, enable: false)
      writeDebugLog("[KnobStateManager] CGEventTap initialized (disabled)")
  }
  ```
  在 `init()` 末尾添加 `setupEventTap()`。

- [ ] **步骤 3：编写 handleEventTap 及按键响应逻辑**
  当处于 knobing 时，过滤数字 1-9 和方向键，阻断并返回 `true` 吞掉它们，在 keyDown 时分发到主线程更新倍数。
  ```swift
  func handleEventTap(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Bool {
      guard state.isKnobing else { return false }
      
      let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
      let keysOfInterest: Set<CGKeyCode> = [
          18, // 1
          19, 20, 21, 23, 22, 26, 28, 25, // 2-9
          126, 125, 123, 124 // Up, Down, Left, Right
      ]
      
      guard keysOfInterest.contains(CGKeyCode(keyCode)) else {
          return false
      }
      
      if type == .keyDown {
          DispatchQueue.main.async { [weak self] in
              self?.handleDirectKeyPress(keyCode: CGKeyCode(keyCode))
          }
      }
      
      return true // 拦截事件
  }
  ```

- [ ] **步骤 4：在 transition(to:) 中动态控制 EventTap 启闭**
  在手势升级到 `knobing` 时调用 `CGEvent.tapEnable(tap: tap, enable: true)`。
  在手势退出 `knobing` 时调用 `CGEvent.tapEnable(tap: tap, enable: false)`。

- [ ] **步骤 5：编译与测试**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnobDetector -project PhantomKnobDetector/PhantomKnobDetector.xcodeproj -destination 'platform=macOS' test`
  预期：PASS

- [ ] **步骤 6：Commit**
  ```bash
  git add PhantomKnobDetector/Service/KnobStateManager.swift
  git commit -m "feat: add CGEventTap lifecycle and interception handler (Task 2)"
  ```

---

### 任务 3：实现对各 Zone 的独立倍率查询与调整持久化逻辑

**文件：**
- 修改：`PhantomKnobDetector/Service/KnobStateManager.swift`

- [ ] **步骤 1：添加唯一存储 Key 助手函数与按键转换助手**
  ```swift
  private func persistentKey(for target: DetectedTarget, zoneIndex: Int) -> String {
      let bundleID = target.bundleID
      let axRole = target.axRole
      let identifier = target.identifier ?? ""
      let displayName = target.displayName
      return "knob_scale_override_\(bundleID)_\(axRole)_\(identifier)_\(displayName)_zone_\(zoneIndex)"
  }
  
  private func getNumberFromKeyCode(_ keyCode: CGKeyCode) -> Int? {
      let keyMapping: [CGKeyCode: Int] = [
          19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9
      ]
      return keyMapping[keyCode]
  }

  private func getDeltaFromKeyCode(_ keyCode: CGKeyCode) -> Double? {
      switch keyCode {
      case 126: return 1.0  // Up
      case 125: return -1.0 // Down
      case 124: return 0.1  // Right
      case 123: return -0.1 // Left
      default: return nil
      }
  }
  ```

- [ ] **步骤 2：在 onMultitouchMoved 中从 UserDefaults 加载已存倍率**
  ```swift
  var resolvedZoneIndex = currentZoneIndex
  let defaultBaseScale: Double?
  
  let radius = calculateRawRadius(points: scaledPoints)
  switch activeScaleConfig {
  case .fixed(let val):
      defaultBaseScale = val
      resolvedZoneIndex = 0
  case .zones(let zones):
      defaultBaseScale = ScaleResolver.resolveHysteresis(radius: radius, zones: zones, currentZoneIndex: &resolvedZoneIndex)
  case .linear(let config):
      defaultBaseScale = ScaleResolver.resolveLinear(radius: radius, config: config)
      resolvedZoneIndex = 0
  }
  
  if resolvedZoneIndex != currentZoneIndex {
      currentZoneIndex = resolvedZoneIndex
  }
  
  let baseScale: Double?
  if let defaultScale = defaultBaseScale {
      if let target = currentTarget {
          let key = persistentKey(for: target, zoneIndex: currentZoneIndex)
          if let overrideValue = UserDefaults.standard.object(forKey: key) as? Double {
              baseScale = overrideValue
          } else {
              baseScale = defaultScale
          }
      } else {
          baseScale = defaultScale
      }
  } else {
      baseScale = nil // Deadzone
  }
  ```

- [ ] **步骤 3：编写 handleDirectKeyPress 修改与实时更新逻辑**
  ```swift
  private func handleDirectKeyPress(keyCode: CGKeyCode) {
      guard let target = currentTarget, let translator = currentTranslator else { return }
      
      let key = persistentKey(for: target, zoneIndex: currentZoneIndex)
      
      // 读取当前的 Zone 倍率值（包含覆盖）
      let currentVal: Double = (UserDefaults.standard.object(forKey: key) as? Double) ?? lastResolvedBaseScale
      
      var updatedVal: Double? = nil
      if keyCode == 18 {
          updatedVal = 1.0 // Reset to 1.0
      } else if let num = getNumberFromKeyCode(keyCode) {
          updatedVal = Double(num)
      } else if let delta = getDeltaFromKeyCode(keyCode) {
          let rawNewVal = currentVal + delta
          updatedVal = max(0.1, (rawNewVal * 10).rounded() / 10)
      }
      
      if let nextVal = updatedVal {
          UserDefaults.standard.set(nextVal, forKey: key)
          self.lastResolvedBaseScale = nextVal
          
          // 立即更新 Translator 的实际比例
          let globalSens = UserDefaults.standard.object(forKey: "globalSensitivity") as? Double ?? 1.0
          let settingsSensitivity: Double
          switch target.axRole {
          case "AXSlider":
              settingsSensitivity = UserDefaults.standard.object(forKey: "sliderSensitivity") as? Double ?? globalSens
          case "AXProgressIndicator":
              settingsSensitivity = UserDefaults.standard.object(forKey: "progressSensitivity") as? Double ?? globalSens
          default:
              settingsSensitivity = globalSens
          }
          translator.scale = nextVal * settingsSensitivity
          
          // 立即刷新 Overlay UI 视图的显示
          overlayController.update(angle: self.currentAngle, displayValue: translator.displayValue, isDeadzone: false, scale: nextVal)
          
          writeDebugLog("[KnobStateManager] handleDirectKeyPress: updated multiplier to \(nextVal) for target: \(target.displayName)")
      }
  }
  ```

- [ ] **步骤 4：编译与测试**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnobDetector -project PhantomKnobDetector/PhantomKnobDetector.xcodeproj -destination 'platform=macOS' test`
  预期：PASS

- [ ] **步骤 5：Commit**
  ```bash
  git add PhantomKnobDetector/Service/KnobStateManager.swift
  git commit -m "feat: implement persistentKey override resolution and direct key update handlers (Task 3)"
  ```

---

### 任务 4：在 Overlay UI 上展示当前倍数及精度规范

**文件：**
- 修改：`PhantomKnobDetector/View/OverlayView.swift`
- 修改：`PhantomKnobDetector/Service/OverlayController.swift`
- 修改：`PhantomKnobDetector/Service/KnobStateManager.swift`

- [ ] **步骤 1：修改 OverlayView 以支持 scale 后缀展示**
  ```swift
  struct OverlayView: View {
      let targetName: String?
      let angle: Double
      let displayValue: String?
      var isDeadzone: Bool = false
      var scale: Double? = nil
      
      var body: some View {
          VStack(spacing: 8) {
              if let targetName = targetName, !targetName.isEmpty {
                  let suffix = scale.map { String(format: " (%.1fx)", $0) } ?? ""
                  Text(targetName + suffix)
                      .font(.system(size: 12, weight: .medium))
                      .foregroundColor(isDeadzone ? .gray : .white)
              }
  ```

- [ ] **步骤 2：更改 OverlayController 接收 scale 参数**
  ```swift
  func show(at position: CGPoint, targetName: String?, displayValue: String?, scale: Double? = nil)
  func update(angle: Double, displayValue: String?, isDeadzone: Bool = false, scale: Double? = nil)
  ```

- [ ] **步骤 3：在 KnobStateManager 中刷新时传入 scale**
  在 `onMultitouchMoved` 触发的 `show` 与 `update` 中传入当前的 `activeBaseScale` 或 `lastResolvedBaseScale`。

- [ ] **步骤 4：编译与测试**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnobDetector -project PhantomKnobDetector/PhantomKnobDetector.xcodeproj -destination 'platform=macOS' test`
  预期：PASS

- [ ] **步骤 5：Commit**
  ```bash
  git commit -am "feat: display current multiplier on Overlay UI and specify formatting (Task 4)"
  ```

---

### 任务 5：编写单元测试验证倍率记忆、独立性及精度舍入

**文件：**
- 创建/修改：`PhantomKnobDetector/PhantomKnobDetectorTests/CustomMultiplierTests.swift`

- [ ] **步骤 1：编写 CustomMultiplierTests 单元测试**
  验证精度控制、Zone 独立持久化及重置为 `1.0`。

- [ ] **步骤 2：运行单元测试验证全红变全绿**
  运行测试确保全部 85 个测试通过。

- [ ] **步骤 3：Commit**
  ```bash
  git add PhantomKnobDetector/PhantomKnobDetectorTests/CustomMultiplierTests.swift
  git commit -m "test: add unit tests for custom multiplier persistence, rounding, and safe reset (Task 5)"
  ```
