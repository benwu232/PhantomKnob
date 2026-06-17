# 文本输入控件调节后自动释放焦点设计规约 (Automatic Focus Release Design Spec)

为了解决在 PhantomKnob 中调节文本输入框（如剪映或达芬奇中的数值微调输入框）后，焦点仍然停留在文本框上，导致后续在时间轴上操作时模拟的方向键事件被文本框拦截的问题，我们需要在手势结束时自动释放焦点。

---

## 解决方案：回车键提交并脱焦 (Confirm and Defocus)

### 1. 核心运行机制
1. **焦点追踪**：在 `KnobStateManager` 内部维护一个状态布尔变量 `didFocusCurrentTextField`，用来记录当前这一轮旋转微调是否触发了模拟鼠标点击聚焦。
2. **触发点击聚焦（手势开始）**：当手势开始并进入 `.knobing` 状态时，如果目标是 `AXTextField` 或拥有专属规则的 `AXStaticText`，且 `translation == .arrowKeyUpDown`，则自动执行 `simulateClick(at:)`。一旦执行成功，将 `didFocusCurrentTextField` 设置为 `true`。
3. **回车释放焦点（手势结束）**：当手势结束转换为 `.cooling`（手势结束冷却阶段）时：
   - 检查 `didFocusCurrentTextField` 是否为 `true`。
   - 如果为 `true`，则自动向系统模拟发送一个 **Return (回车)** 键（包含 `keyDown` 与 `keyUp`，键码为 `36`），从而命令文本框提交当前值并释放焦点。
   - 无论是否发送 Return 键，均在手势结束时将 `didFocusCurrentTextField` 重置为 `false`。
4. **安全沙盒原则**：如果微调没有触发点击聚焦（例如普通的 Timeline 逐帧移动），`didFocusCurrentTextField` 为 `false`，则在手势结束时**绝对不产生**任何回车事件，保证默认时间轴操作不受任何干扰。

---

## 关键模块修改计划

### 1. `KnobStateManager.swift`

#### 状态变量
* 新增 `private var didFocusCurrentTextField = false`。

#### 状态转换方法 (`transition(to:)`)
```swift
        if case .knobing(let target) = newState {
            // ...
            // 针对文本输入与静态文本输入，且只有在需要模拟键盘事件时，才自动注入一次鼠标点击以聚焦
            if target.axRole == "AXTextField" || target.axRole == "AXStaticText" {
                let rule = RuleLibrary.shared.lookup(for: target.ruleKey)
                
                let isStaticText = (target.axRole == "AXStaticText")
                let hasSpecificRule = (rule != nil && rule?.key.axRole != "unknown")
                
                if !isStaticText || hasSpecificRule {
                    let translation = determineTranslation(for: target, rule: rule, radius: self.currentRadius)
                    if translation == .arrowKeyUpDown {
                        if let touchPos = initialTouchPosition {
                            simulateClick(at: touchPos)
                            // 标记当前手势激活了文本框，用于结束时进行回车脱焦
                            didFocusCurrentTextField = true
                        }
                    }
                }
            }
        } else if case .cooling = newState {
            // 在旋转手势结束并转换为 cooling 冷却状态时，如果刚才对文本框进行了聚焦，自动模拟发送回车释放焦点
            if didFocusCurrentTextField {
                simulateReturnKey()
                didFocusCurrentTextField = false
            }
            ControlPanelViewModel.shared.isGestureActive = false
        }
```

#### 按键模拟方法 (`simulateReturnKey()`)
```swift
    private func simulateReturnKey() {
        writeDebugLog("[KnobStateManager] Simulating Return key to release text focus")
        let source = CGEventSource(stateID: .privateState)
        source?.userData = 0xDEADC0DE // 携带特殊标记防自身拦截
        
        let returnKeyCode: CGKeyCode = 36 // macOS 的 Return 键码是 36
        
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: returnKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: returnKeyCode, keyDown: false) else {
            return
        }
        
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
```

---

## 验证与测试计划

### 1. 单元测试
在 `CustomKnobTests.swift` 中新增一个测试用例，验证以下逻辑：
- `testSimulateReturnKeyOnFocusRelease`：
  - 构造一个 `AXTextField` 的 `arrowKeyUpDown` 目标，执行 transition 进入 `.knobing`，此时断言 `didFocusCurrentTextField` 应变为 `true`，且 `didSimulateClick` 被触发。
  - 执行 transition 进入 `.cooling`，断言 `didFocusCurrentTextField` 应被重置为 `false`，且能成功捕获/追踪到 Return 键的模拟发送状态。

### 2. 手动集成测试
- 在剪映中把旋钮移到某个 Inspector 的参数文本框上，进行旋转调节。
- 观察调节时 Overlay 是否正常浮现，且文本框是否有闪烁的光标被鼠标点击激活并支持数值更新。
- 手指抬起，微调结束。观察参数框的光标是否自动消失，并且输入框退出 highLight（回车确认生效）。
- 将鼠标移动回时间线上，旋转旋钮。验证此时应该只有时间线左右逐帧移动，而不再影响刚刚调节的参数输入框。
