# PhantomKnob Free/Premium 体系重命名为 Free/Pro 设计规格说明书

本文档规定了将 PhantomKnob 现有的 "Free/Premium" 命名体系全面重构为 "Free/Pro"（即专业版）的设计细节与执行计划。

---

## 1. 目的与背景

PhantomKnob 作为面向专业人士（如视频剪辑师、设计师、音乐人）的精密手势控制工具，采用 "Professional" / "Pro" 比 "Premium" 更能凸显其生产力工具的定位，且 "Pro" 相比 "Premium" 更加简洁，有利于在 macOS 紧凑的 UI 空间（如状态栏菜单和 Popover 窗口）中展现。

根据用户确认，此次修改：
1. **不考虑向后兼容**：旧版存储的 Key 和类名也将一并彻底重构。
2. **端到端同步**：重构范围同时覆盖 Swift 客户端代码、本地化配置、持久化存储 Key 以及 `website/` 目录下的网页和样式。

---

## 2. 界面与术语规范 (User-Facing Terminology)

*   **英文长格式**：`Professional Edition`（主要用于购买协议、产品介绍等正式文档）。
*   **英文短格式**：`Pro`（如 `Pro Edition`、`Get Pro`、`Upgrade to Pro`、`Activate Pro`，主要用于菜单、界面按钮及状态栏）。
*   **中文格式**：`专业版`（保持原样，与英文 "Pro" 对应）。
*   **代码及变量名**：统一使用 `pro` / `Pro`（如 `isProActive`、`buyPro`）。

---

## 3. 重构详述 (Refactoring Details)

### 3.1 客户端 Swift 代码重命名

所有变量、类名、枚举成员以及调试标识中包含 "Premium" 且表示“高级/专业版”的词汇，统一重命名为 "Pro" 或 "pro"：

| 源命名 | 目标重命名 | 说明 |
| :--- | :--- | :--- |
| `isPremiumActive` | `isProActive` | `FeatureGate`, `LicenseState`, `LicenseManager` 中判断专业版是否激活的属性 |
| `buyPremium` | `buyPro` | 状态栏控制器和视图中的购买/激活动作方法 |
| `PremiumFeature` | `ProFeature` | 表示受限功能的枚举或结构体（若有） |
| `licenseReceipt` | `licenseReceiptPro` 或 `licenseReceipt` | 持久化 Key（详见 3.2 存储 Key 部分） |
| `about.license.premium` | `about.license.pro` | 本地化字符串 Key |
| `menu.license.premium` | `menu.license.pro` | 本地化字符串 Key |

### 3.2 存储与持久化 Key 重命名 (Storage Keys)

为保持整洁性且无需考虑旧版本向后兼容，所有在 `UserDefaults` 和 `KeychainHelper` 中使用的持久化 Key 字符串也进行相应重命名：

*   `licenseReceipt` ➡️ `licenseReceipt` (保持，或重命名为 `licenseReceipt`)
    > [!NOTE]
    > 虽然不需要向后兼容，但为了清晰，我们统一将存储名更新：
    *   `licenseReceipt` ➡️ `licenseReceipt` (为了代码纯洁度，不含 Premium 即可，本身就是 Receipt，所以可以保持不变，或改为 `proLicenseReceipt`)
    *   `licenseKey` ➡️ `proLicenseKey` (或 `licenseKey` - 本身不包含 Premium，可保持)
    *   `licenseEmail` ➡️ `proLicenseEmail` (或 `licenseEmail` - 本身不包含 Premium，可保持)
*   为了彻底清除 Premium 痕迹，确保没有遗留 `Premium` 相关的持久化 Key 字符串。

### 3.3 本地化文件修改 (`PhantomKnob/Localizable.xcstrings`)

*   修改 JSON 中的 Key：将 `menu.license.premium` 重命名为 `menu.license.pro`。
*   更新对应的英文默认值：
    *   `License: Premium` ➡️ `License: Pro`
*   更新其他相关本地化 Key：
    *   `about.license.premium` ➡️ `about.license.pro` (默认值：`✨ Pro Edition Active`)
    *   `about.btn.activate` 默认值：`Activate Pro`
    *   `popover.upgrade` 默认值：`Get Pro for Unlimited Time ➔`
    *   状态栏菜单动态项：
        *   `Buy PhantomKnob Premium...` ➡️ `Buy PhantomKnob Pro...`
        *   `Upgrade to Premium...` ➡️ `Upgrade to Pro...`
    *   调试项：
        *   `Toggle Free/Premium (Debug)` ➡️ `Toggle Free/Pro (Debug)`

### 3.4 网站及本地网页同步 (`website/`)

*   **`website/index.html`** & **`website/style.css`**:
    *   `.pricing-card.premium` ➡️ `.pricing-card.pro`
    *   页面内所有 "Premium" 文本更新为 "Pro" 或 "Professional"。
*   **`website/terms.html`**:
    *   更新 "Pro License" 及 "premium features" 的描述，统一定义为 "Pro features" 或 "Professional features"。
*   **`website/icon_compare.html`**:
    *   `Premium (Pro) 炫彩` ➡️ `Pro 炫彩`
    *   `Premium App Icon` ➡️ `Pro App Icon`
    *   `.sb-circle-premium` ➡️ `.sb-circle-pro`

### 3.5 现有设计文档同步 (Existing Spec Files)

在文档中同步将 "Premium" 替换为 "Pro" 或 "Professional"：
*   `docs/superpowers/specs/2026-07-21-distribution-and-release-design.md`
*   `docs/superpowers/specs/2026-07-21-lemonsqueezy-license-verification-design.md`
*   `docs/superpowers/specs/2026-07-17-free-edition-hud-reminders-design.md`
*   `docs/superpowers/specs/2026-07-07-icon-and-logo-design.md`

---

## 4. 验证计划 (Verification Plan)

### 4.1 自动化测试
*   运行 `PhantomKnobTests`，确保所有因重构影响的编译错误全部修复。
*   检查测试中的 Mock 或断言，确保测试依然能 100% 通过。

### 4.2 手动功能验证
*   **正常启动**：确认应用处于 Free 试用状态时，能够成功触发弹窗并显示 "Get Pro for Unlimited Time"。
*   **调试切换**：在 Debug 模式下通过状态栏 `Toggle Free/Pro (Debug)` 切换状态，验证菜单栏显示的 License 状态由 "License: Free" 变为 "License: Pro"。
*   **购买跳转**：点击状态栏 "Buy PhantomKnob Pro..." 或 "Upgrade to Pro..."，确认能正常跳转到购买/激活页面。
*   **网站检查**：打开 `website/index.html` 和 `website/icon_compare.html`，确认所有卡片、按钮 and 标题中不再包含 "Premium"，其样式也未因重命名类名而遭到破坏。
