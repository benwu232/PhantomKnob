import SwiftUI

extension Color {
    static let hudTitle = Color.white
    static let hudSecondary = Color.white.opacity(0.60)
    static let hudMetadata = Color.white.opacity(0.45)
    static let hudCardBg = Color.white.opacity(0.04)
    static let hudCardBorder = Color.white.opacity(0.08)
    static let hudInputBg = Color.black.opacity(0.25)
    static let hudInputBorder = Color.white.opacity(0.10)
}

extension Font {
    static let hudTitle = Font.system(size: 12, weight: .bold)
    static let hudLabel = Font.system(size: 11, weight: .medium)
    static let hudValue = Font.system(size: 11, weight: .bold, design: .monospaced)
    static let hudCode = Font.system(size: 10, design: .monospaced)
}

extension View {
    /// 统一的微凸悬浮毛玻璃卡片风格
    func hudCardStyle() -> some View {
        self.padding(10)
            .background(Color.hudCardBg)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.hudCardBorder, lineWidth: 1)
            )
    }
    
    /// 统一的微凹下陷输入框/选择器风格
    func hudInputStyle() -> some View {
        self.background(Color.hudInputBg)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.hudInputBorder, lineWidth: 1)
            )
    }
}
