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
    @Published var doubleKnobBaseMultiplier: Double = 1.0
    @Published var linearKnobBaseMultiplier: Double = 1.0
    @Published var doubleKnobDiameter: CGFloat = 120.0
    @Published var linearKnobDiameter: CGFloat = 120.0
    
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
        self.isTouchpadDetected = UserDefaults.standard.bool(forKey: "userGuideTouchpadPracticed")
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
            .sink { [weak self] notification in
                guard let self = self else { return }
                if self.currentStep == 1 {
                    self.touchpadSamplesCount += 1
                    if self.touchpadSamplesCount >= 3 {
                        self.isTouchpadDetected = true
                    }
                } else if self.currentStep == 2 {
                    if let points = notification.userInfo?["points"] as? [Int: CGPoint] {
                        self.processTouchPoints(points)
                    }
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
                if !active {
                    self?.doubleKnobDiameter = 120.0
                    self?.linearKnobDiameter = 120.0
                }
            }
            .store(in: &cancellables)
            
        $hoveredKnob
            .sink { [weak self] type in
                if type == .none {
                    self?.doubleKnobDiameter = 120.0
                    self?.linearKnobDiameter = 120.0
                }
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.publisher(for: NSNotification.Name("UserGuideWindowDidShow"))
            .sink { [weak self] _ in
                self?.resetState()
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
            let volumeKey = RuleKey(bundleID: "com.phantomknob.controlpanel", axRole: "ControlPanel", identifier: "VolumeKnob")
            let rule = RuleLibrary.shared.lookup(for: volumeKey)
            let scale = rule?.singleConfig?.unitPerDegree ?? 1.0
            
            let sensitivity: Float = Float(0.005 * scale)
            let deltaValue = Float(degrees) * sensitivity
            let newVal = max(0.0, min(1.0, volumeVal + deltaValue))
            if audioService.setVolume(newVal) {
                volumeVal = newVal
            }
            
            playFeedbackSound(absDeg)
            
            if accumulatedRotation >= 30.0 && !isTouchpadDetected {
                isTouchpadDetected = true
                UserDefaults.standard.set(true, forKey: "userGuideTouchpadPracticed")
            }
        } else if currentStep == 2 {
            if hoveredKnob == .doubleKnob {
                doubleKnobAngle -= degrees
                let sensitivity = 0.5 * doubleKnobBaseMultiplier * currentMultiplier
                let deltaValue = degrees * sensitivity
                doubleKnobVal = max(0.0, min(100.0, doubleKnobVal + deltaValue))
            } else if hoveredKnob == .linearKnob {
                linearKnobAngle -= degrees
                let sensitivity = 0.5 * linearKnobBaseMultiplier * currentMultiplier
                let deltaValue = degrees * sensitivity
                linearKnobVal = max(0.0, min(100.0, linearKnobVal + deltaValue))
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
    
    private func processTouchPoints(_ points: [Int: CGPoint]) {
        guard points.count >= 2 else { return }
        let (knobCore, _, _) = KnobAlgorithm().calKnob(points)
        guard knobCore.isValid else { return }
        let radius = knobCore.radius
        
        if hoveredKnob == .doubleKnob {
            let doubleKey = RuleKey(bundleID: "com.phantomknob.controlpanel", axRole: "ControlPanel", identifier: "DoubleKnob")
            let rule = RuleLibrary.shared.lookup(for: doubleKey)
            let doubleConfig = rule?.doubleConfig
            
            let maxInner = doubleConfig?.inner.maxRadius ?? 25.0
            let scaleInner = doubleConfig?.inner.unitPerDegree ?? 1.0
            let scaleOuter = doubleConfig?.outer.unitPerDegree ?? 0.1
            
            // 双环：内环对应 scaleInner；外环对应 scaleOuter
            doubleKnobBaseMultiplier = (radius > maxInner) ? scaleOuter : scaleInner
            
            doubleKnobDiameter = OverlayController.calculateDiameter(for: radius)
            linearKnobDiameter = 120.0
        } else if hoveredKnob == .linearKnob {
            let linearKey = RuleKey(bundleID: "com.phantomknob.controlpanel", axRole: "ControlPanel", identifier: "LinearKnob")
            let rule = RuleLibrary.shared.lookup(for: linearKey)
            let linearConfig = rule?.linearConfig
            
            let minR = linearConfig?.minRadius ?? 10.0
            let maxR = linearConfig?.maxRadius ?? 30.0
            let minScale = linearConfig?.minScale ?? 0.1
            let maxScale = linearConfig?.maxScale ?? 5.0
            
            let r = max(minR, min(maxR, radius))
            let ratio = (r - minR) / (maxR - minR)
            
            linearKnobBaseMultiplier = maxScale - ratio * (maxScale - minScale)
            linearKnobDiameter = OverlayController.calculateDiameter(for: radius)
            doubleKnobDiameter = 120.0
        }
    }
    
    func resetState() {
        currentStep = 1
        isTouchpadDetected = UserDefaults.standard.bool(forKey: "userGuideTouchpadPracticed")
        touchpadSamplesCount = 0
        volumeVal = audioService.getVolume() ?? 0.5
        rotationAngle = 0.0
        accumulatedRotation = 0.0
        hovered = false
        hoveredKnob = .none
        doubleKnobVal = 50.0
        linearKnobVal = 50.0
        doubleKnobAngle = 0.0
        linearKnobAngle = 0.0
        doubleKnobDiameter = 120.0
        linearKnobDiameter = 120.0
    }
}
