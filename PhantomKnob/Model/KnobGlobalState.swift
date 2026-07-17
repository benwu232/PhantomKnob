// PhantomKnob/Model/KnobGlobalState.swift
import Foundation
import AppKit

enum KnobGlobalState: Equatable {
    case inactive
    case activated
    case knobing(target: DetectedTarget)
    case cooling(target: DetectedTarget)
    case customizing

    var iconColor: NSColor {
        switch self {
        case .inactive:           return .gray
        case .activated:          return .systemBlue
        case .knobing, .cooling:  return .systemOrange
        case .customizing:        return .systemPurple
        }
    }

    var currentTarget: DetectedTarget? {
        switch self {
        case .inactive, .activated, .customizing: return nil
        case .knobing(let t), .cooling(let t):    return t
        }
    }

    var isKnobing: Bool { if case .knobing = self { return true }; return false }
    var isCooling: Bool { if case .cooling = self { return true }; return false }

    static func == (lhs: KnobGlobalState, rhs: KnobGlobalState) -> Bool {
        switch (lhs, rhs) {
        case (.inactive, .inactive): return true
        case (.activated, .activated): return true
        case (.knobing, .knobing): return true
        case (.cooling, .cooling): return true
        case (.customizing, .customizing): return true
        default: return false
        }
    }
}

enum KnobStateEvent {
    case hotkeyToggle
    case gestureStarted
    case gestureStartedWithTarget(DetectedTarget)   // 移除 angleDelta：KnobStateManager 已取消阈值
    case gestureEnded
    case coolingTimeout
    case appSwitched
    case newGestureOnDifferentTarget
}

extension KnobGlobalState {
    struct TransitionResult {
        let state: KnobGlobalState
        let target: DetectedTarget?
    }

    func transition(event: KnobStateEvent) -> KnobGlobalState? {
        transitionWithResult(event: event)?.state
    }

    func transitionWithResult(event: KnobStateEvent) -> TransitionResult? {
        switch (self, event) {
        case (.inactive, .hotkeyToggle):
            return TransitionResult(state: .activated, target: nil)

        case (.activated, .hotkeyToggle):
            return TransitionResult(state: .inactive, target: nil)

        case (.activated, .gestureStarted):
            return TransitionResult(state: .activated, target: nil)

        case (.activated, .gestureStartedWithTarget(let target)):
            return TransitionResult(state: .knobing(target: target), target: target)

        case (.knobing, .gestureEnded):
            if case .knobing(let target) = self {
                return TransitionResult(state: .cooling(target: target), target: target)
            }
            return nil

        case (.cooling, .coolingTimeout):
            return TransitionResult(state: .activated, target: nil)

        case (.knobing, .appSwitched), (.cooling, .appSwitched):
            return TransitionResult(state: .activated, target: nil)

        case (.cooling, .gestureStartedWithTarget(let newTarget)):
            if case .cooling(let existingTarget) = self {
                // identity 比较：knobKey 匹配则恢复 knobing
                if existingTarget.knobKey == newTarget.knobKey {
                    return TransitionResult(state: .knobing(target: newTarget), target: newTarget)
                } else {
                    return TransitionResult(state: .activated, target: nil)
                }
            }
            return nil

        default:
            return nil
        }
    }
}
