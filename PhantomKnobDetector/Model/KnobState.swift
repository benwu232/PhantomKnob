import Foundation

struct KnobState {
    let current: KnobCore
    let previous: KnobCore
    let deltaAngle: Double
    
    init(current: KnobCore = .invalid, previous: KnobCore = .invalid) {
        self.current = current
        self.previous = previous
        
        var delta = previous.angle - current.angle
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        self.deltaAngle = delta.clamped(to: -15.0...15.0)
    }
    
    var rotationDirection: RotationDirection {
        if deltaAngle > 0 { return .clockwise }
        else if deltaAngle < 0 { return .counterClockwise }
        else { return .none }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
