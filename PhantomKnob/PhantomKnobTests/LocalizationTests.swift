import XCTest
@testable import PhantomKnob

final class LocalizationTests: XCTestCase {
    private var catalogJSON: [String: Any] = [:]
    private var stringEntries: [String: [String: Any]] = [:]

    override func setUpWithError() throws {
        try super.setUpWithError()
        
        let bundle = Bundle(for: LocalizationTests.self)
        var url = bundle.url(forResource: "Localizable", withExtension: "xcstrings") ??
                  Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings")
                  
        if url == nil {
            let sourcePath = #file
            let projectDir = URL(fileURLWithPath: sourcePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let xcstringsURL = projectDir.appendingPathComponent("Localizable.xcstrings")
            if FileManager.default.fileExists(atPath: xcstringsURL.path) {
                url = xcstringsURL
            }
        }
        
        guard let validURL = url else {
            XCTFail("Failed to locate Localizable.xcstrings")
            return
        }
        
        let data = try Data(contentsOf: validURL)
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
            let zhDict = localizations["zh-Hans"]
            let zhUnit = zhDict?["stringUnit"] as? [String: Any]
            let zhState = zhUnit?["state"] as? String
            if zhState != "translated" {
                missingZHKeys.append(key)
            }

            // 检查 en 条目
            let enDict = localizations["en"]
            let enUnit = enDict?["stringUnit"] as? [String: Any]
            let enVariations = enDict?["variations"]
            let enState = enUnit?["state"] as? String
            
            let hasValidEN = (enState == "translated") || (enVariations != nil)
            if !hasValidEN {
                missingENKeys.append(key)
            }
        }

        XCTAssertTrue(missingZHKeys.isEmpty, "Missing translated zh-Hans keys: \(missingZHKeys)")
        XCTAssertTrue(missingENKeys.isEmpty, "Missing translated en keys (\(missingENKeys.count) total): \(missingENKeys)")
    }

    func testFormatSpecifiersMatchBetweenLanguages() {
        let pattern = rePattern()
        for (key, dict) in stringEntries {
            let localizations = dict["localizations"] as? [String: [String: Any]] ?? [:]
            let zhUnit = localizations["zh-Hans"]?["stringUnit"] as? [String: Any]
            let enUnit = localizations["en"]?["stringUnit"] as? [String: Any]
            
            guard let zhValue = zhUnit?["value"] as? String,
                  let enValue = enUnit?["value"] as? String else {
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
