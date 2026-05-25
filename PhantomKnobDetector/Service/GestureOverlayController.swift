import AppKit
import Foundation

protocol GestureOverlayDelegate: AnyObject {
    func onOverlayTouchesBegan(points: [Int: CGPoint])
    func onOverlayTouchesMoved(points: [Int: CGPoint])
    func onOverlayTouchesEnded()
    func onOverlayClickThrough(event: NSEvent)
}

class TouchCaptureView: NSView {
    weak var delegate: GestureOverlayDelegate?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.allowedTouchTypes = [.indirect] // 只接收触控板触控
        self.wantsRestingTouches = true      // 接收静止的手指
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // 捕获双指触控坐标
    private func extractPoints(from event: NSEvent) -> [Int: CGPoint] {
        var points: [Int: CGPoint] = [:]
        let touches = event.touches(matching: .any, in: self)
        for touch in touches {
            if touch.phase == .touching || touch.phase == .began || touch.phase == .moved {
                let pos = touch.normalizedPosition
                guard !pos.x.isNaN && !pos.y.isNaN else { continue }
                let stableId = ObjectIdentifier(touch.identity).hashValue
                points[stableId] = CGPoint(x: pos.x, y: pos.y)
            }
        }
        return points
    }
    
    override func touchesBegan(with event: NSEvent) {
        let points = extractPoints(from: event)
        if points.count >= 2 {
            delegate?.onOverlayTouchesBegan(points: points)
        }
    }
    
    override func touchesMoved(with event: NSEvent) {
        let points = extractPoints(from: event)
        if points.count >= 2 {
            delegate?.onOverlayTouchesMoved(points: points)
        }
    }
    
    override func touchesEnded(with event: NSEvent) {
        delegate?.onOverlayTouchesEnded()
    }
    
    override func touchesCancelled(with event: NSEvent) {
        delegate?.onOverlayTouchesEnded()
    }
    
    // 鼠标点击事件拦截与穿透通知
    override func mouseDown(with event: NSEvent) {
        delegate?.onOverlayClickThrough(event: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        delegate?.onOverlayClickThrough(event: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        delegate?.onOverlayClickThrough(event: event)
    }
}

class GestureOverlayController: NSObject, GestureOverlayDelegate {
    weak var delegate: GestureOverlayDelegate?
    
    private var panel: NSPanel?
    private var captureView: TouchCaptureView?
    private var isVisible = false
    
    func show() {
        guard !isVisible else { return }
        
        if panel == nil {
            createPanel()
        }
        
        // 获取当前包含鼠标的主屏幕大小进行全屏铺满
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        panel?.setFrame(screenFrame, display: true)
        panel?.ignoresMouseEvents = false // 激活拦截以捕捉多指
        panel?.orderFrontRegardless()
        
        isVisible = true
    }
    
    func hide() {
        guard isVisible else { return }
        panel?.orderOut(nil)
        isVisible = false
    }
    
    func tempDisableInterception(durationMs: Int = 5) {
        panel?.ignoresMouseEvents = true
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(durationMs)) { [weak self] in
            self?.panel?.ignoresMouseEvents = false
        }
    }
    
    private func createPanel() {
        let p = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel], // 极其关键：无边框且完全不抢焦点
            backing: .buffered,
            defer: false
        )
        p.level = .statusBar // 置于状态栏层，确保处于全局最顶层
        p.isOpaque = false
        p.backgroundColor = .clear // 完全透明无色
        p.hasShadow = false
        p.ignoresMouseEvents = false
        
        let view = TouchCaptureView(frame: .zero)
        view.delegate = self
        p.contentView = view
        
        self.panel = p
        self.captureView = view
    }
    
    // MARK: - GestureOverlayDelegate forwards
    
    func onOverlayTouchesBegan(points: [Int: CGPoint]) {
        delegate?.onOverlayTouchesBegan(points: points)
    }
    
    func onOverlayTouchesMoved(points: [Int: CGPoint]) {
        delegate?.onOverlayTouchesMoved(points: points)
    }
    
    func onOverlayTouchesEnded() {
        delegate?.onOverlayTouchesEnded()
    }
    
    func onOverlayClickThrough(event: NSEvent) {
        delegate?.onOverlayClickThrough(event: event)
    }
}
