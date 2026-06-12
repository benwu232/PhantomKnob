// PhantomKnob/Storage/RuleLibrary.swift
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
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        if let bundledURL = bundle.url(forResource: "bundled-rules", withExtension: "json"),
           let bundledRules = loadRules(from: bundledURL) {
            loaded.append(contentsOf: bundledRules)
        }

        self.rules = loaded
    }

    /// 按优先级顺序查找匹配 ruleKey 的第一条规则。
    /// 精度：(bundleID + axRole + identifier) > (bundleID + axRole + displayName) > (bundleID + axRole) > (axRole only)
    func lookup(for ruleKey: RuleKey) -> ControlRule? {
        // 1. 精确 ID 匹配
        if let exact = rules.first(where: {
            $0.key.bundleID == ruleKey.bundleID &&
            $0.key.axRole == ruleKey.axRole &&
            $0.key.identifier != nil &&
            $0.key.identifier == ruleKey.identifier
        }) { return exact }

        // 2. DisplayName 匹配
        if let byDisplayName = rules.first(where: {
            $0.key.bundleID == ruleKey.bundleID &&
            $0.key.axRole == ruleKey.axRole &&
            $0.key.displayName != nil &&
            ruleKey.displayName != nil &&
            $0.key.displayName == ruleKey.displayName
        }) { return byDisplayName }

        // 3. 宽泛匹配（同 app 同 role，identifier/displayName 均为 nil）
        if let broad = rules.first(where: {
            $0.key.bundleID == ruleKey.bundleID &&
            $0.key.axRole == ruleKey.axRole &&
            $0.key.identifier == nil &&
            $0.key.displayName == nil
        }) { return broad }

        // 4. 跨 app 匹配（只匹配 role）
        if let byRole = rules.first(where: {
            $0.key.bundleID.isEmpty &&
            $0.key.axRole == ruleKey.axRole
        }) { return byRole }

        return nil
    }

    func saveRule(_ rule: ControlRule) {
        var loadedUserRules: [ControlRule] = []
        
        // 1. 先尝试读取本地 rules.json
        if FileManager.default.fileExists(atPath: userRulesURL.path) {
            if let data = try? Data(contentsOf: userRulesURL),
               let existing = try? JSONDecoder().decode([ControlRule].self, from: data) {
                loadedUserRules = existing
            }
        } else {
            // 确保目录存在
            let dir = userRulesURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        // 2. 合并或追加：如果在 userRules 里有相同 key 的规则，进行替换，否则追加
        if let index = loadedUserRules.firstIndex(where: { $0.key.matches(rule.key) }) {
            loadedUserRules[index] = rule
        } else {
            loadedUserRules.insert(rule, at: 0) // 高优先级追加
        }
        
        // 3. 序列化写回本地
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(loadedUserRules) {
            try? data.write(to: userRulesURL)
        }
        
        // 4. 重载内存规则并通知状态机更新
        self.reload()
        
        NotificationCenter.default.post(
            name: NSNotification.Name("ControlRuleDidUpdate"),
            object: nil,
            userInfo: ["rule": rule]
        )
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
