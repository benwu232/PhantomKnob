# 2026-07-23 升级与购买链接重定向设计规格说明书

本文档描述了将 App 客户端（状态栏菜单及设置面板）中“升级到专业版”与“获取授权码”的硬编码购买 URL，从暂未生效的自定义域名 `phantomknob.com` 重新指向当前在 GitHub Pages 正常运行的分发版落地页的具体设计与技术实现方案。

## 1. 目标

* **确保付费入口可用性**：在自定义域名未完成解析部署前，临时用可用的 GitHub Pages 分发页面地址作为结账与导流的承载，保证内测和分发测试中点击升级能打开网页。
* **统一重定向逻辑**：统一替换客户端所有的跳转入口。

---

## 2. 拟议变更文件

### 2.1 [MODIFY] [StatusBarController.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/StatusBarController.swift)
将状态栏点击 `Upgrade to Pro` 触发的 `buyPro` 方法中跳转的 URL 修改为：
`https://benwu232.github.io/PhantomKnob/#buy`

### 2.2 [MODIFY] [SettingsView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/SettingsView.swift)
将设置面板 -> 许可证 Tab 中点击 `Get License Key ➔` (about.btn.buy) 触发的跳转 URL 修改为：
`https://benwu232.github.io/PhantomKnob/#buy`

---

## 3. 验证计划

### 3.1 自动化测试
* 运行已有测试集确保无 Regression。

### 3.2 手动验证流程
1. 点击状态栏菜单上的 `Upgrade to Pro`（或中文的“升级到专业版”），验证是否顺利打开默认浏览器并跳转至 `https://benwu232.github.io/PhantomKnob/#buy`。
2. 打开 Settings 面板进入 License 页面，点击 `Get License Key ➔` 按钮，验证是否顺利跳转至相同的 URL。
