import SwiftUI

public struct HUDNotchPinsView: View {
    public let angle: Double
    public let primaryColor: Color

    public init(angle: Double, primaryColor: Color) {
        self.angle = angle
        self.primaryColor = primaryColor
    }

    public var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2 - 8
            
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: Angle(degrees: -angle))
            
            let dotRadius = max(2.5, r * 0.08)
            let dotDist = r * 0.75
            var path = Path()
            path.addArc(
                center: CGPoint(x: dotDist, y: 0),
                radius: dotRadius,
                startAngle: .zero,
                endAngle: Angle(degrees: 360),
                clockwise: false
            )
            context.fill(path, with: .color(primaryColor.opacity(0.4)))
        }
    }
}
