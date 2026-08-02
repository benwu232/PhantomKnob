import SwiftUI

public struct HUDBackdropView: View {
    public let overlayStyle: String
    public let isDeadzone: Bool
    public let primaryColor: Color
    public let diameter: CGFloat

    public init(overlayStyle: String, isDeadzone: Bool = false, primaryColor: Color, diameter: CGFloat) {
        self.overlayStyle = overlayStyle
        self.isDeadzone = isDeadzone
        self.primaryColor = primaryColor
        self.diameter = diameter
    }

    public var body: some View {
        Group {
            if isDeadzone {
                Circle()
                    .fill(primaryColor.opacity(0.4))
                    .frame(width: max(0, diameter - 16), height: max(0, diameter - 16))
            } else {
                if overlayStyle == "solid" {
                    Circle()
                        .fill(Color.black.opacity(0.85))
                } else {
                    // "hud" or "minimal"
                    Circle()
                        .fill(Color.clear)
                }
            }
        }
    }
}
