import SwiftUI
import AppKit

struct OverlayView: View {
    let targetName: String
    let angle: Double
    let displayValue: String
    
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            if !targetName.isEmpty {
                Text(targetName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
            }
            
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 60, height: 60)
                
                GeometryReader { geometry in
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    let radius: CGFloat = 25
                    let angleRad = angle * .pi / 180
                    
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: CGPoint(
                            x: center.x + radius * cos(angleRad),
                            y: center.y - radius * sin(angleRad)
                        ))
                    }
                    .stroke(Color.white, lineWidth: 2)
                }
                .frame(width: 60, height: 60)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
            }
            
            Text(displayValue)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.75))
        )
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.2)) {
                opacity = 1
            }
        }
    }
}

#Preview {
    OverlayView(
        targetName: "音量",
        angle: 45,
        displayValue: "65%"
    )
    .background(Color.gray)
}
