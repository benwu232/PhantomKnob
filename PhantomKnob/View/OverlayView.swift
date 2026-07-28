// PhantomKnob/View/OverlayView.swift
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
    var valueText: String? = nil
    let angle: Double
    var isDeadzone: Bool = false
    var scale: Double? = nil
    
    let themeColorHex: String
    let overlayStyle: String
    let rotationStyle: String
    let diameter: CGFloat    // 新增：渐变渲染与内嵌高亮支持
    let outerThemeColorHex: String?
    let innerThemeColorHex: String?
    let configType: KnobConfigType
    let isActive: Bool
    let minRadius: Double?
    let maxRadius: Double?
    let isTooClose: Bool
    
    init(targetName: String?,
         valueText: String? = nil,
         angle: Double,
         isDeadzone: Bool = false,
         isTooClose: Bool = false,
         scale: Double? = nil,
         themeColorHex: String,
         overlayStyle: String,
         rotationStyle: String,
         diameter: CGFloat,
         outerThemeColorHex: String? = nil,
         innerThemeColorHex: String? = nil,
         configType: KnobConfigType = .single,
         isActive: Bool = true,
         minRadius: Double? = nil,
         maxRadius: Double? = nil) {
        self.targetName = targetName
        self.valueText = valueText
        self.angle = angle
        self.isDeadzone = isDeadzone
        self.isTooClose = isTooClose
        self.scale = scale
        self.themeColorHex = themeColorHex
        self.overlayStyle = overlayStyle
        self.rotationStyle = rotationStyle
        self.diameter = diameter
        self.outerThemeColorHex = outerThemeColorHex
        self.innerThemeColorHex = innerThemeColorHex
        self.configType = configType
        self.isActive = isActive
        self.minRadius = minRadius
        self.maxRadius = maxRadius
    }
    
    var body: some View {
        let activeColor: Color = {
            let base = Color(hex: themeColorHex)
            return isActive ? base : base.opacity(0.3)
        }()
        
        VStack(spacing: 4) {
            if isTooClose {
                ZStack {
                    Circle()
                        .stroke(activeColor, lineWidth: 2)
                        .frame(width: 50, height: 50)
                    Circle()
                        .fill(activeColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                }
                .frame(width: diameter, height: diameter)
            } else {
                // 1. 名字及数值悬浮正上方
                let titleText: String = {
                    let name = (targetName == nil || targetName!.isEmpty) ? "Knob" : targetName!
                    return name
                }()
                
                VStack(spacing: 2) {
                    Text(titleText)
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundColor(isDeadzone ? Color.gray.opacity(0.45) : activeColor.opacity(0.70))
                        .lineLimit(1)
                    
                    if let valueText = valueText {
                        Text(valueText)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .tracking(-0.3)
                            .foregroundColor(isDeadzone ? Color.gray.opacity(0.50) : activeColor.opacity(0.85))
                            .lineLimit(1)
                    }
                }
                .frame(height: valueText != nil ? 38 : 20)
                
                // 2. 圆形 Overlay 容器
                ZStack {
                    if isDeadzone {
                        Circle()
                            .fill(activeColor.opacity(0.4))
                            .frame(width: max(0, diameter - 16), height: max(0, diameter - 16))
                    } else {
                        // 圆形底色渲染 (已去掉最外面的圆圈边框)
                        if overlayStyle == "hud" {
                            Circle()
                                .fill(Color.clear)
                        } else if overlayStyle == "solid" {
                            Circle()
                                .fill(Color.black.opacity(0.85))
                        } else {
                            // "minimal": 无背景，无边框
                            Circle()
                                .fill(Color.clear)
                        }
                        
                        // 3. 外围旋转反馈 Canvas
                        Canvas { context, size in
                            let center = CGPoint(x: size.width / 2, y: size.height / 2)
                            let r = min(size.width, size.height) / 2 - 8
                            
                            // 平移到圆心，然后围绕圆心旋转
                            context.translateBy(x: center.x, y: center.y)
                            context.rotate(by: Angle(degrees: -angle))
                            
                            if rotationStyle == "ticks" {
                                let tickCount = 60
                                for i in 0..<tickCount {
                                    let tickAngle = Double(i) * (2 * .pi) / Double(tickCount)
                                    let isMain = (i == 0)
                                    
                                    if isMain {
                                        // 将主 Notch 画为一个位于 0.75 半径处的实心小圆点，大小恢复为原方案
                                        let dotRadius = max(2.5, r * 0.08)
                                        let dotDist = r * 0.75
                                        var path = Path()
                                        path.addArc(
                                            center: CGPoint(x: dotDist * CGFloat(cos(tickAngle)), y: dotDist * CGFloat(sin(tickAngle))),
                                            radius: dotRadius,
                                            startAngle: .zero,
                                            endAngle: Angle(degrees: 360),
                                            clockwise: false
                                        )
                                        context.fill(path, with: .color(activeColor.opacity(0.4)))
                                    }
                                    
                                    // 所有刻度线都在外侧绘制（包括与主 Notch 对应的 0 号大刻度）
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
                                        with: .color(activeColor.opacity(tickOpacity)),
                                        lineWidth: thickness
                                    )
                                }
                            } else if rotationStyle == "rimDot" {
                                // 边缘圆点反馈
                                let dotX = r * CGFloat(cos(0.0))
                                let dotY = r * CGFloat(sin(0.0))
                                let dotRadius = max(1.5, r * 0.055)
                                
                                var path = Path()
                                path.addArc(center: CGPoint(x: dotX, y: dotY), radius: dotRadius, startAngle: .zero, endAngle: Angle(degrees: 360), clockwise: false)
                                context.fill(path, with: .color(activeColor.opacity(0.4)))
                            }
                        }
                        
                        // 4. 正中心倍数显示 (调整为更小、与整体透明度一致为 0.55)
                        if let scale = scale {
                            Text(String(format: "%.1fx", scale))
                                .font(.system(size: 28, weight: .black, design: .monospaced))
                                .tracking(-0.5)
                                .foregroundColor(activeColor.opacity(0.55))
                                .shadow(color: Color.black.opacity(0.15), radius: 1, x: 0, y: 1)
                        }
                    }
                }
                .frame(width: diameter, height: diameter)
            }
        }
        .frame(width: diameter, height: diameter + (isTooClose ? 0 : (valueText != nil ? 38 : 20)))
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
