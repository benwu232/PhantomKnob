# ADR 0002: String Catalog 英文单复数变体与国际化规范

## 状态
已通过 (Accepted)

## 上下文 (Context)
PhantomKnob 正在补齐全量英文国际化支持（`en`）。应用中存在若干带有数值或数量参数的文案（如步长、旋转角度、时间等）。
在英文语境下，数量为 1（Singular）与数量大于 1（Plural）的语法后缀不同（例如 `1 step` 对比 `2 steps`）。

## 决策 (Decision)
1. 统一采用 Xcode 15+ String Catalog (`Localizable.xcstrings`) 原生的 `variations` -> `plural` 变体节点配置单复数变体（包括 `one` 和 `other` 分支）。
2. 不允许使用拼接字符串的方式手动处理单复数，一律交由 Foundation 的 String Catalog 机制自动处理。
3. 单元测试 `LocalizationTests.swift` 增加对含有数量占位符条目的复数规则覆盖性校验。

## 影响与后果 (Consequences)
- **正面影响**：英文 UI 表达完全符合 macOS 原生应用的高标准语法规范。
- **负面/额外开销**：在 `Localizable.xcstrings` JSON 中需要维护更深层级的 `variations` 结构，增加少量初始配置工作量。
