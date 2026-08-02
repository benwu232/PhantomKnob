import SwiftUI

public struct HUDCenterCapView: View {
    public let config: HUDCenterCapComponent
    public let primaryColor: Color

    public init(config: HUDCenterCapComponent, primaryColor: Color) {
        self.config = config
        self.primaryColor = primaryColor
    }

    public var body: some View {
        if config.enabled {
            Circle()
                .fill(primaryColor.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(Circle().stroke(primaryColor, lineWidth: 1.5))
        }
    }
}
