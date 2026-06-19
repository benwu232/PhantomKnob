import Foundation
import SwiftUI
import Combine
import AudioToolbox

enum HoveredKnobType: String {
    case none
    case volumeKnob
    case doubleKnob
    case linearKnob
}

class UserGuideViewModel: ObservableObject {
    @Published var currentStep: Int = 1
    
    // Step 1 states: Volume practice and touchpad check
    @Published var isTouchpadDetected: Bool = false
    @Published var touchpadSamplesCount: Int = 0
    @Published var volumeVal: Float = 0.5
    @Published var rotationAngle: Double = 0.0
    @Published var hovered: Bool = false // True if hovering volume knob in step 1
    
    // Step 2 states: Double/Linear comparison, multipliers, C key customization
    @Published var doubleKnobVal: Double = 50.0
    @Published var linearKnobVal: Double = 50.0
    @Published var doubleKnobAngle: Double = 0.0
    @Published var linearKnobAngle: Double = 0.0
    @Published var hoveredKnob: HoveredKnobType = .none
    @Published var currentMultiplier: Double = 1.0
    
    @Published var isGestureActive: Bool = false
    @Published var skipOnNextStartup: Bool = false
    
    private var tickAccumulator: Double = 0.0
    private let audioService: AudioControlService
    private var cancellables = Set<AnyCancellable>()
    private var systemSoundID: SystemSoundID = 0
    private var lastPlayTime: Double = 0
    
    // Compatibility property for old tests if needed
    var isStep2Unlocked: Bool {
        return isTouchpadDetected
    }
    var accumulatedRotation: Double = 0.0
    
    init(audioService: AudioControlService = AudioControlService()) {
        self.audioService = audioService
        self.volumeVal = audioService.getVolume() ?? 0.5
        self.currentMultiplier = getControlPanelMultiplier()
        setupBindings()
        
        let soundURL = URL(fileURLWithPath: "/System/Library/Sounds/Tink.aiff")
        AudioServicesCreateSystemSoundID(soundURL as CFURL, &systemSoundID)
    }
    
    deinit {
        if systemSoundID != 0 {
            AudioServicesDisposeSystemSoundID(systemSoundID)
        }
    }
    
    private func setupBindings() {
        // Trackpad coordinate detection binding
        NotificationCenter.default.publisher(for: NSNotification.Name("TouchpadCoordinatesValidated"))
            .sink { [weak self] _ in
                guard let self = self, self.currentStep == 1 else { return }
                self.touchpadSamplesCount += 1
                if self.touchpadSamplesCount >= 3 {
                    self.isTouchpadDetected = true
                }
            }
            .store(in: &cancellables)
            
        // Rotation delta binding
        NotificationCenter.default.publisher(for: NSNotification.Name("KnobPanelDidRotate"))
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let delta = notification.userInfo?["delta"] as? Double {
                    self.registerRotation(delta)
                }
            }
            .store(in: &cancellables)
            
        // Base scale (multiplier) update binding
        NotificationCenter.default.publisher(for: NSNotification.Name("KnobBaseScaleDidUpdate"))
            .sink { [weak self] notification in
                guard let self = self, self.currentStep == 2 else { return }
                if let scale = notification.userInfo?["scale"] as? Double {
                    self.currentMultiplier = scale
                }
            }
            .store(in: &cancellables)
            
        ControlPanelViewModel.shared.$isGestureActive
            .receive(on: RunLoop.main)
            .sink { [weak self] active in
                self?.isGestureActive = active
            }
            .store(in: &cancellables)
    }
    
    func nextStep() {
        if currentStep == 1 && !isTouchpadDetected { return }
        currentStep += 1
    }
    
    func registerRotation(_ degrees: Double) {
        let absDeg = abs(degrees)
        accumulatedRotation += absDeg // Compatibility for test
        
        if currentStep == 1 {
            guard hovered else { return }
            
            // Update visual rotation angle
            rotationAngle += degrees
            
            // Sync with system volume
            let sensitivity: Float = 0.005
            let deltaValue = Float(degrees) * sensitivity
            let newVal = max(0.0, min(1.0, volumeVal + deltaValue))
            if audioService.setVolume(newVal) {
                volumeVal = newVal
            }
            
            playFeedbackSound(absDeg)
        } else if currentStep == 2 {
            let sensitivity = 0.5 * currentMultiplier
            let deltaValue = degrees * sensitivity
            
            if hoveredKnob == .doubleKnob {
                doubleKnobAngle += degrees
                doubleKnobVal = max(0.0, min(100.0, doubleKnobVal + deltaValue))
                playFeedbackSound(absDeg)
            } else if hoveredKnob == .linearKnob {
                linearKnobAngle += degrees
                linearKnobVal = max(0.0, min(100.0, linearKnobVal + deltaValue))
                playFeedbackSound(absDeg)
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
    
    func updateTickAccumulationAndGetTicks(_ delta: Double) -> Int {
        tickAccumulator += delta
        if tickAccumulator >= 1.0 {
            let ticks = Int(tickAccumulator)
            tickAccumulator -= Double(ticks)
            return ticks
        }
        return 0
    }
    
    func getTickAccumulator() -> Double {
        return tickAccumulator
    }
    
    private func getControlPanelMultiplier() -> Double {
        let key = "knob_scale_override_com.phantomknob.controlpanel_ControlPanel___控制面板_zone_0"
        let val = UserDefaults.standard.double(forKey: key)
        return val > 0 ? val : 1.0
    }
    
    func completeGuide() {
        UserDefaults.standard.set(skipOnNextStartup, forKey: "skipUserGuideOnStartup")
        UserDefaults.standard.set(true, forKey: "firstRunUserGuideCompleted")
        UserDefaults.standard.set(true, forKey: "firstRunTutorialCompleted") // Sync check key
        UserGuideWindowController.shared.hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            KnobPanelWindowController.shared.show()
        }
    }
}
