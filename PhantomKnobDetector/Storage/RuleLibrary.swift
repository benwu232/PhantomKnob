// PhantomKnobDetector/Storage/RuleLibrary.swift
import Foundation

/// 规则库：查找 ControlRule 的单一入口。
/// 优先级：用户规则（Application Support）> 内置规则（App Bundle）
/// 匹配策略：按精度从高到低，第一条命中即返回。
final class RuleLibrary {
    static let shared = RuleLibrary()

    private var rules: [ControlRule] = []

    private let userRulesURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("PhantomKnob", isDirectory: true)
            .appendingPathComponent("rules.json")
    }()

    init() {
        reload()
    }

    /// 重新从磁盘加载规则（bundled + user）。
    func reload() {
        var loaded: [ControlRule] = []

        // 1. 用户规则（高优先级）
        if let userRules = loadRules(from: userRulesURL) {
            loaded.append(contentsOf: userRules)
        }

        // 2. 内置规则（随 App 分发）
        if let bundledURL = Bundle.main.url(forResource: "bundled-rules", withExtension: "json"),
           let bundledRules = loadRules(from: bundledURL) {
            loaded.append(contentsOf: bundledRules)
        }

        self.rules = loaded
    }

    /// 按优先级顺序查找匹配 ruleKey 的第一条规则。
    /// 精度：(bundleID + axRole + identifier) > (bundleID + axRole) > (axRole only)
    func lookup(for ruleKey: RuleKey) -> ControlRule? {
        // 精确匹配（identifier 完全相同）
        if let exact = rules.first(where: {
            $0.key.bundleID == ruleKey.bundleID &&
            $0.key.axRole == ruleKey.axRole &&
            $0.key.identifier != nil &&
            $0.key.identifier == ruleKey.identifier
        }) { return exact }

        // 宽泛匹配（同 app 同 role，identifier 为 nil 的规则）
        if let broad = rules.first(where: {
            $0.key.bundleID == ruleKey.bundleID &&
            $0.key.axRole == ruleKey.axRole &&
            $0.key.identifier == nil
        }) { return broad }

        // 跨 app 匹配（只匹配 role）
        if let byRole = rules.first(where: {
            $0.key.bundleID.isEmpty &&
            $0.key.axRole == ruleKey.axRole
        }) { return byRole }

        return nil
    }

    private func loadRules(from url: URL) -> [ControlRule]? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode([ControlRule].self, from: data)
    }
}

// 追加到 RuleLibrary（仅测试用）
#if DEBUG
extension RuleLibrary {
    func injectRulesForTesting(_ rules: [ControlRule]) {
        self.rules = rules
    }
}
#endif
