import Foundation

class GenericControlTarget: ControlTarget {
    var value: Double = 50.0
    var minValue: Double = 0.0
    var maxValue: Double = 100.0
    var displayName: String = "通用控制"
    
    func applyDelta(_ deltaAngle: Double) -> Double {
        value = (value + deltaAngle * 0.5).clamped(to: minValue...maxValue)
        return value
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
