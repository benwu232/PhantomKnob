// PhantomKnobDetector/View/OverlayView.swift
import SwiftUI
import AppKit

struct OverlayView: View {
    let targetName: String?
    let angle: Double
    let displayValue: String?
    var isDeadzone: Bool = false
    var scale: Double? = nil

    var body: some View {
        VStack(spacing: 8) {
            if let targetName = targetName, !targetName.isEmpty {
                let suffix = scale.map { String(format: " (%.1fx)", $0) } ?? ""
                Text(targetName + suffix)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isDeadzone ? .gray : .white)
            }

            ZStack {
                Circle()
                    .stroke(isDeadzone ? Color.gray.opacity(0.3) : Color.white.opacity(0.3), lineWidth: 2)
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
                    .stroke(isDeadzone ? Color.gray : Color.white, lineWidth: 2)
                }
                .frame(width: 60, height: 60)

                Circle()
                    .fill(isDeadzone ? Color.gray : Color.white)
                    .frame(width: 8, height: 8)
            }

            if let displayValue = displayValue, !displayValue.isEmpty {
                Text(displayValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isDeadzone ? .gray : .white)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(isDeadzone ? 0.6 : 0.75))
        )
    }
}

struct OverlayView_Previews: PreviewProvider {
    static var previews: some View {
        OverlayView(
            targetName: "音量",
            angle: 45,
            displayValue: "65%"
        )
        .background(Color.gray)
    }
}
