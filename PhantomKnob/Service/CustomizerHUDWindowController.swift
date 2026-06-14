import AppKit
import SwiftUI

class CustomizerWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
}

class CustomizerHUDWindowController: NSObject, NSWindowDelegate {
    static let shared = CustomizerHUDWindowController()
    
    private var window: CustomizerWindow?
    private var localClickMonitor: Any?
    
    var isVisible: Bool {
        return window?.isVisible ?? false
    }
    
    func show(for target: DetectedTarget) {
        if window == nil {
            createWindow(for: target)
        } else {
            // 动态更新 SwiftUI RootView 的 target
            if let visualView = window?.contentView as? NSVisualEffectView,
               let hostingView = visualView.subviews.first(where: { $0 is NSHostingView<CustomizerHUDView> }) as? NSHostingView<CustomizerHUDView> {
                hostingView.rootView = CustomizerHUDView(target: target)
            }
            
            // 动态更新窗口位置到最新的光标处并做边界约束
            updateWindowPosition()
        }
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        setupClickMonitor()
        
        NotificationCenter.default.removeObserver(self, name: NSApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDeactivate),
            name: NSApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    func hide() {
        window?.orderOut(nil)
        removeClickMonitor()
        NotificationCenter.default.removeObserver(self, name: NSApplication.willResignActiveNotification, object: nil)
        
        // 通知状态机恢复激活就绪状态
        NotificationCenter.default.post(name: NSNotification.Name("KnobPanelDidHide"), object: nil)
    }
    
    @objc private func handleAppDeactivate() {
        if NSColorPanel.shared.isVisible {
            NSColorPanel.shared.orderOut(nil)
        }
        hide()
    }
    
    private func calculateWindowFrame() -> NSRect {
        let width: CGFloat = 400
        let height: CGFloat = 520
        let mouseLoc = NSEvent.mouseLocation
        
        // 寻找包含光标的屏幕，支持多屏显示
        let screens = NSScreen.screens
        let screen = screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? screens.first
        let screenFrame = screen?.visibleFrame ?? .zero
        
        var originX = mouseLoc.x + 30
        var originY = mouseLoc.y - height - 30
        
        // 如果右侧溢出，镜像翻转到光标左侧
        if originX + width > screenFrame.maxX {
            originX = mouseLoc.x - width - 30
        }
        // 如果底部溢出，镜像翻转到光标上方
        if originY < screenFrame.minY {
            originY = mouseLoc.y + 30
        }
        
        // 最后进行严格约束，确保 100% 不超出当前屏幕的安全区域
        originX = max(screenFrame.minX, min(originX, screenFrame.maxX - width))
        originY = max(screenFrame.minY, min(originY, screenFrame.maxY - height))
        
        return NSRect(x: originX, y: originY, width: width, height: height)
    }
    
    private func updateWindowPosition() {
        guard let win = window else { return }
        let newFrame = calculateWindowFrame()
        win.setFrame(newFrame, display: true)
    }
    
    private func createWindow(for target: DetectedTarget) {
        let contentRect = calculateWindowFrame()
        
        let win = CustomizerWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        win.backgroundColor = .clear
        win.isOpaque = false
        win.level = .statusBar
        win.hidesOnDeactivate = true
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
        
        let hostingView = NSHostingView(rootView: CustomizerHUDView(target: target))
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
            
            let clickedInHUD = NSPointInRect(clickLocation, win.frame)
            let clickedInColorPanel = NSColorPanel.shared.isVisible && NSPointInRect(clickLocation, NSColorPanel.shared.frame)
            
            if clickedInHUD {
                // 点击在定制 HUD 面板内：如果系统调色板打开，则自动关闭调色板
                if NSColorPanel.shared.isVisible {
                    NSColorPanel.shared.orderOut(nil)
                }
                return event
            } else if clickedInColorPanel {
                // 点击在调色板内：保持开启
                return event
            } else {
                // 点击在两者之外：关闭调色板并隐藏 HUD 面板
                if NSColorPanel.shared.isVisible {
                    NSColorPanel.shared.orderOut(nil)
                }
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 如果新成为 Key 窗口的是系统调色板，则不隐藏定制 HUD 面板
            if NSApp.keyWindow == NSColorPanel.shared {
                return
            }
            // 否则，隐藏两者
            if NSColorPanel.shared.isVisible {
                NSColorPanel.shared.orderOut(nil)
            }
            self.hide()
        }
    }
}
