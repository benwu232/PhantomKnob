# Change Default Global Hotkey to Command + Option + K

This specification details the changes to update the default global activation shortcut for PhantomKnob from `⌘⌥R` to `⌘⌥K` to reduce conflicts and provide an intuitive default key ('K' for Knob).

## Background & Goal

The current default global toggle shortcut is `⌘⌥R`. This shortcut can sometimes conflict with other developer tools or application behaviors. 
We will change the default global hotkey to `⌘⌥K` (Command + Option + K). This:
1. Minimizes keyboard shortcut conflicts.
2. Keeps the `Option` + `Command` modifier pairing to avoid conflicting with system-wide special character typing.
3. Provides an intuitive letter 'K' for Knob.

---

## Proposed Changes

### 1. Default Hotkey Definition

#### [MODIFY] [HotkeySettings.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Model/HotkeySettings.swift)

Update the static default keyCode to 40 (representing 'K'):

```swift
    // Default value: ⌘⌥K (keyCode=40, command|option)
    static let defaultKeyCode: UInt16 = 40
```

### 2. User Guide UI & Documentation Update

#### [MODIFY] [UserGuideView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/UserGuideView.swift)

Update the default fallback text for the global shortcut step description from `⌘ ⌥ R (Command + Option + R)` to `⌘ ⌥ K (Command + Option + K)`:

```swift
Text(String(localized: "guide.step3.feature1.title", defaultValue: "Global Toggle Shortcut: ⌘ ⌥ K (Command + Option + K)"))
```

#### [MODIFY] [Localizable.xcstrings](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Localizable.xcstrings)

Update the localized string for `"guide.step3.feature1.title"` to reflect `⌘ ⌥ K` instead of `⌘ ⌥ R`:

* `"zh-Hans"`: `"全局激活热键：⌘ ⌥ K (Command + Option + K)。可在设置中修改。"`

#### [MODIFY] [CONTEXT.md](file:///Users/wb/work/phantom_knob_mac/CONTEXT.md)

Replace all references to `⌘⌥R` and `Command + Option + R` with `⌘⌥K` and `Command + Option + K`.

---

## Verification Plan

### Automated Verification
Run unit tests to ensure that there are no regressions or syntax/type check errors:
- Command: `xcodebuild -project PhantomKnob.xcodeproj -scheme PhantomKnobTests -configuration Debug test`

### Manual Verification
1. **Reset Settings**:
   - Clear defaults or reset the app container so that default values are reloaded.
   - Or print `HotkeySettings.shared.displayString` on app startup to verify it displays `⌘⌥K`.
2. **Onboarding / User Guide Inspection**:
   - Launch the app, open the User Guide.
   - Verify step 3 displays the updated toggle shortcut: `Global Toggle Shortcut: ⌘ ⌥ K (Command + Option + K)`.
3. **Hotkey Customization & Interaction**:
   - Press `⌘⌥K` globally to confirm it toggles the activation mode (the menu bar icon should change state).
   - Go to settings, modify the hotkey, verify custom hotkey takes effect, then reset or check that custom recording works as expected.
