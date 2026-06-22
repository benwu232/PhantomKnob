import AppKit
import SwiftUI

class SettingsWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
}

class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    
    private var window: SettingsWindow?
    private var localClickMonitor: Any?
    
    var isVisible: Bool {
        return window?.isVisible ?? false
    }
    
    func show() {
        if window == nil {
            createWindow()
        }
        
        // Elevate activation policy to .regular so the settings window can get focus and show up in Dock/App Switcher
        NSLog("[SettingsWindowController] Elevating activation policy to .regular to show settings window")
        NSApp.setActivationPolicy(.regular)
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        setupClickMonitor()
        
        NotificationCenter.default.post(name: NSNotification.Name("SettingsPanelDidShow"), object: nil)
    }
    
    func hide() {
        window?.orderOut(nil)
        removeClickMonitor()
        NSLog("[SettingsWindowController] Settings window closing, reverting activation policy to .accessory")
        NSApp.setActivationPolicy(.accessory)
        
        NotificationCenter.default.post(name: NSNotification.Name("SettingsPanelDidHide"), object: nil)
    }
    
    private func createWindow() {
        let width: CGFloat = 480
        let height: CGFloat = 360 // Accommodate tabs and custom content
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let originX = screenFrame.origin.x + (screenFrame.width - width) / 2
        let originY = screenFrame.origin.y + (screenFrame.height - height) / 2
        
        let contentRect = NSRect(x: originX, y: originY, width: width, height: height)
        let win = SettingsWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        win.backgroundColor = .clear
        win.isOpaque = false
        win.level = .floating
        win.hidesOnDeactivate = true
        win.delegate = self
        
        // Blurred backdrop (Glassmorphism)
        let visualEffectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: contentRect.size))
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 20
        visualEffectView.layer?.masksToBounds = true
        
        win.contentView = visualEffectView
        
        let hostingView = NSHostingView(rootView: SettingsView())
        hostingView.frame = visualEffectView.bounds
        hostingView.autoresizingMask = [.width, .height]
        visualEffectView.addSubview(hostingView)
        
        self.window = win
    }
    
    private func setupClickMonitor() {
        removeClickMonitor()
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let win = self.window else { return event }
            let clickLocation = NSEvent.mouseLocation
            let windowFrame = win.frame
            if !NSPointInRect(clickLocation, windowFrame) {
                DispatchQueue.main.async {
                    self.hide()
                }
            }
            return event
        }
    }
    
    private func removeClickMonitor() {
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
    }
    
    // MARK: - NSWindowDelegate
    
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
