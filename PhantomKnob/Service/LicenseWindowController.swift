import AppKit
import SwiftUI

public class LicenseWindow: NSWindow {
    public override var canBecomeKey: Bool { return true }
}

public class LicenseWindowController: NSObject, NSWindowDelegate {
    public static let shared = LicenseWindowController()
    
    private var window: LicenseWindow?
    
    public var isVisible: Bool {
        return window?.isVisible ?? false
    }
    
    public func show() {
        if window == nil {
            createWindow()
        }
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func hide() {
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func createWindow() {
        let width: CGFloat = 480
        let height: CGFloat = 360
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let originX = screenFrame.origin.x + (screenFrame.width - width) / 2
        let originY = screenFrame.origin.y + (screenFrame.height - height) / 2
        
        let contentRect = NSRect(x: originX, y: originY, width: width, height: height)
        let win = LicenseWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isMovableByWindowBackground = true
        win.appearance = NSAppearance(named: .darkAqua)
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
        
        let hostingView = NSHostingView(rootView: LicenseWindowView())
        hostingView.frame = visualEffectView.bounds
        hostingView.autoresizingMask = [.width, .height]
        visualEffectView.addSubview(hostingView)
        
        self.window = win
    }
    
    public func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
