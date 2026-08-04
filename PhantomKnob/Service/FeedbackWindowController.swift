import AppKit
import SwiftUI
import os

class FeedbackWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
}

class FeedbackWindowController: NSObject, NSWindowDelegate {
    static let shared = FeedbackWindowController()
    
    private var window: FeedbackWindow?
    
    var isVisible: Bool {
        return window?.isVisible ?? false
    }
    
    func show() {
        if window == nil {
            createWindow()
        }
        
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hide() {
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func createWindow() {
        let width: CGFloat = 480
        let height: CGFloat = 380
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let originX = screenFrame.origin.x + (screenFrame.width - width) / 2
        let originY = screenFrame.origin.y + (screenFrame.height - height) / 2
        
        let contentRect = NSRect(x: originX, y: originY, width: width, height: height)
        let win = FeedbackWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.appearance = NSAppearance(named: .darkAqua)
        win.backgroundColor = .clear
        win.isOpaque = false
        win.level = .normal
        win.delegate = self
        
        let visualEffectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: contentRect.size))
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 16
        visualEffectView.layer?.masksToBounds = true
        
        win.contentView = visualEffectView
        
        let hostingView = NSHostingView(rootView: FeedbackView())
        hostingView.frame = visualEffectView.bounds
        hostingView.autoresizingMask = [.width, .height]
        visualEffectView.addSubview(hostingView)
        
        self.window = win
    }
    
    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        hide()
    }
}
