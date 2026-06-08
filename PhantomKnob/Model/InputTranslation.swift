// PhantomKnobDetector/Model/InputTranslation.swift
import Foundation

/// 将旋转角度转化为系统输入事件的策略。描述"如何投递"，不感知目标控件。
/// Avoid: mapping, method, action
enum InputTranslation: String, Codable, CaseIterable {
    case axWrite                // 读取 AXValue，加 delta，写回
    case scrollWheelVertical    // 合成垂直滚轮 CGEvent
    case scrollWheelHorizontal  // 合成水平滚轮 CGEvent
    case arrowKeyUpDown         // 合成上/下方向键
    case arrowKeyLeftRight      // 合成左/右方向键
    case swipeVertical          // 合成垂直双指滑动
    case swipeHorizontal        // 合成水平双指滑动
}
