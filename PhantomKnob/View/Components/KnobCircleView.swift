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
                    let cosVal = CGFloat(cos(angle * .pi / 180))
                    let sinVal = CGFloat(sin(angle * .pi / 180))
                    
                    let startX = center.x - cosVal * lineLength
                    let startY = center.y + sinVal * lineLength
                    
                    let endX = center.x + cosVal * lineLength
                    let endY = center.y - sinVal * lineLength
                    
                    path.move(to: CGPoint(x: startX, y: startY))
                    path.addLine(to: CGPoint(x: endX, y: endY))
                }
                .stroke(Color.black, lineWidth: 3)
            }
        }
        .frame(width: size, height: size)
    }
}

struct KnobCircleView_Previews: PreviewProvider {
    static var previews: some View {
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
}