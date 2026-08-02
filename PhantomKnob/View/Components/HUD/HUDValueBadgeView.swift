import SwiftUI

public struct HUDValueBadgeView: View {
    public let targetName: String?
    public let valueText: String?
    public let isDeadzone: Bool
    public let primaryColor: Color

    public init(targetName: String?, valueText: String? = nil, isDeadzone: Bool = false, primaryColor: Color) {
        self.targetName = targetName
        self.valueText = valueText
        self.isDeadzone = isDeadzone
        self.primaryColor = primaryColor
    }

    public var body: some View {
        let titleText: String = (targetName == nil || targetName!.isEmpty) ? "Knob" : targetName!

        VStack(spacing: 2) {
            Text(titleText)
                .font(.system(size: 13, weight: .semibold))
                .tracking(-0.2)
                .foregroundColor(isDeadzone ? Color.gray.opacity(0.45) : primaryColor.opacity(0.70))
                .lineLimit(1)
            
            if let valueText = valueText {
                Text(valueText)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .tracking(-0.3)
                    .foregroundColor(isDeadzone ? Color.gray.opacity(0.50) : primaryColor.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .frame(height: valueText != nil ? 38 : 20)
    }
}
