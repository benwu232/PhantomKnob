import SwiftUI
import AppKit

/// Inline hotkey recorder control. Used in the LabeledContent value area of the settings panel.
struct HotkeyRecorderView: View {
    @ObservedObject private var settings = HotkeySettings.shared
    @State private var isRecording = false
    @State private var conflictMessage: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if isRecording {
                Text("请按下快捷键…")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 120, alignment: .leading)
                Button(String(localized: "hotkey.button.cancel", defaultValue: "取消")) { stopRecording() }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
            } else {
                Text(settings.displayString)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                Button(String(localized: "hotkey.button.change", defaultValue: "修改…")) { startRecording() }
                    .buttonStyle(.borderless)
                    .foregroundColor(.accentColor)
            }
            if let msg = conflictMessage {
                Text(msg).font(.caption).foregroundColor(.orange)
            }
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        conflictMessage = nil
        // Store monitor in a static var because struct cannot hold reference-type properties and mutate them inside a closure.
        HotkeyRecorderView.installMonitor { [self] event in
            handleKeyDown(event)
        }
    }

    private func stopRecording() {
        isRecording = false
        HotkeyRecorderView.removeMonitor()
    }

    private func handleKeyDown(_ event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !mods.isEmpty, event.keyCode != 0 else { return }
        // System reserved keys blacklist (Cmd+Q / Cmd+W / Cmd+H)
        let reserved: [(UInt16, NSEvent.ModifierFlags)] = [
            (12, [.command]), (13, [.command]), (4, [.command])
        ]
        if reserved.contains(where: { event.keyCode == $0.0 && mods == $0.1 }) {
            conflictMessage = String(localized: "hotkey.reservedBySystem", defaultValue: "该快捷键被系统保留")
            return
        }
        HotkeySettings.shared.keyCode = event.keyCode
        HotkeySettings.shared.modifiers = mods
        conflictMessage = nil
        stopRecording()
    }

    // MARK: - Static monitor management

    private static var activeMonitor: Any?

    private static func installMonitor(handler: @escaping (NSEvent) -> Void) {
        removeMonitor()
        activeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handler(event)
            return nil
        }
    }

    private static func removeMonitor() {
        if let m = activeMonitor { NSEvent.removeMonitor(m); activeMonitor = nil }
    }
}
