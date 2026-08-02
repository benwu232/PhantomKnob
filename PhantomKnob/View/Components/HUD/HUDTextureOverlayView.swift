import SwiftUI

public struct HUDTextureOverlayView: View {
    public let config: HUDTextureOverlayComponent

    public init(config: HUDTextureOverlayComponent) {
        self.config = config
    }

    public var body: some View {
        Group {
            if config.enabled && config.style != "none" {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            }
        }
    }
}
