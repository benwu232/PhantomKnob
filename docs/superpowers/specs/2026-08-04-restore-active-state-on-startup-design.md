# 设计规格：应用启动时恢复旋钮激活状态

**日期**：2026-08-04  
**状态**：已批准  
**主题**：持久化 PhantomKnob 激活状态并在应用启动时自动恢复。

---

## 1. 概述与目标

目前，PhantomKnob 在应用启动时总是初始化为未激活状态（`.inactive`）。对于习惯长期保持旋钮激活的用户，每次重新启动应用或系统后都必须手动按快捷键或点击菜单栏项进行激活。

本特性的目标是在应用启动时自动恢复 PhantomKnob 上次退出时的激活状态（`.activated`），并结合设置开关供用户自定义，提供无缝的后台工具使用体验，同时避免非预期的手势拦截。

---

## 2. 需求与行为

1. **持久化设置开关**：
   - 在 `设置 -> 通用` 中提供配置项：**“启动时恢复激活状态”**（`restoreActiveStateOnStartup`）。
   - 默认值：`true`。
2. **状态记忆**：
   - 当全局状态显式切换为 `.activated` 或 `.inactive` 时，将状态记录到 `UserDefaults.app` 中的 `lastKnobActiveState: Bool`。
   - 临时状态（例如 Option 按住产生的临时激活）**绝不能**覆盖 `lastKnobActiveState`。
3. **启动恢复**：
   - 在 `KnobStateManager.start()` 执行期间，完成基础 UI 初始化后：
     - 检查 `restoreActiveStateOnStartup` 是否为 `true`。
     - 检查 `lastKnobActiveState` 是否为 `true`。
     - 检查 macOS 辅助功能授权状态（`isProcessTrusted()`）。
     - 若满足以上所有条件，自动切换至 `.activated` 状态（并正常启动多点触控捕获与限时计时）。
4. **安全与兜底**：
   - 若启动时未获得 macOS 辅助功能授权（`AXIsProcessTrusted` 为 `false`），自动恢复将中断并安全保持为 `.inactive` 状态。
   - 若处于免费版/试用版限制模式，自动激活时正常触发试用 Session 限时计时。
5. **多语言支持**：
   - 在 `Localizable.xcstrings` 中补充中英文及相关语言文案。

---

## 3. 详细组件变动

### 3.1 `UserDefaults+App.swift` / `AppSettings`
- 添加便捷存取 Key / 属性：
  - `restoreActiveStateOnStartup` (默认值: `true`)
  - `lastKnobActiveState` (默认值: `false`)

### 3.2 `KnobStateManager.swift`
- 在 `transition(to newState: KnobGlobalState)` 中：
  - 当 `newState == .activated` 且非 Option 按住临时状态时，写入 `UserDefaults.app.set(true, forKey: "lastKnobActiveState")`。
  - 当 `newState == .inactive` 且非 Option 按住临时状态时，写入 `UserDefaults.app.set(false, forKey: "lastKnobActiveState")`。
- 在 `start()` 中：
  - 执行条件判断并按需触发自动激活：
    ```swift
    let shouldRestore = UserDefaults.app.object(forKey: "restoreActiveStateOnStartup") as? Bool ?? true
    let wasActive = UserDefaults.app.bool(forKey: "lastKnobActiveState")
    if shouldRestore && wasActive && isProcessTrusted() {
        toggleMode()
    }
    ```

### 3.3 `SettingsView.swift` (`GeneralSettingsView`)
- 在通用设置卡片中新增 Toggle 开关：
  - 标题：`"settings.general.restoreActiveState"`（"启动时恢复激活状态" / "Restore activation state on startup"）
  - 绑定：`@AppStorage("restoreActiveStateOnStartup", store: .app) var restoreActiveStateOnStartup = true`

### 3.4 `Localizable.xcstrings`
- 新增多语言本地化键值对：
  - `settings.general.restoreActiveState`

---

## 4. 验证与测试计划

### 自动化单元测试
- 在 `KnobStateManagerTests` (或新建测试文件) 中编写测试：
  1. 测试状态持久化：验证显式切换到 `.activated` 与 `.inactive` 时 `lastKnobActiveState` 是否正确写入。
  2. 测试启动恢复逻辑：Mock `UserDefaults` 与 `isProcessTrusted()`，验证当条件满足时能够成功自动激活，当权限缺失或开关关闭时安全保持 `.inactive`。

### 手动验证
- 打开应用，切换至激活状态，退出应用。
- 重新打开应用，验证 PhantomKnob 自动处于激活状态。
- 在设置中关闭“启动时恢复激活状态”开关，重复上述步骤，验证应用启动后保持为未激活状态。
