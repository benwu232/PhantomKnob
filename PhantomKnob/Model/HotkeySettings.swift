import AppKit
import Combine

/// Hotkey settings storage. UserDefaults keys correspond to the listener in StatusBarController.
/// keyCode: UInt16 - NSEvent.keyCode, e.g. R = 15
/// modifiers: UInt - NSEvent.ModifierFlags.rawValue, e.g. .command | .option
class HotkeySettings: ObservableObject {
    static let shared = HotkeySettings()

    private static let keyCodeKey = "globalHotkeyKeyCode"
    private static let modifiersKey = "globalHotkeyModifiers"

    // Default value: ⌘⌥R (keyCode=15, command|option)
    static let defaultKeyCode: UInt16 = 15
    static let defaultModifiers: NSEvent.ModifierFlags = [.command, .option]

    @Published var keyCode: UInt16 {
        didSet {
            UserDefaults.standard.set(Int(keyCode), forKey: Self.keyCodeKey)
            NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        }
    }

    @Published var modifiers: NSEvent.ModifierFlags {
        didSet {
            UserDefaults.standard.set(modifiers.rawValue, forKey: Self.modifiersKey)
            NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        }
    }

    private init() {
        let savedKeyCode = UserDefaults.standard.integer(forKey: Self.keyCodeKey)
        let savedModifiers = UserDefaults.standard.integer(forKey: Self.modifiersKey)
        if savedKeyCode != 0 {
            keyCode = UInt16(savedKeyCode)
            modifiers = NSEvent.ModifierFlags(rawValue: UInt(savedModifiers))
        } else {
            keyCode = Self.defaultKeyCode
            modifiers = Self.defaultModifiers
        }
    }

    /// Format the hotkey as a readable string, e.g. "⌘⌥R"
    var displayString: String {
        var parts = ""
        if modifiers.contains(.control) { parts += "⌃" }
        if modifiers.contains(.option)  { parts += "⌥" }
        if modifiers.contains(.shift)   { parts += "⇧" }
        if modifiers.contains(.command) { parts += "⌘" }
        if let char = keyCodeToChar(keyCode) {
            parts += char.uppercased()
        } else {
            parts += "[\(keyCode)]"
        }
        return parts
    }

    /// The lowercase character to be used as a menu key equivalent.
    var keyEquivalent: String {
        return keyCodeToChar(keyCode)?.lowercased() ?? ""
    }

    private func keyCodeToChar(_ code: UInt16) -> String? {
        let map: [UInt16: String] = [
            0:"A", 1:"S", 2:"D", 3:"F", 4:"H", 5:"G", 6:"Z", 7:"X", 8:"C", 9:"V",
            11:"B", 12:"Q", 13:"W", 14:"E", 15:"R", 16:"Y", 17:"T", 31:"O", 32:"U",
            34:"I", 35:"P", 37:"L", 38:"J", 40:"K", 45:"N", 46:"M",
            18:"1", 19:"2", 20:"3", 21:"4", 22:"6", 23:"5", 25:"9", 26:"7", 28:"8", 29:"0"
        ]
        return map[code]
    }
}

extension Notification.Name {
    static let hotkeyDidChange = Notification.Name("com.phantomknob.hotkeyDidChange")
}
