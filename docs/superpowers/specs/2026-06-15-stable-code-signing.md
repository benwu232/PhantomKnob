# Xcode 稳定代码签名与辅助功能权限保持设计规约

为了解决在 macOS 开发过程中，每次重新编译 `PhantomKnob` 导致辅助功能 (Accessibility) 权限丢失的问题，我们需要为项目配置稳定的代码签名。

## 解决方案：Xcode 自动签名与团队绑定

### 运行机制
1. **现状**：当前项目使用 Ad-hoc (本地运行签名)，不绑定任何 Developer Team。每次编译，macOS 都会使用新的 Binary Hash 标识 App，因而将其视作新软件，重置辅助功能授权。
2. **解决方案**：在 Xcode 中为 `PhantomKnob` Target 绑定一个 Apple 账号的 Development Team。
3. **效果**：绑定 Team 后，Xcode 会使用开发者账号签发一个唯一的、稳定的 `Apple Development` 证书进行签名。macOS TCC (辅助功能数据库) 会通过 Designated Requirement (DR) 识别 App 的证书发布机构及 Team ID，即便重新编译二进制哈希改变，辅助功能权限依然终身有效。

---

## Xcode 配置步骤

我们在 Xcode 中按照以下步骤进行配置：

1. **登录 Apple ID**：
   - 打开 Xcode 偏好设置 (`Xcode -> Settings -> Accounts`)。
   - 点击左下角的 `+` 号，选择 `Apple ID`，登录您的免费或付费 Apple 账号。
2. **绑定 Team 证书**：
   - 在 Xcode 项目导航栏中点击 `PhantomKnob` 根节点进入工程设置。
   - 选择 `PhantomKnob` Target，进入 `Signing & Capabilities` 标签页。
   - 勾选 `Automatically manage signing`。
   - 在 `Team` 下拉菜单中选择刚才登录的账号（通常显示为 `Your Name (Personal Team)`）。
3. **重新编译与单次授权**：
   - 编译运行项目。
   - 系统将弹出提示，引导您在 `系统设置 -> 隐私与安全性 -> 辅助功能` 中为 `PhantomKnob` 进行授权。
   - 此后，即便再次修改代码并重新编译，该权限也会永久保留，不再弹窗。

---

## 验证计划

1. **首次授权验证**：
   - 在 Xcode 中配置 Team 后，Build & Run 运行项目。
   - 手动在 macOS 系统设置中授予辅助功能权限。
2. **重构/重编译验证**：
   - 随意修改一行 Swift 代码（例如添加注释），在 Xcode 中 `Product -> Clean Build Folder`，然后再次编译运行。
   - 检查 App 是否依然能直接控制系统上的滑块而不再被撤销辅助功能权限。
