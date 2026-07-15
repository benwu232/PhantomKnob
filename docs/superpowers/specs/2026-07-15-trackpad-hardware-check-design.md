# App Startup Trackpad Hardware Self-Check Design

This specification details the design for adding an automatic hardware self-check at application startup to verify the presence of a trackpad (either internal or external), and reverting the user guide to the original 3 steps.

## Background & Goal

PhantomKnob is a gesture-oriented macOS menu bar app that relies entirely on multitouch trackpads to control dials. Running the app on a Mac without a trackpad leaves the app non-functional.
Previously, the user added a trackpad hardware requirement step as the first step of the onboarding User Guide. However, placing this check inside the User Guide doesn't prevent non-functional startup and clutters the instructions. 
Instead, we will:
1. Run a trackpad hardware self-check at application startup.
2. If no trackpad is detected, show a critical alert and terminate the app.
3. Revert the User Guide to the original three step-by-step instructions.

---

## Proposed Changes

### 1. Hardware Detection Module

#### [NEW] [HardwareDetector.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/HardwareDetector.swift)

Create a lightweight helper to query connected HID devices. It uses public IOKit APIs to search for trackpads (both internal MacBook trackpads and external Magic Trackpads).

```swift
import Foundation
import IOKit
import IOKit.hid

struct HardwareDetector {
    /// Checks if at least one multitouch trackpad is currently connected.
    static func isTrackpadConnected() -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        
        // Match standard HID touchpad page/usage configurations:
        // 1. Page: Digitizer (0x0D), Usage: Touch Pad (0x05)
        // 2. Page: Generic Desktop (0x01), Usage: Touch Pad (0x05)
        let matchingDicts: [[String: Any]] = [
            [
                kIOHIDDeviceUsagePageKey: 0x0D,
                kIOHIDDeviceUsageKey: 0x05
            ],
            [
                kIOHIDDeviceUsagePageKey: 0x01,
                kIOHIDDeviceUsageKey: 0x05
            ]
        ]
        
        IOHIDManagerSetDeviceMatchingMultiple(manager, matchingDicts as CFArray)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        
        guard let devices = IOHIDManagerCopyDevices(manager) else {
            return false
        }
        
        let nsSet = devices as NSSet
        return nsSet.count > 0
    }
}
```

### 2. Startup Validation Logic

#### [MODIFY] [PhantomKnobApp.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/App/PhantomKnobApp.swift)

In `AppState.init()`, perform the check at the very beginning of the initialization pipeline. If no trackpad is detected:
* Pop up a critical `NSAlert` with the localized warning message.
* Terminate the application immediately after the alert is dismissed.

```swift
// In AppState.init()
init() {
    #if !TESTING
    if !HardwareDetector.isTrackpadConnected() {
        let alert = NSAlert()
        alert.messageText = String(localized: "startup.noTrackpad.title", defaultValue: "No Trackpad Detected")
        alert.informativeText = String(localized: "startup.noTrackpad.message", defaultValue: "PhantomKnob requires a trackpad (MacBook trackpad or Magic Trackpad) to perform knob gestures. The application will now exit.")
        alert.alertStyle = .critical
        alert.addButton(withTitle: String(localized: "startup.noTrackpad.quit", defaultValue: "Quit"))
        alert.runModal()
        NSApp.terminate(nil)
        return
    }
    #endif
    
    // Existing setup...
}
```
> [!NOTE]
> We wrap the hardware check in `#if !TESTING` to prevent unit tests from blocking or failing in CI/CD environments where no physical trackpads are present.

### 3. Localizations & User Guide Step Restoration

#### [MODIFY] [Localizable.xcstrings](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Localizable.xcstrings)

Revert the first page's step strings and introduce localized text for the startup warning:

##### String Adjustments:
1. `guide.step1.step1` -> `"PhantomKnob 需要辅助功能权限。如有要求，请授权"`
2. `guide.step1.step2` -> `"移动鼠标到音量练习旋钮上"`
3. `guide.step1.step3` -> `"用两指接触触控板，并做旋转动作"`
4. `guide.step1.step4` -> [DELETE]
5. Add `startup.noTrackpad.title`:
   * `"zh-Hans"`: `"未检测到触控板"`
   * `Default (English)`: `"No Trackpad Detected"`
6. Add `startup.noTrackpad.message`:
   * `"zh-Hans"`: `"PhantomKnob 必须在有触控板的Mac系统（如MacBook内置触控板或外接妙控板）上运行。程序即将退出。"`
   * `Default (English)`: `"PhantomKnob requires a trackpad (MacBook trackpad or Magic Trackpad) to perform knob gestures. The application will now exit."`
7. Add `startup.noTrackpad.quit`:
   * `"zh-Hans"`: `"退出"`
   * `Default (English)`: `"Quit"`

---

## Verification Plan

### Automated Verification
We will run a compile build to ensure no syntax/type check errors:
- Command: `xcodebuild -project PhantomKnob.xcodeproj -scheme PhantomKnob -configuration Debug build`

### Manual Verification
1. **With Magic Trackpad Turned Off (or no trackpad connected)**:
   * Power down the Magic Trackpad (or disconnect it).
   * Launch the app.
   * Verify that a critical dialog pops up with the message "No Trackpad Detected".
   * Clicking "Quit" should close the app.
2. **With Magic Trackpad Turned On (or built-in trackpad available)**:
   * Power on the Magic Trackpad.
   * Launch the app.
   * Verify that the app launches successfully (showing the menu bar icon or user guide window).
3. **User Guide check**:
   * Open the User Guide window.
   * Verify that Page 1 lists exactly 3 correct bullet points.
