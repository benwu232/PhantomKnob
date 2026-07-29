import SwiftUI

extension Color {
    static let hudTitle = Color.white
    static let hudSecondary = Color.white.opacity(0.75)
    static let hudMetadata = Color.white.opacity(0.55)
    static let hudCardBg = Color.white.opacity(0.04)
    static let hudCardBorder = Color.white.opacity(0.08)
    static let hudInputBg = Color.black.opacity(0.25)
    static let hudInputBorder = Color.white.opacity(0.10)
}

extension Font {
    static let hudTitle = Font.system(size: 13, weight: .bold)
    static let hudLabel = Font.system(size: 12, weight: .medium)
    static let hudValue = Font.system(size: 12, weight: .bold, design: .monospaced)
    static let hudCode = Font.system(size: 11, design: .monospaced)
}

extension View {
    /// 统一的微凸悬浮毛玻璃卡片风格
    func hudCardStyle() -> some View {
        self.padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.hudCardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
    
    /// 统一的微凹下陷输入框/选择器风格
    func hudInputStyle() -> some View {
        self.background(Color.hudInputBg)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(
                        LinearGradient(
                            colors: [Color.black.opacity(0.3), Color.white.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
    }
}
