import AppKit
import SwiftUI


class KnobPanelWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        let keyCode = event.keyCode
        if keyCode == 123 { // Left arrow
            ControlPanelViewModel.shared.selectPrevVariable()
        } else if keyCode == 124 { // Right arrow
            ControlPanelViewModel.shared.selectNextVariable()
        } else if keyCode == 48 { // Tab key
            if event.modifierFlags.contains(.shift) {
                ControlPanelViewModel.shared.selectPrevVariable()
            } else {
                ControlPanelViewModel.shared.selectNextVariable()
            }
        } else {
            super.keyDown(with: event)
        }
    }
}

class KnobPanelWindowController: NSObject, NSWindowDelegate {
    static let shared = KnobPanelWindowController()
    
    var window: KnobPanelWindow?
    private var localClickMonitor: Any?
    var isPinned: Bool = false
    
    var isVisible: Bool {
        return window?.isVisible ?? false
    }
    
    func show() {
        if window == nil {
            createWindow()
        }
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        if isPinned {
            window?.hidesOnDeactivate = false
            removeClickMonitor()
        } else {
            window?.hidesOnDeactivate = true
            setupClickMonitor()
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("KnobPanelDidShow"), object: nil)
    }
    
    func hide() {
        window?.orderOut(nil)
        removeClickMonitor()
        NotificationCenter.default.post(name: NSNotification.Name("KnobPanelDidHide"), object: nil)
    }
    
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
    
    func setPinned(_ pinned: Bool) {
        self.isPinned = pinned
        if let win = window {
            if pinned {
                win.hidesOnDeactivate = false
                removeClickMonitor()
            } else {
                win.hidesOnDeactivate = true
                setupClickMonitor()
            }
        }
    }
    
    private func createWindow() {
        let width: CGFloat = 720
        let height: CGFloat = 420
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let originX = screenFrame.origin.x + (screenFrame.width - width) / 2
        let originY = screenFrame.origin.y + (screenFrame.height - height) / 2
        
        let contentRect = NSRect(x: originX, y: originY, width: width, height: height)
        let win = KnobPanelWindow(
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
        win.isMovableByWindowBackground = true
        
        // 毛玻璃特效
        let visualEffectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: contentRect.size))
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.autoresizingMask = [.width, .height]
        
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 20
        visualEffectView.layer?.masksToBounds = true
        
        win.contentView = visualEffectView
        
        // 嵌入 SwiftUI 视图
        let hostingView = NSHostingView(rootView: KnobPanelView().environmentObject(ControlPanelViewModel.shared))
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
    
    func windowDidResignKey(_ notification: Notification) {
        if !isPinned {
            hide()
        }
    }
}
