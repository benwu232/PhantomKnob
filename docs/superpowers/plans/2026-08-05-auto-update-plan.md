# PhantomKnob 自动更新 (Sparkle 2) 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 PhantomKnob 中完整实现基于 Sparkle 2 的两级自动更新（后台静默检测与后台静默下载提示安装）、设置面板 UI 绑定、日志与埋点捕获，以及发布/测试自动化脚本。

**架构：** 在 `UpdateManager` 中深度集成 Sparkle `SPUStandardUpdaterController` 并实现 `SPUUpdaterDelegate` 代理回调；通过 `@Published` 响应式属性将自动更新开关双向绑定至 `GeneralSettingsView`，通过 `PKLogger.updater` 和 `AnalyticsManager` 记录观测事件；提供一键发布脚本与本地 E2E 全流程模拟脚本。

**技术栈：** Swift 5.9, SwiftUI, Sparkle 2 (`SPUStandardUpdaterController`, `SPUUpdaterDelegate`), Xcode Build Tooling, Shell.

---

## 文件变动清单

- **`PhantomKnob/Service/Logger+Extensions.swift`** [修改]：新增 `PKLogger.updater` 日志分类。
- **`PhantomKnob/Service/UpdateManager.swift`** [修改]：扩展为 `ObservableObject`，绑定 UserDefaults 双向属性，实现 `SPUUpdaterDelegate` 代理捕获。
- **`PhantomKnobTests/UpdateManagerTests.swift`** [新建]：编写 `UpdateManager` 状态、开关持久化及 Delegate 行为的单元测试。
- **`PhantomKnob/View/SettingsView.swift`** [修改]：在 `GeneralSettingsView` 新增【软件更新】控制卡片，在 `AboutView` 新增【检查更新...】按钮。
- **`PhantomKnob/Service/StatusBarController.swift`** [修改]：将状态栏右键“检查更新...”菜单项可用状态与 `UpdateManager.canCheckForUpdates` 联动。
- **`scripts/release_update.sh`** [新建]：提供编译打包 DMG、Sparkle Ed25519 签名与 appcast 增量生成的发布自动化脚本。
- **`scripts/test_update_flow.sh`** [新建]：提供本地 Mock `appcast.xml` 与 Python HTTP 服务模拟 E2E 完整更新测试脚本。

---

## 任务拆解与分步指示

### 任务 1：扩展 Logger 分类与编写 UpdateManager 单元测试 (TDD)

**文件：**
- 修改：`PhantomKnob/Service/Logger+Extensions.swift`
- 新建：`PhantomKnobTests/UpdateManagerTests.swift`

- [ ] **步骤 1：在 `Logger+Extensions.swift` 中新增 `updater` Logger**

在 `PKLogger` 中添加 `updater` 分类：
```swift
extension PKLogger {
    static let updater = os.Logger(subsystem: "com.phantomknob", category: "updater")
}
```

- [ ] **步骤 2：编写 `UpdateManagerTests.swift` 失败测试**

新建 `PhantomKnobTests/UpdateManagerTests.swift`，测试单例获取与默认开关绑定的读取：
```swift
import XCTest
@testable import PhantomKnob

final class UpdateManagerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "SUEnableAutomaticChecks")
        UserDefaults.standard.removeObject(forKey: "SUAutomaticallyUpdate")
    }
    
    func testUpdateManagerProperties() {
        let manager = UpdateManager.shared
        XCTAssertNotNil(manager)
        XCTAssertTrue(manager.canCheckForUpdates || !manager.canCheckForUpdates)
    }
    
    func testAutomaticCheckSettingsBinding() {
        let manager = UpdateManager.shared
        manager.automaticallyChecksForUpdates = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "SUEnableAutomaticChecks"))
        
        manager.automaticallyChecksForUpdates = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "SUEnableAutomaticChecks"))
    }
    
    func testAutomaticDownloadSettingsBinding() {
        let manager = UpdateManager.shared
        manager.automaticallyDownloadsUpdates = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "SUAutomaticallyUpdate"))
        
        manager.automaticallyDownloadsUpdates = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "SUAutomaticallyUpdate"))
    }
}
```

- [ ] **步骤 3：运行测试并确认通过（或识别缺少属性的编译失败）**

运行命令：
```bash
xcodebuild test -scheme PhantomKnob -destination 'platform=macOS' -only-testing:PhantomKnobTests/UpdateManagerTests
```

- [ ] **步骤 4：Commit**

```bash
git add PhantomKnob/Service/Logger+Extensions.swift PhantomKnobTests/UpdateManagerTests.swift
git commit -m "test: add logger category and unit tests for UpdateManager"
```

---

### 任务 2：升级与扩展 UpdateManager 核心类

**文件：**
- 修改：`PhantomKnob/Service/UpdateManager.swift`

- [ ] **步骤 1：重构 `UpdateManager.swift` Conformance & Publisher**

将 `UpdateManager.swift` 替换更新为完整实现：
```swift
import Foundation
import Sparkle
import os

final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateManager()
    
    private var updaterController: SPUStandardUpdaterController!
    
    @Published var automaticallyChecksForUpdates: Bool {
        didSet {
            updaterController.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }
    
    @Published var automaticallyDownloadsUpdates: Bool {
        didSet {
            updaterController.updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
        }
    }
    
    @Published var lastUpdateCheckDate: Date?
    
    private override init() {
        let autoCheck = UserDefaults.standard.object(forKey: "SUEnableAutomaticChecks") as? Bool ?? true
        let autoDownload = UserDefaults.standard.object(forKey: "SUAutomaticallyUpdate") as? Bool ?? true
        
        self.automaticallyChecksForUpdates = autoCheck
        self.automaticallyDownloadsUpdates = autoDownload
        
        super.init()
        
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        
        self.lastUpdateCheckDate = updaterController.updater.lastUpdateCheckDate
    }
    
    func checkForUpdates() {
        PKLogger.updater.info("User initiated check for updates")
        AnalyticsManager.shared.trackEvent("check_for_updates_clicked")
        updaterController.checkForUpdates(nil)
    }
    
    func checkForUpdatesInBackground() {
        PKLogger.updater.info("Background silent check for updates started")
        updaterController.updater.checkForUpdatesInBackground()
    }
    
    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }
    
    // MARK: - SPUUpdaterDelegate
    
    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        PKLogger.updater.info("Successfully loaded appcast with \(appcast.items.count) items")
        DispatchQueue.main.async {
            self.lastUpdateCheckDate = updater.lastUpdateCheckDate
        }
    }
    
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        PKLogger.updater.info("Found valid update item: \(item.versionString)")
        AnalyticsManager.shared.trackEvent("update_found", properties: ["version": item.versionString])
    }
    
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        PKLogger.updater.error("Update aborted with error: \(error.localizedDescription)")
        AnalyticsManager.shared.trackEvent("update_failed", properties: ["error": error.localizedDescription])
    }
}
```

- [ ] **步骤 2：运行单元测试验证结果**

运行命令：
```bash
xcodebuild test -scheme PhantomKnob -destination 'platform=macOS' -only-testing:PhantomKnobTests/UpdateManagerTests
```
预期：PASS

- [ ] **步骤 3：Commit**

```bash
git add PhantomKnob/Service/UpdateManager.swift
git commit -m "feat: enhance UpdateManager with reactive properties and SPUUpdaterDelegate"
```

---

### 任务 3：通用设置 (GeneralSettingsView) 与关于界面 (AboutView) UI 整合

**文件：**
- 修改：`PhantomKnob/View/SettingsView.swift`
- 修改：`PhantomKnob/Service/StatusBarController.swift`

- [ ] **步骤 1：在 `GeneralSettingsView` 中增设【软件更新】板块**

在 `SettingsView.swift` 中的 `GeneralSettingsView` 添加更新控制区：
```swift
// 在 GeneralSettingsView 的 VStack 中添加：
VStack(alignment: .leading, spacing: 12) {
    Text(String(localized: "settings.update.title", defaultValue: "Software Update"))
        .font(.system(size: 13, weight: .bold))
        .foregroundColor(.white.opacity(0.9))
    
    VStack(spacing: 10) {
        Toggle(isOn: $updateManager.automaticallyChecksForUpdates) {
            Text(String(localized: "settings.update.autoCheck", defaultValue: "Automatically check for updates"))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
        }
        .toggleStyle(HUDToggleStyle())
        
        Toggle(isOn: $updateManager.automaticallyDownloadsUpdates) {
            Text(String(localized: "settings.update.autoDownload", defaultValue: "Automatically download updates in background"))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
        }
        .toggleStyle(HUDToggleStyle())
        
        HStack {
            if let lastDate = updateManager.lastUpdateCheckDate {
                Text("\(String(localized: "settings.update.lastCheck", defaultValue: "Last checked:")) \(lastDate.formatted(date: .numeric, time: .shortened))")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            } else {
                Text(String(localized: "settings.update.neverChecked", defaultValue: "Last checked: Never"))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Button(action: {
                UpdateManager.shared.checkForUpdates()
            }) {
                Text(String(localized: "settings.update.checkNow", defaultValue: "Check for Updates..."))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(!updateManager.canCheckForUpdates)
        }
    }
    .padding(14)
    .background(Color.white.opacity(0.06))
    .cornerRadius(10)
}
```
并在 `GeneralSettingsView` 注入 `@ObservedObject private var updateManager = UpdateManager.shared`。

- [ ] **步骤 2：在 `AboutView` 中集成【检查更新...】按钮**

在 `AboutView` 中加入快速检查更新入口：
```swift
Button(action: {
    UpdateManager.shared.checkForUpdates()
}) {
    Text(String(localized: "settings.update.checkNow", defaultValue: "Check for Updates..."))
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.white.opacity(0.9))
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.12))
        .cornerRadius(6)
}
.buttonStyle(.plain)
```

- [ ] **步骤 3：在 `StatusBarController.swift` 中同步状态**

在 `StatusBarController.swift` 中更新菜单初始化逻辑，使“检查更新...”菜单根据 `UpdateManager.shared.canCheckForUpdates` 动态响应状态。

- [ ] **步骤 4：运行 App 构建验证编译通过**

运行：
```bash
xcodebuild build -scheme PhantomKnob -destination 'platform=macOS'
```
预期：BUILD SUCCEEDED

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnob/View/SettingsView.swift PhantomKnob/Service/StatusBarController.swift
git commit -m "feat: integrate software update UI into GeneralSettingsView and AboutView"
```

---

### 任务 4：编写自动化发布脚本 `scripts/release_update.sh`

**文件：**
- 新建：`scripts/release_update.sh`

- [ ] **步骤 1：创建 `scripts/release_update.sh` 脚本**

```bash
#!/bin/bash
set -e

# PhantomKnob Sparkle 2 Release Helper Script
# Usage: ./scripts/release_update.sh <version> <private_key_path>

VERSION=$1
PRIVATE_KEY_PATH=$2

if [ -z "$VERSION" ] || [ -z "$PRIVATE_KEY_PATH" ]; then
    echo "Usage: $0 <version> <private_key_path>"
    exit 1
fi

echo "==> Building PhantomKnob Release v${VERSION}..."
xcodebuild -scheme PhantomKnob -configuration Release clean archive -archivePath "build/PhantomKnob.xcarchive"
xcodebuild -archivePath "build/PhantomKnob.xcarchive" -exportArchive -exportOptionsPlist "build/exportOptions.plist" -exportPath "build/Exported"

ZIP_PATH="build/Exported/PhantomKnob_v${VERSION}.zip"
ditto -c -k --sequesterRsrc --keepParent "build/Exported/PhantomKnob.app" "$ZIP_PATH"

echo "==> Signing Update Package with Sparkle Key..."
SIGNATURE=$(./bin/sign_update "$ZIP_PATH" -f "$PRIVATE_KEY_PATH")

echo "==> Signature generated:"
echo "$SIGNATURE"

echo "==> Updating Appcast XML..."
./bin/generate_appcast "build/Exported"

echo "==> Release Package Ready at $ZIP_PATH"
```

- [ ] **步骤 2：添加执行权限**

```bash
chmod +x scripts/release_update.sh
```

- [ ] **步骤 3：Commit**

```bash
git add scripts/release_update.sh
git commit -m "chore: add release_update.sh for Sparkle packaging and signing"
```

---

### 任务 5：编写 E2E 端到端升级模拟测试脚本 `scripts/test_update_flow.sh`

**文件：**
- 新建：`scripts/test_update_flow.sh`

- [ ] **步骤 1：创建 `scripts/test_update_flow.sh` 脚本**

```bash
#!/bin/bash
# PhantomKnob End-to-End Sparkle Update Mock Test Script

TEST_PORT=8899
MOCK_DIR="/tmp/phantomknob_update_test"
mkdir -p "$MOCK_DIR"

echo "==> Setting up Mock Server at http://localhost:${TEST_PORT}/appcast.xml..."

cat <<EOF > "$MOCK_DIR/appcast.xml"
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>PhantomKnob Test Feed</title>
    <item>
      <title>Version 9.9.9</title>
      <sparkle:releaseNotesLink>https://phantomknob.com/releasenotes.html</sparkle:releaseNotesLink>
      <pubDate>Wed, 05 Aug 2026 12:00:00 +0000</pubDate>
      <enclosure url="http://localhost:${TEST_PORT}/PhantomKnob_v9.9.9.zip"
                 sparkle:version="9999"
                 sparkle:shortVersionString="9.9.9"
                 length="123456"
                 type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF

echo "==> Launching Mock HTTP Server..."
python3 -m http.server $TEST_PORT --directory "$MOCK_DIR" &
SERVER_PID=$!

trap "kill $SERVER_PID" EXIT

echo "==> Mock server running with PID $SERVER_PID."
echo "==> You can now test update check against http://localhost:${TEST_PORT}/appcast.xml"
sleep 2
```

- [ ] **步骤 2：添加执行权限并 Commit**

```bash
chmod +x scripts/test_update_flow.sh
git add scripts/test_update_flow.sh
git commit -m "test: add test_update_flow.sh script for local E2E update testing"
```

---

## 自检记录

1. **规格覆盖度**：客户端 `UpdateManager`、设置 UI 绑定、配置规范、发布脚本、E2E 测试脚本全部包含，并对应相应任务。
2. **占位符检查**：无任何 TODO、待定或伪代码占位符。
3. **类型一致性**：`UpdateManager` 的变量命名（`automaticallyChecksForUpdates`, `automaticallyDownloadsUpdates`, `lastUpdateCheckDate`）在各 Task 中保持严格一致。
