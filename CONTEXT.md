# PhantomKnobDetector Context

## Glossary

### Knob
A two-finger rotation gesture on a trackpad that simulates a physical knob/dial. The system detects the absolute position of two fingers via `normalizedPosition`, calculates the angle between them, and derives rotation delta.

**Gesture disambiguation (Global Control Mode):**
- **Default mode**: Pan (two-finger scroll/translate) — gesture passes through to system
- **Knob mode**: Activated when angle change exceeds 5° within 2-second detection window
- **Mode locking**: Once determined (knob or pan), mode is locked until fingers leave trackpad

### Knob Detection
The process of verifying whether a trackpad supports the absolute coordinates (`normalizedPosition`) required for Knob gesture recognition.

**Detection Lifecycle:**
- **Timeout**: 30 seconds with visual countdown → "检测超时，请重试"
- **Confirmation**: Requires 3 consecutive valid touch events (within 500ms each) to confirm support
- **Cancellation**: "取消" button on detection page returns to welcome
- **Finger lift**: If fingers lift before 3 samples collected, stay in detection mode (don't fail)

### Detection Cache
Detection results are cached permanently in UserDefaults. Cache does NOT track hardware changes.

**Cache behavior:**
- **Validity**: Permanent (no expiration)
- **Hardware changes**: Not detected — user must manually trigger "重新检测" in Settings
- **Storage key**: `com.phantomknob.detectionResult`

### DetectionResult
The outcome of a knob detection attempt, containing diagnostic information.

**Fields:**
- `isSupported`: Whether the trackpad supports knob gestures
- `timestamp`: When the detection was performed
- `deviceModel`: Hardware identifier (e.g., "MacBookPro18,3")
- `macOSVersion`: Operating system version
- `details`: Failure diagnostics (if unsupported)
  - `normalizedPositionAvailable`: Whether the core capability was detected
  - `sampleCount`: Number of touch events analyzed
  - `errorMessage`: Human-readable failure reason (localized to system language)

### normalizedPosition
An `NSTouch` property providing normalized touch coordinates (0.0-1.0). The core capability being detected. Validity criteria: non-NaN, x/y in 0.0-1.0 range, both fingers have valid values.

### calKnob()
Core algorithm ported from Flutter version. Finds the two most-distant touch points, computes their midpoint as the knob center, and their connecting-line direction as the angle.

**Angle convention:**
- Uses macOS native coordinate system (Y-axis points up)
- 0° points right (+X direction)
- Counter-clockwise rotation is positive
- Formula: `angle = atan2(dy, dx) * 180 / π`

### ControlTarget
A protocol abstracting any object that can be controlled by a Knob gesture (e.g., a demo slider, system volume, system brightness).

### DemoSliderTarget
The MVP implementation of ControlTarget for the demo page.

**Behavior:**
- **Range**: 0-100
- **Initial value**: 50 (center)
- **Direction**: Clockwise rotation → increase value; Counter-clockwise → decrease value
- **Sensitivity**: 1° rotation → 0.5 value change (full 360° ≈ 180 value change)
- **Persistence**: Value persists when fingers lift (mimics physical knob)
- **Delta clamping**: ±1° per update (prevents jitter-induced jumps)

### Knob Visualization
Visual representation of the knob in the demo page.

**MVP design (simplified):**
- White circular background with gray border
- Single indicator line from center showing angle
- Indicator rotates with finger movement
- No finger position display
- No 3D effects or shadows
- Value displayed below knob in large system font

### Global Control Mode
A feature that allows users to control any adjustable UI element (sliders, progress bars, scroll bars) via Knob gesture across all applications.

**Activation:** Hotkey (`⌘⇧K` by default, customizable in settings)

**Architecture:**
- **KnobStateManager**: Central state machine managing the entire control lifecycle
- **TargetDetector**: Uses Accessibility API to find controllable elements under cursor
- **AccessibilityTarget**: ControlTarget implementation for system UI elements
- **OverlayController**: Manages the visual feedback overlay

---

## Global Control State Machine

### KnobStateManager
Central state machine managing global control mode. Single source of truth for all state transitions.

### States

| State | Color | Target | Description |
|-------|-------|--------|-------------|
| `inactive` | Gray | None | Feature disabled |
| `activated` | Blue | None | Feature enabled, waiting for gesture |
| `knobing` | Orange | Locked | Actively controlling target value |
| `cooling` | Orange | Locked | Gesture ended, 1-second grace period for continuation |

### State Transitions

```
inactive ──[hotkey]──→ activated ──[gesture + target + angle>5°]──→ knobing
    ↑                      ↑                                          │
    │                      │              ┌───────────────────────────┘
    │                      │              │
    │                   [1s timeout]   [fingers lift]
    │                      ↑              │
    │                      │              ▼
    │                   cooling ←─────────┘
    │                      │
    │         [1s timeout] │ [gesture + same target]
    │                      │        │
    └──────────────────────┘        └──→ knobing (resume)
```

**Transition rules:**
- `inactive` → `activated`: Hotkey pressed
- `activated` → `inactive`: Hotkey pressed
- `activated` → `knobing`: Gesture started + target detected + angle change > 5° within 2s
- `knobing` → `cooling`: Fingers left trackpad
- `cooling` → `knobing`: New gesture within 1s + same target
- `cooling` → `activated`: 1s timeout OR target changed
- `knobing`/`cooling` → `inactive`: Hotkey pressed
- Any state → `activated`: Application switched (clears target)

---

## Target Detection

### TargetDetector
Detects controllable UI elements under the cursor using macOS Accessibility API.

**Detection trigger:** Only when gesture starts (`touchesBegan`)

**Detection flow:**
1. Get cursor position via `NSEvent.mouseLocation`
2. Get UI element at position via `AXUIElementCopyElementAtPosition`
3. Check if element is adjustable (AXRole + AXValue + AXMinValue + AXMaxValue)
4. If not adjustable, search up through parent elements (max 10 levels)
5. Return `AccessibilityTarget` or nil

**Supported element types:**
- `AXSlider`: Volume, brightness, system sliders
- `AXProgressIndicator`: Video progress bars, loading indicators
- `AXScrollBar`: Scroll position controls

**Target locking:** Once detected, target is locked for the entire gesture duration. User must release fingers and start new gesture to change target.

### AccessibilityTarget
ControlTarget implementation for Accessibility API elements.

**Properties:**
- `element`: AXUIElement reference
- `value`: Current value from AXValue
- `minValue`, `maxValue`: Range from AXMinValue/AXMaxValue
- `displayName`: From AXTitle or AXDescription (may be empty)

**Error handling:** If `AXUIElementSetAttributeValue` fails, post `accessibilityPermissionRevoked` notification.

---

## Gesture Classification

### Detection Window
A 2-second window starting from `touchesBegan` to determine gesture type.

**Default mode:** Pan (gesture passes through to system)

**Knob activation:**
- Track initial angle on `touchesBegan`
- On each `touchesMoved`, calculate angle delta
- If `|angle delta| > 5°` within 2s → lock to knob mode
- Reset initial angle when entering knob mode (subsequent deltas calculated from this point)

**After detection window:**
- If no angle threshold exceeded → stay in pan mode (locked)
- Gesture continues to pass through to system

**Threshold rationale:** 5° is sensitive enough for intentional rotation while avoiding false triggers from hand tremor during normal scrolling.

---

## Sensitivity

### Base Sensitivity
Default: 1° rotation → 0.5 value change (full 360° ≈ 180 value change)

### Per-Type Override
Sensitivity can be customized per element type:
- `sliderSensitivity`: For AXSlider elements
- `progressSensitivity`: For AXProgressIndicator elements
- `scrollbarSensitivity`: For AXScrollBar elements

If type-specific sensitivity not set, falls back to global default.

### Radius-Based Sensensitivity (Future)
Knob radius (distance between two fingers) affects sensitivity:
- Small radius (< 0.3 normalized): High sensitivity (1° → 1.0 value)
- Medium radius (0.3-0.7): Default sensitivity (1° → 0.5 value)
- Large radius (> 0.7): Low sensitivity (1° → 0.25 value)

Rationale: Small radius = fingers close = small physical movement = need higher sensitivity; large radius = fingers spread = large movement = finer control.

### Storage
All sensitivity settings stored in UserDefaults with auto-save on change.

---

## Overlay UI

### Display Position
Fixed at gesture start position (mouse cursor location with offset to avoid occlusion).

### Content (Adaptive)
```
┌─────────────┐
│   [Name]    │  ← Target name (if AXTitle exists and < 10 chars)
│     ╱       │  ← Angle indicator
│   ◉         │  ← Center point
│    65%      │  ← Current value (percentage/time/raw)
└─────────────┘
```

**Value format:**
- Range 0-100: Percentage (65%)
- Range 0-3600+ (video): Time format (01:23:45)
- Other: Raw value

### Visibility
- Fade in when entering `knobing` state
- Fade out over 1 second when entering `cooling` state
- Fade in again if returning to `knobing` within 1 second

---

## Hotkey

### Default
`⌘⇧K` (Command + Shift + K)

### Conflict Detection
On registration, check if hotkey is already in use by another app. If conflict detected, prompt user to choose different hotkey.

### Customization
Users can change hotkey in Settings.

---

## Permissions

### Accessibility Permission
Required for Global Control Mode to work.

**Check points:**
1. App launch
2. Before entering `activated` state
3. On every `AXUIElementSetAttributeValue` call (catch failures)

**Permission revoked during use:**
- Catch API failure
- Post notification
- Return to `inactive` state
- Show permission guidance UI

---

## Bounded Contexts

This is a single-context application (macOS native app).

## Navigation

### AppViewModel
Central state manager handling screen navigation and detection lifecycle.

**Responsibilities:**
- Manages `currentScreen` state (welcome → detection → result/demo)
- Holds `detectionResult` for cross-screen access
- Provides navigation methods: `startDetection()`, `completeDetection()`, `reset()`

**Screen flow:**
- Detection success → auto-navigate to demo (no user confirmation)
- Detection failure → show result page with details

**MVP scope:**
- No standalone Settings page
- Demo page has "重新检测" button to restart detection
- Future: Menu bar icon with settings/detector access
