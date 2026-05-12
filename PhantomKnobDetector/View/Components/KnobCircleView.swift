import SwiftUI

struct KnobCircleView: View {
    let angle: Double
    let size: CGFloat = 100
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: size, height: size)
            
            Circle()
                .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                .frame(width: size, height: size)
            
            GeometryReader { geometry in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let lineLength = size / 2 - 10
                
                Path { path in
                    path.move(to: center)
                    let endX = center.x + CGFloat(cos(angle * .pi / 180)) * lineLength
                    let endY = center.y - CGFloat(sin(angle * .pi / 180)) * lineLength
                    path.addLine(to: CGPoint(x: endX, y: endY))
                }
                .stroke(Color.black, lineWidth: 3)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack {
        KnobCircleView(angle: 0)
        KnobCircleView(angle: 45)
        KnobCircleView(angle: 90)
        KnobCircleView(angle: 180)
        KnobCircleView(angle: -45)
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}