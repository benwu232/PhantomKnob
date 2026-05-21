import AppKit
import Foundation

protocol GlobalTouchDelegate: AnyObject {
    func onGlobalTouchesBegan(_ touches: Set<NSTouch>)
    func onGlobalTouchesMoved(_ touches: Set<NSTouch>)
    func onGlobalTouchesEnded(_ touches: Set<NSTouch>)
}

class GlobalTouchHandler {
    weak var delegate: GlobalTouchDelegate?
    
    private var eventMonitor: Any?
    private var isMonitoring = false
    
    func startMonitoring() {
        writeDebugLog("[GlobalTouchHandler] startMonitoring() called, isMonitoring: \(isMonitoring)")
        guard !isMonitoring else { return }
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.gesture, .indirectTouches]
        ) { [weak self] event in
            self?.handleEvent(event)
        }
        
        isMonitoring = true
    }
    
    func stopMonitoring() {
        writeDebugLog("[GlobalTouchHandler] stopMonitoring() called, isMonitoring: \(isMonitoring)")
        guard isMonitoring, let monitor = eventMonitor else { return }
        
        NSEvent.removeMonitor(monitor)
        eventMonitor = nil
        isMonitoring = false
    }
    
    private func handleEvent(_ event: NSEvent) {
        writeDebugLog("[GlobalTouchHandler] handleEvent: type = \(event.type)")
        switch event.type {
        case .gesture:
            handleGestureEvent(event)
        case .indirectTouches:
            handleTouchEvent(event)
        default:
            break
        }
    }
    
    private func handleGestureEvent(_ event: NSEvent) {
        writeDebugLog("[GlobalTouchHandler] handleGestureEvent: phase = \(event.phase.rawValue)")
        switch event.phase {
        case .began:
            let touches = event.touches(matching: .any, in: nil)
            writeDebugLog("[GlobalTouchHandler] began, touches count: \(touches.count)")
            delegate?.onGlobalTouchesBegan(touches)
        case .changed:
            let touches = event.touches(matching: .any, in: nil)
            delegate?.onGlobalTouchesMoved(touches)
        case .ended, .cancelled:
            let touches = event.touches(matching: .any, in: nil)
            writeDebugLog("[GlobalTouchHandler] ended/cancelled, touches count: \(touches.count)")
            delegate?.onGlobalTouchesEnded(touches)
        default:
            break
        }
    }
    
    private func handleTouchEvent(_ event: NSEvent) {
        writeDebugLog("[GlobalTouchHandler] handleTouchEvent: phase = \(event.phase.rawValue)")
        let touches = event.touches(matching: .any, in: nil)
        switch event.phase {
        case .began:
            writeDebugLog("[GlobalTouchHandler] touch began, touches count: \(touches.count)")
            delegate?.onGlobalTouchesBegan(touches)
        case .changed:
            delegate?.onGlobalTouchesMoved(touches)
        case .ended, .cancelled:
            writeDebugLog("[GlobalTouchHandler] touch ended/cancelled, touches count: \(touches.count)")
            delegate?.onGlobalTouchesEnded(touches)
        default:
            break
        }
    }
    
    deinit {
        stopMonitoring()
    }
}
