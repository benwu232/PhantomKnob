# CapCut Text Focus & Generic AX Diagnostics Design Spec

Introduce support for adjusting parameter text boxes in CapCut/剪映 by simulating a click to focus followed by arrow keys, and create a generic AX diagnostics command-line tool.

## User Review Required

> [!NOTE]
> We will bypass the `AXMinValue`/`AXMaxValue` requirement in `TargetDetector` ONLY for `AXTextField` and `AXStaticText` roles, and ONLY consider them controllable if a matching rule exists in the RuleLibrary. This avoids accidental mouse click triggers in other apps that do not have custom rules for labels or static text.

## Proposed Changes

### 1. Diagnostics Tool (Generic)

#### [NEW] [inspect_ax_tool.swift](file:///Users/wb/work/phantom_knob_mac/scripts/inspect_ax_tool.swift)
A standalone, generic command-line utility. Every 1 second, it inspects the application and AX element hierarchy under the mouse cursor, dumping detailed properties to help users configure rules.
- Retrieves window and application under cursor.
- Traverses the accessibility parent hierarchy (depth 0 to 10).
- Prints roles, subroles, titles, identifiers, descriptions, settable attributes, available actions, and current values.
- Recommends rule configurations for PhantomKnob.

### 2. PhantomKnob Application Core

#### [MODIFY] [TargetDetector.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/TargetDetector.swift)
Modify `tryBuildTarget` to relax constraints:
- By default, elements must have `AXMinValue` and `AXMaxValue`.
- Exception: If the element's role is `AXTextField` or `AXStaticText`, return it as a valid `DetectedTarget` even without min/max attributes.

#### [MODIFY] [KnobStateManager.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/Service/KnobStateManager.swift)
Integrate auto-focus simulation:
- When transitioning to `.knobing(target:)`:
  - If `target.axRole` is `"AXTextField"` or `"AXStaticText"`:
    - Post a mouse click (`leftMouseDown` and `leftMouseUp` at `initialTouchPosition`) to focus the text box.
- Ensure click events are sent with the source identifier `0xDEADC0DE` or from the main HID tap to prevent self-interception loop.

#### [MODIFY] [bundled-rules.json](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/App/bundled-rules.json)
Add rules for CapCut / 剪映 text boxes to translate rotation into `arrowKeyUpDown`:
- Applications: `com.lemon.jianying`, `com.lemon.jianyingpro`, `com.lemon.lv`, `com.lemon.lvoverseas`
- Roles: `AXStaticText`, `AXTextField`
- Translation: `arrowKeyUpDown`
- Scale: `fixed(1.0)`

---

## Verification Plan

### Automated Tests
- Build and run `PhantomKnobTests` to verify no regressions in rule matching.

### Manual Verification
1. Run `swift scripts/inspect_ax_tool.swift` and hover over CapCut's adjustment text boxes to verify they are detected as `AXStaticText` or `AXTextField`.
2. Run PhantomKnob, hover over a text box in CapCut's Adjustment tab, start rotating on the trackpad.
3. Verify that the text box receives focus (blinking cursor appears) and its value changes incrementally.
4. Verify that timeline scrubbing still works as expected using `arrowKeyLeftRight`.
