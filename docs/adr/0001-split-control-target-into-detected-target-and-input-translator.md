# ADR-0001: Split ControlTarget into DetectedTarget + InputTranslator

**Date:** 2026-05-28  
**Status:** Accepted

## Context

`ControlTarget` was a protocol that mixed three concerns:

1. **Identity metadata** — what element is being controlled (`displayName`, `minValue`, `maxValue`)
2. **Execution** — how to apply a rotation delta (`applyDelta(_ deltaAngle: Double) -> Double`)
3. **Value read-back** — current value for overlay display

This worked for the original design where the only control method was AX direct write (read current value, add delta, write back). The `applyDelta` signature assumed you always knew the element's value range, and execution always meant "write a new numeric value via AX API".

The design became a problem when we introduced multiple `InputTranslation` strategies (scroll wheel synthesis, arrow key injection, swipe gestures). These strategies:
- Do not read or write `AXValue`
- Cannot provide a meaningful `displayValue` (no absolute value available)
- Do not need `minValue`/`maxValue`
- Have fundamentally different accumulation semantics (discrete vs. continuous)

Forcing all of these into `applyDelta` would have meant either a leaky abstraction (every caller checking the translation type) or a bloated protocol with optional fields.

## Decision

Split `ControlTarget` into two separate abstractions:

**`DetectedTarget`** — a pure metadata struct. Describes *what* is under the cursor. No execution logic. Fields: `bundleID`, `axRole`, `identifier`, `displayName`, `element`. Used by the state machine for identity comparison (via `ruleKey`) and by the overlay for display name.

**`InputTranslator`** — a protocol for execution. Describes *how* to deliver the knob's intent. Interface: `apply(units: Double, direction: RotationDirection)` + `displayValue: String?`. Owns its own accumulator for discrete event types. Returns `nil` for `displayValue` when absolute value is not available (non-axWrite translations).

`KnobStateManager` holds both at runtime:
- `currentTarget: DetectedTarget?` — for identity comparison and overlay name
- `currentTranslator: InputTranslator?` — for execution

## Alternatives Considered

**Keep `ControlTarget` unified, add an `InputTranslation` field.**  
This would still force `applyDelta` to dispatch on translation type internally. Every implementation would need to know about all 7 translation kinds. Rejected: the abstraction does not pay for itself.

**Replace with a single fat `InputTranslator` that also carries metadata.**  
Simpler call sites, but conflates identity (used for state machine cooling → knobing comparison) with execution (hot path per frame). A target identity change does not imply a translator change and vice versa.

## Consequences

- `ControlTarget` protocol is deprecated. `DemoSliderTarget` and `GenericControlTarget` remain temporarily during migration.
- Identity comparison in the cooling → knobing state transition switches from `displayName` equality to `ruleKey` equality (more stable: based on `bundleID + axRole + AXIdentifier`).
- Overlay value display is now `nil` for all non-`axWrite` translations; the overlay hides the value area rather than showing a meaningless number.
