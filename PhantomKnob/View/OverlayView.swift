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
    
    let skin: HUDSkin?

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
         skin: HUDSkin? = nil) {
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
    }
    
    var body: some View {
        let activeColor: Color = {
            let base = Color(hex: themeColorHex)
            return isActive ? base : base.opacity(0.3)
        }()
        
        let resolvedSkin = skin ?? HUDSkinManager.shared.resolveSkin(skinID: nil, overrides: HUDSkinOverride(primaryColorHex: themeColorHex))

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
                        HUDValueBadgeView(config: resolvedSkin.components.valueBadge, valueText: valueText)
                    }
                }
                .frame(height: valueText != nil ? 38 : 20)
                
                // 8 图层解耦容器
                ZStack {
                    // Layer 1: Backdrop
                    if resolvedSkin.components.backdrop.enabled {
                        HUDBackdropView(config: resolvedSkin.appearance.backdrop, primaryColor: activeColor)
                    }
                    // Layer 2: Texture Overlay
                    if resolvedSkin.components.textureOverlay.enabled {
                        HUDTextureOverlayView(config: resolvedSkin.components.textureOverlay)
                    }
                    // Layer 3: Custom Image Assets
                    HUDCustomImageView(assets: resolvedSkin.customImageAssets)

                    // Layer 4: Center Cap
                    if resolvedSkin.components.centerCap.enabled {
                        HUDCenterCapView(config: resolvedSkin.components.centerCap, primaryColor: activeColor)
                    }

                    // Layer 5: Gauge
                    if resolvedSkin.components.gauge.enabled {
                        HUDGaugeView(config: resolvedSkin.components.gauge, primaryColor: activeColor)
                    }

                    // Layer 6: Notch Pins
                    if resolvedSkin.components.notchPins.enabled {
                        HUDNotchPinsView(config: resolvedSkin.components.notchPins, primaryColor: activeColor)
                    }

                    // Layer 7: Pointer
                    if resolvedSkin.components.pointer.enabled {
                        HUDPointerView(config: resolvedSkin.components.pointer, angle: angle, primaryColor: activeColor)
                    }
                    
                    if let scale = scale {
                        Text(String(format: "%.1fx", scale))
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .tracking(-0.5)
                            .foregroundColor(activeColor.opacity(0.55))
                            .shadow(color: Color.black.opacity(0.15), radius: 1, x: 0, y: 1)
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
