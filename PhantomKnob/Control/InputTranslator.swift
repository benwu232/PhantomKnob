// PhantomKnob/Control/InputTranslator.swift
import Foundation

/// 执行旋钮控制的运行时对象。
/// 接收 (units, direction) 并向系统注入对应事件。
/// 内部自行管理离散事件的 accumulator。
protocol InputTranslator: AnyObject {
    /// 施加旋转 delta。
    /// - Parameters:
    ///   - units: 本帧要施加的单位数（浮点，可 < 1）
    ///   - direction: 旋转方向（顺时针 = 增加，逆时针 = 减少）
    func apply(units: Double, direction: RotationDirection)

    /// overlay 显示的当前值字符串。非 axWrite 类型返回 nil（overlay 隐藏值区域）。
    var displayValue: String? { get }

    /// 步长倍率（动态感应度与按键加成后的最终缩放因子）
    var scale: Double { get set }
}
