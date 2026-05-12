import Foundation
import CoreGraphics

class KnobAlgorithm {
    
    func calKnob(_ points: [Int: CGPoint]) -> (KnobCore, Int, Int) {
        if points.count < 2 {
            return (KnobCore.invalid, 0, 0)
        }
        
        var maxDist: CGFloat = 0
        var fingerIdx1 = 0, fingerIdx2 = 0
        
        for (id1, p1) in points {
            for (id2, p2) in points {
                if id1 == id2 { continue }
                let dist = distance(p1, p2)
                if dist > maxDist {
                    maxDist = dist
                    fingerIdx1 = min(id1, id2)
                    fingerIdx2 = max(id1, id2)
                }
            }
        }
        
        guard let point1 = points[fingerIdx1],
              let point2 = points[fingerIdx2] else {
            return (KnobCore.invalid, 0, 0)
        }
        
        let center = CGPoint(
            x: (point1.x + point2.x) / 2,
            y: (point1.y + point2.y) / 2
        )
        
        let radius = maxDist / 2
        
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        let angle = atan2(dy, dx) * 180 / .pi
        
        return (KnobCore(center: center, radius: radius, angle: angle), fingerIdx1, fingerIdx2)
    }
    
    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        return sqrt(dx * dx + dy * dy)
    }
}
