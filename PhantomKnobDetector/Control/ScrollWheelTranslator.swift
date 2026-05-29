// PhantomKnobDetector/Control/ScrollWheelTranslator.swift
import Foundation
import CoreGraphics

/// 合成滚轮 CGEvent 并注入系统。
/// 连续事件：CGEvent 支持浮点 delta，无需 accumulator。
final class ScrollWheelTranslator: InputTranslator {
    private let axis: Axis
    private let scale: Double
    private var accumulator: Double = 0

    enum Axis { case vertical, horizontal }

    init(axis: Axis = .vertical, scale: Double = 1.0) {
        self.axis = axis
        self.scale = scale
    }

    func apply(units: Double, direction: RotationDirection) {
        let delta = units * scale * (direction == .clockwise ? 1.0 : -1.0)
        accumulator += delta
        
        let steps = Int(accumulator)
        guard steps != 0 else { return }
        
        accumulator -= Double(steps) // 扣除整数部分，保留余数

        switch axis {
        case .vertical:
            synthesizeScroll(deltaY: CGFloat(steps), deltaX: 0)
        case .horizontal:
            synthesizeScroll(deltaY: 0, deltaX: CGFloat(steps))
        }
    }

    var displayValue: String? { nil }

    private func synthesizeScroll(deltaY: CGFloat, deltaX: CGFloat) {
        let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(deltaY),
            wheel2: Int32(deltaX),
            wheel3: 0
        )
        // 高精度浮点 delta，确保慢速旋转时也能流畅响应
        event?.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: Double(deltaY))
        event?.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: Double(deltaX))
        event?.post(tap: .cghidEventTap)
    }
}
