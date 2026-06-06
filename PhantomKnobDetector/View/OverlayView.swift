// PhantomKnobDetector/View/OverlayView.swift
import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 113, 227) // 科技蓝 Fallback
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct OverlayView: View {
    let targetName: String?
    let angle: Double
    var isDeadzone: Bool = false
    var scale: Double? = nil
    
    let themeColorHex: String
    let overlayStyle: String
    let rotationStyle: String
    let diameter: CGFloat
    
    var body: some View {
        let activeColor = Color(hex: themeColorHex)
        
        VStack(spacing: 4) {
            // 1. 名字悬浮正上方
            let titleText: String = {
                let name = (targetName == nil || targetName!.isEmpty) ? "Knob" : targetName!
                return name
            }()
            
            Text(titleText)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isDeadzone ? Color.gray.opacity(0.6) : activeColor.opacity(0.8))
                .shadow(color: Color.black.opacity(0.8), radius: 2, x: 0, y: 1)
                .lineLimit(1)
                .frame(height: 17)
            
            // 2. 圆形 Overlay 容器
            ZStack {
                // 圆形底色渲染
                if overlayStyle == "hud" {
                    Circle()
                        .fill(Color.clear)
                        .overlay(
                            Circle()
                                .stroke(isDeadzone ? Color.gray.opacity(0.3) : activeColor.opacity(0.4), lineWidth: 1.5)
                        )
                } else if overlayStyle == "solid" {
                    Circle()
                        .fill(Color.black.opacity(0.85))
                        .overlay(
                            Circle()
                                .stroke(isDeadzone ? Color.gray.opacity(0.5) : activeColor, lineWidth: 2)
                        )
                } else {
                    // "minimal": 无背景，仅绘制虚线边圈
                    Circle()
                        .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4]))
                }
                
                // 3. 外围旋转反馈 Canvas
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r = min(size.width, size.height) / 2 - 8
                    
                    // 平移到圆心，然后围绕圆心旋转
                    context.translateBy(x: center.x, y: center.y)
                    context.rotate(by: Angle(degrees: angle))
                    
                    if rotationStyle == "ticks" {
                        let tickCount = 48
                        for i in 0..<tickCount {
                            let tickAngle = Double(i) * (2 * .pi) / Double(tickCount)
                            let isMain = (i == 0)
                            let tickLength: CGFloat = isMain ? max(2.5, r * 0.11) : max(1.5, r * 0.055)
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
                            
                            context.stroke(
                                path,
                                with: .color(isMain ? (isDeadzone ? .gray : activeColor) : Color.white.opacity(0.3)),
                                lineWidth: isMain ? 1.5 : 0.75
                            )
                        }
                    } else if rotationStyle == "rimDot" {
                        // 边缘圆点反馈
                        let dotX = r * CGFloat(cos(0.0))
                        let dotY = r * CGFloat(sin(0.0))
                        let dotRadius = max(1.5, r * 0.055)
                        
                        var path = Path()
                        path.addArc(center: CGPoint(x: dotX, y: dotY), radius: dotRadius, startAngle: .zero, endAngle: Angle(degrees: 360), clockwise: false)
                        context.fill(path, with: .color(isDeadzone ? .gray : activeColor))
                    }
                }
                
                // 4. 正中心倍数显示
                if let scale = scale {
                    Text(String(format: "%.1fx", scale))
                        .font(.system(size: max(11, diameter * 0.15), weight: .black, design: .monospaced))
                        .foregroundColor(isDeadzone ? Color.gray.opacity(0.6) : activeColor.opacity(0.8))
                        .shadow(color: Color.black.opacity(0.4), radius: 1, x: 0, y: 1)
                }
            }
            .frame(width: diameter, height: diameter)
        }
        .frame(width: diameter, height: diameter + 20)
    }
}

struct OverlayView_Previews: PreviewProvider {
    static var previews: some View {
        OverlayView(
            targetName: "音量",
            angle: 45,
            isDeadzone: false,
            scale: 1.5,
            themeColorHex: "#34C759",
            overlayStyle: "hud",
            rotationStyle: "ticks",
            diameter: 160
        )
        .background(Color.gray)
    }
}
