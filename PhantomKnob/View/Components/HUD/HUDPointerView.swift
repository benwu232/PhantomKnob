import SwiftUI

public struct HUDPointerView: View {
    public let config: HUDPointerComponent
    public let angle: Double
    public let primaryColor: Color

    public init(config: HUDPointerComponent, angle: Double, primaryColor: Color) {
        self.config = config
        self.angle = angle
        self.primaryColor = primaryColor
    }

    public var body: some View {
        Capsule()
            .fill(primaryColor)
            .frame(width: 4, height: 24)
            .offset(y: -50)
            .rotationEffect(.degrees(angle))
    }
}
