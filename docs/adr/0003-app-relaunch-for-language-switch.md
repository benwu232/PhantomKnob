# ADR 0003: 应用语言切换统一重启机制

## 状态
已通过 (Accepted)

## 上下文 (Context)
PhantomKnob 支持在应用内部手动选择应用语言（系统默认、English、简体中文）。在 macOS 应用开发中，改变语言有两种技术路径：
1. 修改系统级别 `AppleLanguages` 首选项并重启 App（标准 macOS 做法）。
2. 在运行时用 Swizzling 或自定义 `Bundle` 子类替换 `Bundle.main` 从而拦截 `NSLocalizedString` 实现免重启动态刷新。

第二种做法会引入代码复杂性、内存泄漏隐患以及与 AppKit 菜单、系统通知、SwiftUI 内部缓存不兼容的问题。

## 决策 (Decision)
1. 坚决采用 **标准重启机制**：当用户在设置面板更改语言后，触发平滑重启（`relaunchApp()`）使 `AppleLanguages` 生效。
2. 避免引入任何 Bundle Swizzling 或自定义全局 Bundle 代理，代码库中所有 `Text` 和 `String(localized:)` 统一使用 macOS 原生 Bundle 加载。

## 影响与后果 (Consequences)
- **正面影响**：架构极度干净简练，100% 贴合 macOS 原生 AppKit/SwiftUI 行为，杜绝运行时资源加载紊乱与内存异常。
- **负面影响**：用户切换语言需要经历一次极速的应用重启过程。
