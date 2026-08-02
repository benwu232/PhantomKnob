import SwiftUI

public struct HUDPointerView: View {
    public let angle: Double
    public let primaryColor: Color
    public let rotationStyle: String

    public init(angle: Double, primaryColor: Color, rotationStyle: String = "rimDot") {
        self.angle = angle
        self.primaryColor = primaryColor
        self.rotationStyle = rotationStyle
    }

    public var body: some View {
        Group {
            if rotationStyle == "rimDot" {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r = min(size.width, size.height) / 2 - 8
                    
                    context.translateBy(x: center.x, y: center.y)
                    context.rotate(by: Angle(degrees: -angle))
                    
                    let dotX = r * CGFloat(cos(0.0))
                    let dotY = r * CGFloat(sin(0.0))
                    let dotRadius = max(1.5, r * 0.055)
                    
                    var path = Path()
                    path.addArc(center: CGPoint(x: dotX, y: dotY), radius: dotRadius, startAngle: .zero, endAngle: Angle(degrees: 360), clockwise: false)
                    context.fill(path, with: .color(primaryColor.opacity(0.4)))
                }
            }
        }
    }
}
