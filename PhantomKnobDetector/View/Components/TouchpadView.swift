import AppKit
import SwiftUI

class TouchpadView: NSView {
    weak var touchDelegate: TouchpadEventDelegate?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsRestingTouches = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsRestingTouches = true
    }
    
    override func touchesBegan(with event: NSEvent) {
        let touches = event.touches(matching: .touching, in: self)
        touchDelegate?.onTouchesBegan(touches)
    }
    
    override func touchesMoved(with event: NSEvent) {
        let touches = event.touches(matching: .touching, in: self)
        touchDelegate?.onTouchesMoved(touches)
    }
    
    override func touchesEnded(with event: NSEvent) {
        let touches = event.touches(matching: .touching, in: self)
        touchDelegate?.onTouchesEnded(touches)
    }
    
    override func touchesCancelled(with event: NSEvent) {
        let touches = event.touches(matching: .touching, in: self)
        touchDelegate?.onTouchesEnded(touches)
    }
}

struct TouchpadViewWrapper: NSViewRepresentable {
    let delegate: TouchpadEventDelegate
    
    func makeNSView(context: Context) -> TouchpadView {
        let view = TouchpadView()
        view.touchDelegate = delegate
        return view
    }
    
    func updateNSView(_ nsView: TouchpadView, context: Context) {
        nsView.touchDelegate = delegate
    }
}
