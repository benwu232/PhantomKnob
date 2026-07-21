import Foundation
import Security
import CryptoKit
import IOKit

public struct LicenseReceipt: Codable {
    public let licenseKey: String
    public let email: String
    public let deviceUUID: String
    public let activatedAt: Date
    public let lastVerifiedAt: Date
    public let signature: String
}

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
    private let publicKeyRepresentation: Data
    
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
        },
        publicKeyRepresentation: Data = Data(base64Encoded: "Sg6X484hS3Fsk2k8XzV8pTzH59WkE/B3eJmXb5mU8QY=")!
    ) {
        self.currentDateProvider = currentDateProvider
        self.storageRead = storageRead
        self.storageWrite = storageWrite
        self.publicKeyRepresentation = publicKeyRepresentation
    }
    
    var currentState: LicenseState {
        if let receiptStr = storageRead("proLicenseReceipt"),
           let receiptData = receiptStr.data(using: .utf8),
           let receipt = try? JSONDecoder().decode(LicenseReceipt.self, from: receiptData) {
            
            if verifyReceiptOffline(receipt) {
                let now = currentDateProvider()
                let daysSinceVerification = now.timeIntervalSince(receipt.lastVerifiedAt) / (24 * 60 * 60)
                if daysSinceVerification > 15 {
                    triggerSilentVerification(for: receipt)
                    if daysSinceVerification > 22 {
                        // 宽限期 7 天后到期，降级
                        return checkTrialStatus()
                    }
                }
                return .licensed
            }
        }
        
        if storageRead("proLicenseKey") != nil, storageRead("proLicenseEmail") != nil {
            return .licensed
        }
        
        return checkTrialStatus()
    }

    private func checkTrialStatus() -> LicenseState {
        guard let trialStartDateStr = storageRead("proTrialStartDate"),
              let trialStartDate = formatter.date(from: trialStartDateStr) else {
            let now = currentDateProvider()
            let nowStr = formatter.string(from: now)
            storageWrite("proTrialStartDate", nowStr)
            return .trialing(daysRemaining: 14)
        }
        
        let now = currentDateProvider()
        let secondsElapsed = now.timeIntervalSince(trialStartDate)
        let daysElapsed = Int(secondsElapsed / (24 * 60 * 60))
        
        if daysElapsed < 0 {
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
        
        storageWrite("proLicenseKey", licenseKey)
        storageWrite("proLicenseEmail", email)
        return true
    }
    
    func deactivate() {
        storageWrite("proLicenseReceipt", nil)
        storageWrite("proLicenseKey", nil)
        storageWrite("proLicenseEmail", nil)
        NotificationCenter.default.post(name: NSNotification.Name("LicenseStateDidChange"), object: nil)
    }
    
    private var isRefreshing = false
    
    private func triggerSilentVerification(for receipt: LicenseReceipt) {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        let uuid = getDeviceUUID()
        guard let url = URL(string: "https://licensing.phantomknob.com/activate") else {
            isRefreshing = false
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        let payload: [String: String] = [
            "license_key": receipt.licenseKey,
            "email": receipt.email,
            "device_uuid": uuid
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { self.isRefreshing = false }
            guard let data = data, error == nil,
                  let newReceipt = try? JSONDecoder().decode(LicenseReceipt.self, from: data) else {
                return
            }
            if self.verifyReceiptOffline(newReceipt) {
                if let receiptStr = String(data: data, encoding: .utf8) {
                    self.storageWrite("proLicenseReceipt", receiptStr)
                    NotificationCenter.default.post(name: NSNotification.Name("LicenseStateDidChange"), object: nil)
                }
            }
        }.resume()
    }
    
    func activateOnline(licenseKey: String, email: String, completion: @escaping (Bool, String?) -> Void) {
        let uuid = getDeviceUUID()
        guard let url = URL(string: "https://licensing.phantomknob.com/activate") else {
            completion(false, "Internal Error: Invalid URL")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15.0
        
        let payload: [String: String] = [
            "license_key": licenseKey.trimmingCharacters(in: .whitespacesAndNewlines),
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "device_uuid": uuid
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    completion(false, error?.localizedDescription ?? "网络连接失败")
                }
                return
            }
            
            do {
                let receipt = try JSONDecoder().decode(LicenseReceipt.self, from: data)
                if self.verifyReceiptOffline(receipt) {
                    if let receiptStr = String(data: data, encoding: .utf8) {
                        self.storageWrite("proLicenseReceipt", receiptStr)
                        self.storageWrite("proLicenseKey", receipt.licenseKey)
                        self.storageWrite("proLicenseEmail", receipt.email)
                        
                        NotificationCenter.default.post(name: NSNotification.Name("LicenseStateDidChange"), object: nil)
                        DispatchQueue.main.async {
                            completion(true, nil)
                        }
                    } else {
                        DispatchQueue.main.async { completion(false, "激活数据格式错误") }
                    }
                } else {
                    DispatchQueue.main.async { completion(false, "数字签名校验失败，请联系支持团队") }
                }
            } catch {
                let serverError = String(data: data, encoding: .utf8) ?? "未知激活错误"
                DispatchQueue.main.async {
                    completion(false, serverError)
                }
            }
        }.resume()
    }
    
    func debugToggleLicense() {
        if case .licensed = currentState {
            storageWrite("proLicenseKey", nil)
            storageWrite("proLicenseEmail", nil)
            let expiredDate = Date().addingTimeInterval(-20 * 24 * 60 * 60)
            storageWrite("proTrialStartDate", formatter.string(from: expiredDate))
        } else {
            storageWrite("proLicenseKey", "DEBUG_KEY")
            storageWrite("proLicenseEmail", "debug@example.com")
        }
        NotificationCenter.default.post(name: NSNotification.Name("LicenseStateDidChange"), object: nil)
    }
    
    public func getDeviceUUID() -> String {
        let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(platformExpert) }
        if platformExpert > 0 {
            if let uuid = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
                return uuid.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return "UNKNOWN_DEVICE_UUID"
    }
    
    public func verifyReceiptOffline(_ receipt: LicenseReceipt) -> Bool {
        // 1. 验证设备 UUID 匹配
        guard receipt.deviceUUID == getDeviceUUID() else { return false }
        
        // 2. 验证 Signature
        guard let sigData = Data(base64Encoded: receipt.signature) else { return false }
        let message = "\(receipt.licenseKey)|\(receipt.email)|\(receipt.deviceUUID)|\(Int(receipt.activatedAt.timeIntervalSince1970))|\(Int(receipt.lastVerifiedAt.timeIntervalSince1970))"
        guard let messageData = message.data(using: .utf8) else { return false }
        
        // 使用 CryptoKit 验证 Ed25519 签名
        do {
            let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyRepresentation)
            return publicKey.isValidSignature(sigData, for: messageData)
        } catch {
            return false
        }
    }
}
