import Foundation
import Security

class KeychainHelper {
    static func set(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]
            SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        } else {
            var newItem = query
            newItem[kSecValueData as String] = data
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }
    
    static func get(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

class LicenseManager {
    static let shared = LicenseManager()
    
    private let currentDateProvider: () -> Date
    private let storageRead: (String) -> String?
    private let storageWrite: (String, String?) -> Void
    private let formatter = ISO8601DateFormatter()
    
    init(
        currentDateProvider: @escaping () -> Date = { Date() },
        storageRead: @escaping (String) -> String? = {
            #if DEBUG
            UserDefaults.app.string(forKey: $0)
            #else
            KeychainHelper.get(forKey: $0)
            #endif
        },
        storageWrite: @escaping (String, String?) -> Void = { key, value in
            #if DEBUG
            if let val = value {
                UserDefaults.app.set(val, forKey: key)
            } else {
                UserDefaults.app.removeObject(forKey: key)
            }
            #else
            if let val = value {
                KeychainHelper.set(val, forKey: key)
            } else {
                KeychainHelper.delete(forKey: key)
            }
            #endif
        }
    ) {
        self.currentDateProvider = currentDateProvider
        self.storageRead = storageRead
        self.storageWrite = storageWrite
    }
    
    var currentState: LicenseState {
        if storageRead("licenseKey") != nil, storageRead("licenseEmail") != nil {
            return .licensed
        }
        
        guard let trialStartDateStr = storageRead("trialStartDate"),
              let trialStartDate = formatter.date(from: trialStartDateStr) else {
            // First launch, record date
            let now = currentDateProvider()
            let nowStr = formatter.string(from: now)
            storageWrite("trialStartDate", nowStr)
            return .trialing(daysRemaining: 14)
        }
        
        let now = currentDateProvider()
        let secondsElapsed = now.timeIntervalSince(trialStartDate)
        let daysElapsed = Int(secondsElapsed / (24 * 60 * 60))
        
        if daysElapsed < 0 {
            // Clock drift protection
            return .trialing(daysRemaining: 14)
        }
        
        if daysElapsed <= 14 {
            return .trialing(daysRemaining: 14 - daysElapsed)
        } else {
            return .free
        }
    }
    
    func activate(licenseKey: String, email: String) -> Bool {
        guard !licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        storageWrite("licenseKey", licenseKey)
        storageWrite("licenseEmail", email)
        return true
    }
    
    func deactivate() {
        storageWrite("licenseKey", nil)
        storageWrite("licenseEmail", nil)
    }
    
    func debugToggleLicense() {
        if case .licensed = currentState {
            storageWrite("licenseKey", nil)
            storageWrite("licenseEmail", nil)
            let expiredDate = Date().addingTimeInterval(-20 * 24 * 60 * 60)
            storageWrite("trialStartDate", formatter.string(from: expiredDate))
        } else {
            storageWrite("licenseKey", "DEBUG_KEY")
            storageWrite("licenseEmail", "debug@example.com")
        }
        NotificationCenter.default.post(name: NSNotification.Name("LicenseStateDidChange"), object: nil)
    }
}
