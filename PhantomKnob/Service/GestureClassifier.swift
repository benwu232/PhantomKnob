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
    private var initialCentroid: CGPoint?
    private var detectionStartTime: Date?
    private let detectionWindow: TimeInterval = 0.8
    private let angleThreshold: Double = 8.0
    private let translationThreshold: CGFloat = 3.0
    private let algorithm = KnobAlgorithm()
    private let minDistanceThreshold: CGFloat = 20.0 // 最小旋钮距离阈值 (mm)
    private var closeDistanceStartTime: Date?       // 记录两指小于 10mm 的开始时间
    
    func processTouchesBegan(points: [Int: CGPoint]) {
        let (knobCore, _, _) = algorithm.calKnob(points)
        if knobCore.isValid && knobCore.radius * 2 >= minDistanceThreshold {
            initialAngle = knobCore.angle
            initialCentroid = calculateCentroid(points: points)
            detectionStartTime = Date()
        } else {
            initialAngle = nil
            initialCentroid = nil
            detectionStartTime = nil
        }
        closeDistanceStartTime = nil
        currentMode = .pan
    }
    
    func processTouchesMoved(points: [Int: CGPoint]) -> GestureMode {
        if currentMode == .knob {
            if points.count >= 2 {
                let (knobCore, _, _) = algorithm.calKnob(points)
                let currentDistance = knobCore.isValid ? knobCore.radius * 2 : 0
                if currentDistance < minDistanceThreshold {
                    if closeDistanceStartTime == nil {
                        closeDistanceStartTime = Date()
                    } else if Date().timeIntervalSince(closeDistanceStartTime!) >= 1.0 {
                        // 持续 1.0s 小于 10mm，降级回 .pan，并重置定位基准以允许在同一次触摸中重新激活
                        currentMode = .pan
                        closeDistanceStartTime = nil
                        initialAngle = calculateAngle(points: points)
                        initialCentroid = calculateCentroid(points: points)
                        detectionStartTime = Date()
                    }
                } else {
                    closeDistanceStartTime = nil
                }
            } else {
                // 单指延续状态，不需要距离校验，重置计时器
                closeDistanceStartTime = nil
            }
            return currentMode
        }
        
        guard let initialAngle = initialAngle,
              let initialCentroid = initialCentroid,
              let startTime = detectionStartTime else {
            return currentMode
        }
        
        // 超出 0.8s 判定窗口直接返回 .pan (超时锁)
        if Date().timeIntervalSince(startTime) > detectionWindow {
            return .pan
        }
        
        let currentCentroid = calculateCentroid(points: points)
        let distanceMoved = distance(initialCentroid, currentCentroid)
        
        let currentAngle = calculateAngle(points: points)
        let delta = abs(angleDelta(from: initialAngle, to: currentAngle))
        
        // 简化核心条件：位移在阈值内 且 旋转角度达标 且 间距达标
        if distanceMoved < translationThreshold && delta > angleThreshold {
            let (knobCore, _, _) = algorithm.calKnob(points)
            let currentDistance = knobCore.isValid ? knobCore.radius * 2 : 0
            if currentDistance >= minDistanceThreshold {
                currentMode = .knob
            }
        }
        
        return currentMode
    }
    
    func processTouchesEnded() {
        currentMode = .pan
        initialAngle = nil
        initialCentroid = nil
        detectionStartTime = nil
        closeDistanceStartTime = nil
    }
    
    func forcePassthrough() {
        currentMode = .passthrough
        initialAngle = nil
        initialCentroid = nil
        detectionStartTime = nil
        closeDistanceStartTime = nil
    }

    
    func forceKnob() {
        currentMode = .knob
    }
    
    func getCurrentAngle(points: [Int: CGPoint]) -> Double {
        return calculateAngle(points: points)
    }
    
    private func calculateCentroid(points: [Int: CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        for pt in points.values {
            sumX += pt.x
            sumY += pt.y
        }
        return CGPoint(x: sumX / CGFloat(points.count), y: sumY / CGFloat(points.count))
    }
    
    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        return sqrt(dx * dx + dy * dy)
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
