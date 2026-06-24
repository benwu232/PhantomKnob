import SwiftUI
import AppKit

enum SettingsTab {
    case general
    case about
}

// MARK: - Root View

struct SettingsView: View {
    @State private var activeTab: SettingsTab = .general
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with tabs and Close button
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        activeTab = .general
                    }
                }) {
                    Text("通用")
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
                    Text("关于")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(activeTab == .about ? .white : .white.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(activeTab == .about ? Color.white.opacity(0.12) : Color.clear)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Close button (X)
                Button(action: {
                    SettingsWindowController.shared.hide()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(6)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Tab content
            ScrollView {
                VStack(spacing: 16) {
                    if activeTab == .general {
                        GeneralSettingsView()
                    } else {
                        AboutView()
                    }
                }
                .padding(20)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 480, height: 360)
        .foregroundColor(.white)
    }
}

// MARK: - General Tab

struct GeneralSettingsView: View {
    @State private var hasAccessibilityPermission = AXIsProcessTrusted()
    @AppStorage("skipUserGuideOnStartup") private var skipUserGuideOnStartup = false
    @State private var launchAtLogin = false

    var body: some View {
        VStack(spacing: 14) {
            // -- Hotkey Section --
            VStack(alignment: .leading, spacing: 10) {
                Text("热键")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("全局控制开关")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("激活 / 关闭旋钮控制模式")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    HotkeyRecorderView()
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            // -- Accessibility Section --
            VStack(alignment: .leading, spacing: 10) {
                Text("辅助功能权限")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                
                HStack {
                    Image(systemName: hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(hasAccessibilityPermission ? .green : .red)
                        .font(.system(size: 16))
                    
                    Text(hasAccessibilityPermission ? "已授权辅助功能权限" : "未授权辅助功能权限")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if !hasAccessibilityPermission {
                        Button(action: {
                            openAccessibilityPreferences()
                        }) {
                            Text("打开系统设置")
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
                    Text("全局控制模式必须有辅助功能权限才能正常监测手势并执行动作。")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.leading, 24)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            // -- Startup Section --
            VStack(alignment: .leading, spacing: 10) {
                Text("启动")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                
                Toggle("登录时自动启动", isOn: Binding(
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
                            alert.messageText = "设置开机启动失败"
                            alert.informativeText = error.localizedDescription
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "确定")
                            alert.runModal()
                            
                            launchAtLogin = LaunchAtLoginService.shared.isEnabled
                        }
                    }
                ))
                .toggleStyle(.checkbox)
                .foregroundColor(.white.opacity(0.85))
                .font(.system(size: 13))
                
                Toggle("启动时显示使用引导", isOn: Binding(
                    get: { !skipUserGuideOnStartup },
                    set: { skipUserGuideOnStartup = !$0 }
                ))
                .toggleStyle(.checkbox)
                .foregroundColor(.white.opacity(0.85))
                .font(.system(size: 13))
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )

            // -- Trackpad Section --
            VStack(alignment: .leading, spacing: 10) {
                Text("触控板")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("重新检测触控板")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("如果您更换了触控板设备，可以重新发起测试")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    
                    Button(action: {
                        resetAndRedetect()
                    }) {
                        Text("重新检测…")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .onAppear {
            hasAccessibilityPermission = AXIsProcessTrusted()
            launchAtLogin = LaunchAtLoginService.shared.isEnabled
        }
    }

    private func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func resetAndRedetect() {
        UserDefaults.standard.removeObject(forKey: "com.phantomknob.detectionResult")
        SettingsWindowController.shared.hide()
        UserGuideWindowController.shared.show()
    }
}

// MARK: - About Tab

struct AboutView: View {
    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "版本 \(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
            VStack(spacing: 4) {
                Text("Phantom Knob")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text(versionString)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Text("使用两指旋转手势，像拨动物理旋钮一样\n精确控制任意剪辑或音频应用中的滑块和进度条")
                .multilineTextAlignment(.center)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .lineSpacing(4)
            
            Button(action: {
                SettingsWindowController.shared.hide()
                UserGuideWindowController.shared.show()
            }) {
                Text("打开使用引导")
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
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
