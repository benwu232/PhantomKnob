import Foundation
import CoreGraphics

enum GestureMode {
    case pan
    case knob
    case passthrough
}

class GestureClassifier {
    private(set) var currentMode: GestureMode = .pan
    private var initialAngle: Double?
    private var detectionStartTime: Date?
    private let detectionWindow: TimeInterval = 2.0
    private let angleThreshold: Double = 5.0
    private let algorithm = KnobAlgorithm()
    
    func processTouchesBegan(points: [Int: CGPoint]) {
        initialAngle = calculateAngle(points: points)
        detectionStartTime = Date()
        currentMode = .pan
    }
    
    func processTouchesMoved(points: [Int: CGPoint]) -> GestureMode {
        if currentMode == .knob {
            return .knob
        }
        
        guard let initialAngle = initialAngle,
              let startTime = detectionStartTime else {
            return currentMode
        }
        
        if Date().timeIntervalSince(startTime) > detectionWindow {
            return currentMode
        }
        
        let currentAngle = calculateAngle(points: points)
        let delta = abs(angleDelta(from: initialAngle, to: currentAngle))
        
        if delta > angleThreshold {
            currentMode = .knob
            self.initialAngle = currentAngle
        }
        
        return currentMode
    }
    
    func processTouchesEnded() {
        currentMode = .pan
        initialAngle = nil
        detectionStartTime = nil
    }
    
    func forcePassthrough() {
        currentMode = .passthrough
        initialAngle = nil
        detectionStartTime = nil
    }
    
    func getCurrentAngle(points: [Int: CGPoint]) -> Double {
        return calculateAngle(points: points)
    }
    
    private func calculateAngle(points: [Int: CGPoint]) -> Double {
        guard points.count >= 2 else { return 0 }
        let (knobCore, _, _) = algorithm.calKnob(points)
        return knobCore.angle
    }
    
    private func angleDelta(from a1: Double, to a2: Double) -> Double {
        var delta = a2 - a1
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }
}
