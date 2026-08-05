# PhantomKnob 自动更新与 Sparkle 2 架构设计规范

**文档时间**：2026-08-05  
**目标**：为 PhantomKnob 建立基于 Sparkle 2 的完整自动更新架构、客户端 UI 整合、数据埋点监控与自动化发布流程。

---

## 1. 概述与设计目标

PhantomKnob 目前已引入 Sparkle 2 依赖并在 `Info.plist` 中配置了 `SUFeedURL` (`https://phantomknob.com/appcast.xml`) 与 `SUPublicEDKey`。本设计旨在完成：
1. **客户端解耦与 UI 整合**：扩展 `UpdateManager` 为符合响应式特性的单例，并在通用设置 (`GeneralSettingsView`) 与关于界面 (`AboutView`) 提供直观控制开关。
2. **两级自动更新机制**：支持静默自动检查 (`SUEnableAutomaticChecks`) 以及后台静默下载提示安装 (`SUAutomaticallyUpdate`)。
3. **安全与发布流水线**：规范基于 Ed25519 的签名与 `appcast.xml` 增量构建流程。
4. **可观测性与测试策略**：集成日志记录、Sentry 告警与 TDD 单元测试。

---

## 2. 客户端架构设计

### 2.1 UpdateManager 服务扩展 (`PhantomKnob/Service/UpdateManager.swift`)

`UpdateManager` 继承 `ObservableObject`，封装 Sparkle 的 `SPUStandardUpdaterController` 并实现 `SPUUpdaterDelegate` 接口：

* **核心单例与响应式属性**：
  * `@Published var automaticallyChecksForUpdates: Bool`：读写 Sparkle UserDefaults `SUEnableAutomaticChecks`。
  * `@Published var automaticallyDownloadsUpdates: Bool`：读写 Sparkle UserDefaults `SUAutomaticallyUpdate`。
  * `@Published var lastUpdateCheckDate: Date?`：持久化与显示上一次检查时间。
  * `var canCheckForUpdates: Bool`：只读计算属性，标识当前是否允许发起新轮检查。
* **对外暴露方法**：
  * `func checkForUpdates()`：用户手动触发（弹出标准更新界面）。
  * `func checkForUpdatesInBackground()`：应用启动时发起的静默后台检查。
* **Sparkle 代理方法 (`SPUUpdaterDelegate`)**：
  * `updater(_:didFinishLoadingAppcast:)`：解析远端 appcast 成功日志。
  * `updater(_:didFindValidUpdate:)`：发现新版本，记录 `AnalyticsManager` 埋点。
  * `updater(_:didAbortWithError:)`：检查或下载失败时记录 `PKLogger.updater` 与 `SentryManager` 警告。

### 2.2 设置界面与状态栏菜单绑定

#### 通用设置 (`PhantomKnob/View/SettingsView.swift` -> `GeneralSettingsView`)
在通用设置中新增【软件更新】卡片：
* **开关 1**：`Toggle("自动检查更新", isOn: $updateManager.automaticallyChecksForUpdates)`
* **开关 2**：`Toggle("后台自动下载更新", isOn: $updateManager.automaticallyDownloadsUpdates)`
* **说明文本**：展示“上次检查：YYYY-MM-DD HH:mm”
* **操作按钮**：`Button("检查更新...") { UpdateManager.shared.checkForUpdates() }`（在 `canCheckForUpdates == false` 时自动置灰）。

#### 关于界面与右键菜单
* `AboutView`：版本号下方添加辅助“检查更新”按钮。
* `StatusBarController`：状态栏右键菜单项目保持调用 `UpdateManager.shared.checkForUpdates()`。

---

## 3. Info.plist 与配置标准

在 `PhantomKnob/Info.plist` 与 `project.yml` 中维持如下配置标准：
```xml
<key>SUFeedURL</key>
<string>https://raw.githubusercontent.com/benwu232/PhantomKnob/main/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>5CmEsYugmzzvzy/eL9awVk3/bqjCwAap9i0K3ao/3sM=</string>
<key>SUEnableAutomaticChecks</key>
<true/>
<key>SUAutomaticallyUpdate</key>
<true/>
```

---

## 4. 发布流程与签名自动化

### 4.1 密钥保护规则
* **公钥**：开源存于 `Info.plist` 中用于校验。
* **私钥**：存储于发布者的 macOS Keychain 或 GitHub Secrets (`SPARKLE_PRIVATE_KEY`)，绝对禁止提交至 Git 仓库。

### 4.2 一键发布脚本 (`scripts/release_update.sh`)
自动化脚本包含以下步骤：
1. `xcodebuild` 导出 Release 版本的 `PhantomKnob.app`，并打包为 `PhantomKnob_vX.X.X.dmg` (或 `.zip`)。
2. 使用 Sparkle `sign_update` 传入私钥计算 `edSignature` 与文件字节长度。
3. 调用 `generate_appcast` 生成或合并最新的 `appcast.xml` 条目。
4. 将 DMG 发布至 GitHub Releases / CDN 托管，同步将 `appcast.xml` 推送至 `phantomknob.com`。

---

## 5. 可观测性与异常处理

1. **日志记录**：`Logger+Extensions.swift` 中增加 `PKLogger.updater` 分类，统一跟踪 Sparkle 生命周期。
2. **事件埋点**：
   * `check_for_updates_clicked`（手动点击）
   * `update_found`（包含目标版本号 `version`）
   * `update_failed`（包含错误类型与描述）

---

### 6.2 单元与委托代理测试 (`PhantomKnobTests/UpdateManagerTests.swift`)
遵循项目 TDD 策略：
* 测试 `UpdateManager.shared` 单例正确响应 Sparkle 状态。
* 测试 `automaticallyChecksForUpdates` 与 `automaticallyDownloadsUpdates` 的 UserDefaults 持久化绑定。
* Mock 模拟 `SPUUpdaterDelegate` 代理回调，验证在接收到 `didDownloadUpdate` 与 `didAbortWithError` 时的埋点与日志行为。

### 6.3 完整 E2E 自动升级全流程自动化验证脚本 (`scripts/test_update_flow.sh`)
为验证“检查 -> 后台静默下载 -> 校验签名 -> 解压安装 -> 替换重启”的全链路，提供专门的 E2E 测试验证方案：
1. **准备测试目标**：自动化脚本编译一个高版本号的 Dummy App（例如 `v9.9.9`），并生成对应的测试用 Ed25519 签名与 `test_appcast.xml`。
2. **本地服务托管**：通过后台 Python 启动 `http://localhost:8080/test_appcast.xml`。
3. **注入与触发**：运行带有测试 `SUFeedURL` 参数的本地应用实例，触发后台自动下载。
4. **校验结果**：断言测试安装包是否成功解压至 Sparkle 的安装缓存区，并验证应用接收到 `SPUUpdater` 的重启就绪通知。

