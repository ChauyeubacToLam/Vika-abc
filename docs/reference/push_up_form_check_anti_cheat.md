# Push-Up Form Check + Anti-Cheat Notes

This document explains the push-up state machine and the helper methods added
around it. The implementation lives in `lib/exercise/push up/push_up.dart`.

## Why push-up has more helpers than squat

Squat mostly needs one side-view chain and one primary state signal:
`hip-knee-ankle` knee angle. Push-up needs the same state-machine pattern, but
it also has to reject common cheats:

- starting from the floor instead of a high plank
- doing knee push-ups
- bending only the elbows while the body stays still
- drifting the hands/wrists into a different setup mid-rep
- losing the straight shoulder-hip-knee-ankle line

That is why push-up has more geometry checks. The generic buffer math was moved
to `FrameBuffer`; the remaining helpers are push-up-specific.

## Data Flow

Every active frame:

1. `checkingPose()` gets the tracked side landmarks with
   `SideTrackedExerciseMixin`.
2. `_calculateGeometry()` computes all push-up-specific angles and distances
   once for that frame.
3. A `FrameSnapshot` is pushed into `frameBuffer` with elbow angle, body joint
   y positions, trunk deviation, and line angles.
4. `_updateActiveGuard()` runs live anti-cheat checks during active reps.
5. `_updatePushUpState()` updates the state machine using buffered elbow
   direction and ROM from the plank elbow baseline.
6. `_completeRep()` collects metric faults, logs the rep, and resets for the
   next cycle.

## Baselines

### Elbow Baseline

`_baselineElbowAngle` is the user's top/plank elbow angle. It behaves like
squat's standing knee baseline:

- captured during valid start position
- refreshed only while the user is in a valid plank
- used by `_topElbowAngle`
- rep entry requires `topElbowAngle - currentElbowAngle > ROM_GATE`

This replaces the old fixed `DESCEND_ANGLE_THRESHOLD`.

### Wrist Baseline

`_baselineWristY` is captured only during `isInStartPosition()`, while the user
is holding the strict high-plank setup. It is intentionally not refreshed during
the set. This prevents a user from starting on the floor and then drifting into a
wall/incline style setup mid-rep.

### Heel Baseline

`_baselineHeelY` is also captured only during `isInStartPosition()`. During the
active rep, heel y is allowed a looser drift than wrist y because foot keypoints
can wobble during a real push-up. Sustained large drift rejects the rep, which
prevents leg-lift or foot-base changes from faking knee/body movement.

### Rep-Start Knee Baseline

`_repStartKneeY` is captured when the state changes from `plank` to
`descending`. The frame buffer is cleared at that transition to match Squat's
active-rep pattern, so this one baseline stays outside the buffer. It prevents a
valid fast descent from being rejected just because the first body movement
happened before the cleared buffer had enough frames.

## State Machine

States:

- `plank`
- `descending`
- `bottom`
- `ascending`

`_updatePushUpState()` mirrors squat's pattern:

- `frameBuffer.getChange("elbowAngle", ANGLE_STABLE_GATE)` detects whether the
  elbow angle is increasing, decreasing, or stable.
- `StickyDebouncer directionDetection` smooths direction changes.
- `ROM_GATE` confirms the elbow has moved far enough away from the personalized
  plank baseline before entering `descending`.
- `_bottomDebouncer` confirms bottom when elbow angle is within the configured
  bottom range.
- `_plankDebouncer` confirms return to plank.

## Live Anti-Cheat

`_updateActiveGuard()` runs during `descending`, `bottom`, and `ascending`.

- Knee movement: `frameBuffer.getChange("kneeY", positionGate)` catches ongoing
  frame-to-frame knee motion. `_repStartKneeY` catches the first movement after
  the Squat-style buffer clear. Together they answer one question: did the body
  move with the elbow bend?
- Body-line guard: `_evaluateActiveGeometry()` checks knee clearance and the two
  straight-body angles: shoulder-hip-knee and hip-knee-ankle. It also keeps a
  small shoulder-above-wrist support check to reject lying-flat reps.
- Wrist drift guard: compares current wrist y against `_baselineWristY`.
- Heel drift guard: compares current heel y against `_baselineHeelY` with a
  looser threshold to keep the lower-body base anchored.
- Elbow-only guard: during descent, after elbow ROM passes `ROM_GATE`, the knee
  must show frame-to-frame movement. If knee y stays stable, the rep is treated
  as an elbow-only cheat.

## Rep Completion

There is no separate cumulative-motion anti-cheat at rep completion now. That
was removed to keep the push-up logic closer to squat. Completion only checks:

- the rep was not already rejected by a live guard
- bottom was reached
- depth, trunk, and tempo metrics evaluate their own faults

The live knee-movement guard is the primary signal that the user moved the body
rather than only bending the elbows.

## FrameBuffer Helpers

`lib/utils/frame_buffer.dart` now owns reusable buffer math:

- `getTravel(key)` = peak max minus peak min for a signal
- `getMaxAbs(key)` = largest absolute value in the buffer
- `getMaxAbsFromBaseline(key, baseline)` = largest deviation from a baseline

Push-up uses these for rep logging. These helpers are generic enough for
squat/curl-up/future exercises, unlike the push-up geometry checks.

## Why Geometry Helpers Stayed Local

`_PushUpGeometry`, `_calculateGeometry()`, `_evaluatePlankGeometry()`, and
`_evaluateActiveGeometry()` are not generic frame-buffer utilities. They encode
push-up-specific meaning:

- knee/hip should be off the support line
- shoulder-hip-knee and hip-knee-ankle should stay straight
- trunk should be horizontal for the selected camera-facing side
- shoulder should stay above the wrist/support point enough to reject lying flat

Moving these to `FrameBuffer` would mix exercise semantics into a generic time
series buffer. If another exercise needs similar body-line checks later, the
right abstraction would be a pose-geometry utility, not `FrameBuffer`.
