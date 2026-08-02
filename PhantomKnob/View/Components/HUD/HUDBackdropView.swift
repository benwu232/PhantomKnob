import SwiftUI

public struct HUDBackdropView: View {
    public let config: HUDBackdropConfig
    public let primaryColor: Color

    public init(config: HUDBackdropConfig, primaryColor: Color) {
        self.config = config
        self.primaryColor = primaryColor
    }

    public var body: some View {
        if config.material == "darkBlur" {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().stroke(primaryColor, lineWidth: config.borderWidth))
                .shadow(color: primaryColor.opacity(0.3), radius: config.shadowRadius)
                .opacity(config.opacity)
        } else {
            Circle()
                .fill(Color.black.opacity(config.opacity))
                .overlay(Circle().stroke(primaryColor, lineWidth: config.borderWidth))
        }
    }
}
