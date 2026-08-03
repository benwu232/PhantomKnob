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
    let diameter: CGFloat
    let outerThemeColorHex: String?
    let innerThemeColorHex: String?
    let configType: KnobConfigType
    let isActive: Bool
    let minRadius: Double?
    let maxRadius: Double?
    let isTooClose: Bool
    
    let skin: HUDSkin?
    let sessionID: Int
    let isExiting: Bool

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
         maxRadius: Double? = nil,
         skin: HUDSkin? = nil,
         sessionID: Int = 0,
         isExiting: Bool = false) {
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
        self.skin = skin
        self.sessionID = sessionID
        self.isExiting = isExiting
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
                // 1. 名字及数值悬浮正上方 (Layer 8)
                HUDValueBadgeView(targetName: targetName, valueText: valueText, isDeadzone: isDeadzone, primaryColor: activeColor)
                
                // 2. 圆形 Overlay 容器（包含 Layer 1, 5, 6, 7 & Scale 文本）
                ZStack {
                    // Layer 1: Backdrop / Circle Fill / Deadzone
                    HUDBackdropView(overlayStyle: overlayStyle, isDeadzone: isDeadzone, primaryColor: activeColor, diameter: diameter)
                    
                    if !isDeadzone {
                        if rotationStyle == "ticks" {
                            // Layer 6: Notch Pin (主 Notch 圆点)
                            HUDNotchPinsView(angle: angle, primaryColor: activeColor)
                            
                            // Layer 5: Gauge Ticks (60 刻度线)
                            HUDGaugeView(angle: angle, primaryColor: activeColor, tickCount: 60)
                        } else if rotationStyle == "rimDot" {
                            // Layer 7: RimDot Pointer
                            HUDPointerView(angle: angle, primaryColor: activeColor, rotationStyle: "rimDot")
                        }
                        
                        // 4. 正中心倍数显示
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
        .modifier(HUDAnimationModifier(animations: skin?.animations, isExiting: isExiting))
        .id(sessionID)
    }
}

struct HUDAnimationModifier: ViewModifier {
    let animations: HUDAnimationConfig?
    let isExiting: Bool
    @State private var isAppeared: Bool = false
    @State private var isExitingAnimated: Bool = false

    func body(content: Content) -> some View {
        let entranceType = animations?.entrance.type ?? .simpleCenterScaleIn
        let exitType = animations?.exit.type ?? .simpleCenterScaleOut
        let entranceDuration = animations?.entrance.duration ?? 0.30
        let exitDuration = animations?.exit.duration ?? 0.30

        let targetScale: CGFloat = {
            if isExitingAnimated {
                return exitType == .simpleCenterScaleOut ? 0.2 : 1.0
            } else if isAppeared {
                return 1.0
            } else {
                return initialScale(for: entranceType)
            }
        }()

        content
            .scaleEffect(targetScale)
            .rotationEffect(isAppeared ? .zero : initialRotation(for: entranceType))
            .opacity(isExitingAnimated ? 0.0 : (isAppeared ? 1.0 : (entranceDuration == 0 ? 1.0 : 0.0)))
            .onAppear {
                if entranceDuration > 0 {
                    withAnimation(.easeOut(duration: entranceDuration)) {
                        isAppeared = true
                    }
                } else {
                    isAppeared = true
                }
            }
            .onChange(of: isExiting) { newValue in
                if newValue {
                    withAnimation(.easeOut(duration: exitDuration)) {
                        isExitingAnimated = true
                    }
                } else {
                    isExitingAnimated = false
                }
            }
    }

    private func initialScale(for type: EntranceAnimationType) -> CGFloat {
        switch type {
        case .simpleCenterScaleIn: return 0.2
        case .pointExpand: return 0.05
        case .glitchPop: return 0.4
        case .spinIn: return 0.2
        case .fadeInOnly: return 1.0
        }
    }

    private func initialRotation(for type: EntranceAnimationType) -> Angle {
        switch type {
        case .spinIn: return .degrees(-180)
        case .glitchPop: return .degrees(15)
        default: return .zero
        }
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
