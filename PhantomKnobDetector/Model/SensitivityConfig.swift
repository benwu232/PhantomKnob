import Foundation

enum ControlType {
    case slider
    case progressIndicator
    case scrollbar
    case unknown
}

struct SensitivityConfig: Codable {
    var globalDefault: Double = 0.5
    
    var sliderSensitivity: Double?
    var progressSensitivity: Double?
    var scrollbarSensitivity: Double?
    
    func sensitivity(for type: ControlType) -> Double {
        switch type {
        case .slider:
            return sliderSensitivity ?? globalDefault
        case .progressIndicator:
            return progressSensitivity ?? globalDefault
        case .scrollbar:
            return scrollbarSensitivity ?? globalDefault
        case .unknown:
            return globalDefault
        }
    }
}
