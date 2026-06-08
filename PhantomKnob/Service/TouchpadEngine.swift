import AppKit

protocol TouchpadEventDelegate: AnyObject {
    func onTouchesBegan(_ touches: Set<NSTouch>)
    func onTouchesMoved(_ touches: Set<NSTouch>)
    func onTouchesEnded(_ touches: Set<NSTouch>)
}

class TouchpadEngine {
    weak var delegate: TouchpadEventDelegate?
    
    init() {}
    
    func processTouchesBegan(_ touches: Set<NSTouch>) {
        delegate?.onTouchesBegan(touches)
    }
    
    func processTouchesMoved(_ touches: Set<NSTouch>) {
        delegate?.onTouchesMoved(touches)
    }
    
    func processTouchesEnded(_ touches: Set<NSTouch>) {
        delegate?.onTouchesEnded(touches)
    }
}
