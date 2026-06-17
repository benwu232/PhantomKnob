import AppKit
import SwiftUI

class StatusBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var globalHotkeyMonitor: Any?
    private var localHotkeyMonitor: Any?
    
    @Published var currentState: KnobGlobalState = .inactive
    @Published var targetName: String?
    
    var onToggleHotkey: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    
    init() {
        NSLog("[StatusBarController] init() called")
        setupStatusBar()
        setupGlobalHotkey()
        setupLocalHotkey()
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
    
    private func setupLocalHotkey() {
        localHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            writeDebugLog("[StatusBarController] Local keyDown: keyCode=\(event.keyCode) modifiers=\(event.modifierFlags.rawValue) charsIgnoringModifiers=\(event.charactersIgnoringModifiers ?? "") chars=\(event.characters ?? "")")
            if event.keyCode == 49 && event.modifierFlags.contains(.option) {
                KnobPanelWindowController.shared.toggle()
                return nil
            }
            if event.keyCode == 15 {
                let hasCmdOpt = event.modifierFlags.contains([.command, .option])
                let hasCtrlOpt = event.modifierFlags.contains([.control, .option])
                if hasCmdOpt || hasCtrlOpt {
                    writeDebugLog("[StatusBarController] Local hotkey detected")
                    self?.toggleMode()
                    return nil
                }
            }
            return event
        }
        NSLog("[StatusBarController] Local hotkey monitor installed")
    }
    
    private func setupGlobalHotkey() {
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            writeDebugLog("[StatusBarController] Global keyDown: keyCode=\(event.keyCode) modifiers=\(event.modifierFlags.rawValue) charsIgnoringModifiers=\(event.charactersIgnoringModifiers ?? "") chars=\(event.characters ?? "")")
            if event.keyCode == 49 && event.modifierFlags.contains(.option) {
                KnobPanelWindowController.shared.toggle()
                return
            }
            if event.keyCode == 15 {
                let hasCmdOpt = event.modifierFlags.contains([.command, .option])
                let hasCtrlOpt = event.modifierFlags.contains([.control, .option])
                if hasCmdOpt || hasCtrlOpt {
                    writeDebugLog("[StatusBarController] Global hotkey detected")
                    self?.toggleMode()
                }
            }
        }
        NSLog("[StatusBarController] Global hotkey monitor installed")
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = createIcon(for: .inactive)
            button.image?.isTemplate = true
            button.toolTip = "Knob 控制：未激活（按 ⌘⌥R 激活）"
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        menu = NSMenu()
        
        let statusMenuItem = NSMenuItem(title: "状态：未激活", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu?.addItem(statusMenuItem)
        
        let guideMenuItem = NSMenuItem(title: "使用引导...", action: #selector(openGuide), keyEquivalent: "")
        guideMenuItem.target = self
        menu?.addItem(guideMenuItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        let toggleItem = NSMenuItem(
            title: "切换控制模式",
            action: #selector(toggleMode),
            keyEquivalent: "r"
        )
        toggleItem.keyEquivalentModifierMask = [.command, .option]
        toggleItem.target = self
        menu?.addItem(toggleItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(
            title: "设置...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu?.addItem(settingsItem)
        
        menu?.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu?.addItem(quitItem)
    }
    
    func updateState(_ state: KnobGlobalState, targetName: String? = nil) {
        NSLog("[StatusBarController] updateState called with state: \(state)")
        self.currentState = state
        self.targetName = targetName
        
        if let button = statusItem?.button {
            let newImage = createIcon(for: state)
            newImage?.isTemplate = (state == .inactive)
            button.image = newImage
            button.toolTip = createTooltip(for: state, targetName: targetName)
            NSLog("[StatusBarController] Image updated, isTemplate: \(newImage?.isTemplate ?? false)")
        }
        
        if let menu = menu, let firstItem = menu.items.first {
            firstItem.title = "状态：\(stateDescription(for: state, targetName: targetName))"
        }
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
        NSLog("[StatusBarController] toggleMode menu item clicked")
        onToggleHotkey?()
    }
    
    @objc private func openSettings() {
        onOpenSettings?()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    @objc private func openGuide() {
        UserGuideWindowController.shared.show()
    }
    
    private func createIcon(for state: KnobGlobalState) -> NSImage? {
        // Use SF Symbol for better visibility
        let symbolName: String
        switch state {
        case .inactive: symbolName = "circle"
        case .activated: symbolName = "circle.fill"
        case .knobing, .cooling: symbolName = "circle.lefthalf.fill"
        case .customizing: symbolName = "circle.dashed"
        }
        
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            return image.withSymbolConfiguration(config) ?? image
        }
        
        // Fallback: create a larger circle
        let size = NSSize(width: 20, height: 20)
        let image = NSImage(size: size)
        
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
        NSColor.gray.setFill()
        path.fill()
        image.unlockFocus()
        
        return image
    }
    
    private func createTooltip(for state: KnobGlobalState, targetName: String?) -> String {
        switch state {
        case .inactive:
            return "Knob 控制：未激活（按 ⌘⌥R 激活）"
        case .activated:
            return "Knob 控制：已激活，等待手势"
        case .knobing:
            if let name = targetName {
                return "Knob 控制：正在控制 \(name)"
            }
            return "Knob 控制：正在控制"
        case .cooling:
            if let name = targetName {
                return "Knob 控制：冷却中 (\(name))"
            }
            return "Knob 控制：冷却中"
        case .customizing:
            return "Knob 控制：定制中"
        }
    }
    
    private func stateDescription(for state: KnobGlobalState, targetName: String?) -> String {
        switch state {
        case .inactive: return "未激活"
        case .activated: return "已激活"
        case .knobing:
            if let name = targetName { return "控制中 - \(name)" }
            return "控制中"
        case .cooling:
            if let name = targetName { return "冷却中 - \(name)" }
            return "冷却中"
        case .customizing: return "定制中"
        }
    }
}
