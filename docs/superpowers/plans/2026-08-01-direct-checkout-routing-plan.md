# 直达 Lemon Squeezy 结账页跳转 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将客户端与网页端的所有购买链接更新为直达 Lemon Squeezy 结账直链 `https://benwu232.lemonsqueezy.com/checkout/buy/745d4e0d-3c01-4264-bbe2-46ed187ddf10`，实现从 App 与官网直接拉起收银台。

**架构：** 在 `AppSettings.swift` 中定义统一的 `storeCheckoutURL` 常量，更新 App 客户端 `LicenseWindowView` 按钮跳转行为，并同步更新官网 `index.html` 与 `index_zh.html` 中的购买链接。

**技术栈：** Swift (AppKit / SwiftUI), HTML (官网)

---

### 任务 1：提取与配置 App 端的直联结账 URL

**文件：**
- 修改：`PhantomKnob/Model/AppSettings.swift`
- 修改：`PhantomKnob/View/LicenseWindowView.swift`
- 测试：`PhantomKnobTests/LicenseManagerTests.swift`

- [ ] **步骤 1：在 AppSettings.swift 中定义 storeCheckoutURL**

在 `PhantomKnob/Model/AppSettings.swift` 中添加静态常量：
```swift
public static let storeCheckoutURL = URL(string: "https://benwu232.lemonsqueezy.com/checkout/buy/745d4e0d-3c01-4264-bbe2-46ed187ddf10")!
```

- [ ] **步骤 2：更新 LicenseWindowView.swift 中的购买按钮跳转逻辑**

修改 `PhantomKnob/View/LicenseWindowView.swift` 中的按钮 Action：
```swift
Button(action: {
    NSWorkspace.shared.open(AppSettings.storeCheckoutURL)
}) {
    Text("🛒 立即获取 Pro 授权")
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(.black)
        .padding(.horizontal, 28)
        .padding(.vertical, 8)
        .background(Color.orange)
        .cornerRadius(8)
}
.buttonStyle(.plain)
```

- [ ] **步骤 3：编写/扩展单元测试验证 URL 结构**

在 `PhantomKnobTests/LicenseManagerTests.swift` 中添加针对 `storeCheckoutURL` 的单元测试：
```swift
func testStoreCheckoutURLIsValid() {
    let url = AppSettings.storeCheckoutURL
    XCTAssertEqual(url.host, "benwu232.lemonsqueezy.com")
    XCTAssertTrue(url.path.contains("checkout/buy/745d4e0d-3c01-4264-bbe2-46ed187ddf10"))
}
```

- [ ] **步骤 4：运行测试与 Swift 编译验证**

运行命令：
```bash
swift build
```
预期：Build complete! 0 errors.

- [ ] **步骤 5：Commit**

```bash
git add PhantomKnob/Model/AppSettings.swift PhantomKnob/View/LicenseWindowView.swift PhantomKnobTests/LicenseManagerTests.swift
git commit -m "feat: configure direct Lemon Squeezy checkout URL in App"
```

---

### 任务 2：更新网页端 (PhantomKnob 仓库) 的直联购买链接

**文件：**
- 修改：`/Users/wb/work/PhantomKnob/index_zh.html`
- 修改：`/Users/wb/work/PhantomKnob/index.html`

- [ ] **步骤 1：修改 index_zh.html 的结账台链接**

在 `/Users/wb/work/PhantomKnob/index_zh.html` 中找到 Pro 卡片的购买按钮：
```html
<a href="https://benwu232.lemonsqueezy.com/checkout/buy/745d4e0d-3c01-4264-bbe2-46ed187ddf10" class="plan-btn pro">购买许可</a>
```

- [ ] **步骤 2：修改 index.html 的结账台链接**

在 `/Users/wb/work/PhantomKnob/index.html` 中找到 Pro 卡片的购买按钮：
```html
<a href="https://benwu232.lemonsqueezy.com/checkout/buy/745d4e0d-3c01-4264-bbe2-46ed187ddf10" class="plan-btn pro">Purchase License</a>
```

- [ ] **步骤 3：在分发仓库中 Commit 并 Push**

```bash
cd /Users/wb/work/PhantomKnob
git add index.html index_zh.html
git commit -m "feat: update purchase buttons to direct Lemon Squeezy checkout URL"
git push origin main
```
