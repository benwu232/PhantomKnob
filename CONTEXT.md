# PhantomKnob Context

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
**(Deprecated — being replaced by `DetectedTarget` + `InputTranslator`. See below.)**
A protocol that previously mixed identity metadata with execution logic. `DemoSliderTarget` and `GenericControlTarget` remain until migration is complete.

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

**Detection trigger:** Only when gesture starts (`touchesBegan`). No continuous hover detection (Plan B).

**Detection flow:**
1. Get cursor position via `NSEvent.mouseLocation`
2. Get UI element at position via `AXUIElementCopyElementAtPosition`
3. Check if element is adjustable (AXRole + AXValue + AXMinValue + AXMaxValue)
4. If not adjustable, search up through parent elements (max 10 levels)
5. Return `DetectedTarget` or nil

**Supported element types:**
- `AXSlider`: Volume, brightness, system sliders
- `AXProgressIndicator`: Video progress bars, loading indicators
- `AXScrollBar`: Scroll position controls

**Target locking:** Once detected, target is locked for the entire gesture duration. User must release fingers and start new gesture to change target.

### DetectedTarget
Pure metadata struct describing the UI element under cursor. No execution logic.

**Fields:**
- `bundleID`: Bundle identifier of the frontmost app
- `axRole`: AX role string (e.g., `"AXSlider"`)
- `identifier`: `AXIdentifier` value, nil if not set by the app
- `displayName`: From `AXTitle` or `AXDescription`, used in overlay
- `element`: `AXUIElement` reference, nil when no AX element is found
- `ruleKey`: Computed from `bundleID + axRole + identifier`; used for identity comparison and rule lookup

**Identity comparison:** Two targets are considered the same if their `ruleKey` matches (replaces previous `displayName` comparison).

### RuleKey
Unique identifier for a `ControlRule`. Used as lookup key in the RuleLibrary and for target identity comparison in the state machine.

**Structure:** `bundleID · axRole · identifier?`

**Matching precedence (most to least specific):**
1. `bundleID + axRole + identifier` — exact match
2. `bundleID + axRole` — all controls of that type in the app
3. `axRole` only — cross-app type default
4. Auto-detect fallback — no rule found

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

## Input Translation System

### InputTranslation
The strategy for converting a rotation delta into a re-injected system event. Describes *how* the knob's intent is delivered — not *what* is being controlled.
_Avoid: mapping, method, action_

**Supported kinds:**
- `axWrite`: Read current AXValue, add delta, write back via Accessibility API
- `scrollWheelVertical`: Synthesize a vertical scroll wheel CGEvent
- `scrollWheelHorizontal`: Synthesize a horizontal scroll wheel CGEvent
- `arrowKeyUpDown`: Synthesize up/down arrow key events
- `arrowKeyLeftRight`: Synthesize left/right arrow key events
- `swipeVertical`: Synthesize a vertical two-finger swipe gesture
- `swipeHorizontal`: Synthesize a horizontal two-finger swipe gesture

**Auto-detection hierarchy (when no rule exists):**
1. `AXUIElementIsAttributeSettable(kAXValueAttribute) == true` → `axWrite`
2. AX actions include `AXIncrement`/`AXDecrement` → `arrowKeyUpDown`
3. No AX attributes / custom Canvas → `scrollWheelVertical` (default fallback)

### InputTranslator
Runtime object that executes an `InputTranslation` for a given delta. Owns an internal accumulator for discrete event types (e.g., arrow keys require integer presses; fractional deltas are accumulated across frames).

**Interface:**
```
apply(units: Double, direction: RotationDirection)
displayValue: String?   // nil for non-axWrite translations
```

**Accumulator rule:** Continuous events (scrollWheel, swipe) accept fractional units directly via CGEvent double-value fields. Discrete events (arrowKey) accumulate until ≥ 1.0, fire integer presses, carry remainder.

### ScaleConfig
Configuration describing how rotation angle maps to InputTranslation units. It can be defined globally in `settings.jsonc` or overridden per-knob in `rules.jsonc`.

**Default:** `fixed(1.0)` — 1° rotation = 1 minimum unit (universal, no heuristics)

**Schemes:**
1. **fixed**: Resolves to a fixed multiplier.
   * If a single zone is configured: resolved to that fixed scale value.
   * If 2 or more zones are configured: dynamically resolves to a zone's scale using a hysteresis state machine based on `minRadius`, `maxRadius`, and `margin`.
2. **linear**: Linearly interpolates the scale between `minRadius` (maps to `minScale`) and `maxRadius` (maps to `maxScale`).

**Keyboard Override (Numeric keys 2-9):**
* Pressing a numeric key `2-9` during rotation locks the base scale resolved at that moment and multiplies it by the key value. Releasing the key restores dynamic resolution.

### ControlRule
A stored entry in the RuleLibrary describing how to control a specific element.

**Fields:**
- `key`: `RuleKey` (identity + lookup key)
- `translation`: `InputTranslation` kind
- `scaleConfig`: `ScaleConfig` (default: `.fixed(1.0)`)
- `extra`: `[String: String]?` (reserved for future extension without breaking Codable)

### RuleLibrary
Lookup table mapping `RuleKey` → `ControlRule`. Consulted at gesture start before auto-detection.

**Matching strategy:** First match wins (ordered by specificity). No cascading/inheritance.

**Storage — two layers:**
1. **Bundled rules** (read-only, in App Bundle): Ships with built-in rules for known apps (Final Cut Pro, DaVinci Resolve, CapCut, etc.). Updated via app releases.
2. **User rules** (`~/Library/Application Support/PhantomKnob/rules.json`): User-defined overrides, higher priority. File created only when user explicitly saves a rule.

---

## Scale

**Default scale:** 1° rotation = 1 minimum adjustment unit (same across all `InputTranslation` types).

The "minimum unit" is translation-specific:
- `scrollWheel`: 1 pixel (CGEvent delta)
- `arrowKey`: 1 key press
- `axWrite`: 1 AX value unit
- `swipe`: 1 pixel (gesture delta)

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

### Value Display
- `axWrite` translation: shows current value read from AXValue (percentage, time, or raw)
- All other translations: value area is hidden (user observes effect directly on screen)

### Radius Deadzone State
- When `radius < minRadius` (fingers too close), the overlay circle and angle indicator turn gray (disabled style) to indicate that the gesture is in the inactive deadzone, and value adjustments are suspended. Returning above `minRadius` restores the active visual style.

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
