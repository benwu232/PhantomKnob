# 首次启动跳过版本更新日志/欢迎弹窗设计规范

## 1. 业务目标
为了提供清爽的首次安装与运行体验，避免用户在首次打开 App 时连续受到“新手引导/手势练习 (User Guide)”与“版本欢迎弹窗/更新日志 (Release Notes)”两个独立窗口的连续打扰，我们对 Release Notes 的弹出行为做如下优化：
1. **首次安装/运行不弹窗**：在用户首次运行程序（`lastSeenReleaseNotesVersion` 在 `UserDefaults` 中尚未被记录）时，跳过自动弹窗，并在后台直接记录当前 App 版本为“已读”。
2. **升级时弹出，且默认已读**：在未来 App 升级（如从 `1.0` 升级到 `1.1`）时，自动弹出更新日志窗口。在用户点击关闭（Got it）时，系统自动将当前版本记录为已读，且无需勾选“Don't show this version again”选项，避免重复弹出。
3. **UI 界面精简**：移除 `ReleaseNotesView` 底部多余的 `Don't show this version again` 选项框，使界面更加简洁高档。

---

## 2. 详细设计 (Detailed Design)

### 2.1 ReleaseNotesController 逻辑重构
修改 `ReleaseNotesController.swift` 中的 `showIfNeeded()` 方法：
- 首先检查 `lastSeenReleaseNotesVersion` 是否为 `nil`。如果为 `nil`，说明这是首次运行该功能（或全新安装），我们直接将当前版本写入 `UserDefaults` 并提前返回，不显示弹窗。
- 如果不为 `nil` 且当前版本与记录的最新版本不一致，则获取当前版本的更新日志并显示。
- 修改 `show(version:title:items:)` 里的闭包回调，当弹窗消失时，无条件在 `UserDefaults` 中将当前版本标记为已读。

### 2.2 ReleaseNotesView 界面调整
在 `ReleaseNotesView.swift` 中：
- 移除底部 footer 中的 `Toggle` 复选框（即 `"Don't show this version again"`）。
- 移除 `@State private var dontShowAgain = false` 变量。
- 点击 `"Got it"` 按钮时触发的 `onDismiss` 闭包变更为不带参数的闭包 `() -> Void`。

---

## 3. 代码修改参考

### 3.1 `ReleaseNotesController.swift` 修改
```swift
    func showIfNeeded() {
        // 1. Skip if user guide onboarding isn't completed
        let guideCompleted = UserDefaults.app.bool(forKey: "firstRunUserGuideCompleted")
        guard guideCompleted else { return }
        
        // 2. Check version changes
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        
        // If lastSeenVersion is nil, user is running the app/feature for the first time.
        // We register the current version as read and skip showing.
        guard let lastSeenVersion = UserDefaults.app.string(forKey: "lastSeenReleaseNotesVersion") else {
            UserDefaults.app.set(currentVersion, forKey: "lastSeenReleaseNotesVersion")
            return
        }
        
        guard currentVersion != lastSeenVersion else { return }
        
        // 3. Load release notes content
        guard let notes = loadReleaseNotes(for: currentVersion) else { return }
        
        // 4. Show window
        show(version: currentVersion, title: notes.title, items: notes.items)
    }
```

### 3.2 `ReleaseNotesView.swift` 修改
```swift
struct ReleaseNotesView: View {
    let version: String
    let title: String
    let items: [String]
    
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // ... Header and ScrollView ...
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Footer
            HStack {
                Spacer()
                
                Button(action: {
                    onDismiss()
                }) {
                    Text(String(localized: "release.button.gotIt", defaultValue: "Got it"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 520, height: 380)
        .background(Color.clear)
    }
}
```

---

## 4. 验证计划

### 4.1 单元测试验证
- 检查 `ReleaseNotesTests.swift` 编译并能正常运行。
- 添加/更新针对 `ReleaseNotesController` 在首次运行与后续升级时行为的测试用例。

### 4.2 手动联调测试
1. **全新安装/首次启动测试**：清除 App 缓存/本地 `UserDefaults`，重启 App。确认仅弹出新手引导界面，延迟 1 秒后**不会**弹出 `Welcome to PhantomKnob!` 的更新日志窗口。
2. **版本升级测试**：
   - 手动将 `UserDefaults.app` 中 `lastSeenReleaseNotesVersion` 修改为 `"0.9"`（或更低的版本号），重启 App。
   - 验证延迟 1 秒后是否会正常弹出版本更新日志窗口。
   - 点击 `"Got it"` 按钮，验证窗口是否正常消失，且在 `UserDefaults.app` 中已正确写入当前版本号（如 `"1.0"`）。
   - 再次重启 App，确认不会再弹出更新日志。
