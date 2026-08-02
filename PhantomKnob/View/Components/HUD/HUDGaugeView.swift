import SwiftUI

public struct HUDGaugeView: View {
    public let config: HUDGaugeComponent
    public let primaryColor: Color

    public init(config: HUDGaugeComponent, primaryColor: Color) {
        self.config = config
        self.primaryColor = primaryColor
    }

    public var body: some View {
        ZStack {
            ForEach(0..<config.tickCount, id: \.self) { i in
                Rectangle()
                    .fill(primaryColor.opacity(i % 5 == 0 ? 0.9 : 0.4))
                    .frame(width: i % 5 == 0 ? 2 : 1, height: i % 5 == 0 ? 8 : 4)
                    .offset(y: -70)
                    .rotationEffect(.degrees(Double(i) * (360.0 / Double(max(1, config.tickCount)))))
            }
        }
    }
}
