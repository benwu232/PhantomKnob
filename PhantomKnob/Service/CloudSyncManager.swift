// PhantomKnob/Service/CloudSyncManager.swift
import Foundation
import Combine

public final class CloudSyncManager {
    public static let shared = CloudSyncManager()
    
    private var cancellables = Set<AnyCancellable>()
    private var isSyncingFromCloud = false
    
    private init() {}
    
    public func start() {
        // 1. 订阅云端变更通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
        
        // 2. 初始主动拉取一次云端并强制生效
        NSUbiquitousKeyValueStore.default.synchronize()
        
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
        if NSUbiquitousKeyValueStore.default.data(forKey: "com.phantomknob.my_knobs.data") == nil {
            syncLocalRulesToCloud()
        }
        if NSUbiquitousKeyValueStore.default.longLong(forKey: "globalHotkeyKeyCode") == 0 {
            syncLocalHotkeyToCloud()
        }
        // skipUserGuideOnStartup 本身在 KVS 中若无，可默认把本地的送过去
        if NSUbiquitousKeyValueStore.default.object(forKey: "skipUserGuideOnStartup") == nil {
            let localVal = UserDefaults.standard.bool(forKey: "skipUserGuideOnStartup")
            NSUbiquitousKeyValueStore.default.set(localVal, forKey: "skipUserGuideOnStartup")
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }
    
    private func syncLocalRulesToCloud() {
        guard !isSyncingFromCloud else { return }
        let url = RuleLibrary.shared.userRulesURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return }
        
        let cloudData = NSUbiquitousKeyValueStore.default.data(forKey: "com.phantomknob.my_knobs.data")
        if cloudData != data {
            NSUbiquitousKeyValueStore.default.set(data, forKey: "com.phantomknob.my_knobs.data")
            NSUbiquitousKeyValueStore.default.synchronize()
            NSLog("[CloudSync] Synced local custom rules to cloud.")
        }
    }
    
    private func syncLocalHotkeyToCloud() {
        guard !isSyncingFromCloud else { return }
        let keyCode = UserDefaults.standard.integer(forKey: "globalHotkeyKeyCode")
        let modifiers = UserDefaults.standard.integer(forKey: "globalHotkeyModifiers")
        
        let cloudKeyCode = NSUbiquitousKeyValueStore.default.longLong(forKey: "globalHotkeyKeyCode")
        let cloudModifiers = NSUbiquitousKeyValueStore.default.longLong(forKey: "globalHotkeyModifiers")
        
        var changed = false
        if keyCode != 0 && cloudKeyCode != Int64(keyCode) {
            NSUbiquitousKeyValueStore.default.set(Int64(keyCode), forKey: "globalHotkeyKeyCode")
            changed = true
        }
        if modifiers != 0 && cloudModifiers != Int64(modifiers) {
            NSUbiquitousKeyValueStore.default.set(Int64(modifiers), forKey: "globalHotkeyModifiers")
            changed = true
        }
        
        if changed {
            NSUbiquitousKeyValueStore.default.synchronize()
            NSLog("[CloudSync] Synced local hotkey to cloud.")
        }
    }
    
    private func syncLocalGeneralSettingsToCloud() {
        guard !isSyncingFromCloud else { return }
        let localVal = UserDefaults.standard.bool(forKey: "skipUserGuideOnStartup")
        let cloudVal = NSUbiquitousKeyValueStore.default.bool(forKey: "skipUserGuideOnStartup")
        if localVal != cloudVal {
            NSUbiquitousKeyValueStore.default.set(localVal, forKey: "skipUserGuideOnStartup")
            NSUbiquitousKeyValueStore.default.synchronize()
            NSLog("[CloudSync] Synced skipUserGuideOnStartup to cloud: \(localVal)")
        }
    }
    
    @objc private func storeDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }
        
        guard reason == NSUbiquitousKeyValueStoreServerChange || reason == NSUbiquitousKeyValueStoreInitialSync else {
            return
        }
        
        guard let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }
        
        isSyncingFromCloud = true
        defer { isSyncingFromCloud = false }
        
        var needsReloadRules = false
        var needsNotifyHotkey = false
        
        for key in changedKeys {
            if key == "com.phantomknob.my_knobs.data" {
                if let data = NSUbiquitousKeyValueStore.default.data(forKey: key) {
                    let url = RuleLibrary.shared.userRulesURL
                    let dir = url.deletingLastPathComponent()
                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    try? data.write(to: url)
                    needsReloadRules = true
                    NSLog("[CloudSync] Received rules from cloud, updated my_knobs.json.")
                }
            } else if key == "globalHotkeyKeyCode" {
                let val = NSUbiquitousKeyValueStore.default.longLong(forKey: key)
                if val != 0 && UserDefaults.standard.integer(forKey: "globalHotkeyKeyCode") != Int(val) {
                    UserDefaults.standard.set(Int(val), forKey: "globalHotkeyKeyCode")
                    needsNotifyHotkey = true
                }
            } else if key == "globalHotkeyModifiers" {
                let val = NSUbiquitousKeyValueStore.default.longLong(forKey: key)
                if val != 0 && UserDefaults.standard.integer(forKey: "globalHotkeyModifiers") != Int(val) {
                    UserDefaults.standard.set(Int(val), forKey: "globalHotkeyModifiers")
                    needsNotifyHotkey = true
                }
            } else if key == "skipUserGuideOnStartup" {
                let val = NSUbiquitousKeyValueStore.default.bool(forKey: key)
                if UserDefaults.standard.bool(forKey: "skipUserGuideOnStartup") != val {
                    UserDefaults.standard.set(val, forKey: "skipUserGuideOnStartup")
                    NSLog("[CloudSync] Received skipUserGuideOnStartup from cloud: \(val).")
                }
            }
        }
        
        if needsReloadRules {
            RuleLibrary.shared.reload()
        }
        
        if needsNotifyHotkey {
            NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
            NSLog("[CloudSync] Received hotkey configuration from cloud, re-registered hotkey.")
        }
    }
}
