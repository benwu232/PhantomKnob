# Xcode 稳定代码签名与辅助功能权限保持 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 Xcode 项目中配置 Automatic Code Signing 并绑定 Development Team，使得重新编译后的应用程序依然保留已授予的 macOS 辅助功能 (Accessibility) 权限。

**架构：** 通过使用含有 Stable Team ID 的 Apple Developer Certificate（包含免费和付费账号个人 Team）对二进制文件进行签名，让 macOS TCC 根据相同的 Designated Requirement (DR) 授权，排除 Binary Hash 变更的干扰。

**技术栈：** Xcode 15+, macOS Settings TCC API

---

### 任务 1：Xcode 工程自动签名与账号绑定

**文件：**
- 修改：`PhantomKnob/PhantomKnob.xcodeproj/project.pbxproj` (由 Xcode UI 自动修改)

- [ ] **步骤 1：在 Xcode 偏好设置中登录 Apple ID**
  - 操作：打开 Xcode，导航至 `Xcode -> Settings -> Accounts`。
  - 操作：点击左下角 `+` 按钮，选择 `Apple ID`，登录您的账号（免费的个人账号即可）。

- [ ] **步骤 2：在项目配置中启用自动签名并绑定 Team**
  - 操作：在 Xcode 的左侧 Project Navigator 中点击 `PhantomKnob` 根节点进入设置。
  - 操作：选择 Targets 下的 `PhantomKnob` 主 Target。
  - 操作：切换到 `Signing & Capabilities` 标签页，确保已勾选 `Automatically manage signing`。
  - 操作：在 `Team` 下拉菜单中选择刚才登录的账号（显示为 `Your Name (Personal Team)`）。

- [ ] **步骤 3：确认 Xcode 自动生成开发签名配置**
  - 预期：Xcode 将自动联机/本地生成 `Apple Development` 签名证书及相关 Profile，无红字警告提示，状态显示为 "Signing Certificate: Apple Development..."。

---

### 任务 2：首次权限授予与联调测试

**文件：**
- 运行测试：`xcodebuild` / Xcode Build Target

- [ ] **步骤 1：首次编译运行 PhantomKnob**
  - 操作：在 Xcode 中选择 `PhantomKnob` Scheme，按下 `Cmd + R`（或在控制台运行 `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build`）以开发模式编译并启动 App。

- [ ] **步骤 2：授权辅助功能权限**
  - 预期：App 运行后会请求辅助功能控制。
  - 操作：按照系统提示打开 `系统设置 -> 隐私与安全性 -> 辅助功能`。
  - 操作：找到列表中的 `PhantomKnob` 并打开开关，输入 Mac 密码完成授权。

- [ ] **步骤 3：验证手势与设置是否正常工作**
  - 预期：在触控板上旋转手势，HUD 或滑块能够正常做出对应的线性/双旋钮交互反应。

---

### 任务 3：代码重构与权限保持验证 (持久化测试)

- [ ] **步骤 1：在 Swift 源码中进行轻微修改以促发二进制 Hash 变更**
  - 操作：在 [StatusBarController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/StatusBarController.swift) 文件开头或任意位置添加一行注释，例如：
    ```swift
    // Stable Code Signing Verification Comment
    ```

- [ ] **步骤 2：清理工程缓存并重新编译运行**
  - 操作：在 Xcode 中按 `Cmd + Shift + K` 清理工程（或在菜单栏选择 `Product -> Clean Build Folder`）。
  - 操作：按 `Cmd + R` 再次编译运行。

- [ ] **步骤 3：验证权限是否依然保留**
  - 预期：重新运行的 App 直接控制系统滑块，**不再**弹出任何“需要辅助功能权限”的警告，且在 `系统设置 -> 隐私与安全性 -> 辅助功能` 中，`PhantomKnob` 依然处于开启状态。
