import XCTest
import CryptoKit
@testable import PhantomKnob

class LicenseManagerTests: XCTestCase {
    var mockStorage: [String: String] = [:]
    var simulatedDate = Date()
    var licenseManager: LicenseManager!
    
    override func setUp() {
        super.setUp()
        mockStorage = [:]
        simulatedDate = Date()
        
        licenseManager = LicenseManager(
            currentDateProvider: { self.simulatedDate },
            storageRead: { key in self.mockStorage[key] },
            storageWrite: { key, value in
                if let val = value {
                    self.mockStorage[key] = val
                } else {
                    self.mockStorage.removeValue(forKey: key)
                }
            }
        )
    }
    
    func testStoreCheckoutURLIsValid() {
        let url = AppSettings.storeCheckoutURL
        XCTAssertEqual(url.host, "benwu232.lemonsqueezy.com")
        XCTAssertTrue(url.path.contains("checkout/buy/745d4e0d-3c01-4264-bbe2-46ed187ddf10"))
    }
    
    func testFirstLaunchInitializesTrial() {
        // Initial state should be trialing with 14 days remaining
        let state = licenseManager.currentState
        if case .trialing(let days) = state {
            XCTAssertEqual(days, 14)
        } else {
            XCTFail("Expected trialing state, got \(state)")
        }
        
        // It should have written the start date to storage
        XCTAssertNotNil(mockStorage["proTrialStartDate"])
    }
    
    func testTrialProgressiveDays() {
        // First launch initializes trial start
        _ = licenseManager.currentState
        let formatter = ISO8601DateFormatter()
        let startDateStr = mockStorage["proTrialStartDate"]!
        let startDate = formatter.date(from: startDateStr)!
        
        // Move simulated date forward by 5 days
        simulatedDate = startDate.addingTimeInterval(5 * 24 * 60 * 60)
        let stateAfter5Days = licenseManager.currentState
        if case .trialing(let days) = stateAfter5Days {
            XCTAssertEqual(days, 9)
        } else {
            XCTFail("Expected trialing state, got \(stateAfter5Days)")
        }
        
        // Move simulated date forward by 14 days
        simulatedDate = startDate.addingTimeInterval(14 * 24 * 60 * 60)
        let stateAfter14Days = licenseManager.currentState
        if case .trialing(let days) = stateAfter14Days {
            XCTAssertEqual(days, 0)
        } else {
            XCTFail("Expected trialing state, got \(stateAfter14Days)")
        }
        
        // Move simulated date forward by 15 days (expired)
        simulatedDate = startDate.addingTimeInterval(15 * 24 * 60 * 60)
        let stateAfter15Days = licenseManager.currentState
        XCTAssertEqual(stateAfter15Days, .free)
    }
    
    func testActivationSetsLicensedState() {
        // Initially in trialing
        XCTAssertNotEqual(licenseManager.currentState, .licensed)
        
        // Activate license
        let success = licenseManager.activate(licenseKey: "TEST-LICENSE-KEY", email: "user@example.com")
        XCTAssertTrue(success)
        XCTAssertEqual(licenseManager.currentState, .licensed)
        XCTAssertEqual(mockStorage["proLicenseKey"], "TEST-LICENSE-KEY")
        XCTAssertEqual(mockStorage["proLicenseEmail"], "user@example.com")
    }
    
    func testDeactivationRevertsToTrial() {
        // Activate first
        _ = licenseManager.activate(licenseKey: "TEST-LICENSE-KEY", email: "user@example.com")
        XCTAssertEqual(licenseManager.currentState, .licensed)
        
        // Deactivate
        licenseManager.deactivate()
        
        // Should revert to trialing
        if case .trialing(let days) = licenseManager.currentState {
            XCTAssertEqual(days, 14)
        } else {
            XCTFail("Expected trialing state after deactivation")
        }
    }
    
    func testDebugToggleLicense() {
        #if DEBUG
        // Start in trialing / expired (not licensed)
        XCTAssertNotEqual(licenseManager.currentState, .licensed)
        
        // Toggle (should change to licensed)
        licenseManager.debugToggleLicense()
        XCTAssertEqual(licenseManager.currentState, .licensed)
        
        // Toggle again (should revert to expired free)
        licenseManager.debugToggleLicense()
        XCTAssertEqual(licenseManager.currentState, .free)
        #endif
    }
    
    func testOfflineReceiptVerification() {
        // 1. 生成测试 Ed25519 私钥和公钥
        let testPrivateKey = Curve25519.Signing.PrivateKey()
        let testPublicKey = testPrivateKey.publicKey
        let pubKeyData = testPublicKey.rawRepresentation
        
        // 2. 创建一个基于测试公钥的 LicenseManager 实例
        let manager = LicenseManager(
            currentDateProvider: { self.simulatedDate },
            storageRead: { key in self.mockStorage[key] },
            storageWrite: { key, value in
                if let val = value {
                    self.mockStorage[key] = val
                } else {
                    self.mockStorage.removeValue(forKey: key)
                }
            },
            publicKeyRepresentation: pubKeyData
        )
        
        let key = "TEST-LICENSE-KEY"
        let email = "user@example.com"
        let uuid = manager.getDeviceUUID()
        let now = Date()
        
        // 3. 用测试私钥对消息签名
        let message = "\(key)|\(email)|\(uuid)|\(Int(now.timeIntervalSince1970))|\(Int(now.timeIntervalSince1970))"
        let messageData = message.data(using: .utf8)!
        let signature = try! testPrivateKey.signature(for: messageData).base64EncodedString()
        
        let receipt = LicenseReceipt(
            licenseKey: key,
            email: email,
            deviceUUID: uuid,
            activatedAt: now,
            lastVerifiedAt: now,
            signature: signature
        )
        
        // 4. 验证合法的签名和 UUID 应该通过
        XCTAssertTrue(manager.verifyReceiptOffline(receipt))
        
        // 5. 验证篡改的邮箱签名应该失败
        let temperedReceipt = LicenseReceipt(
            licenseKey: key,
            email: "hacker@example.com", // 篡改
            deviceUUID: uuid,
            activatedAt: now,
            lastVerifiedAt: now,
            signature: signature
        )
        XCTAssertFalse(manager.verifyReceiptOffline(temperedReceipt))
        
        // 6. 验证错误的设备 UUID 应该失败
        let wrongDeviceReceipt = LicenseReceipt(
            licenseKey: key,
            email: email,
            deviceUUID: "WRONG-UUID-123", // 篡改
            activatedAt: now,
            lastVerifiedAt: now,
            signature: signature
        )
        XCTAssertFalse(manager.verifyReceiptOffline(wrongDeviceReceipt))
        
        // 7. 用外部另一个无关的私钥签名，应该失败
        let unrelatedPrivateKey = Curve25519.Signing.PrivateKey()
        let unrelatedSignature = try! unrelatedPrivateKey.signature(for: messageData).base64EncodedString()
        let badSignatureReceipt = LicenseReceipt(
            licenseKey: key,
            email: email,
            deviceUUID: uuid,
            activatedAt: now,
            lastVerifiedAt: now,
            signature: unrelatedSignature // 无关签名
        )
        XCTAssertFalse(manager.verifyReceiptOffline(badSignatureReceipt))
    }
    
    func testOfflineGracePeriodExpiresAndDegrades() {
        let testPrivateKey = Curve25519.Signing.PrivateKey()
        let pubKeyData = testPrivateKey.publicKey.rawRepresentation
        
        let manager = LicenseManager(
            currentDateProvider: { self.simulatedDate },
            storageRead: { key in self.mockStorage[key] },
            storageWrite: { key, value in
                if let val = value {
                    self.mockStorage[key] = val
                } else {
                    self.mockStorage.removeValue(forKey: key)
                }
            },
            publicKeyRepresentation: pubKeyData
        )
        
        let key = "TEST-LICENSE-KEY"
        let email = "user@example.com"
        let uuid = manager.getDeviceUUID()
        
        // 1. 模拟在宽限期内（上次验证在 20 天前，介于 15 ~ 22 天之间）
        let activatedDate = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let verifiedDateWithinGrace = Date().addingTimeInterval(-20 * 24 * 60 * 60)
        
        let msg = "\(key)|\(email)|\(uuid)|\(Int(activatedDate.timeIntervalSince1970))|\(Int(verifiedDateWithinGrace.timeIntervalSince1970))"
        let sig = try! testPrivateKey.signature(for: msg.data(using: .utf8)!).base64EncodedString()
        
        let receiptWithinGrace = LicenseReceipt(
            licenseKey: key,
            email: email,
            deviceUUID: uuid,
            activatedAt: activatedDate,
            lastVerifiedAt: verifiedDateWithinGrace,
            signature: sig
        )
        
        let encoder = JSONEncoder()
        let receiptJsonData = try! encoder.encode(receiptWithinGrace)
        mockStorage["proLicenseReceipt"] = String(data: receiptJsonData, encoding: .utf8)
        
        // 我们需要把 trial 模拟为过期，排除干扰
        let formatter = ISO8601DateFormatter()
        mockStorage["proTrialStartDate"] = formatter.string(from: Date().addingTimeInterval(-20 * 24 * 60 * 60))
        
        // 此时由于 20 < 22 天，应当仍处于 .licensed 状态
        XCTAssertEqual(manager.currentState, .licensed)
        
        // 2. 模拟宽限期失效（上次验证在 25 天前，超过 22 天限制）
        let verifiedDateExpired = Date().addingTimeInterval(-25 * 24 * 60 * 60)
        let msgExpired = "\(key)|\(email)|\(uuid)|\(Int(activatedDate.timeIntervalSince1970))|\(Int(verifiedDateExpired.timeIntervalSince1970))"
        let sigExpired = try! testPrivateKey.signature(for: msgExpired.data(using: .utf8)!).base64EncodedString()
        
        let receiptExpired = LicenseReceipt(
            licenseKey: key,
            email: email,
            deviceUUID: uuid,
            activatedAt: activatedDate,
            lastVerifiedAt: verifiedDateExpired,
            signature: sigExpired
        )
        
        let receiptJsonDataExpired = try! encoder.encode(receiptExpired)
        mockStorage["proLicenseReceipt"] = String(data: receiptJsonDataExpired, encoding: .utf8)
        
        // 此时已经超过宽限期，应当退回到 trial 过期状态即 .free
        XCTAssertEqual(manager.currentState, .free)
    }
}
