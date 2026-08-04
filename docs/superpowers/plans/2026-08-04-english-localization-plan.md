# 全量英文国际化与自动化验证实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 为 PhantomKnob 补齐全量英文（`en`）翻译、清理冗余字符串、补充 Plural 单复数规则，并建立自动化单元测试 `LocalizationTests.swift` 保证多语言质量与语法正确性。

**架构：** 基于 TDD 策略先在 `PhantomKnobTests` 中建立 `Localizable.xcstrings` 完整性与占位符匹配测试；扫描并抽离 UI / Service 中硬编码的中文；补齐 214+ 条 Key 的 `en` 翻译与 Plural 变体；最终跑通命令行单元测试全量验证。

**技术栈：** macOS (13.0+), Swift 5.9, Xcode String Catalog (`.xcstrings`), XCTest, `AppLanguageManager`.

---

### 任务 1：创建 `LocalizationTests.swift` 自动化校验单元测试 (TDD Red)

**文件：**
- 创建：`PhantomKnob/PhantomKnobTests/LocalizationTests.swift`
- 修改：`PhantomKnob/project.yml`（添加新测试文件依赖配置（如适用）或由 XcodeGen / xcodebuild 自动感知）

- [ ] **步骤 1：编写失败的 `LocalizationTests.swift` 测试**

```swift
import XCTest
@testable import PhantomKnob

final class LocalizationTests: XCTestCase {
    private var catalogJSON: [String: Any] = [:]
    private var stringEntries: [String: [String: Any]] = [:]

    override func setUpWithError() throws {
        try super.setUpWithError()
        
        let bundle = Bundle(for: LocalizationTests.self)
        guard let url = bundle.url(forResource: "Localizable", withExtension: "xcstrings") ??
                        Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings") else {
            // 回退直接读取源码路径
            let sourcePath = #file
            let projectDir = URL(fileURLWithPath: sourcePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let xcstringsURL = projectDir.appendingPathComponent("Localizable.xcstrings")
            let data = try Data(contentsOf: xcstringsURL)
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            self.catalogJSON = json
            self.stringEntries = json["strings"] as? [String: [String: Any]] ?? [:]
            return
        }
        
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        self.catalogJSON = json
        self.stringEntries = json["strings"] as? [String: [String: Any]] ?? [:]
    }

    func testSourceLanguageIsEnglish() {
        let sourceLang = catalogJSON["sourceLanguage"] as? String
        XCTAssertEqual(sourceLang, "en", "Source language in Localizable.xcstrings must be 'en'")
    }

    func testAllKeysHaveTranslatedEnglishAndChinese() {
        var missingENKeys: [String] = []
        var missingZHKeys: [String] = []

        for (key, dict) in stringEntries {
            let state = dict["extractionState"] as? String
            if state == "stale" { continue }

            let localizations = dict["localizations"] as? [String: [String: Any]] ?? [:]
            
            // 检查 zh-Hans 条目
            let zhState = localizations["zh-Hans"]?["stringUnit"]?["state"] as? String
            if zhState != "translated" {
                missingZHKeys.append(key)
            }

            // 检查 en 条目
            let enUnit = localizations["en"]?["stringUnit"]
            let enVariations = localizations["en"]?["variations"]
            let enState = enUnit?["state"] as? String
            
            let hasValidEN = (enState == "translated") || (enVariations != "nil" && enVariations != nil)
            if !hasValidEN {
                missingENKeys.append(key)
            }
        }

        XCTAssertTrue(missingZHKeys.isEmpty, "Missing translated zh-Hans keys: \(missingZHKeys)")
        XCTAssertTrue(missingENKeys.isEmpty, "Missing translated en keys: \(missingENKeys)")
    }

    func testFormatSpecifiersMatchBetweenLanguages() {
        let pattern = rePattern()
        for (key, dict) in stringEntries {
            let localizations = dict["localizations"] as? [String: [String: Any]] ?? [:]
            guard let zhValue = localizations["zh-Hans"]?["stringUnit"]?["value"] as? String,
                  let enValue = localizations["en"]?["stringUnit"]?["value"] as? String else {
                continue
            }

            let zhSpecs = extractSpecifiers(from: zhValue, pattern: pattern)
            let enSpecs = extractSpecifiers(from: enValue, pattern: pattern)
            XCTAssertEqual(zhSpecs.count, enSpecs.count, "Specifier count mismatch for key '\(key)': zh=\(zhSpecs), en=\(enSpecs)")
        }
    }

    private func extractSpecifiers(from string: String, pattern: NSRegularExpression) -> [String] {
        let range = NSRange(string.startIndex..., in: string)
        let matches = pattern.matches(in: string, range: range)
        return matches.compactMap { match in
            guard let r = Range(match.range, in: string) else { return nil }
            return String(string[r])
        }
    }

    private func rePattern() -> NSRegularExpression {
        return try! NSRegularExpression(pattern: "%([0-9]+\\$)?(\\.[0-9]+)?[@dffs]", options: [])
    }
}
```

- [ ] **步骤 2：运行单元测试确认失败（Red）**

运行：
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme PhantomKnob -destination "platform=macOS" CODE_SIGN_IDENTITY="-" -only-testing:PhantomKnobTests/LocalizationTests
```
预期：FAIL，提示 `Missing translated en keys` 且包含 200+ 条未翻译 key。

- [ ] **步骤 3：Commit 测试**

```bash
git add PhantomKnob/PhantomKnobTests/LocalizationTests.swift
git commit -m "test: add LocalizationTests to verify string catalog completeness and format specifiers"
```

---

### 任务 2：扫描清理 `stale` 条目并提取 UI/Service 硬编码中文

**文件：**
- 修改：`PhantomKnob/Localizable.xcstrings`
- 修改：`PhantomKnob/Service/AppLanguageManager.swift`
- 修改：`PhantomKnob/Service/StatusBarController.swift`

- [ ] **步骤 1：扫描并清除 `stale` 条目及未引用的死 Key**

在 `PhantomKnob/` 目录下遍历 `Localizable.xcstrings`，移除 `extractionState: "stale"` 节点。

- [ ] **步骤 2：扫描并替换硬编码中文为标准 String Catalog Key**

对 `StatusBarController.swift` 和 `AppLanguageManager.swift` 中硬编码的中文字符串使用 `String(localized: "key")` 进行替代，并在 `Localizable.xcstrings` 中增加相应的 Key 定义。

- [ ] **步骤 3：Commit 变更**

```bash
git add PhantomKnob/Localizable.xcstrings PhantomKnob/Service/
git commit -m "refactor: cleanup stale localization keys and extract hardcoded strings"
```

---

### 任务 3：全量补齐 `Localizable.xcstrings` 英文翻译与 Plural 变体

**文件：**
- 修改：`PhantomKnob/Localizable.xcstrings`

- [ ] **步骤 1：补齐所有 214+ 条 Key 的 Native 英文翻译 (`state: "translated"`)**

对 `Localizable.xcstrings` 中每个 Key 的 `localizations.en` 补齐准确的英文翻译，例如：
- `"about.description"` -> `"PhantomKnob uses innovative technology and patented algorithms to bring knob gestures to your trackpad..."`
- `"guide.nav.close"` -> `"Close Guide"`
- `"about.version"` -> `"Version %1$@ (%2$@)"`

- [ ] **步骤 2：为数量/步长参数文案添加 `variations.plural`（遵守 ADR-0002）**

为数量格式化 Key（如 `%@ mm`、包含 step/degree 的描述）添加 String Catalog `plural` 变体节点（包含 `one` 与 `other`）。

- [ ] **步骤 3：运行单元测试验证通过（Green）**

运行：
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme PhantomKnob -destination "platform=macOS" CODE_SIGN_IDENTITY="-" -only-testing:PhantomKnobTests/LocalizationTests
```
预期：PASS（0 failures）。

- [ ] **步骤 4：Commit 变更**

```bash
git add PhantomKnob/Localizable.xcstrings
git commit -m "feat: complete all English localizations and plural variations in Localizable.xcstrings"
```

---

### 任务 4：全量回归测试与集成验证

**文件：**
- 无新文件变动，运行整体测试套件

- [ ] **步骤 1：运行完整单元测试集**

运行：
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme PhantomKnob -destination "platform=macOS" CODE_SIGN_IDENTITY="-"
```
预期：除了已知外部手势超时测试外的所有单元测试与 `LocalizationTests` 全数 PASS。

- [ ] **步骤 2：Commit 计划成果标记**

```bash
git commit --allow-empty -m "chore: complete English localization and verification suite"
```
