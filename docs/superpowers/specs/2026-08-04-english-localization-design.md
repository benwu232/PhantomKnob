# PhantomKnob 全量英文国际化与验证设计规范

## 目标与概述

PhantomKnob 目前已具备 `AppLanguageManager` 与 `Localizable.xcstrings` 基础框架，但 214+ 条 String Catalog 条目中绝大部分缺少英文（`en`）翻译，且部分 UI / Service 中存在硬编码中文文本。

本设计旨在补齐完整的英文国际化支持，建立多语言自动校验单元测试，确保应用在英文（`en`）和简体中文（`zh-Hans`）环境下的文字质量、界面一致性及动态切换稳定性。

---

## 1. String Catalog 与文案提炼设计

### 1.1 字符串目录规范 (`Localizable.xcstrings`)
- **主语言（Source Language）**：保持 `"en"`。
- **全量翻译覆盖**：
  - 对现有 214+ 条 Key 补齐 `en` 的 `stringUnit`（状态标为 `translated`）。
  - 对于带参数的动态格式化字符串（例如 `版本 %@ (%@)`、`已完成: %d° / 360°`），保证英文翻译使用正确的占位符引用（`Version %1$@ (%2$@)`、`Completed: %1$d° / 360°`）。
- **硬编码中文扫描与剥离**：
  - 扫描 `PhantomKnob/View/`、`PhantomKnob/Service/`、`PhantomKnob/ViewModel/` 等目录中残留的硬编码中文字符串。
  - 为硬编码字符串分配标准 Key（如 `menu.license.manage`、`status.pro_activated`）并存入 Catalog。
- **单复数规则（Pluralization）**：
  - 针对带有数量参数的英文文案，严格使用 String Catalog 原生的 `variations` -> `plural` 变体节点（包含 `one` 与 `other` 分支），确保如 `1 step` 与 `2 steps` 的规范呈现。
- **冗余/废弃字符串清理（Unused String Cleanup）**：
  1. **清理 `stale` 自动条目**：直接移除被编译器标记为 `"extractionState": "stale"` 的无用 Key。
  2. **扫描未引用的 `manual` Key**：编写自动扫描工具检测 `.swift` 代码库中的 Key 引用，将未在任何 View / Service 中被引用的废弃 Key 从 `Localizable.xcstrings` 中清理，保持 Catalog 精简干净。

### 1.2 文案提炼与风格
- **通用/设置**：符合 macOS 标准 UI 术语习惯（`Preferences...`、`General`、`Launch at Login`）。
- **引导与教程**：精准易懂的动作指导（`Rotate knob to test`、`Hold C key while turning`）。
- **HUD/状态提示**：简洁高效（`Pro License Activated`、`Customizer Panel`）。

---

## 2. UI 与服务层集成设计

### 2.1 SwiftUI 视图层
- 使用 SwiftUI 原生 `Text("key")` 或 `LocalizedStringKey`。
- 支持环境刷新与设置页（`SettingsView`）语言切换联动。

### 2.2 AppKit 与服务层
- `StatusBarController` 菜单项使用 `String(localized: "key")` 动态生成。
- `LicenseManager`、`KnobStateManager` 的 HUD 提示及日志/通知统一采用 `String(localized: "key")`。

### 2.3 语言切换与重启流程
- 严格维持 `AppLanguageManager` 的标准 macOS App 重启机制（`AppleLanguages` + `relaunchApp()`）。
- 不引入自定义 Bundle 拦截与 Swizzling，所有视图与后台 Service 统一依托原生 `Bundle.main` 与系统 `NSBundle` 生命周期，确保内存与资源加载绝对稳定。

---

## 3. 测试与验证机制设计 (TDD)

### 3.1 单元测试 (`LocalizationTests.swift`)
- **Catalog 完整性校验**：解析 `Localizable.xcstrings` JSON，自动遍历检查：
  - 每一个 Key 均拥有 `en` 语言下的 `translated` 状态。
  - 每一个 Key 均拥有 `zh-Hans` 语言下的 `translated` 状态。
- **占位符匹配校验**：校验中英文翻译中的占位符类型与数量匹配。
- **Language Manager 逻辑测试**：验证语言首选项读写与 `AppleLanguages` 覆盖逻辑。

### 3.2 运行与体验验证
- 命令行运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme PhantomKnob -destination "platform=macOS" CODE_SIGN_IDENTITY="-"`
- 手动核验英文和中文环境下的状态栏菜单、设置页、HUD 弹框与使用引导。

---

## 4. 规格自检清单

- [x] 占位符扫描：包含完整明确的需求与格式说明，无 TODO / 待定。
- [x] 内部一致性：符合现有 `AppLanguageManager` 逻辑与项目目录结构。
- [x] 范围检查：集中于英文国际化全量补齐与测试校验。
- [x] 模糊性检查：明确占位符规则、文案提炼规范与验证命令。
