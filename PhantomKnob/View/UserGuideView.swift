import SwiftUI

struct UserGuideView: View {
    @StateObject private var viewModel = UserGuideViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                if viewModel.currentStep == 1 {
                    Text(String(localized: "guide.stepWelcome.title", defaultValue: "Welcome"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text(String(localized: "guide.stepWelcome.subtitle", defaultValue: "Discover how to use trackpad gestures to control sliders"))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                } else if viewModel.currentStep == 2 {
                    Text(String(localized: "guide.step1.title", defaultValue: "Step 1: Detect & Rotate"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text(String(localized: "guide.step1.subtitle", defaultValue: "Verify your trackpad and practice the rotation gesture"))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                } else if viewModel.currentStep == 3 {
                    Text(String(localized: "guide.step2.title", defaultValue: "Step 2: Advanced Knobs"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text(String(localized: "guide.step2.subtitle", defaultValue: "Practice double-ring and variable speed knobs, adjust speed, and try customizer"))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                } else if viewModel.currentStep == 4 {
                    Text(String(localized: "guide.step3.title", defaultValue: "Step 3: Go Global"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text(String(localized: "guide.step3.subtitle", defaultValue: "Master shortcuts and discover supported apps"))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text(String(localized: "guide.stepShortcuts.title", defaultValue: "Shortcuts & Operations Guide"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text(String(localized: "guide.stepShortcuts.subtitle", defaultValue: "Quick reference manual for system gestures and shortcuts"))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.top, 28)
            .padding(.bottom, 16)
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Content
            Group {
                if viewModel.currentStep == 1 {
                    welcomeView
                } else if viewModel.currentStep == 2 {
                    step1View
                } else if viewModel.currentStep == 3 {
                    step2View
                } else if viewModel.currentStep == 4 {
                    step3View
                } else {
                    shortcutsView
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
                
                if viewModel.currentStep < 5 {
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
                                colors: viewModel.currentStep == 2 && !viewModel.isTouchpadDetected
                                    ? [Color(white: 1.0, opacity: 0.1), Color(white: 1.0, opacity: 0.1)]
                                    : [Color.blue, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                        .shadow(color: Color.blue.opacity(viewModel.currentStep == 2 && !viewModel.isTouchpadDetected ? 0 : 0.3), radius: 4, y: 2)
                    }
                    .disabled(viewModel.currentStep == 2 && !viewModel.isTouchpadDetected)
                    .buttonStyle(.plain)
                } else {
                    Button(action: {
                        viewModel.completeGuide()
                    }) {
                        Text(String(localized: "guide.nav.exit", defaultValue: "Exit"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.8), Color.red.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(8)
                            .shadow(color: Color.red.opacity(0.2), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 725, height: 575)
        .overlay(
            HStack {
                HUDCircleButton(icon: "xmark", color: .white.opacity(0.7)) {
                    UserGuideWindowController.shared.hide()
                }
                Spacer()
                HUDCircleButton(
                    icon: viewModel.isPinned ? "pin.fill" : "pin",
                    color: viewModel.isPinned ? .orange : .white.opacity(0.6)
                ) {
                    viewModel.isPinned.toggle()
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14),
            alignment: .top
        )
    }
    
    // MARK: - Step 1: Device test & Volume practice
    private var step1View: some View {
        VStack(spacing: 0) {
            Spacer()
            
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
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "guide.step1.intro", defaultValue: "Please practice using the knob gesture on your trackpad:"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.bottom, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    bulletItem(text: String(localized: "guide.step1.step1", defaultValue: "Grant accessibility permission to PhantomKnob in System Settings > Privacy & Security > Accessibility."))
                    bulletItem(text: String(localized: "guide.step1.step2", defaultValue: "Move the cursor onto the volume practice dial."))
                    bulletItem(text: String(localized: "guide.step1.step3", defaultValue: "Touch the trackpad with two fingers and perform a rotation gesture."))
                }
                
                Text(String(localized: "guide.step1.footer", defaultValue: "The system will detect whether your hardware supports knob gestures; if supported, you will see the dial rotate and hear the volume change."))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.03))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .padding(.horizontal, 32)
            .padding(.bottom, 12)
            
            HStack(spacing: 8) {
                if viewModel.isTouchpadDetected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                    Text(String(localized: "guide.step1.detectedSuccess", defaultValue: "🎉 Congratulations! You have successfully used the knob gesture. Please click Next to continue."))
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
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Step 2: Knob comparison, multipliers, HUD trigger
    private var step2View: some View {
        VStack(spacing: 0) {
            Spacer()
            
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
                            themeColorHex: "#007AFF",
                            overlayStyle: AppSettings.shared.defaultOverlayStyle,
                            rotationStyle: AppSettings.shared.defaultRotationStyle,
                            diameter: viewModel.doubleKnobDiameter
                        )
                        .scaleEffect(viewModel.hoveredKnob == .doubleKnob ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.hoveredKnob)
                        .onHover { isHover in
                            viewModel.hoveredKnob = isHover ? .doubleKnob : .none
                        }
                    }
                    .frame(height: 180)
                    
                    Text(String(localized: "guide.step2.doubleKnobDesc1", defaultValue: "Double-Ring (Outer 0.1x, Inner 1.0x)"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Text(String(localized: "guide.step2.doubleKnobDesc2", defaultValue: "Switches between fine and coarse tuning automatically"))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .frame(height: 24)
                    
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
                .frame(width: 260)
                
                // Linear Knob
                VStack(spacing: 8) {
                    ZStack {
                        OverlayView(
                            targetName: String(localized: "guide.step2.linearKnobName", defaultValue: "Variable Speed Dial"),
                            valueText: String(format: "%.1f", viewModel.linearKnobVal),
                            angle: viewModel.linearKnobAngle,
                            isDeadzone: false,
                            scale: viewModel.linearKnobBaseMultiplier * viewModel.currentMultiplier,
                            themeColorHex: "#34C759",
                            overlayStyle: AppSettings.shared.defaultOverlayStyle,
                            rotationStyle: AppSettings.shared.defaultRotationStyle,
                            diameter: viewModel.linearKnobDiameter
                        )
                        .scaleEffect(viewModel.hoveredKnob == .linearKnob ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.hoveredKnob)
                        .onHover { isHover in
                            viewModel.hoveredKnob = isHover ? .linearKnob : .none
                        }
                    }
                    .frame(height: 180)
                    
                    Text(String(localized: "guide.step2.linearKnobDesc1", defaultValue: "Variable Speed (0.1x ~ 5.0x)"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Text(String(localized: "guide.step2.linearKnobDesc2", defaultValue: "Speed scales continuously based on finger rotation radius"))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .frame(height: 24)
                    
                    Button(action: {
                        triggerCustomizer(for: "LinearKnob")
                    }) {
                        Text(String(localized: "guide.step2.customizeButton", defaultValue: "Customize Dial"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 260)
            }
            
            Spacer()
            
            // Card layout instruction box matching Page 1
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "guide.step2.hintTitle", defaultValue: "💡 Fine-tune speed & customize:").trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.bottom, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    bulletItem(text: String(localized: "guide.step2.hintLine1", defaultValue: "Press ↑/↓ to adjust by 1.0x, ←/→ to adjust by 0.1x, or 2-9 to multiply speed."))
                    bulletItem(text: String(localized: "guide.step2.hintLine2", defaultValue: "Press 'C' key while rotating to open the Customizer HUD panel."))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.03))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
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
                HStack(alignment: .center, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "menubar.rectangle")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "guide.step3.featureStatusbar.title", defaultValue: "Quick Control Panel"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Text(String(localized: "guide.step3.featureStatusbar.desc", defaultValue: "Double-click the menu bar icon to pop up the quick control panel, allowing you to easily adjust volume, screen brightness, etc., with knob gestures."))
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    Spacer(minLength: 12)
                    
                    Button(action: {
                        viewModel.completeGuide()
                    }) {
                        Text(String(localized: "guide.nav.start", defaultValue: "Enable Global Control"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: [Color.green, Color.emerald],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(6)
                            .shadow(color: Color.green.opacity(0.3), radius: 3, y: 1.5)
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "command")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "guide.step3.feature1.title", defaultValue: "Global Toggle Shortcut: ⌘ ⌥ K (Command + Option + K)"))
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
    
    private func bulletItem(text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .foregroundColor(.blue)
                .font(.system(size: 13, weight: .bold))
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Step 1: Welcome & Intro
    private var welcomeView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(nsImage: NSImage(named: "NSApplicationIcon") ?? NSImage())
                .resizable()
                .frame(width: 80, height: 80)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.2), radius: 6, y: 3)
            
            VStack(spacing: 8) {
                Text(String(localized: "guide.welcome.headline", defaultValue: "Welcome to PhantomKnob"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Text(String(localized: "guide.welcome.intro", defaultValue: "Use natural two-finger rotation gestures to precisely control\nsliders and dials in video or audio editors, just like a physical dial."))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    viewModel.nextStep()
                }
            }) {
                Text(String(localized: "guide.welcome.start", defaultValue: "Start Onboarding Guide"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                    .shadow(color: Color.blue.opacity(0.3), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
    }

    // MARK: - Step 5: Shortcuts Reference
    private var shortcutsView: some View {
        ScrollView(showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                
                // Status Bar Icon Operations
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "guide.shortcuts.section.statusbar", defaultValue: "Status Bar Icon Operations"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                    
                    shortcutRow(key: String(localized: "guide.shortcuts.statusbar.click", defaultValue: "Single Click"), desc: String(localized: "guide.shortcuts.statusbar.click.desc", defaultValue: "Toggle global gesture control mode (activate/deactivate)"))
                    shortcutRow(key: String(localized: "guide.shortcuts.statusbar.doubleClick", defaultValue: "Double Click"), desc: String(localized: "guide.shortcuts.statusbar.doubleClick.desc", defaultValue: "Show/hide the shortcut button panel (Control Panel)"))
                    shortcutRow(key: String(localized: "guide.shortcuts.statusbar.rightClick", defaultValue: "Right Click / Ctrl+Click"), desc: String(localized: "guide.shortcuts.statusbar.rightClick.desc", defaultValue: "Open app system menu (Settings, User Guide, etc.)"))
                }
                .padding(12)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
                
                // Keyboard Shortcuts
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "guide.shortcuts.section.keyboard", defaultValue: "Keyboard Shortcuts"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.orange)
                    
                    shortcutRow(key: "⌘ ⌥ K", desc: String(localized: "guide.shortcuts.keyboard.toggle", defaultValue: "Global control switch shortcut — toggle active state instantly"))
                    shortcutRow(key: String(localized: "guide.shortcuts.keyboard.bypass", defaultValue: "Hold Option Key"), desc: String(localized: "guide.shortcuts.keyboard.bypass.desc", defaultValue: "Temporarily bypass gestures to use native trackpad scroll or zoom"))
                }
                .padding(12)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)

                // Auxiliary Keys During Rotation
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "guide.shortcuts.section.auxiliary", defaultValue: "Auxiliary Keys (Active During Rotation)"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.green)
                    
                    shortcutRow(key: "C", desc: String(localized: "guide.shortcuts.auxiliary.cKey", defaultValue: "Press during gesture rotation to directly show the Customizer panel"))
                    shortcutRow(key: "1", desc: String(localized: "guide.shortcuts.auxiliary.key1", defaultValue: "Reset rotation speed to 1.0x of the base speed setting"))
                    shortcutRow(key: "2 - 9", desc: String(localized: "guide.shortcuts.auxiliary.key2to9", defaultValue: "Set rotation speed multiplier to 2.0x ~ 9.0x of the base speed setting"))
                    shortcutRow(key: "↑ / ↓", desc: String(localized: "guide.shortcuts.auxiliary.arrowsVertical", defaultValue: "Increase/decrease rotation speed multiplier by 1.0x"))
                    shortcutRow(key: "← / →", desc: String(localized: "guide.shortcuts.auxiliary.arrowsHorizontal", defaultValue: "Increase/decrease rotation speed multiplier by 0.1x"))
                }
                .padding(12)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    private func shortcutRow(key: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.12))
                .cornerRadius(4)
                .frame(width: 140, alignment: .leading)
            
            Text(desc)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
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
