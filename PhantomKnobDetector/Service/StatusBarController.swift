import AppKit
import SwiftUI

class StatusBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    
    @Published var currentState: KnobGlobalState = .inactive
    @Published var targetName: String?
    
    var onToggleHotkey: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    
    init() {
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = createIcon(for: .inactive)
            button.image?.isTemplate = true
            button.toolTip = "Knob 控制：未激活（按 ⌘⇧K 激活）"
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
        
        menu?.addItem(NSMenuItem.separator())
        
        let toggleItem = NSMenuItem(
            title: "切换控制模式",
            action: #selector(toggleMode),
            keyEquivalent: "k"
        )
        toggleItem.keyEquivalentModifierMask = [.command, .shift]
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
        
        statusItem?.menu = menu
    }
    
    func updateState(_ state: KnobGlobalState, targetName: String? = nil) {
        self.currentState = state
        self.targetName = targetName
        
        if let button = statusItem?.button {
            button.image = createIcon(for: state)
            button.toolTip = createTooltip(for: state, targetName: targetName)
        }
        
        if let menu = menu, let firstItem = menu.items.first {
            firstItem.title = "状态：\(stateDescription(for: state, targetName: targetName))"
        }
    }
    
    @objc private func statusBarButtonClicked() {
        onToggleHotkey?()
    }
    
    @objc private func toggleMode() {
        onToggleHotkey?()
    }
    
    @objc private func openSettings() {
        onOpenSettings?()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    private func createIcon(for state: KnobGlobalState) -> NSImage? {
        let color: NSColor
        switch state {
        case .inactive: color = .gray
        case .activated: color = .systemBlue
        case .knobing, .cooling: color = .systemOrange
        }
        
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(ovalIn: rect.insetBy(dx: 3, dy: 3))
        color.setFill()
        path.fill()
        image.unlockFocus()
        
        return image
    }
    
    private func createTooltip(for state: KnobGlobalState, targetName: String?) -> String {
        switch state {
        case .inactive:
            return "Knob 控制：未激活（按 ⌘⇧K 激活）"
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
        }
    }
}
