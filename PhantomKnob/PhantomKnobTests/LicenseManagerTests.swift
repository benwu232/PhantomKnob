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
    
    func testFirstLaunchInitializesTrial() {
        // Initial state should be trialing with 14 days remaining
        let state = licenseManager.currentState
        if case .trialing(let days) = state {
            XCTAssertEqual(days, 14)
        } else {
            XCTFail("Expected trialing state, got \(state)")
        }
        
        // It should have written the start date to storage
        XCTAssertNotNil(mockStorage["trialStartDate"])
    }
    
    func testTrialProgressiveDays() {
        // First launch initializes trial start
        _ = licenseManager.currentState
        let formatter = ISO8601DateFormatter()
        let startDateStr = mockStorage["trialStartDate"]!
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
        XCTAssertEqual(mockStorage["licenseKey"], "TEST-LICENSE-KEY")
        XCTAssertEqual(mockStorage["licenseEmail"], "user@example.com")
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
}
