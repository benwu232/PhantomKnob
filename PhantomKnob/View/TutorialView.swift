import SwiftUI

class TutorialViewModel: ObservableObject {
    @Published var currentStep: Int = 1
    @Published var isStep2Unlocked: Bool = false
    @Published var accumulatedRotation: Double = 0.0
    
    func nextStep() {
        if currentStep == 2 && !isStep2Unlocked { return }
        currentStep += 1
    }
    
    func registerRotation(_ degrees: Double) {
        guard currentStep == 2 else { return }
        accumulatedRotation += abs(degrees)
        if accumulatedRotation >= 360.0 {
            isStep2Unlocked = true
        }
    }
    
    func completeTutorial() {
        UserDefaults.standard.set(true, forKey: "firstRunTutorialCompleted")
        KnobPanelWindowController.shared.hide()
    }
}

struct TutorialView: View {
    @StateObject var tutorialVM = TutorialViewModel()
    @EnvironmentObject var controlPanelVM: ControlPanelViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            if tutorialVM.currentStep == 1 {
                VStack(spacing: 16) {
                    Text(String(localized: "tutorial.step1.title", defaultValue: "Welcome to Phantom Knob!"))
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text(String(localized: "tutorial.step1.description", defaultValue: "Adjust volume, screen brightness, and keyboard backlight by rotating two fingers on your trackpad."))
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(String(localized: "tutorial.step1.hotkey", defaultValue: "Double-click the menu bar icon or press ⌥Space to toggle the control panel."))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Button(String(localized: "tutorial.step1.button", defaultValue: "Start Onboarding")) {
                        tutorialVM.nextStep()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else if tutorialVM.currentStep == 2 {
                VStack(spacing: 16) {
                    Text(String(localized: "tutorial.step2.title", defaultValue: "Gesture Practice (Rotate 360°)"))
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text(String(localized: "tutorial.step2.description", defaultValue: "Hover your cursor over any dial below, then place two fingers on the trackpad and rotate."))
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.8))
                    
                    ProgressView(value: min(tutorialVM.accumulatedRotation, 360.0), total: 360.0)
                        .progressViewStyle(.linear)
                        .frame(width: 240)
                    
                    let progressText = String(format: String(localized: "tutorial.step2.progress", defaultValue: "Completed: %d° / 360°"), Int(min(tutorialVM.accumulatedRotation, 360.0)))
                    Text(progressText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.blue)
                    
                    Button(String(localized: "tutorial.step2.button", defaultValue: "Next")) {
                        tutorialVM.nextStep()
                    }
                    .disabled(!tutorialVM.isStep2Unlocked)
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 16) {
                    Text(String(localized: "tutorial.step3.title", defaultValue: "Congratulations! Onboarding completed."))
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text(String(localized: "tutorial.step3.description", defaultValue: "When this panel is visible, gestures control the selected dial. When hidden, they control any slider under your cursor."))
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Button(String(localized: "tutorial.step3.button", defaultValue: "Get Started")) {
                        tutorialVM.completeTutorial()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("KnobPanelDidRotate"))) { notification in
            if let delta = notification.userInfo?["delta"] as? Double {
                tutorialVM.registerRotation(delta)
            }
        }
    }
}
