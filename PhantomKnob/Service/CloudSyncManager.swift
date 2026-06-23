import Foundation
import Combine

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
    internal var cloudStore: CloudKeyValueStore = NSUbiquitousKeyValueStore.default
    #else
    private let cloudStore: CloudKeyValueStore = NSUbiquitousKeyValueStore.default
    #endif
    
    private var cancellables = Set<AnyCancellable>()
    private var isSyncingFromCloud = false
    private var isStarted = false
    
    private init() {}
    
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
        
        // 3. 订阅本地自定义规则更新
        NotificationCenter.default.publisher(for: NSNotification.Name("ControlRuleDidUpdate"))
            .sink { [weak self] _ in
                self?.syncLocalRulesToCloud()
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
            syncLocalRulesToCloud()
        }
        if cloudStore.longLong(forKey: "globalHotkeyKeyCode") == 0 {
            syncLocalHotkeyToCloud()
        }
        // skipUserGuideOnStartup 本身在 KVS 中若无，可默认把本地的送过去
        if cloudStore.object(forKey: "skipUserGuideOnStartup") == nil {
            let localVal = UserDefaults.standard.bool(forKey: "skipUserGuideOnStartup")
            cloudStore.set(localVal, forKey: "skipUserGuideOnStartup")
            cloudStore.synchronize()
        }
    }
    
    private func syncLocalRulesToCloud() {
        guard !isSyncingFromCloud else { return }
        let url = RuleLibrary.shared.userRulesURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return }
        
        let cloudData = cloudStore.data(forKey: "com.phantomknob.my_knobs.data")
        if cloudData != data {
            cloudStore.set(data, forKey: "com.phantomknob.my_knobs.data")
            cloudStore.synchronize()
            NSLog("[CloudSync] Synced local custom rules to cloud.")
        }
    }
    
    private func syncLocalHotkeyToCloud() {
        guard !isSyncingFromCloud else { return }
        let keyCode = UserDefaults.standard.integer(forKey: "globalHotkeyKeyCode")
        let modifiers = UserDefaults.standard.integer(forKey: "globalHotkeyModifiers")
        
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
            NSLog("[CloudSync] Synced local hotkey to cloud.")
        }
    }
    
    private func syncLocalGeneralSettingsToCloud() {
        guard !isSyncingFromCloud else { return }
        let localVal = UserDefaults.standard.bool(forKey: "skipUserGuideOnStartup")
        let cloudVal = cloudStore.bool(forKey: "skipUserGuideOnStartup")
        if localVal != cloudVal {
            cloudStore.set(localVal, forKey: "skipUserGuideOnStartup")
            cloudStore.synchronize()
            NSLog("[CloudSync] Synced skipUserGuideOnStartup to cloud: \(localVal)")
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
        
        var needsReloadRules = false
        var needsNotifyHotkey = false
        
        for key in changedKeys {
            if key == "com.phantomknob.my_knobs.data" {
                if let data = cloudStore.data(forKey: key) {
                    print("[CloudSyncDebug] Found rules data in cloudStore, size: \(data.count) bytes")
                    let url = RuleLibrary.shared.userRulesURL
                    let dir = url.deletingLastPathComponent()
                    do {
                        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                        try data.write(to: url)
                        needsReloadRules = true
                        print("[CloudSyncDebug] Successfully wrote rules data to \(url.path)")
                    } catch {
                        print("[CloudSyncDebug] Failed to write rules data: \(error)")
                    }
                } else {
                    print("[CloudSyncDebug] Rules data is nil in cloudStore")
                }
            } else if key == "globalHotkeyKeyCode" {
                let val = cloudStore.longLong(forKey: key)
                print("[CloudSyncDebug] Found hotkey keycode in cloudStore: \(val)")
                if val != 0 && UserDefaults.standard.integer(forKey: "globalHotkeyKeyCode") != Int(val) {
                    UserDefaults.standard.set(Int(val), forKey: "globalHotkeyKeyCode")
                    needsNotifyHotkey = true
                }
            } else if key == "globalHotkeyModifiers" {
                let val = cloudStore.longLong(forKey: key)
                print("[CloudSyncDebug] Found hotkey modifiers in cloudStore: \(val)")
                if val != 0 && UserDefaults.standard.integer(forKey: "globalHotkeyModifiers") != Int(val) {
                    UserDefaults.standard.set(Int(val), forKey: "globalHotkeyModifiers")
                    needsNotifyHotkey = true
                }
            } else if key == "skipUserGuideOnStartup" {
                let val = cloudStore.bool(forKey: key)
                print("[CloudSyncDebug] Found skipUserGuideOnStartup in cloudStore: \(val)")
                if UserDefaults.standard.bool(forKey: "skipUserGuideOnStartup") != val {
                    UserDefaults.standard.set(val, forKey: "skipUserGuideOnStartup")
                }
            }
        }
        
        if needsReloadRules {
            RuleLibrary.shared.reload()
            print("[CloudSyncDebug] Reloaded RuleLibrary. Rules count: \(RuleLibrary.shared.lookup(for: RuleKey(bundleID: "com.test.synced", axRole: "AXSlider")) != nil)")
            // 通知 UI 和测试规则库已重新加载
            NotificationCenter.default.post(
                name: NSNotification.Name("ControlRuleDidUpdate"),
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
