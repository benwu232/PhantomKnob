import SwiftUI
import AppKit

enum SettingsTab {
    case general
    case about
}

// MARK: - Root View

struct SettingsView: View {
    @State private var activeTab: SettingsTab = .general
    @State private var isPinned: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Close, Tabs and Pin buttons
            HStack {
                HUDCircleButton(icon: "xmark", color: .white.opacity(0.7)) {
                    SettingsWindowController.shared.hide()
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            activeTab = .general
                        }
                    }) {
                        Text(String(localized: "settings.tab.general", defaultValue: "General"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(activeTab == .general ? .white : .white.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(activeTab == .general ? Color.white.opacity(0.12) : Color.clear)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            activeTab = .about
                        }
                    }) {
                        Text(String(localized: "settings.tab.about", defaultValue: "About"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(activeTab == .about ? .white : .white.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(activeTab == .about ? Color.white.opacity(0.12) : Color.clear)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                HUDCircleButton(
                    icon: isPinned ? "pin.fill" : "pin",
                    color: isPinned ? .orange : .white.opacity(0.6)
                ) {
                    isPinned.toggle()
                    SettingsWindowController.shared.isPinned = isPinned
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Tab content with gradient mask
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if activeTab == .general {
                        GeneralSettingsView()
                    } else {
                        AboutView()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .frame(maxHeight: .infinity)
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.05),
                        .init(color: .black, location: 0.95),
                        .init(color: .clear, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(width: 560, height: 440)
        .foregroundColor(.white)
        .preferredColorScheme(.dark)
        .onAppear {
            isPinned = SettingsWindowController.shared.isPinned
        }
    }
}

// MARK: - General Tab

struct GeneralSettingsView: View {
    @State private var hasAccessibilityPermission = AXIsProcessTrusted()
    @AppStorage("skipUserGuideOnStartup") private var skipUserGuideOnStartup = false
    @State private var launchAtLogin = false

    var body: some View {
        VStack(spacing: 14) {
            // -- Language Section Card --
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .foregroundColor(.blue)
                        .font(.system(size: 12, weight: .semibold))
                    Text(String(localized: "settings.section.language", defaultValue: "Language"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                HStack {
                    Text(String(localized: "settings.language.title", defaultValue: "Language"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Picker("", selection: Binding(
                        get: { AppLanguageManager.shared.currentLanguage },
                        set: { newLanguage in
                            let oldLanguage = AppLanguageManager.shared.currentLanguage
                            guard newLanguage != oldLanguage else { return }
                            
                            AppLanguageManager.shared.currentLanguage = newLanguage
                            
                            // Prompt user to restart
                            let alert = NSAlert()
                            alert.messageText = String(localized: "settings.language.alert.title", defaultValue: "Change Language")
                            alert.informativeText = String(localized: "settings.language.alert.message", defaultValue: "PhantomKnob must restart to apply the new language settings. Would you like to restart now?")
                            alert.alertStyle = .informational
                            alert.addButton(withTitle: String(localized: "settings.language.alert.restartNow", defaultValue: "Restart Now"))
                            alert.addButton(withTitle: String(localized: "settings.language.alert.later", defaultValue: "Later"))
                            
                            let response = alert.runModal()
                            if response == .alertFirstButtonReturn {
                                AppLanguageManager.shared.relaunchApp()
                            }
                        }
                    )) {
                        ForEach(AppLanguageManager.Language.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            // -- Hotkey Section Card --
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "keyboard")
                        .foregroundColor(.blue)
                        .font(.system(size: 12, weight: .semibold))
                    Text(String(localized: "settings.section.hotkey", defaultValue: "Hotkey"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "settings.hotkey.title", defaultValue: "Global Toggle Switch"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text(String(localized: "settings.hotkey.subtitle", defaultValue: "Activate / deactivate knob control mode"))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    HotkeyRecorderView()
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            // -- Accessibility Section Card --
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "accessibility")
                        .foregroundColor(hasAccessibilityPermission ? .green : .red)
                        .font(.system(size: 12, weight: .semibold))
                    Text(String(localized: "settings.section.accessibility", defaultValue: "Accessibility Permission"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                HStack {
                    Image(systemName: hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(hasAccessibilityPermission ? .green : .red)
                        .font(.system(size: 16))
                    
                    Text(hasAccessibilityPermission 
                         ? String(localized: "settings.accessibility.granted", defaultValue: "Accessibility permission granted")
                         : String(localized: "settings.accessibility.notGranted", defaultValue: "Accessibility permission not granted"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if !hasAccessibilityPermission {
                        Button(action: {
                            openAccessibilityPreferences()
                        }) {
                            Text(String(localized: "settings.accessibility.openSettings", defaultValue: "Open System Settings"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.red.opacity(0.4), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if !hasAccessibilityPermission {
                    Text(String(localized: "settings.accessibility.description", defaultValue: "Global control mode requires Accessibility permission to detect gestures and perform actions."))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.leading, 24)
                }
            }
            .padding(12)
            .background(hasAccessibilityPermission ? Color.white.opacity(0.04) : Color.red.opacity(0.03))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(hasAccessibilityPermission ? Color.white.opacity(0.06) : Color.red.opacity(0.2), lineWidth: 1)
            )

            // -- Startup & Updates Section Card --
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.horizontal")
                        .foregroundColor(.orange)
                        .font(.system(size: 12, weight: .semibold))
                    Text(String(localized: "settings.section.startup", defaultValue: "Startup & Updates"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(String(localized: "settings.startup.launchAtLogin", defaultValue: "Launch at Login"), isOn: Binding(
                        get: { launchAtLogin },
                        set: { newValue in
                            do {
                                if newValue {
                                    try LaunchAtLoginService.shared.enable()
                                } else {
                                    try LaunchAtLoginService.shared.disable()
                                }
                                launchAtLogin = newValue
                            } catch {
                                let alert = NSAlert()
                                alert.messageText = String(localized: "settings.startup.errorTitle", defaultValue: "Failed to set Launch at Login")
                                alert.informativeText = error.localizedDescription
                                alert.alertStyle = .warning
                                alert.addButton(withTitle: String(localized: "settings.alert.ok", defaultValue: "OK"))
                                alert.runModal()
                                
                                launchAtLogin = LaunchAtLoginService.shared.isEnabled
                            }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .foregroundColor(.white.opacity(0.85))
                    .font(.system(size: 13))
                    
                    Toggle(String(localized: "settings.startup.showGuide", defaultValue: "Show User Guide on Startup"), isOn: Binding(
                        get: { !skipUserGuideOnStartup },
                        set: { skipUserGuideOnStartup = !$0 }
                    ))
                    .toggleStyle(.checkbox)
                    .foregroundColor(.white.opacity(0.85))
                    .font(.system(size: 13))

                    Toggle(String(localized: "settings.startup.autoUpdate", defaultValue: "Automatically check for updates"), isOn: Binding(
                        get: { UserDefaults.app.object(forKey: "SUEnableAutomaticChecks") as? Bool ?? true },
                        set: { UserDefaults.app.set($0, forKey: "SUEnableAutomaticChecks") }
                    ))
                    .toggleStyle(.checkbox)
                    .foregroundColor(.white.opacity(0.85))
                    .font(.system(size: 13))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            // -- Privacy Section Card --
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.blue)
                        .font(.system(size: 12, weight: .semibold))
                    Text(String(localized: "settings.section.privacy", defaultValue: "Privacy"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Toggle(String(localized: "settings.crashReporting", defaultValue: "Send crash reports"), isOn: Binding(
                    get: { !UserDefaults.app.bool(forKey: "disableCrashReporting") },
                    set: { UserDefaults.app.set(!$0, forKey: "disableCrashReporting") }
                ))
                .toggleStyle(.checkbox)
                .foregroundColor(.white.opacity(0.85))
                .font(.system(size: 13))

                Toggle(String(localized: "settings.analytics", defaultValue: "Share anonymous usage statistics"), isOn: Binding(
                    get: { !UserDefaults.app.bool(forKey: "disableAnalytics") },
                    set: { newValue in
                        UserDefaults.app.set(!newValue, forKey: "disableAnalytics")
                        if newValue {
                            AnalyticsManager.shared.initialize()
                        }
                    }
                ))
                .toggleStyle(.checkbox)
                .foregroundColor(.white.opacity(0.85))
                .font(.system(size: 13))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .onAppear {
            hasAccessibilityPermission = AXIsProcessTrusted()
            launchAtLogin = LaunchAtLoginService.shared.isEnabled
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibilityPermission = AXIsProcessTrusted()
            launchAtLogin = LaunchAtLoginService.shared.isEnabled
        }
    }

    private func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

// MARK: - About Tab
struct AboutView: View {
    @State private var licenseState: LicenseState = LicenseManager.shared.currentState
    
    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        let format = String(localized: "about.version", defaultValue: "Version %@ (%@)")
        return String(format: format, v, b)
    }

    private var appIcon: NSImage {
        if case .free = licenseState {
            return NSImage(named: "AppIconFree") ?? NSImage(named: "NSApplicationIcon") ?? NSImage()
        } else {
            return NSImage(named: "NSApplicationIcon") ?? NSImage()
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 72, height: 72)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            VStack(spacing: 4) {
                Text("PhantomKnob")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text(versionString)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Text(String(localized: "about.description", defaultValue: "Use natural two-finger rotation gestures to precisely control\nsliders and dials in video or audio editors, just like a physical dial."))
                .multilineTextAlignment(.center)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .lineSpacing(4)
            
            Button(action: {
                SettingsWindowController.shared.hide()
                UserGuideWindowController.shared.show()
            }) {
                Text(String(localized: "about.openGuide", defaultValue: "Open User Guide"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(minHeight: 260)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LicenseStateDidChange"))) { _ in
            self.licenseState = LicenseManager.shared.currentState
        }
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
