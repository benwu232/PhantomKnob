# Design Spec: Fixed Center of Overlay UI (圆心固定，半径可变)

## Goal Description
During knob gesture rotation, the overlay UI's diameter changes dynamically based on the gesture radius. Previously, the overlay's origin was calculated relative to the cursor using offsets that scaled with `diameter`. This caused the visual center of the knob to shift dynamically, introducing visual jitter and drift.

The goal is to fix the visual center of the knob UI on the screen at the start of the gesture, allowing only its radius to change symmetrically around this fixed center point.

## Proposed Changes

### 1. OverlayController.swift
- Introduce a private property `fixedCenter: CGPoint` to store the locked center of the knob.
- Calculate the `fixedCenter` once when `show()` is called by using a fixed offset from the initial cursor position. The offset is calculated using 0.6 of the maximum knob radius:
  `centerOffset = 15.0 + 150.0 * 0.6 = 105.0`.
- Clamp the `fixedCenter` inside the screen's visible frame if the maximum diameter panel (300.0) would overflow.
- In `updatePanelFrame()`, calculate the dynamic panel frame origin relative to `fixedCenter` and the current `diameter`:
  - `origin.x = fixedCenter.x - diameter / 2`
  - `origin.y = fixedCenter.y - diameter / 2`

### 2. OverlayControllerTests.swift
- Adapt the quadrant collision avoidance tests (`testQuadrantCollisionAvoidance()`) to assert the new coordinates based on the fixed-center calculation.

## Verification Plan

### Automated Tests
Run the project's test suite to ensure all unit tests (including overlay frame calculation tests) build and pass successfully:
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme PhantomKnobDetector -destination 'platform=macOS'`
