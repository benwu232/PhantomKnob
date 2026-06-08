// PhantomKnob/Control/ArrowKeyTranslator.swift
import Foundation
import CoreGraphics

/// 合成方向键事件，支持 accumulator（积累到 ≥ 1.0 才发送，余数保留）。
final class ArrowKeyTranslator: InputTranslator {
    private let axis: Axis
    var scale: Double
    private var accumulator: Double = 0

    enum Axis { case upDown, leftRight }

    // macOS 虚拟键码
    private static let keyUp:    CGKeyCode = 126
    private static let keyDown:  CGKeyCode = 125
    private static let keyLeft:  CGKeyCode = 123
    private static let keyRight: CGKeyCode = 124

    init(axis: Axis = .upDown, scale: Double = 1.0) {
        self.axis = axis
        self.scale = scale
    }

    func apply(units: Double, direction: RotationDirection) {
        let signed = units * scale * (direction == .clockwise ? 1.0 : -1.0)
        accumulator += signed
        let presses = Int(accumulator)           // 整数部分：要发送的次数
        accumulator -= Double(presses)           // 保留余数

        guard presses != 0 else { return }
        let (increaseKey, decreaseKey) = keyPair()
        let keyCode = presses > 0 ? increaseKey : decreaseKey
        let count = abs(presses)
        for _ in 0..<count {
            pressKey(keyCode)
        }
    }

    var displayValue: String? { nil }

    private func keyPair() -> (CGKeyCode, CGKeyCode) {
        switch axis {
        case .upDown:    return (Self.keyUp, Self.keyDown)
        case .leftRight: return (Self.keyRight, Self.keyLeft)
        }
    }

    private static let eventSource: CGEventSource? = {
        let source = CGEventSource(stateID: .privateState)
        source?.userData = 0xDEADC0DE
        return source
    }()

    private func pressKey(_ keyCode: CGKeyCode) {
        let source = Self.eventSource
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up   = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }
}
