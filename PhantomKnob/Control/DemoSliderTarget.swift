import Foundation

class DemoSliderTarget {
    var value: Double = 50.0
    let minValue: Double = 0
    let maxValue: Double = 100
    let displayName: String = "演示数值"
    
    private let sensitivity: Double = 0.5
    
    func applyDelta(_ deltaAngle: Double) -> Double {
        let newValue = value + deltaAngle * sensitivity
        value = newValue.clamped(to: minValue...maxValue)
        return value
    }
}
