import AppKit
import os

public class AppLanguageManager {
    public static let shared = AppLanguageManager()
    
    private let languageKey = "appLanguage"
    
    public enum Language: String, CaseIterable, Identifiable {
        case system = "system"
        case english = "en"
        case chinese = "zh-Hans"
        
        public var id: String { self.rawValue }
        
        public var displayName: String {
            switch self {
            case .system:
                return String(localized: "language.system", defaultValue: "System Default")
            case .english:
                return "English"
            case .chinese:
                return "简体中文"
            }
        }
    }
    
    public var currentLanguage: Language {
        get {
            let val = UserDefaults.app.string(forKey: languageKey) ?? "system"
            return Language(rawValue: val) ?? .system
        }
        set {
            UserDefaults.app.set(newValue.rawValue, forKey: languageKey)
            applyLanguageOverride(newValue)
        }
    }
    
    public func applyLanguageOverrideOnStartup() {
        // 移除命令行参数（如 Xcode 启动时传递的 -AppleLanguages）对语言的覆盖
        var volatileDomain = UserDefaults.app.volatileDomain(forName: "NSArgumentDomain")
        if volatileDomain["AppleLanguages"] != nil {
            volatileDomain.removeValue(forKey: "AppleLanguages")
            UserDefaults.app.setVolatileDomain(volatileDomain, forName: "NSArgumentDomain")
        }
        
        let lang = currentLanguage
        applyLanguageOverride(lang)
    }
    
    private func applyLanguageOverride(_ language: Language) {
        switch language {
        case .system:
            UserDefaults.app.removeObject(forKey: "AppleLanguages")
        case .english:
            UserDefaults.app.set(["en"], forKey: "AppleLanguages")
        case .chinese:
            UserDefaults.app.set(["zh-Hans"], forKey: "AppleLanguages")
        }
        UserDefaults.app.synchronize()
    }
    
    public func relaunchApp() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error = error {
                PKLogger.language.error("Failed to relaunch app: \(String(describing: error))")
            }
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
}
