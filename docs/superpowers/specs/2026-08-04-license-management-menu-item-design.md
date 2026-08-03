# 状态栏右键菜单 License 管理入口设计

## 概览
当前，当 PhantomKnob 激活为 Pro 版（状态为 `.licensed`）时，状态栏右键菜单仅显示置灰的信息项 `License: Pro`，没有任何可点击的菜单项用于打开 License 窗口。导致 Pro 用户无法在菜单中查看已绑定邮箱或进行设备解绑。

本规格说明书详细记录了状态栏右键菜单 License 入口的更新逻辑：Free 版用户显示“🛒 升级到专业版...”，Pro 版用户显示“🔑 许可管理...”。两者点击后均打开现有的 `LicenseWindowView` 窗口。

## 用户界面与交互行为
- **Free 免费版 (`.free`)**：
  - 显示菜单项 `menu.upgradeToPro`：“🛒 升级到专业版...” (英文："🛒 Upgrade to Pro...")
  - 点击动作：打开 `LicenseWindow`（显示功能特权对比与购买/激活输入框）。
- **Pro 授权激活版 (`.licensed`)**：
  - 显示菜单项 `menu.manageLicense`：“🔑 许可管理...” (英文："🔑 Manage License...")
  - 点击动作：打开 `LicenseWindow`（显示已激活状态、脱敏邮箱以及“解绑当前设备”按钮）。
- **Trial 试用期 (`.trialing(daysRemaining)`)**：
  - 剩余天数 < 3 天：显示 `menu.buyPro`：“🛒 购买 PhantomKnob Pro...” (英文："🛒 Buy PhantomKnob Pro...")
  - 剩余天数 >= 3 天：显示 `menu.upgradeToPro`：“🛒 升级到专业版...” (英文："🛒 Upgrade to Pro...")

## 系统改动内容

### 1. `PhantomKnob/Service/StatusBarController.swift`
- 更新 `setupMenu()` 方法中针对 `LicenseManager.shared.currentState` 的 `switch` 分支逻辑：
  - 在 `.licensed` 状态下，构建并添加 `manageItem` (`NSMenuItem`)，Target 为 `#selector(openLicenseWindow)`。
  - 在 `.free` 状态下，构建并添加 `buyItem` (`NSMenuItem`)，Target 为 `#selector(openLicenseWindow)`。
  - 将 `#selector(buyPro)` 别名/重构为 `#selector(openLicenseWindow)`。

### 2. `PhantomKnob/Localizable.xcstrings`
- 新增本地化字符串条目 `menu.manageLicense`：
  - 中文：`🔑 许可管理...`
  - 英文：`🔑 Manage License...`

### 3. 自动化测试 (`PhantomKnobTests/StatusBarControllerTests.swift`)
- 新增/更新单元测试，验证：
  - 当授权状态为 `.free` 时，菜单包含 `menu.upgradeToPro` 菜单项。
  - 当授权状态为 `.licensed` 时，菜单包含 `menu.manageLicense` 菜单项。

## 验证计划
1. **自动化测试**：
   - 运行 `StatusBarControllerTests.swift` 中的单元测试。
2. **手动验证**：
   - 使用 Debug 切换或状态 Mock 在 Free 与 Pro 授权状态间切换。
   - 检查状态栏右键菜单在 Free 模式下显示“升级到专业版...”，在 Pro 模式下显示“许可管理...”。
   - 在 Pro 模式下点击“许可管理...”，验证 `LicenseWindow` 正确显示已绑定邮箱及解绑按钮。
