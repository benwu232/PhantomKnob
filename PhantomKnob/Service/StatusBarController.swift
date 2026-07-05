import AppKit
import SwiftUI
import Combine
import os

class StatusBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var globalHotkeyMonitor: Any?
    private var localHotkeyMonitor: Any?
    private var toggleMenuItem: NSMenuItem?
    private var versionMenuItem: NSMenuItem?
    private var hotkeyChangeObserver: AnyCancellable?
    private var licenseChangeObserver: AnyCancellable?
    
    @Published var currentState: KnobGlobalState = .inactive
    @Published var targetName: String?
    
    var onToggleHotkey: (() -> Void)?
    
    init() {
        PKLogger.statusBar.info("init() called")
        setupStatusBar()
        setupGlobalHotkey()
        setupLocalHotkey()
        
        // Reinstall hotkey monitors when the hotkey settings change
        hotkeyChangeObserver = NotificationCenter.default
            .publisher(for: .hotkeyDidChange)
            .sink { [weak self] _ in self?.reinstallHotkeyMonitors() }
            
        licenseChangeObserver = NotificationCenter.default
            .publisher(for: NSNotification.Name("LicenseStateDidChange"))
            .sink { [weak self] _ in
                self?.updateVersionItem()
            }
    }
    
    deinit {
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
    }
    
    private func reinstallHotkeyMonitors() {
        if let m = globalHotkeyMonitor { NSEvent.removeMonitor(m); globalHotkeyMonitor = nil }
        if let m = localHotkeyMonitor  { NSEvent.removeMonitor(m); localHotkeyMonitor = nil }
        setupGlobalHotkey()
        setupLocalHotkey()
        
        // Update menu item shortcut dynamically
        updateMenuHotkey()
        
        // Refresh tooltip
        updateState(currentState, targetName: targetName)
    }
    
    private func updateMenuHotkey() {
        let hs = HotkeySettings.shared
        toggleMenuItem?.keyEquivalent = hs.keyEquivalent
        toggleMenuItem?.keyEquivalentModifierMask = hs.modifiers
    }

    private func setupLocalHotkey() {
        localHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            PKLogger.statusBar.debug("Local keyDown: keyCode=\(event.keyCode) modifiers=\(event.modifierFlags.rawValue) charsIgnoringModifiers=\(event.charactersIgnoringModifiers ?? "") chars=\(event.characters ?? "")")
            if event.keyCode == 49 && event.modifierFlags.contains(.option) {
                KnobPanelWindowController.shared.toggle()
                return nil
            }
            let hs = HotkeySettings.shared
            let pressedMods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == hs.keyCode && pressedMods == hs.modifiers {
                PKLogger.statusBar.debug("Local hotkey detected")
                self?.toggleMode()
                return nil
            }
            return event
        }
        PKLogger.statusBar.info("Local hotkey monitor installed")
    }
    
    private func setupGlobalHotkey() {
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            PKLogger.statusBar.debug("Global keyDown: keyCode=\(event.keyCode) modifiers=\(event.modifierFlags.rawValue) charsIgnoringModifiers=\(event.charactersIgnoringModifiers ?? "") chars=\(event.characters ?? "")")
            if event.keyCode == 49 && event.modifierFlags.contains(.option) {
                KnobPanelWindowController.shared.toggle()
                return
            }
            let hs = HotkeySettings.shared
            let pressedMods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == hs.keyCode && pressedMods == hs.modifiers {
                PKLogger.statusBar.debug("Global hotkey detected")
                self?.toggleMode()
            }
        }
        PKLogger.statusBar.info("Global hotkey monitor installed")
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = createIcon(for: .inactive)
            button.image?.isTemplate = true
            button.toolTip = String(localized: "tooltip.inactive", defaultValue: "Knob Control: Inactive (Press \(HotkeySettings.shared.displayString) to activate)")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        menu = NSMenu()
        
        let statusMenuItem = NSMenuItem(
            title: String(localized: "status.inactive", defaultValue: "Status: Inactive"),
            action: nil,
            keyEquivalent: ""
        )
        statusMenuItem.isEnabled = false
        menu?.addItem(statusMenuItem)
        
        let versionItem = NSMenuItem(
            title: "",
            action: nil,
            keyEquivalent: ""
        )
        versionItem.isEnabled = false
        self.versionMenuItem = versionItem
        menu?.addItem(versionItem)
        updateVersionItem()
        
        let guideMenuItem = NSMenuItem(
            title: String(localized: "menu.userGuide", defaultValue: "User Guide…"),
            action: #selector(openGuide),
            keyEquivalent: ""
        )
        guideMenuItem.target = self
        menu?.addItem(guideMenuItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        let hs = HotkeySettings.shared
        let toggleItem = NSMenuItem(
            title: String(localized: "menu.toggleMode", defaultValue: "Toggle Control Mode"),
            action: #selector(toggleMode),
            keyEquivalent: hs.keyEquivalent
        )
        toggleItem.keyEquivalentModifierMask = hs.modifiers
        toggleItem.target = self
        toggleMenuItem = toggleItem
        menu?.addItem(toggleItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(
            title: String(localized: "menu.settings", defaultValue: "Settings…"),
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu?.addItem(settingsItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        let debugToggleItem = NSMenuItem(
            title: "Toggle Free/Premium (Debug)",
            action: #selector(debugToggleLicense),
            keyEquivalent: "t"
        )
        debugToggleItem.keyEquivalentModifierMask = [.command, .option]
        debugToggleItem.target = self
        menu?.addItem(debugToggleItem)
        menu?.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: String(localized: "menu.quit", defaultValue: "Quit"),
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu?.addItem(quitItem)
    }
    
    func updateState(_ state: KnobGlobalState, targetName: String? = nil) {
        PKLogger.statusBar.info("updateState called with state: \(String(describing: state))")
        self.currentState = state
        self.targetName = targetName
        
        if let button = statusItem?.button {
            let newImage = createIcon(for: state)
            newImage?.isTemplate = true
            button.image = newImage
            button.toolTip = createTooltip(for: state, targetName: targetName)
            PKLogger.statusBar.info("Image updated, isTemplate: \(newImage?.isTemplate ?? false)")
        }
        
        if let menu = menu, let firstItem = menu.items.first {
            let format = String(localized: "menu.status.format", defaultValue: "Status: %@")
            firstItem.title = String(format: format, stateDescription(for: state, targetName: targetName))
        }
        
        updateVersionItem()
    }
    
    func updateVersionItem(timeRemaining: Double? = nil) {
        let licenseState = LicenseManager.shared.currentState
        let title: String
        switch licenseState {
        case .licensed:
            title = String(localized: "menu.license.premium", defaultValue: "License: Premium")
        case .trialing(let days):
            let format = String(localized: "menu.license.trial", defaultValue: "License: Trial (%d days remaining)")
            title = String(format: format, days)
        case .free:
            let prefix = String(localized: "menu.license.free", defaultValue: "License: Free Edition")
            if let time = timeRemaining {
                let minutes = Int(time) / 60
                let seconds = Int(time) % 60
                let format = String(localized: "menu.session.remaining", defaultValue: "Session Remaining: %02d:%02d")
                let sessionStr = String(format: format, minutes, seconds)
                title = "\(prefix) (\(sessionStr))"
            } else {
                let limitStr = String(localized: "menu.session.limit", defaultValue: "Session Limit: 15 minutes")
                title = "\(prefix) (\(limitStr))"
            }
        }
        
        versionMenuItem?.title = title
    }
    
    func updateStateActivating(secondsRemaining: Double) {
        if let button = statusItem?.button {
            let symbolImage = NSImage(systemSymbolName: "circle.dashed", accessibilityDescription: nil)
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            let finalImage = symbolImage?.withSymbolConfiguration(config) ?? symbolImage
            finalImage?.isTemplate = true
            button.image = finalImage
            
            let format = String(localized: "tooltip.activating", defaultValue: "Activating in %ds...")
            button.toolTip = String(format: format, Int(ceil(secondsRemaining)))
        }
        
        if let menu = menu, let firstItem = menu.items.first {
            firstItem.title = String(localized: "status.activating", defaultValue: "Status: Activating...")
        }
        
        updateVersionItem()
    }
    
    private var pendingMenuWorkItem: DispatchWorkItem?
    
    @objc func statusBarButtonClicked() {
        handleStatusItemClick(event: NSApp.currentEvent)
    }
    
    func handleStatusItemClick(event: NSEvent?) {
        guard let ev = event else {
            if let menu = menu {
                statusItem?.popUpMenu(menu)
            }
            return
        }
        
        if ev.clickCount == 2 {
            pendingMenuWorkItem?.cancel()
            pendingMenuWorkItem = nil
            KnobPanelWindowController.shared.toggle()
        } else if ev.clickCount == 1 {
            pendingMenuWorkItem?.cancel()
            
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                if let menu = self.menu {
                    self.statusItem?.popUpMenu(menu)
                }
                self.pendingMenuWorkItem = nil
            }
            pendingMenuWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
        }
    }
    
    @objc private func toggleMode() {
        PKLogger.statusBar.info("toggleMode menu item clicked")
        onToggleHotkey?()
    }
    
    @objc func openSettings() {
        PKLogger.statusBar.info("openSettings() clicked, showing custom settings window")
        SettingsWindowController.shared.show()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc private func openGuide() {
        UserGuideWindowController.shared.show()
    }
    
    private func createIcon(for state: KnobGlobalState) -> NSImage? {
        let name: String
        switch state {
        case .inactive: name = "statusbar_inactive"
        case .activated: name = "statusbar_activated"
        case .knobing, .cooling: name = "statusbar_knobing"
        case .customizing: name = "statusbar_inactive"
        }
        let image = NSImage(named: name)
        image?.isTemplate = true
        return image
    }
    
    private func createTooltip(for state: KnobGlobalState, targetName: String?) -> String {
        switch state {
        case .inactive:
            return String(localized: "tooltip.inactive", defaultValue: "Knob Control: Inactive (Press \(HotkeySettings.shared.displayString) to activate)")
        case .activated:
            return String(localized: "tooltip.activated", defaultValue: "Knob Control: Active, waiting for gesture")
        case .knobing:
            if let name = targetName {
                let format = String(localized: "tooltip.knobing.withTarget", defaultValue: "Knob Control: Controlling %@")
                return String(format: format, name)
            }
            return String(localized: "tooltip.knobing", defaultValue: "Knob Control: Controlling")
        case .cooling:
            if let name = targetName {
                let format = String(localized: "tooltip.cooling.withTarget", defaultValue: "Knob Control: Cooling down (%@)")
                return String(format: format, name)
            }
            return String(localized: "tooltip.cooling", defaultValue: "Knob Control: Cooling down")
        case .customizing:
            return String(localized: "tooltip.customizing", defaultValue: "Knob Control: Customizing")
        }
    }
    
    private func stateDescription(for state: KnobGlobalState, targetName: String?) -> String {
        switch state {
        case .inactive:
            return String(localized: "state.inactive", defaultValue: "Inactive")
        case .activated:
            return String(localized: "state.activated", defaultValue: "Active")
        case .knobing:
            if let name = targetName {
                let format = String(localized: "state.knobing.withTarget", defaultValue: "Controlling - %@")
                return String(format: format, name)
            }
            return String(localized: "state.knobing", defaultValue: "Controlling")
        case .cooling:
            if let name = targetName {
                let format = String(localized: "state.cooling.withTarget", defaultValue: "Cooling - %@")
                return String(format: format, name)
            }
            return String(localized: "state.cooling", defaultValue: "Cooling down")
        case .customizing:
            return String(localized: "state.customizing", defaultValue: "Customizing")
        }
    }
    
    @objc func debugToggleLicense() {
        LicenseManager.shared.debugToggleLicense()
    }
}
