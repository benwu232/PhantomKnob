import Foundation
import Combine
import os

public protocol CloudKeyValueStore: AnyObject {
    func data(forKey aKey: String) -> Data?
    func set(_ anObject: Any?, forKey aKey: String)
    func longLong(forKey aKey: String) -> Int64
    func bool(forKey aKey: String) -> Bool
    func object(forKey aKey: String) -> Any?
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: CloudKeyValueStore {}

public final class CloudSyncManager {
    public static let shared = CloudSyncManager()
    
    #if DEBUG
    internal var cloudStore: CloudKeyValueStore
    #else
    private var cloudStore: CloudKeyValueStore
    #endif
    
    private var cancellables = Set<AnyCancellable>()
    private var isSyncingFromCloud = false
    private var isStarted = false
    
    private init() {
        if NSClassFromString("XCTestCase") != nil {
            self.cloudStore = InMemoryCloudStore()
        } else {
            self.cloudStore = NSUbiquitousKeyValueStore.default
        }
    }
    
    public func start() {
        guard !isStarted else { return }
        isStarted = true
        
        // 1. 订阅云端变更通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil
        )
        
        // 2. 初始主动拉取一次云端并强制生效
        cloudStore.synchronize()
        
        // 3. 订阅本地自定义配置更新
        NotificationCenter.default.publisher(for: NSNotification.Name("KnobDidUpdate"))
            .sink { [weak self] _ in
                self?.syncLocalKnobsToCloud()
            }
            .store(in: &cancellables)
            
        // 4. 订阅本地快捷键变更
        NotificationCenter.default.publisher(for: .hotkeyDidChange)
            .sink { [weak self] _ in
                self?.syncLocalHotkeyToCloud()
            }
            .store(in: &cancellables)
            
        // 5. 监听本地 UserDefaults 变更（主要用于 skipUserGuideOnStartup）
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.syncLocalGeneralSettingsToCloud()
            }
            .store(in: &cancellables)
            
        // 6. 首次启动将本地既有数据尝试推到云端（如果云端为空）
        initialPushIfNeeded()
    }
    
    private func initialPushIfNeeded() {
        if cloudStore.data(forKey: "com.phantomknob.my_knobs.data") == nil {
            syncLocalKnobsToCloud()
        }
        if cloudStore.longLong(forKey: "globalHotkeyKeyCode") == 0 {
            syncLocalHotkeyToCloud()
        }
        // skipUserGuideOnStartup 本身在 KVS 中若无，可默认把本地的送过去
        if cloudStore.object(forKey: "skipUserGuideOnStartup") == nil {
            let localVal = UserDefaults.app.bool(forKey: "skipUserGuideOnStartup")
            cloudStore.set(localVal, forKey: "skipUserGuideOnStartup")
            cloudStore.synchronize()
        }
    }
    
    private func syncLocalKnobsToCloud() {
        guard !isSyncingFromCloud else { return }
        let url = KnobCustomizer.shared.myKnobsURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return }
        
        let cloudData = cloudStore.data(forKey: "com.phantomknob.my_knobs.data")
        if cloudData != data {
            cloudStore.set(data, forKey: "com.phantomknob.my_knobs.data")
            cloudStore.synchronize()
            PKLogger.cloudSync.info("Synced local custom knobs to cloud.")
        }
    }
    
    private func syncLocalHotkeyToCloud() {
        guard !isSyncingFromCloud else { return }
        let keyCode = UserDefaults.app.integer(forKey: "globalHotkeyKeyCode")
        let modifiers = UserDefaults.app.integer(forKey: "globalHotkeyModifiers")
        
        let cloudKeyCode = cloudStore.longLong(forKey: "globalHotkeyKeyCode")
        let cloudModifiers = cloudStore.longLong(forKey: "globalHotkeyModifiers")
        
        var changed = false
        if keyCode != 0 && cloudKeyCode != Int64(keyCode) {
            cloudStore.set(Int64(keyCode), forKey: "globalHotkeyKeyCode")
            changed = true
        }
        if modifiers != 0 && cloudModifiers != Int64(modifiers) {
            cloudStore.set(Int64(modifiers), forKey: "globalHotkeyModifiers")
            changed = true
        }
        
        if changed {
            cloudStore.synchronize()
            PKLogger.cloudSync.info("Synced local hotkey to cloud.")
        }
    }
    
    private func syncLocalGeneralSettingsToCloud() {
        guard !isSyncingFromCloud else { return }
        let localVal = UserDefaults.app.bool(forKey: "skipUserGuideOnStartup")
        let cloudVal = cloudStore.bool(forKey: "skipUserGuideOnStartup")
        if localVal != cloudVal {
            cloudStore.set(localVal, forKey: "skipUserGuideOnStartup")
            cloudStore.synchronize()
            PKLogger.cloudSync.info("Synced skipUserGuideOnStartup to cloud: \(localVal)")
        }
    }
    
    @objc private func storeDidChange(_ notification: Notification) {
        print("[CloudSyncDebug] storeDidChange triggered!")
        guard let userInfo = notification.userInfo else {
            print("[CloudSyncDebug] userInfo is nil")
            return
        }
        guard let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            print("[CloudSyncDebug] reason is nil or not Int: \(String(describing: userInfo[NSUbiquitousKeyValueStoreChangeReasonKey]))")
            return
        }
        
        print("[CloudSyncDebug] reason: \(reason)")
        guard reason == NSUbiquitousKeyValueStoreServerChange || reason == NSUbiquitousKeyValueStoreInitialSyncChange else {
            print("[CloudSyncDebug] reason is not ServerChange/InitialSync")
            return
        }
        
        guard let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            print("[CloudSyncDebug] changedKeys is nil or not [String]")
            return
        }
        
        print("[CloudSyncDebug] changedKeys: \(changedKeys)")
        isSyncingFromCloud = true
        defer { isSyncingFromCloud = false }
        
        var needsReloadKnobs = false
        var needsNotifyHotkey = false
        
        for key in changedKeys {
            if key == "com.phantomknob.my_knobs.data" {
                if let data = cloudStore.data(forKey: key) {
                    print("[CloudSyncDebug] Found knobs data in cloudStore, size: \(data.count) bytes")
                    let url = KnobCustomizer.shared.myKnobsURL
                    let dir = url.deletingLastPathComponent()
                    do {
                        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                        try data.write(to: url)
                        needsReloadKnobs = true
                        print("[CloudSyncDebug] Successfully wrote knobs data to \(url.path)")
                    } catch {
                        print("[CloudSyncDebug] Failed to write knobs data: \(error)")
                    }
                } else {
                    print("[CloudSyncDebug] Knobs data is nil in cloudStore")
                }
            } else if key == "globalHotkeyKeyCode" {
                let val = cloudStore.longLong(forKey: key)
                print("[CloudSyncDebug] Found hotkey keycode in cloudStore: \(val)")
                if val != 0 && UserDefaults.app.integer(forKey: "globalHotkeyKeyCode") != Int(val) {
                    UserDefaults.app.set(Int(val), forKey: "globalHotkeyKeyCode")
                    needsNotifyHotkey = true
                }
            } else if key == "globalHotkeyModifiers" {
                let val = cloudStore.longLong(forKey: key)
                print("[CloudSyncDebug] Found hotkey modifiers in cloudStore: \(val)")
                if val != 0 && UserDefaults.app.integer(forKey: "globalHotkeyModifiers") != Int(val) {
                    UserDefaults.app.set(Int(val), forKey: "globalHotkeyModifiers")
                    needsNotifyHotkey = true
                }
            } else if key == "skipUserGuideOnStartup" {
                let val = cloudStore.bool(forKey: key)
                print("[CloudSyncDebug] Found skipUserGuideOnStartup in cloudStore: \(val)")
                if UserDefaults.app.bool(forKey: "skipUserGuideOnStartup") != val {
                    UserDefaults.app.set(val, forKey: "skipUserGuideOnStartup")
                }
            }
        }
        
        if needsReloadKnobs {
            KnobCustomizer.shared.reload()
            print("[CloudSyncDebug] Reloaded KnobCustomizer. Knobs count: \(KnobCustomizer.shared.knob(for: KnobKey(bundleID: "com.test.synced", axRole: "AXSlider")) != nil)")
            // 通知 UI 和测试配置库已重新加载
            NotificationCenter.default.post(
                name: NSNotification.Name("KnobDidUpdate"),
                object: nil,
                userInfo: nil
            )
        }
        
        if needsNotifyHotkey {
            NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
            print("[CloudSyncDebug] Posted hotkeyDidChange notification")
        }
    }
}

private final class InMemoryCloudStore: CloudKeyValueStore {
    var storage: [String: Any] = [:]
    
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
        return true
    }
}
