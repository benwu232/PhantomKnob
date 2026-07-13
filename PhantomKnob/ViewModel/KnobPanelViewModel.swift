import Foundation
import SwiftUI
import Combine

enum ControllableVariable {
    case volume
    case brightness
    case keyboardBacklight
}

class ControlPanelViewModel: ObservableObject {
    static let shared = ControlPanelViewModel()
    
    @Published var isPinned: Bool = false {
        didSet {
            KnobPanelWindowController.shared.setPinned(isPinned)
        }
    }
    @Published var volumeVal: Float = 0.5
    @Published var brightnessVal: Float = 0.5
    @Published var backlightVal: Float = 0.3
    
    @Published var focusedVariable: ControllableVariable? = nil
    @Published var isGestureActive = false
    @Published var rotationAngles: [ControllableVariable: Double] = [
        .volume: 0, .brightness: 0, .keyboardBacklight: 0
    ]
    
    private let audioService: AudioControlService
    private let brightnessService: DisplayBrightnessService
    private let backlightService: KeyboardBacklightService
    
    init(
        audioService: AudioControlService = AudioControlService(),
        brightnessService: DisplayBrightnessService = DisplayBrightnessService(),
        backlightService: KeyboardBacklightService = KeyboardBacklightService()
    ) {
        self.audioService = audioService
        self.brightnessService = brightnessService
        self.backlightService = backlightService
        
        refreshSystemValues()
    }
    
    func refreshSystemValues() {
        self.volumeVal = audioService.getVolume() ?? 0.5
        self.brightnessVal = brightnessService.getBrightness() ?? 0.5
        self.backlightVal = backlightService.getBrightness() ?? 0.3
    }
    
    func setHoverTarget(_ target: ControllableVariable?) {
        focusedVariable = target
    }
    
    func receiveRotationDelta(_ deltaDegrees: Double) {
        let target = focusedVariable ?? .volume
        
        let sensitivity: Float = 0.005
        let deltaValue = Float(deltaDegrees) * sensitivity
        
        switch target {
        case .volume:
            let newVal = max(0.0, min(1.0, volumeVal + deltaValue))
            if audioService.setVolume(newVal) {
                volumeVal = newVal
                rotationAngles[.volume, default: 0.0] += deltaDegrees
            }
        case .brightness:
            let newVal = max(0.0, min(1.0, brightnessVal + deltaValue))
            if brightnessService.setBrightness(newVal) {
                brightnessVal = newVal
                rotationAngles[.brightness, default: 0.0] += deltaDegrees
            }
        case .keyboardBacklight:
            let newVal = max(0.0, min(1.0, backlightVal + deltaValue))
            if backlightService.setBrightness(newVal) {
                backlightVal = newVal
                rotationAngles[.keyboardBacklight, default: 0.0] += deltaDegrees
            }
        }
    }
}
