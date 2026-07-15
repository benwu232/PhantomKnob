import Foundation
import SwiftUI
import Combine
import AudioToolbox

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
    
    @Published var focusedVariable: ControllableVariable? = .volume
    @Published var isGestureActive = false
    @Published var rotationAngles: [ControllableVariable: Double] = [
        .volume: 0, .brightness: 0, .keyboardBacklight: 0
    ]
    
    private let audioService: AudioControlService
    private let brightnessService: DisplayBrightnessService
    private let backlightService: KeyboardBacklightService
    
    private var systemSoundID: SystemSoundID = 0
    private var lastPlayTime: Double = 0
    private var tickAccumulator: Double = 0.0
    
    init(
        audioService: AudioControlService = AudioControlService(),
        brightnessService: DisplayBrightnessService = DisplayBrightnessService(),
        backlightService: KeyboardBacklightService = KeyboardBacklightService()
    ) {
        self.audioService = audioService
        self.brightnessService = brightnessService
        self.backlightService = backlightService
        
        refreshSystemValues()
        
        let soundURL = URL(fileURLWithPath: "/System/Library/Sounds/Tink.aiff")
        AudioServicesCreateSystemSoundID(soundURL as CFURL, &systemSoundID)
    }
    
    deinit {
        if systemSoundID != 0 {
            AudioServicesDisposeSystemSoundID(systemSoundID)
        }
    }
    
    func refreshSystemValues() {
        self.volumeVal = audioService.getVolume() ?? 0.5
        self.brightnessVal = brightnessService.getBrightness() ?? 0.5
        self.backlightVal = backlightService.getBrightness() ?? 0.3
    }
    
    func setHoverTarget(_ target: ControllableVariable?) {
        if let target = target {
            focusedVariable = target
        }
    }
    
    func selectNextVariable() {
        switch focusedVariable {
        case .volume:
            focusedVariable = .brightness
        case .brightness:
            focusedVariable = .keyboardBacklight
        case .keyboardBacklight:
            focusedVariable = .volume
        case nil:
            focusedVariable = .volume
        }
    }
    
    func selectPrevVariable() {
        switch focusedVariable {
        case .volume:
            focusedVariable = .keyboardBacklight
        case .brightness:
            focusedVariable = .volume
        case .keyboardBacklight:
            focusedVariable = .brightness
        case nil:
            focusedVariable = .volume
        }
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
                playFeedbackSound(abs(deltaDegrees))
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
    
    private func playFeedbackSound(_ absDeg: Double) {
        let ticks = updateTickAccumulationAndGetTicks(absDeg)
        let now = ProcessInfo.processInfo.systemUptime
        if ticks > 0 && (now - lastPlayTime) >= 0.1 {
            if systemSoundID != 0 {
                AudioServicesPlaySystemSound(systemSoundID)
            } else {
                AudioServicesPlaySystemSound(1104)
            }
            lastPlayTime = now
        }
    }
    
    private func updateTickAccumulationAndGetTicks(_ delta: Double) -> Int {
        tickAccumulator += delta
        if tickAccumulator >= 1.0 {
            let ticks = Int(tickAccumulator)
            tickAccumulator -= Double(ticks)
            return ticks
        }
        return 0
    }
}
