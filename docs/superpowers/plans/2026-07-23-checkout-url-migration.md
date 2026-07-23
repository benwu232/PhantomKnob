# 升级与购买链接重定向 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将 App 客户端内状态栏菜单的“Upgrade to Pro”和设置面板中的“Get License Key”跳转 URL 更新为 `https://benwu232.github.io/PhantomKnob/#buy`。

**架构：**
1. 修改 `StatusBarController.swift` 中的 `buyPro()` 逻辑跳转。
2. 修改 `SettingsView.swift` 中的 `Get License Key` 按钮跳转。

**技术栈：** Swift 5.0, SwiftUI, git

---

### 任务 1：更新 StatusBarController 中的购买重定向链接

**文件：**
- 修改：`PhantomKnob/Service/StatusBarController.swift`

- [ ] **步骤 1：替换 `StatusBarController.swift` 中的 `buyPro()` URL**

  找到 `StatusBarController.swift` 中的 `buyPro()` 方法（位于第 538 行左右），将跳转的硬编码 URL 由 `https://phantomknob.com#buy` 替换为 `https://benwu232.github.io/PhantomKnob/#buy`：
  ```swift
      @objc func buyPro() {
          if let url = URL(string: "https://benwu232.github.io/PhantomKnob/#buy") {
              NSWorkspace.shared.open(url)
          }
      }
  ```

- [ ] **步骤 2：编译项目验证成功**

  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
  预期：Build Succeeded

- [ ] **步骤 3：Commit**

  ```bash
  git add PhantomKnob/Service/StatusBarController.swift
  git commit -m "feat: redirect status bar purchase menu link to GitHub Pages landing page"
  ```

---

### 任务 2：更新 SettingsView 中的获取许可证重定向链接

**文件：**
- 修改：`PhantomKnob/View/SettingsView.swift`

- [ ] **步骤 1：替换 `SettingsView.swift` 中的获取授权码按钮 URL**

  找到 `SettingsView.swift` 中的 `about.btn.buy` 关联的 Button（位于第 560 行左右），将跳转 URL 由 `https://phantomknob.com#buy` 替换为 `https://benwu232.github.io/PhantomKnob/#buy`：
  ```swift
                          Button(action: {
                              if let url = URL(string: "https://benwu232.github.io/PhantomKnob/#buy") {
                                  NSWorkspace.shared.open(url)
                              }
                          }) {
                              Text(String(localized: "about.btn.buy", defaultValue: "Get License Key ➔"))
                                  ...
                          }
  ```

- [ ] **步骤 2：运行单元测试集，确保无 Regression**

  运行：`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project PhantomKnob/PhantomKnob.xcodeproj -scheme PhantomKnob -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
  预期：Test Succeeded

- [ ] **步骤 3：Commit**

  ```bash
  git add PhantomKnob/View/SettingsView.swift
  git commit -m "feat: redirect settings panel license purchase button link to GitHub Pages landing page"
  ```
