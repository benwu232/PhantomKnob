# Design Spec: Restore Knob Active State on Startup

**Date**: 2026-08-04  
**Status**: Approved  
**Topic**: Persisting PhantomKnob active state and restoring it automatically on application startup.

---

## 1. Overview & Goal

Currently, PhantomKnob always initializes in the `.inactive` state upon application launch. Users who routinely keep PhantomKnob activated must manually press the hotkey or menu bar item to toggle activation after every app launch or system restart.

The goal of this feature is to allow users to opt-in (or use by default) automatic restoration of PhantomKnob's `.activated` state when the app starts, providing a seamless background utility experience while safeguarding against unintentional gesture interception.

---

## 2. Requirements & Behavior

1. **Persistent Preference**:
   - Provide a user setting in `Settings -> General`: **"Restore activation state on startup"** (`restoreActiveStateOnStartup`).
   - Default value: `true`.
2. **State Memory**:
   - Save the active state (`lastKnobActiveState: Bool`) to `UserDefaults.app` whenever the global state transitions explicitly into `.activated` or `.inactive`.
   - Temporary states (such as Option key hold activation) MUST NOT overwrite `lastKnobActiveState`.
3. **Startup Restoration**:
   - During `KnobStateManager.start()`, after default status bar UI initialization:
     - Check if `restoreActiveStateOnStartup` is `true`.
     - Check if `lastKnobActiveState` was `true`.
     - Check accessibility trusted status (`isProcessTrusted()`).
     - If all conditions are met, automatically transition to `.activated` (and start multitouch capture and session limits if applicable).
4. **Safety & Fallbacks**:
   - If macOS Accessibility permission (`AXIsProcessTrusted`) is NOT granted upon startup, automatic restoration will abort and fallback safely to `.inactive`.
   - If feature gate / session limits apply, starting in active mode respects session timer tracking.
5. **Localization**:
   - Provide localized key-value pairs in `Localizable.xcstrings` for English and Simplified Chinese (and traditional Chinese / Japanese if present).

---

## 3. Detailed Component Changes

### 3.1 `UserDefaults+App.swift` / `AppSettings`
- Add convenience keys / properties:
  - `restoreActiveStateOnStartup` (default: `true`)
  - `lastKnobActiveState` (default: `false`)

### 3.2 `KnobStateManager.swift`
- In `transition(to newState: KnobGlobalState)`:
  - When `newState == .activated` (and not temporary Option hold), set `UserDefaults.app.set(true, forKey: "lastKnobActiveState")`.
  - When `newState == .inactive` (and not temporary Option hold), set `UserDefaults.app.set(false, forKey: "lastKnobActiveState")`.
- In `start()`:
  - Perform condition check:
    ```swift
    let shouldRestore = UserDefaults.app.object(forKey: "restoreActiveStateOnStartup") as? Bool ?? true
    let wasActive = UserDefaults.app.bool(forKey: "lastKnobActiveState")
    if shouldRestore && wasActive && isProcessTrusted() {
        toggleMode() // or completeActivation()
    }
    ```

### 3.3 `SettingsView.swift` (`GeneralSettingsView`)
- Add a new settings toggle under General settings tab:
  - Title: `"settings.general.restoreActiveState"` ("Restore activation state on startup" / "启动时恢复激活状态")
  - Bound to `@AppStorage("restoreActiveStateOnStartup", store: .app) var restoreActiveStateOnStartup = true`

### 3.4 `Localizable.xcstrings`
- Add localization strings for:
  - `settings.general.restoreActiveState`

---

## 4. Verification Plan

### Automated Unit Tests
- Add tests in `KnobStateManagerTests` (or new test file):
  1. Test state persistence: Verify `lastKnobActiveState` updates on state transitions to `.activated` and `.inactive`.
  2. Test startup logic: Mock `UserDefaults` and `isProcessTrusted()` to verify auto-activation occurs when conditions are met and stays `.inactive` when flag/permission is false.

### Manual Verification
- Launch application, toggle to Active, quit application.
- Launch application again, verify PhantomKnob starts up in Active mode.
- Toggle setting off in Settings, repeat, verify PhantomKnob starts up in Inactive mode.
