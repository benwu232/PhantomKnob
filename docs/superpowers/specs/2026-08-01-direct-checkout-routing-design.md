# 直达 Lemon Squeezy 购买页面跳转设计规格书

## 1. 概述
在 PhantomKnob macOS 客户端及官网落地页中，用户点击“升级到 Pro 版”或“获取 Pro 授权”时，不再跳转到产品主页顶部，而是直接重定向至 Lemon Squeezy 官方 Hosted Checkout 付款页面。此设计旨在缩短购买路径、降低用户认知成本并提升 Pro 版本转化率。

---

## 2. Lemon Squeezy 结账链接规范

### 2.1 链接格式
Lemon Squeezy 提供的官方结账直链格式如下：
```text
https://[store-subdomain].lemonsqueezy.com/buy/[product-variant-id-or-slug]
```
示例占位链接：
`https://phantomknob.lemonsqueezy.com/buy/pro`（或您在 Lemon Squeezy Dashboard 复制的真实 Checkout URL）。

### 2.2 重定向（Redirect URL）配置
在 Lemon Squeezy 后台产品的 **Settings** ➔ **Confirmation Modal / Redirect URL** 中，配置付款成功后的跳转目标：
```text
https://benwu232.github.io/PhantomKnob/activate.html?key={license_key}&email={customer_email}
```
* **效果**：用户付款成功后，Lemon Squeezy 会自动带着密钥与邮箱跳转至 `activate.html`，触发 `phantomknob://activate` 协议一键唤醒 App 自动完成激活。

---

## 3. 架构与组件变更

### 3.1 客户端配置 (`LicenseWindowView.swift` & `AppConfig.swift`)
1. **收银台常量提取**：
   在 `AppSettings.swift` 或 `AppConfig` 中定义统一的 `storeCheckoutURL`：
   ```swift
   public static let storeCheckoutURL = URL(string: "https://phantomknob.lemonsqueezy.com/buy/pro")!
   ```
2. **按钮动作更新 (`LicenseWindowView.swift`)**：
   修改“🛒 立即获取 Pro 授权”按钮点击逻辑：
   ```swift
   Button(action: {
       NSWorkspace.shared.open(AppConfig.storeCheckoutURL)
   }) {
       Text("🛒 立即获取 Pro 授权")
   }
   ```

### 3.2 网页端按钮更新 (`index.html` & `index_zh.html`)
将 Pro 卡片与导航栏中的购买按钮 `href` 均指向标准的 Lemon Squeezy 直链结账地址：
```html
<a href="https://phantomknob.lemonsqueezy.com/buy/pro" class="plan-btn pro">购买许可</a>
```

---

## 4. 验证计划

### 4.1 客户端验证
1. 在 App 状态栏右键菜单中点击“🛒 升级到 Pro 版...”。
2. 点击弹窗中的“🛒 立即获取 Pro 授权”按钮。
3. 验证默认浏览器是否直接打开了 Lemon Squeezy Checkout 付款页面。

### 4.2 网页端验证
1. 在官网 `index_zh.html` 或 `index.html` 点击“购买许可”。
2. 验证浏览器是否直接跳转至 Lemon Squeezy 付款页面。
