# Settings Panel Design

## 背景

PhantomKnob 已有菜单栏图标，菜单中已有「设置...」入口（`StatusBarController` 中的 `openSettings`），但 `onOpenSettings` 回调未接入，且现有 `SettingsView.swift` 包含已废弃的全局灵敏度控件。本次设计重构设置面板，使其聚焦于真正需要的程序级设置项。

## 设计决策

### 结构：Tab 分页（方案 A）

使用 macOS 原生 `TabView` + `Settings` Scene，两个 Tab：

| Tab | 内容 |
|-----|------|
| 通用 ⚙️ | 热键、权限、启动选项、触控板检测 |
| 关于 ℹ️ | App 图标、版本、链接 |

**未做的事（有意推迟）：**
- 「定制 Knob」列表 Tab —— C 键流程已覆盖，列表管理是低频需求，留待用户真正需要时再加
- 全局灵敏度 —— 不同旋钮类型（单/双/线性）参数结构差异大，无法用单一滑块统一表达；数字键 2-9 已提供实时倍率覆盖

### 可扩展性原则

每个设置组用独立 Section（标头 + 圆角卡片）。新增设置项只需在已有 Section 里追加行，或新增 Section，无需改 Tab 结构。

---

## 通用 Tab 设置项

### 热键

| 字段 | 值 |
|------|-----|
| 标签 | 全局控制开关 |
| 副标签 | 激活 / 关闭旋钮控制模式 |
| 默认值 | ⌘⌥R |
| 交互 | 点击「修改...」→ 弹出录制热键小窗 → 用户按下新组合键 → 冲突检测 → 确认保存 |
| 存储 | UserDefaults，键名 `globalHotkeyKeyCode` + `globalHotkeyModifiers` |

**热键录制窗口行为：**
1. 弹出浮动小窗，显示「请按下新的快捷键组合」
2. 监听下一个含修饰键的 keyDown（至少需要一个修饰键）
3. 检测冲突（调用现有 `StatusBarController` 冲突检测逻辑）
4. 冲突时提示用户重新录制；无冲突时显示新热键预览，用户确认后保存
5. 取消返回原热键

**`StatusBarController` 改造：** 热键从硬编码 keyCode=15/⌘⌥ 改为从 UserDefaults 动态读取，支持运行时切换。

### 权限

| 状态 | 显示 |
|------|------|
| 已授权 | 绿色 pill「✓ 已授权」 |
| 未授权 | 红色 pill「✗ 未授权」+ 「打开系统设置」按钮（跳转 `x-apple.systempreferences:…Privacy_Accessibility`） |

面板 `onAppear` 时调用 `AXIsProcessTrusted()` 实时读取状态，不缓存。

### 启动

| 字段 | 值 |
|------|-----|
| 标签 | 启动时显示使用引导 |
| 控件 | Toggle |
| 存储 | `UserDefaults["skipUserGuideOnStartup"]`（已存在，取反显示） |

### 触控板

| 字段 | 值 |
|------|-----|
| 标签 | 重新检测触控板 |
| 副标签 | 更换硬件后使用 |
| 控件 | 按钮「重新检测...」 |
| 行为 | 清除 `com.phantomknob.detectionResult` 缓存 → 打开检测流程（复用现有 `UserGuideWindowController` 或独立窗口）|

---

## 关于 Tab

| 元素 | 内容 |
|------|------|
| App 图标 | 圆角方形，72×72，复用 `Assets.xcassets` 中的 AppIcon |
| App 名称 | Phantom Knob |
| 版本号 | 从 `Bundle.main` 读取 CFBundleShortVersionString + CFBundleVersion |
| 简介 | 「使用两指旋转手势，像拨动旋钮一样精确控制任意应用中的滑块和进度条」 |
| 链接 | 检查更新 / 使用引导 / 发送反馈（占位，链接地址后续补充）|

---

## 入口接入

`StatusBarController.openSettings()` 当前调用 `onOpenSettings?()` 回调但未接入。

修改方式：使用 macOS 标准 API `NSApp.sendAction(#selector(NSApplication.showSettingsWindow(_:)), to: nil, from: nil)`（macOS 13+）或 `NSApp.sendAction(Selector("showPreferencesWindow:"), to: nil, from: nil)`（兼容旧版），由 SwiftUI `Settings { SettingsView() }` Scene 自动响应。

---

## 文件变更范围

| 文件 | 变更 |
|------|------|
| `View/SettingsView.swift` | 全量重写：去掉灵敏度 Tab，保留 GeneralSettingsView + AboutView，加 Section 结构 |
| `Service/StatusBarController.swift` | 修改 `openSettings()` 使用标准 API；热键改为从 UserDefaults 动态读取 |
| `App/PhantomKnobApp.swift` | 无需修改（Settings Scene 已存在） |
| `View/HotkeyRecorderView.swift` | 新建：热键录制小窗组件 |

---

## 不在范围内

- 定制 Knob 列表页
- 全局灵敏度设置
- 多语言（当前全中文）
- iCloud 同步设置
