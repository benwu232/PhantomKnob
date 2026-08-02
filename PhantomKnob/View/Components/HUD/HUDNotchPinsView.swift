import SwiftUI

public struct HUDNotchPinsView: View {
    public let config: HUDNotchPinsComponent
    public let primaryColor: Color

    public init(config: HUDNotchPinsComponent, primaryColor: Color) {
        self.config = config
        self.primaryColor = primaryColor
    }

    public var body: some View {
        Group {
            if config.enabled && config.type != "none" {
                Circle()
                    .fill(primaryColor)
                    .frame(width: 4, height: 4)
                    .offset(y: -75)
            }
        }
    }
}
