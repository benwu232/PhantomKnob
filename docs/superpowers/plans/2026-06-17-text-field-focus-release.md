# 文本输入控件调节后自动释放焦点 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在用户旋转旋钮微调完毕后，自动向系统发送一次 Return (回车) 键，让被激活的文本框自动脱焦，解决后续时间轴被误拦截的问题。

**架构：** 在 `KnobStateManager` 内部加入 `didFocusCurrentTextField` 状态跟踪标记。开始调节时如果执行了模拟点击，则置为 `true`；手势结束转换为 `.cooling` 状态时如果标记为 `true`，则自动调用 `simulateReturnKey()` 模拟发送回车键码 `36`，并清空标记。

**技术栈：** Swift 5.0, CGEvent, ApplicationServices, XCTest

---

## 文件修改清单

1. **修改**：[KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/KnobStateManager.swift)
   - 新增 `didFocusCurrentTextField` 状态属性。
   - 在 transition 至 `.knobing` 且模拟点击发生时置为 `true`。
   - 在 transition 至 `.cooling` 时若标记为真则调用回车模拟方法，并清空标记。
   - 实现 `simulateReturnKey()`。
2. **修改**：[CustomKnobTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnobTests/CustomKnobTests.swift)
   - 编写 `testSimulateReturnKeyOnFocusRelease` 测试用例，验证状态机转换及状态复位逻辑。

---

## 任务分解

### 任务 1：在 `KnobStateManager` 中加入状态变量和更新逻辑

**文件：**
- 修改：[KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/KnobStateManager.swift)

- [ ] **步骤 1：添加 `didFocusCurrentTextField` 状态变量**
  在 `KnobStateManager.swift` 类的属性声明处（约第 38-42 行左右）添加以下变量：
  ```swift
  private var didFocusCurrentTextField = false
  ```

- [ ] **步骤 2：在 transition 到 `.knobing` 且触发点击时将标记置为 `true`**
  修改 `transition(to newState: KnobGlobalState)` 中处理 `.knobing` 时的点击聚焦分支：
  ```swift
              if target.axRole == "AXTextField" || target.axRole == "AXStaticText" {
                  let rule = RuleLibrary.shared.lookup(for: target.ruleKey)
                  let isStaticText = (target.axRole == "AXStaticText")
                  let hasSpecificRule = (rule != nil && rule?.key.axRole != "unknown")
                  
                  if !isStaticText || hasSpecificRule {
                      let translation = determineTranslation(for: target, rule: rule, radius: self.currentRadius)
                      if translation == .arrowKeyUpDown {
                          if let touchPos = initialTouchPosition {
                              simulateClick(at: touchPos)
                              self.didFocusCurrentTextField = true
                          }
                      }
                  }
              }
  ```

- [ ] **步骤 3：在 transition 到 `.cooling` 时重置标记**
  修改 `transition(to newState: KnobGlobalState)` 中处理非 `.knobing`（冷却）的分支：
  ```swift
          } else if case .cooling = newState {
              self.didFocusCurrentTextField = false
              ControlPanelViewModel.shared.isGestureActive = false
          }
  ```

- [ ] **步骤 4：编译检查**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
  预期：BUILD SUCCEEDED

- [ ] **步骤 5：Commit 临时更改**
  运行：
  ```bash
  git add PhantomKnob/Service/KnobStateManager.swift
  git commit -m "feat: add didFocusCurrentTextField flag to KnobStateManager"
  ```

---

### 任务 2：实现 Return 键模拟发送并在冷却时触发

**文件：**
- 修改：[KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/KnobStateManager.swift)

- [ ] **步骤 1：在 `KnobStateManager` 尾部实现 `simulateReturnKey`**
  ```swift
      private func simulateReturnKey() {
          writeDebugLog("[KnobStateManager] Simulating Return key to release text focus")
          let source = CGEventSource(stateID: .privateState)
          source?.userData = 0xDEADC0DE
          
          let returnKeyCode: CGKeyCode = 36 // Return key
          
          guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: returnKeyCode, keyDown: true),
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: returnKeyCode, keyDown: false) else {
              return
          }
          
          keyDown.post(tap: .cghidEventTap)
          keyUp.post(tap: .cghidEventTap)
      }
  ```

- [ ] **步骤 2：在 transition 到 `.cooling` 时触发模拟回车**
  修改 `transition(to newState: KnobGlobalState)` 中处理 `.cooling` 的逻辑，如果之前设置了 `didFocusCurrentTextField` 则发送回车事件：
  ```swift
          } else if case .cooling = newState {
              if self.didFocusCurrentTextField {
                  self.simulateReturnKey()
                  self.didFocusCurrentTextField = false
              }
              ControlPanelViewModel.shared.isGestureActive = false
          }
  ```

- [ ] **步骤 3：编译检查**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
  预期：BUILD SUCCEEDED

- [ ] **步骤 4：Commit 临时更改**
  运行：
  ```bash
  git add PhantomKnob/Service/KnobStateManager.swift
  git commit -m "feat: implement simulateReturnKey and trigger it in cooling transition"
  ```

---

### 任务 3：编写测试用例验证焦点释放逻辑

**文件：**
- 修改：[CustomKnobTests.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/PhantomKnobTests/CustomKnobTests.swift)

- [ ] **步骤 1：在 `KnobStateManager` 暴露出模拟回车的回调或检测标记（仅测试）**
  在 `KnobStateManager.swift` 类的属性声明处（约第 38-42 行左右）添加用于测试的标记：
  ```swift
  var didSimulateReturnForTest = false
  ```
  in `simulateReturnKey()` 方法体开头添加：
  ```swift
  didSimulateReturnForTest = true
  ```

- [ ] **步骤 2：在 `CustomKnobTests.swift` 尾部添加 `testSimulateReturnKeyOnFocusRelease` 测试用例**
  ```swift
      func testSimulateReturnKeyOnFocusRelease() {
          let textFieldKey = RuleKey(bundleID: "com.test.text", axRole: "AXTextField", displayName: "TextField")
          let keyboardRule = ControlRule(
              key: textFieldKey,
              themeColor: "#0A84FF",
              configType: .single,
              singleConfig: SingleKnobConfig(unitPerDegree: 1.0, translation: .arrowKeyUpDown, clockwiseAction: "arrowUp")
          )
          RuleLibrary.shared.saveRule(keyboardRule)
          
          let manager = KnobStateManager(
              targetDetector: TargetDetector(),
              gestureClassifier: GestureClassifier(),
              overlayController: OverlayController(),
              statusBarController: StatusBarController(),
              touchHandler: GlobalTouchHandler()
          )
          manager.currentTarget = DetectedTarget(bundleID: textFieldKey.bundleID, axRole: textFieldKey.axRole, identifier: textFieldKey.identifier, displayName: textFieldKey.displayName ?? "", element: nil, parentChain: [])
          manager.initialTouchPosition = CGPoint(x: 100, y: 100)
          
          // 初始断言
          XCTAssertFalse(manager.didSimulateReturnForTest)
          
          // Transition to knobing -> Should click and set flag
          manager.transition(to: .knobing(target: manager.currentTarget!))
          XCTAssertTrue(manager.didSimulateClickForTest)
          
          // Transition to cooling -> Should simulate return and reset flag
          manager.transition(to: .cooling(target: manager.currentTarget!))
          XCTAssertTrue(manager.didSimulateReturnForTest)
          
          RuleLibrary.shared.reload()
      }
  ```

- [ ] **步骤 3：运行完整单元测试套件**
  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
  预期：TEST SUCCEEDED，所有 131 个用例全部通过

- [ ] **步骤 4：Commit 与清理**
  运行：
  ```bash
  git add PhantomKnob/Service/KnobStateManager.swift PhantomKnob/PhantomKnobTests/CustomKnobTests.swift
  git commit -m "test: add testSimulateReturnKeyOnFocusRelease unit test"
  ```
