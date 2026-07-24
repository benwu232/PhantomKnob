import AppKit
import SwiftUI

class UserGuideWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
}

class UserGuideWindowController: NSObject, NSWindowDelegate {
    static let shared = UserGuideWindowController()
    
    private var window: UserGuideWindow?
    private var localClickMonitor: Any?
    var isPinned: Bool = false
    var initialStep: Int = 1
    weak var viewModel: UserGuideViewModel?
    
    var isVisible: Bool {
        return window?.isVisible ?? false
    }
    
    func show(step: Int? = nil) {
        self.initialStep = step ?? 1
        
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
        
        NotificationCenter.default.post(name: NSNotification.Name("UserGuideWindowDidShow"), object: nil)
        // 通知状态机开启临时拦截
        NotificationCenter.default.post(name: NSNotification.Name("KnobPanelDidShow"), object: nil)
    }
    
    func hide() {
        window?.orderOut(nil)
        removeClickMonitor()
        
        // 通知状态机还原拦截
        NotificationCenter.default.post(name: NSNotification.Name("KnobPanelDidHide"), object: nil)
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
        let width: CGFloat = 725
        let height: CGFloat = 575
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let originX = screenFrame.origin.x + (screenFrame.width - width) / 2
        let originY = screenFrame.origin.y + (screenFrame.height - height) / 2
        
        let contentRect = NSRect(x: originX, y: originY, width: width, height: height)
        let win = UserGuideWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isMovableByWindowBackground = true
        
        win.backgroundColor = .clear
        win.isOpaque = false
        win.level = .floating
        win.hidesOnDeactivate = true
        win.delegate = self
        
        let visualEffectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: contentRect.size))
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 20
        visualEffectView.layer?.masksToBounds = true
        
        win.contentView = visualEffectView
        
        let hostingView = NSHostingView(rootView: UserGuideView())
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
        if CustomizerHUDWindowController.shared.isVisible || NSColorPanel.shared.isVisible {
            return
        }
        if !isPinned {
            hide()
        }
    }
}
