import Foundation

protocol ControlTarget {
    var value: Double { get set }
    var minValue: Double { get }
    var maxValue: Double { get }
    var displayName: String { get }
    
    func applyDelta(_ deltaAngle: Double) -> Double
}
