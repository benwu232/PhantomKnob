import SwiftUI
import AppKit

// MARK: - Root View

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("通用", systemImage: "gear") }
            AboutView()
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 320)
    }
}

// MARK: - General Tab

struct GeneralSettingsView: View {
    @State private var hasAccessibilityPermission = AXIsProcessTrusted()
    @AppStorage("skipUserGuideOnStartup") private var skipUserGuideOnStartup = false

    var body: some View {
        Form {
            // -- Hotkey --
            Section(header: Text("热键")) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("全局控制开关")
                        Text("激活 / 关闭旋钮控制模式")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    HotkeyRecorderView()
                }
            }

            // -- Accessibility Permission --
            Section(
                header: Text("辅助功能权限"),
                footer: Group {
                    if !hasAccessibilityPermission {
                        Text("全局控制模式必须有辅助功能权限才能工作。")
                            .foregroundColor(.secondary)
                    }
                }
            ) {
                HStack {
                    Image(systemName: hasAccessibilityPermission
                          ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(hasAccessibilityPermission ? .green : .red)
                    Text(hasAccessibilityPermission ? "已授权" : "未授权")
                    Spacer()
                    if !hasAccessibilityPermission {
                        Button("打开系统设置") { openAccessibilityPreferences() }
                    }
                }
            }

            // -- Startup --
            Section(header: Text("启动")) {
                Toggle("启动时显示使用引导", isOn: Binding(
                    get: { !skipUserGuideOnStartup },
                    set: { skipUserGuideOnStartup = !$0 }
                ))
            }

            // -- Trackpad --
            Section(header: Text("触控板")) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("重新检测触控板")
                        Text("更换硬件后使用")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("重新检测…") { resetAndRedetect() }
                }
            }
        }
        .padding()
        .onAppear { hasAccessibilityPermission = AXIsProcessTrusted() }
    }

    private func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func resetAndRedetect() {
        UserDefaults.standard.removeObject(forKey: "com.phantomknob.detectionResult")
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
                    .resizable().frame(width: 72, height: 72)
                    .cornerRadius(16)
            }
            VStack(spacing: 4) {
                Text("Phantom Knob").font(.title2).fontWeight(.bold)
                Text(versionString).foregroundColor(.secondary).font(.subheadline)
            }
            Text("使用两指旋转手势，像拨动旋钮一样\n精确控制任意应用中的滑块和进度条")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary).font(.callout)
            Button("使用引导") { UserGuideWindowController.shared.show() }
                .buttonStyle(.link)
            Spacer()
        }
        .frame(maxWidth: .infinity).padding()
    }
}

#Preview { SettingsView() }
