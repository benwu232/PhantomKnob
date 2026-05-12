# PhantomKnobDetector Context

## Glossary

### Knob
A two-finger rotation gesture on a trackpad that simulates a physical knob/dial. The system detects the absolute position of two fingers via `normalizedPosition`, calculates the angle between them, and derives rotation delta.

**Gesture disambiguation:**
- **MVP**: All two-finger gestures are treated as knob gestures (no conflict resolution needed)
- **Future**: Hotkey toggle or motion pattern analysis (angle/position change rate) — not implemented in MVP

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
