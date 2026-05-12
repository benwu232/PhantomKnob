import Foundation
import CoreGraphics

struct KnobCore {
    let center: CGPoint
    let radius: Double
    let angle: Double
    
    init(center: CGPoint = .zero, radius: Double = 0, angle: Double = 0) {
        self.center = center
        self.radius = radius
        self.angle = angle
    }
    
    var isValid: Bool { radius > 0 }
    
    static let invalid = KnobCore(center: .zero, radius: 0, angle: 0)
}
