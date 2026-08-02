import SwiftUI

public struct HUDGaugeView: View {
    public let angle: Double
    public let primaryColor: Color
    public let tickCount: Int

    public init(angle: Double, primaryColor: Color, tickCount: Int = 60) {
        self.angle = angle
        self.primaryColor = primaryColor
        self.tickCount = tickCount
    }

    public var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = min(size.width, size.height) / 2 - 8
            
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: Angle(degrees: -angle))
            
            let count = max(1, tickCount)
            for i in 0..<count {
                let tickAngle = Double(i) * (2 * .pi) / Double(count)
                
                let baseLength = max(3.5, r * 0.09)
                let isMajorTick = (i % 5 == 0)
                let tickLength: CGFloat = isMajorTick ? baseLength * 1.5 : baseLength
                let startR = r - tickLength
                
                var path = Path()
                path.move(to: CGPoint(
                    x: CGFloat(startR * cos(tickAngle)),
                    y: CGFloat(startR * sin(tickAngle))
                ))
                path.addLine(to: CGPoint(
                    x: CGFloat(r * cos(tickAngle)),
                    y: CGFloat(r * sin(tickAngle))
                ))
                
                let thickness: CGFloat = isMajorTick ? 3.0 : 1.5
                let distance = min(Double(i), Double(60 - i)) / 30.0
                let opacityFactor = 1.0 - 0.65 * distance
                let tickOpacity = 0.4 * opacityFactor
                
                context.stroke(
                    path,
                    with: .color(primaryColor.opacity(tickOpacity)),
                    lineWidth: thickness
                )
            }
        }
    }
}
