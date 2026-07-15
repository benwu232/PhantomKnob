# 切换默认全局热键为 Command + Option + Q 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将 PhantomKnob 的默认激活快捷键从 `⌘⌥R` 改为 `⌘⌥Q`，以减少按键冲突。

**架构：** 
- 修改 `HotkeySettings.swift` 中的默认键码值。
- 在 `PhantomKnobTests` 中增加相应的单元测试来验证默认键码。
- 更新 `UserGuideView.swift` 默认属性中的文案和 `Localizable.xcstrings` 中的中文字符串。
- 替换 `CONTEXT.md` 中所有老快捷键的文本。

**技术栈：** Swift, SwiftUI, XCTest, macOS Localization

---

### 任务 1：添加单元测试并验证失败

**文件：**
- 修改：`PhantomKnob/PhantomKnobTests/HotkeySettingsTests.swift`

- [ ] **步骤 1：修改单元测试文件**

在 `PhantomKnob/PhantomKnobTests/HotkeySettingsTests.swift` 中编写测试以验证新的默认键码（12）和修饰键（Command + Option）：

```swift
import XCTest
@testable import PhantomKnob

final class HotkeySettingsTests: XCTestCase {
    func testDefaultHotkeyValues() {
        // 'Q' 键的 keyCode 是 12
        XCTAssertEqual(HotkeySettings.defaultKeyCode, 12)
        XCTAssertEqual(HotkeySettings.defaultModifiers, [.command, .option])
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：`xcodebuild -project PhantomKnob.xcodeproj -scheme PhantomKnobTests -sdk macosx -destination 'platform=macOS' test -only-testing PhantomKnobTests/HotkeySettingsTests`
预期：测试失败（或者是编译错误，因为目前 `defaultKeyCode` 还是 31）。

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnob/PhantomKnobTests/HotkeySettingsTests.swift
git commit -m "test: add HotkeySettings default values test (expect fail)"
```

---

### 任务 2：修改默认快捷键使其通过测试

**文件：**
- 修改：`PhantomKnob/Model/HotkeySettings.swift`

- [ ] **步骤 1：修改默认键码定义**

在 `PhantomKnob/Model/HotkeySettings.swift` 中，将 `defaultKeyCode` 的值从 `31` 改为 `12`。

```swift
<<<<
    // Default value: ⌘⌥O (keyCode=31, command|option)
    static let defaultKeyCode: UInt16 = 31
====
    // Default value: ⌘⌥Q (keyCode=12, command|option)
    static let defaultKeyCode: UInt16 = 12
>>>>
```

- [ ] **步骤 2：运行测试验证通过**

运行：`xcodebuild -project PhantomKnob.xcodeproj -scheme PhantomKnobTests -sdk macosx -destination 'platform=macOS' test -only-testing PhantomKnobTests/HotkeySettingsTests`
预期：编译通过，测试通过。

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnob/Model/HotkeySettings.swift
git commit -m "feat: change default hotkey to Command + Option + Q"
```

---

### 任务 3：更新用户引导界面及本地化字符串

**文件：**
- 修改：`PhantomKnob/View/UserGuideView.swift`
- 修改：`PhantomKnob/Localizable.xcstrings`

- [ ] **步骤 1：修改 UserGuideView.swift 默认文案**

在 `PhantomKnob/View/UserGuideView.swift` 中，将 fallback 默认文本更新为 `⌘ ⌥ Q (Command + Option + Q)`。

```swift
<<<<
                        Text(String(localized: "guide.step3.feature1.title", defaultValue: "Global Toggle Shortcut: ⌘ ⌥ O (Command + Option + O)"))
====
                        Text(String(localized: "guide.step3.feature1.title", defaultValue: "Global Toggle Shortcut: ⌘ ⌥ Q (Command + Option + Q)"))
>>>>
```

- [ ] **步骤 2：修改 Localizable.xcstrings 本地化值**

在 `PhantomKnob/Localizable.xcstrings` 中，更新 `"guide.step3.feature1.title"` 的 `zh-Hans` 翻译值。

```json
<<<<
            "value" : "全局激活热键：⌘ ⌥ O (Command + Option + O)。可在设置中修改。"
====
            "value" : "全局激活热键：⌘ ⌥ Q (Command + Option + Q)。可在设置中修改。"
>>>>
```

- [ ] **步骤 3：完整测试构建**

运行：`xcodebuild -project PhantomKnob.xcodeproj -scheme PhantomKnobTests -sdk macosx -destination 'platform=macOS' test`
预期：所有测试通过。

- [ ] **步骤 4：Commit**

```bash
git add PhantomKnob/View/UserGuideView.swift PhantomKnob/Localizable.xcstrings
git commit -m "ui: update user guide text and localizations for ⌘⌥Q shortcut"
```

---

### 任务 4：更新说明文档

**文件：**
- 修改：`CONTEXT.md`

- [ ] **步骤 1：修改 CONTEXT.md 引用**

在 `CONTEXT.md` 中，将所有 `⌘⌥O` 和 `Command + Option + O` 替换为 `⌘⌥Q` 和 `Command + Option + Q`。

```markdown
<<<<
**Activation:** Hotkey (`⌘⌥O` by default, customizable in settings)
====
**Activation:** Hotkey (`⌘⌥Q` by default, customizable in settings)
>>>>
```

```markdown
<<<<
### Default
`⌘⌥O` (Command + Option + O)
====
### Default
`⌘⌥Q` (Command + Option + Q)
>>>>
```

- [ ] **步骤 2：Commit**

```bash
git add CONTEXT.md
git commit -m "docs: update CONTEXT.md for default shortcut change"
```
