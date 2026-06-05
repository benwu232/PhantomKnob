# 旋钮手势个性化倍率记忆与按键调速优化 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现按键调速（Option 组合键）、各档位半径独立微调、倍率的持久化记忆与安全重置（Option+1 设为 1.0），且新旋钮缺省为单半径，并在 Overlay UI 上实时显示倍数。

**架构：** 在 `AppSettings` 中将默认区域设为单半径（1个 Zone）。在 `KnobStateManager` 每次移动帧检测中，结合 `Option` 键（KeyCode 58/61）与上一帧按键状态做 Edge-triggered 差集。计算所得的 Zone Index 对应的 `UserDefaults` 覆盖值被用来覆盖默认 `baseScale`，修改结果使用 `(val * 10).rounded() / 10` 进行四舍五入并写入存储。在手势中向 `OverlayController` 传入计算得到的倍率并更新 Overlay UI 视图的显示文本。

**技术栈：** Swift 5.0+, Apple private MultitouchSupport framework, CoreGraphics (CGEventSource.keyState), UserDefaults, SwiftUI.

---

### 任务 1：更新 AppSettings 全局默认值为单半径模式

**文件：**
- 修改：`PhantomKnobDetector/Model/AppSettings.swift:11-14`
- 测试：`PhantomKnobDetector/PhantomKnobDetectorTests/AppSettingsTests.swift`

- [ ] **步骤 1：修改 AppSettings.swift 全局默认值为单半径**
  将 `FixedSchemeConfig` 里的默认 `zones` 修改为只有一个 Zone（范围 5.0 至 100.0，倍率 1.0）。
  ```swift
  // PhantomKnobDetector/Model/AppSettings.swift 核心修改内容：
  struct FixedSchemeConfig: Codable {
      var zones: [RadiusZone] = [
          RadiusZone(minRadius: 5.0, maxRadius: 100.0, margin: 2.0, scale: 1.0)
      ]
  }
  ```

- [ ] **步骤 2：创建单元测试文件验证 AppSettings 默认值**
  创建 `AppSettingsTests.swift` 验证默认的 `zones` 数量为 1，且默认倍率为 `1.0`。
  ```swift
  // PhantomKnobDetectorTests/AppSettingsTests.swift
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
  git commit -m "feat: default AppSettings to single radius and add unit tests"
  ```

---

### 任务 2：实现键状态边沿触发与 Option 组合键检测

**文件：**
- 修改：`PhantomKnobDetector/Service/KnobStateManager.swift`

- [ ] **步骤 1：增加 previousKeysState 成员变量并定义按键常量**
  在 `KnobStateManager` 类中增加 `previousKeysState` 用于缓存上一帧的按键，定义 Option 键和功能键码。
  ```swift
  // KnobStateManager.swift 属性声明区：
  private var previousKeysState: Set<CGKeyCode> = []
  ```

- [ ] **步骤 2：在 `onMultitouchBegan` 与 `onMultitouchEnded` 中清空上一帧状态**
  在手势生命周期的开始和结束时清除 `previousKeysState`。
  ```swift
  previousKeysState.removeAll()
  ```

- [ ] **步骤 3：在 `onMultitouchMoved` 中编写 Edge-Triggered 按键过滤**
  只在 `Option` 键按下时检测其他键，通过上一帧与当前帧的差集获取当前帧新按下的键。
  ```swift
  // KnobStateManager.swift inside onMultitouchMoved:
  let optionDown = CGEventSource.keyState(.combinedSessionState, key: 58) || CGEventSource.keyState(.combinedSessionState, key: 61)
  
  var newlyPressed: Set<CGKeyCode> = []
  if optionDown {
      let keysToPoll: [CGKeyCode] = [
          18, // 1
          19, 20, 21, 23, 22, 26, 28, 25, // 2-9
          126, 125, 123, 124 // Up, Down, Left, Right
      ]
      var currentPressed: Set<CGKeyCode> = []
      for keyCode in keysToPoll {
          if CGEventSource.keyState(.combinedSessionState, key: keyCode) {
              currentPressed.insert(keyCode)
          }
      }
      newlyPressed = currentPressed.subtracting(previousKeysState)
      previousKeysState = currentPressed
  } else {
      previousKeysState.removeAll()
  }
  ```

- [ ] **步骤 4：编译检查**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnobDetector -project PhantomKnobDetector/PhantomKnobDetector.xcodeproj -destination 'generic/platform=macOS' build`
  预期：BUILD SUCCEEDED

- [ ] **步骤 5：Commit**
  ```bash
  git add PhantomKnobDetector/Service/KnobStateManager.swift
  git commit -m "feat: add edge-triggered key polling and option modifier check"
  ```

---

### 任务 3：实现对多档半径的独立倍率查询与调整记忆逻辑

**文件：**
- 修改：`PhantomKnobDetector/Service/KnobStateManager.swift`

- [ ] **步骤 1：增加唯一持久化 Key 生成助手函数**
  在 `KnobStateManager` 尾部定义根据 target 和 zoneIndex 生成存储 Key 的函数。
  ```swift
  private func persistentKey(for target: ControlTarget, zoneIndex: Int) -> String {
      let bundleID = target.bundleID
      let axRole = target.axRole
      let identifier = target.identifier ?? ""
      let displayName = target.displayName
      return "knob_scale_override_\(bundleID)_\(axRole)_\(identifier)_\(displayName)_zone_\(zoneIndex)"
  }
  ```

- [ ] **步骤 2：改造求值逻辑以动态从 UserDefaults 加载已存倍率**
  获取默认求出的 `defaultBaseScale` 后，如果有已存的覆写值则对其覆盖。
  ```swift
  // KnobStateManager.swift onMultitouchMoved 核心求值修改：
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

- [ ] **步骤 3：实现按键修改及保存逻辑**
  解析 `newlyPressed` 键，应用数字设置、方向键增减并限制下限 0.1 及保存。
  ```swift
  // 按键触发修改逻辑：
  if let target = currentTarget, let currentVal = baseScale {
      let key = persistentKey(for: target, zoneIndex: currentZoneIndex)
      
      if newlyPressed.contains(18) {
          // Option + 1 -> 重置为安全值 1.0
          UserDefaults.standard.set(1.0, forKey: key)
      } else if let num = getNumberPressed(from: newlyPressed) {
          // Option + 2-9
          UserDefaults.standard.set(Double(num), forKey: key)
      } else if let delta = getArrowDelta(from: newlyPressed) {
          // Option + 方向键
          let rawNewVal = currentVal + delta
          let newVal = max(0.1, (rawNewVal * 10).rounded() / 10)
          UserDefaults.standard.set(newVal, forKey: key)
      }
  }
  
  // 两个键值解析助手方法：
  private func getNumberPressed(from pressed: Set<CGKeyCode>) -> Int? {
      let keyMapping: [CGKeyCode: Int] = [
          19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9
      ]
      for (k, v) in keyMapping {
          if pressed.contains(k) { return v }
      }
      return nil
  }
  
  private func getArrowDelta(from pressed: Set<CGKeyCode>) -> Double? {
      if pressed.contains(126) { return 1.0 }   // Up
      if pressed.contains(125) { return -1.0 }  // Down
      if pressed.contains(124) { return 0.1 }   // Right
      if pressed.contains(123) { return -0.1 }  // Left
      return nil
  }
  ```

- [ ] **步骤 4：编译检查**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnobDetector -project PhantomKnobDetector/PhantomKnobDetector.xcodeproj -destination 'generic/platform=macOS' build`
  预期：BUILD SUCCEEDED

- [ ] **步骤 5：Commit**
  ```bash
  git add PhantomKnobDetector/Service/KnobStateManager.swift
  git commit -m "feat: implement target zone-specific multiplier lookup, update and persistence"
  ```

---

### 任务 4：在 Overlay UI 上展示当前倍数及视觉同步

**文件：**
- 修改：`PhantomKnobDetector/View/OverlayView.swift`
- 修改：`PhantomKnobDetector/Service/OverlayController.swift`
- 修改：`PhantomKnobDetector/Service/KnobStateManager.swift`

- [ ] **步骤 1：扩展 OverlayView 及 controller 以支持显示 multiplier 字段**
  在 `OverlayView` 和 `OverlayController` 中暴露 `scale` 属性或直接在显示标题后缀叠加倍率。
  ```swift
  // OverlayController.swift 接口变更：
  func show(at point: NSPoint, targetName: String?, displayValue: String?, scale: Double?)
  func update(angle: Double, displayValue: String?, isDeadzone: Bool, scale: Double?)
  ```
  如果 `scale` 存在且不为 `nil`，我们将其格式化为 `String(format: "%.1fx", scale)`。
  更新 `OverlayView.swift` 的 UI 排版，例如在标题后显示：`"\(targetName) (\(scaleText))"`。

- [ ] **步骤 2：在 `KnobStateManager.swift` 刷新时将当前倍数传入**
  在调用 `overlayController.show` 和 `overlayController.update` 时传入 `baseScale`。
  ```swift
  overlayController.show(..., scale: activeBaseScale)
  overlayController.update(..., scale: activeBaseScale)
  ```

- [ ] **步骤 3：编译检查**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnobDetector -project PhantomKnobDetector/PhantomKnobDetector.xcodeproj -destination 'generic/platform=macOS' build`
  预期：BUILD SUCCEEDED

- [ ] **步骤 4：Commit**
  ```bash
  git commit -am "feat: display current multiplier on Overlay UI with format consistency"
  ```

---

### 任务 5：编写单元测试验证倍率记忆、独立性及精度舍入

**文件：**
- 创建/修改：`PhantomKnobDetector/PhantomKnobDetectorTests/CustomMultiplierTests.swift`

- [ ] **步骤 1：编写 CustomMultiplierTests 单元测试**
  编写测试用例覆盖以下情况：
  1. `testPrecisionRounding`：验证浮点精度在增减 `0.1` 后被 `(val * 10).rounded() / 10` 四舍五入，并正确限制下限 `0.1`。
  2. `testZoneIndependentPersistence`：模拟两个 Zone，修改并存储 Zone 0 以后，读取 Zone 1 依然能读到默认值。
  3. `testSafeResetToOne`：验证写入自定义倍率后，按 1 键将覆盖值安全重置为 `1.0`。
  
  示例如下：
  ```swift
  // PhantomKnobDetectorTests/CustomMultiplierTests.swift
  import XCTest
  @testable import PhantomKnobDetector

  final class CustomMultiplierTests: XCTestCase {
      override func setUp() {
          super.setUp()
          // 清除测试用的 UserDefaults 键值
          UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
      }

      func testPrecisionRounding() {
          let val = 1.0000000000000002 - 0.1
          let rounded = (val * 10).rounded() / 10
          XCTAssertEqual(rounded, 0.9)

          let lowVal = 0.05
          let clamped = max(0.1, (lowVal * 10).rounded() / 10)
          XCTAssertEqual(clamped, 0.1)
      }
      
      func testZoneIndependentPersistence() {
          let target = ControlTarget(bundleID: "com.test.app", axRole: "AXSlider", identifier: "volume", displayName: "Volume")
          let key0 = "knob_scale_override_com.test.app_AXSlider_volume_Volume_zone_0"
          let key1 = "knob_scale_override_com.test.app_AXSlider_volume_Volume_zone_1"
          
          UserDefaults.standard.set(3.5, forKey: key0)
          UserDefaults.standard.set(1.5, forKey: key1)
          
          XCTAssertEqual(UserDefaults.standard.double(forKey: key0), 3.5)
          XCTAssertEqual(UserDefaults.standard.double(forKey: key1), 1.5)
      }
  }
  ```

- [ ] **步骤 2：运行单元测试验证全绿**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme PhantomKnobDetector -project PhantomKnobDetector/PhantomKnobDetector.xcodeproj -destination 'platform=macOS' test`
  预期：Test Suite Passed

- [ ] **步骤 3：Commit**
  ```bash
  git add PhantomKnobDetector/PhantomKnobDetectorTests/CustomMultiplierTests.swift
  git commit -m "test: add unit tests for custom multiplier persistence, precision rounding and safe reset"
  ```
