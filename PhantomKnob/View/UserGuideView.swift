import SwiftUI

struct UserGuideView: View {
    @StateObject private var viewModel = UserGuideViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                if viewModel.currentStep == 1 {
                    Text(String(localized: "guide.step1.title", defaultValue: "Step 1: Detect & Rotate"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text(String(localized: "guide.step1.subtitle", defaultValue: "Verify your trackpad and practice the rotation gesture"))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                } else if viewModel.currentStep == 2 {
                    Text(String(localized: "guide.step2.title", defaultValue: "Step 2: Modes & Customization"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text(String(localized: "guide.step2.subtitle", defaultValue: "Try different knob modes and customize your dial"))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text(String(localized: "guide.step3.title", defaultValue: "Step 3: Go Global"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text(String(localized: "guide.step3.subtitle", defaultValue: "Master shortcuts and discover supported apps"))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Content
            Group {
                if viewModel.currentStep == 1 {
                    step1View
                } else if viewModel.currentStep == 2 {
                    step2View
                } else {
                    step3View
                }
            }
            .frame(maxHeight: .infinity)
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Footer (Navigation)
            HStack {
                if viewModel.currentStep > 1 {
                    Button(action: {
                        withAnimation {
                            viewModel.currentStep -= 1
                        }
                    }) {
                        Text(String(localized: "guide.nav.prev", defaultValue: "Previous"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                if viewModel.currentStep == 2 {
                    Button(action: {
                        viewModel.completeGuide()
                    }) {
                        Text(String(localized: "guide.nav.close", defaultValue: "Close Guide"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                
                if viewModel.currentStep < 3 {
                    Button(action: {
                        withAnimation {
                            viewModel.nextStep()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(String(localized: "guide.nav.next", defaultValue: "Next"))
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: viewModel.currentStep == 1 && !viewModel.isTouchpadDetected
                                    ? [Color(white: 1.0, opacity: 0.1), Color(white: 1.0, opacity: 0.1)]
                                    : [Color.blue, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                        .shadow(color: Color.blue.opacity(viewModel.currentStep == 1 && !viewModel.isTouchpadDetected ? 0 : 0.3), radius: 4, y: 2)
                    }
                    .disabled(viewModel.currentStep == 1 && !viewModel.isTouchpadDetected)
                    .buttonStyle(.plain)
                } else {
                    Button(action: {
                        viewModel.completeGuide()
                    }) {
                        Text(String(localized: "guide.nav.start", defaultValue: "Enable Global Control"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [Color.green, Color.emerald],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(8)
                            .shadow(color: Color.green.opacity(0.3), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 725, height: 575)
    }
    
    // MARK: - Step 1: Device test & Volume practice
    private var step1View: some View {
        VStack(spacing: 16) {
            Text(String(localized: "guide.step1.description", defaultValue: "Please practice the rotation gesture on your trackpad:\nHover your cursor over the volume dial, then rotate with two fingers."))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 16)
            
            ZStack {
                RadialKnobControlView(
                    title: String(localized: "guide.step1.practiceKnob", defaultValue: "Volume Practice Dial"),
                    icon: "speaker.wave.3.fill",
                    value: viewModel.volumeVal,
                    angle: viewModel.rotationAngle,
                    isFocused: viewModel.hovered,
                    isGestureActive: viewModel.isGestureActive,
                    showPercentage: true
                )
                .onHover { isHover in
                    viewModel.hovered = isHover
                    viewModel.hoveredKnob = isHover ? .volumeKnob : .none
                }
                
                if !viewModel.hovered && !viewModel.isTouchpadDetected {
                    CursorGuideAnimationView()
                        .offset(x: 70, y: -50)
                        .transition(.opacity)
                }
            }
            .frame(height: 140)
            
            HStack(spacing: 8) {
                if viewModel.isTouchpadDetected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                    Text(String(localized: "guide.step1.detectedSuccess", defaultValue: "✅ Trackpad detected successfully! Your device is fully supported."))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.green)
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                    Text(String(format: String(localized: "guide.step1.waitingDetection", defaultValue: "Waiting for rotation gestures to detect device (Samples: %@/3)…"), "\(viewModel.touchpadSamplesCount)"))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.05))
            .cornerRadius(20)
            
            Spacer()
        }
    }
    
    // MARK: - Step 2: Knob comparison, multipliers, HUD trigger
    private var step2View: some View {
        VStack(spacing: 8) {
            // Side-by-side self-drawn knobs
            HStack(spacing: 80) {
                // Double Ring Knob
                VStack(spacing: 8) {
                    ZStack {
                        OverlayView(
                            targetName: String(localized: "guide.step2.doubleKnobName", defaultValue: "Double-Ring Dial"),
                            valueText: String(format: "%.1f", viewModel.doubleKnobVal),
                            angle: viewModel.doubleKnobAngle,
                            isDeadzone: false,
                            scale: viewModel.doubleKnobBaseMultiplier * viewModel.currentMultiplier,
                            themeColorHex: "#F59E0B",
                            overlayStyle: AppSettings.shared.defaultOverlayStyle,
                            rotationStyle: AppSettings.shared.defaultRotationStyle,
                            diameter: viewModel.doubleKnobDiameter
                        )
                        .onHover { isHover in
                            viewModel.hoveredKnob = isHover ? .doubleKnob : .none
                        }
                    }
                    .frame(height: 340)
                    
                    Text(String(localized: "guide.step2.doubleKnobDesc1", defaultValue: "Double-Ring (Outer 0.1x, Inner 1.0x)"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Text(String(localized: "guide.step2.doubleKnobDesc2", defaultValue: "Switches between fine and coarse tuning automatically"))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        triggerCustomizer(for: "DoubleKnob")
                    }) {
                        Text(String(localized: "guide.step2.customizeButton", defaultValue: "Customize Dial"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 300)
                
                // Linear Knob
                VStack(spacing: 8) {
                    ZStack {
                        OverlayView(
                            targetName: String(localized: "guide.step2.linearKnobName", defaultValue: "Variable Speed Dial"),
                            valueText: String(format: "%.1f", viewModel.linearKnobVal),
                            angle: viewModel.linearKnobAngle,
                            isDeadzone: false,
                            scale: viewModel.linearKnobBaseMultiplier * viewModel.currentMultiplier,
                            themeColorHex: "#F59E0B",
                            overlayStyle: AppSettings.shared.defaultOverlayStyle,
                            rotationStyle: AppSettings.shared.defaultRotationStyle,
                            diameter: viewModel.linearKnobDiameter
                        )
                        .onHover { isHover in
                            viewModel.hoveredKnob = isHover ? .linearKnob : .none
                        }
                    }
                    .frame(height: 340)
                    
                    Text(String(localized: "guide.step2.linearKnobDesc1", defaultValue: "Variable Speed (0.1x ~ 5.0x)"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Text(String(localized: "guide.step2.linearKnobDesc2", defaultValue: "Speed scales continuously based on finger rotation radius"))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        triggerCustomizer(for: "LinearKnob")
                    }) {
                        Text(String(localized: "guide.step2.customizeButton", defaultValue: "Customize Dial"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.15))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 300)
            }
            .padding(.vertical, 10)
            
            // Instruction Box
            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "guide.step2.hintTitle", defaultValue: "💡 Fine-tune speed with keyboard"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Text(String(localized: "guide.step2.hintLine1", defaultValue: "• Press ↑/↓ to adjust by 1.0x, ←/→ to adjust by 0.1x, or 2-9 to multiply speed."))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
                Text(String(localized: "guide.step2.hintLine2", defaultValue: "• Press 'C' key while rotating to open the Customizer HUD panel."))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    private var supportedApps: [String] {
        let appNames: [String: String] = [
            "com.apple.QuickTimePlayerX": "QuickTime Player",
            "com.apple.FinalCut": "Final Cut Pro",
            "com.apple.logic10": "Logic Pro",
            "com.blackmagic-design.DaVinciResolve": "DaVinci Resolve",
            "com.lemon.lvoverseas": "CapCut",
            "com.lemon.jianyingpro": "JianYing",
        ]
        _ = appNames
        return ["QuickTime Player", "Final Cut Pro", "DaVinci Resolve", "CapCut", "Logic Pro"]
    }

    // MARK: - Step 3: Global intro & Confirm
    private var step3View: some View {
        VStack(spacing: 20) {
            Text(String(localized: "guide.step3.readyTitle", defaultValue: "Phantom Knob is ready!"))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.green)
                .padding(.top, 20)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "command")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "guide.step3.feature1.title", defaultValue: "Global Toggle Shortcut: ⌘ ⌥ R (Command + Option + R)"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text(String(localized: "guide.step3.feature1.desc", defaultValue: "Press the shortcut or enable it from the menu bar to control any slider, stepper, or dial with gestures."))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "option")
                        .font(.system(size: 18))
                        .foregroundColor(.cyan)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "guide.step3.feature2.title", defaultValue: "Temporarily Bypass Gestures: Hold Option Key"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text(String(localized: "guide.step3.feature2.desc", defaultValue: "If you want to use native trackpad scrolling or pinch-to-zoom, hold the Option key to temporarily bypass gestures."))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.purple)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "guide.step3.feature3.title", defaultValue: "Out-of-the-box Creative App Integrations"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text(String(localized: "guide.step3.feature3.desc", defaultValue: "Phantom Knob works with timelines, volumes, and sliders in supported apps. Hover over any control and rotate."))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                        HStack(spacing: 6) {
                            ForEach(supportedApps, id: \.self) { appName in
                                Text(appName)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            Toggle(String(localized: "guide.step3.skipGuide", defaultValue: "Don't show user guide again on next startup"), isOn: $viewModel.skipOnNextStartup)
                .toggleStyle(.checkbox)
                .foregroundColor(.white.opacity(0.85))
                .font(.system(size: 12))
            
            Spacer()
        }
    }
    
    // MARK: - Customizer Trigger Helper
    private func triggerCustomizer(for knobType: String) {
        let target = DetectedTarget(
            bundleID: "com.phantomknob.controlpanel",
            axRole: "ControlPanel",
            identifier: knobType,
            displayName: knobType == "DoubleKnob" 
                ? String(localized: "guide.step2.doubleKnobName", defaultValue: "Double-Ring Dial") 
                : String(localized: "guide.step2.linearKnobName", defaultValue: "Variable Speed Dial"),
            element: nil,
            parentChain: []
        )
        CustomizerHUDWindowController.shared.show(for: target)
    }
}

struct CursorGuideAnimationView: View {
    @State private var pulse = false
    
    var body: some View {
        Image(systemName: "hand.draw.fill")
            .font(.system(size: 32))
            .foregroundColor(Color.blue.opacity(0.8))
            .scaleEffect(pulse ? 1.2 : 0.9)
            .offset(x: pulse ? -10 : 10, y: pulse ? 10 : -10)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

// Color asset helpers to avoid styling compilation errors
extension Color {
    static let emerald = Color(red: 16/255, green: 185/255, blue: 129/255)
    static let amber = Color(red: 245/255, green: 158/255, blue: 11/255)
}
