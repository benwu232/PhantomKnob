import SwiftUI

public struct HUDValueBadgeView: View {
    public let config: HUDValueBadgeComponent
    public let valueText: String

    public init(config: HUDValueBadgeComponent, valueText: String) {
        self.config = config
        self.valueText = valueText
    }

    public var body: some View {
        VStack {
            if config.position == "topFloating" {
                Text(valueText)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.ultraThinMaterial))
            } else if config.position == "center" {
                Text(valueText)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
            }
        }
    }
}
