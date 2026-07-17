// PhantomKnob/PhantomKnobTests/CloudSyncManagerTests.swift
import XCTest
@testable import PhantomKnob

// 模拟的 iCloud 键值存储对象，打破沙盒环境/命令行下 KVS 默认不生效的局限
final class MockCloudStore: CloudKeyValueStore {
    var storage: [String: Any] = [:]
    var synchronizeCalled = false
    
    func data(forKey aKey: String) -> Data? {
        return storage[aKey] as? Data
    }
    
    func set(_ anObject: Any?, forKey aKey: String) {
        storage[aKey] = anObject
    }
    
    func longLong(forKey aKey: String) -> Int64 {
        if let val = storage[aKey] as? Int64 {
            return val
        }
        if let val = storage[aKey] as? Int {
            return Int64(val)
        }
        return 0
    }
    
    func bool(forKey aKey: String) -> Bool {
        return storage[aKey] as? Bool ?? false
    }
    
    func object(forKey aKey: String) -> Any? {
        return storage[aKey]
    }
    
    func synchronize() -> Bool {
        synchronizeCalled = true
        return true
    }
}

final class CloudSyncManagerTests: XCTestCase {
    
    private var mockStore: MockCloudStore!
    private var originalStore: CloudKeyValueStore!
    
    private let suiteName = "com.phantomknob.PhantomKnobTests"
    
    override func setUp() {
        super.setUp()
        UserDefaults.app = UserDefaults(suiteName: suiteName) ?? .standard
        UserDefaults.app.removePersistentDomain(forName: suiteName)
        
        mockStore = MockCloudStore()
        originalStore = CloudSyncManager.shared.cloudStore
        CloudSyncManager.shared.cloudStore = mockStore
    }
    
    override func tearDown() {
        CloudSyncManager.shared.cloudStore = originalStore
        UserDefaults.app.removePersistentDomain(forName: suiteName)
        UserDefaults.app = .standard
        super.tearDown()
    }
    
    func testCloudSyncManagerExternalKnobsUpdate() throws {
        // 1. 初始化
        let manager = CloudSyncManager.shared
        manager.start()
        
        // 2. 模拟外部发来的自定义配置
        let mockKnob = Knob(
            key: KnobKey(bundleID: "com.test.synced", axRole: "AXSlider"),
            translation: .arrowKeyUpDown
        )
        let encoder = JSONEncoder()
        let mockData = try encoder.encode([mockKnob])
        
        let expectation = self.expectation(description: "Knob customizer is reloaded when knobs are synced from cloud")
        
        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("KnobDidUpdate"),
            object: nil,
            queue: nil
        ) { _ in
            // 再次查询库中是否存在云端注入的配置
            let lookupKey = KnobKey(bundleID: "com.test.synced", axRole: "AXSlider")
            let matched = KnobCustomizer.shared.knob(for: lookupKey)
            if matched?.translation == .arrowKeyUpDown {
                expectation.fulfill()
            }
        }
        
        // 3. 发送模拟云端变更通知
        let userInfo: [AnyHashable: Any] = [
            NSUbiquitousKeyValueStoreChangeReasonKey: NSUbiquitousKeyValueStoreServerChange,
            NSUbiquitousKeyValueStoreChangedKeysKey: ["com.phantomknob.my_knobs.data"]
        ]
        
        // 注入 KVS Mock：直接在 memory 中改变并写入本地然后发送系统通知触发 manager 执行
        mockStore.set(mockData, forKey: "com.phantomknob.my_knobs.data")
        
        NotificationCenter.default.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            userInfo: userInfo
        )
        
        waitForExpectations(timeout: 2.0, handler: nil)
        NotificationCenter.default.removeObserver(observer)
        
        // 4. 清理本地模拟写入的文件
        try? FileManager.default.removeItem(at: KnobCustomizer.shared.myKnobsURL)
        KnobCustomizer.shared.reload()
    }
    
    func testCloudSyncManagerExternalHotkeyUpdate() {
        let manager = CloudSyncManager.shared
        manager.start()
        
        let expectation = self.expectation(description: "Hotkey change notification posted")
        let observer = NotificationCenter.default.addObserver(
            forName: .hotkeyDidChange,
            object: nil,
            queue: nil
        ) { _ in
            XCTAssertEqual(UserDefaults.app.integer(forKey: "globalHotkeyKeyCode"), 18)
            XCTAssertEqual(UserDefaults.app.integer(forKey: "globalHotkeyModifiers"), 256)
            expectation.fulfill()
        }
        
        // 模拟 KVS 云端更改了键：globalHotkeyKeyCode=18, globalHotkeyModifiers=256
        mockStore.set(Int64(18), forKey: "globalHotkeyKeyCode")
        mockStore.set(Int64(256), forKey: "globalHotkeyModifiers")
        
        let userInfo: [AnyHashable: Any] = [
            NSUbiquitousKeyValueStoreChangeReasonKey: NSUbiquitousKeyValueStoreServerChange,
            NSUbiquitousKeyValueStoreChangedKeysKey: ["globalHotkeyKeyCode", "globalHotkeyModifiers"]
        ]
        
        NotificationCenter.default.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            userInfo: userInfo
        )
        
        waitForExpectations(timeout: 2.0, handler: nil)
        NotificationCenter.default.removeObserver(observer)
    }
}
