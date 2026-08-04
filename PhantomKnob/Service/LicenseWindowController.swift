import AppKit
import SwiftUI

public class LicenseWindow: NSWindow {
    public override var canBecomeKey: Bool { return true }
}

public class LicenseWindowController: NSObject, NSWindowDelegate {
    public static let shared = LicenseWindowController()
    
    private var window: LicenseWindow?
    private var localClickMonitor: Any?
    
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
        setupClickMonitor()
        NotificationCenter.default.post(name: NSNotification.Name("LicenseWindowDidShow"), object: nil)
    }
    
    public func hide() {
        window?.orderOut(nil)
        removeClickMonitor()
        NSApp.setActivationPolicy(.accessory)
        NotificationCenter.default.post(name: NSNotification.Name("LicenseWindowDidHide"), object: nil)
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
        let isTesting = NSClassFromString("XCTestCase") != nil
        if isTesting { return }
        hide()
    }
}
