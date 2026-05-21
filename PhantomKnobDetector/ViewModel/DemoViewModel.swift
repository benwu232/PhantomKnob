import Foundation
import SwiftUI
import AppKit

class DemoViewModel: ObservableObject, TouchpadEventDelegate {
    @Published var knobAngle: Double = 0
    @Published var displayValue: Double = 50.0
    @Published var isActive: Bool = false
    @Published var centerX: Double = 0
    @Published var centerY: Double = 0
    @Published var radius: Double = 0
    
    private let touchpadEngine = TouchpadEngine()
    private let knobAlgorithm = KnobAlgorithm()
    private var controlTarget: ControlTarget
    private var previousKnob: KnobCore = .invalid
    
    init() {
        self.controlTarget = DemoSliderTarget()
        touchpadEngine.delegate = self
    }
    
    func onTouchesBegan(_ touches: Set<NSTouch>) {
        handleTouchUpdate(touches)
    }
    
    func onTouchesMoved(_ touches: Set<NSTouch>) {
        handleTouchUpdate(touches)
    }
    
    func onTouchesEnded(_ touches: Set<NSTouch>) {
        if touches.count < 2 {
            isActive = false
        }
    } 
    
    private func handleTouchUpdate(_ touches: Set<NSTouch>) {
        guard touches.count >= 2 else { return }
        
        var points: [Int: CGPoint] = [:]
        for touch in touches {
            let pos = touch.normalizedPosition
            guard !pos.x.isNaN && !pos.y.isNaN else { continue }
            // Use touch.identity for a stable key across events — the same
            // physical finger always gets the same ID, so fingerIdx1 = min(id1,id2)
            // in KnobAlgorithm always refers to the same finger and the angle
            // vector never flips direction mid-gesture.
            let stableId = ObjectIdentifier(touch.identity).hashValue
            points[stableId] = CGPoint(x: pos.x, y: pos.y)
        }
        
        guard points.count >= 2 else { return }
        
        let (currentKnob, _, _) = knobAlgorithm.calKnob(points)
        guard currentKnob.isValid else { return }
        
        let state = KnobState(current: currentKnob, previous: previousKnob)
        
        knobAngle = currentKnob.angle
        displayValue = controlTarget.applyDelta(state.deltaAngle)
        isActive = true
        
        centerX = currentKnob.center.x
        centerY = currentKnob.center.y
        radius = currentKnob.radius
        
        previousKnob = currentKnob
    }
    
    func getTouchpadEngine() -> TouchpadEngine {
        return touchpadEngine
    }
}
