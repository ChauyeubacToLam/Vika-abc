# scaleFactor calibration — implementation spec

Owning decision: `docs/decisions.md` → "2026-07-05 · scaleFactor: hold-seeded, EMA-adaptive,
side-aware source". This doc is the HOW; the ADR is the WHY. Read the ADR first.

Target file: `lib/exercise/exercise_base.dart` (base only). Executor: T-core change — write it
annotated, Nam reviews every line.

## Problem being fixed

`calScaleFactor` returns `1.0` whenever the 4 torso landmarks aren't all present, and it checks
*presence of the map key* (`!= null`), not confidence. But `PoseSmoother.smoothing`
(`lib/utils/pose_smoother.dart:36`) preserves every key ML Kit returns — occluded landmarks arrive
as low-confidence entries with kept/hallucinated coordinates, not as missing keys. So today's failure
is either (a) scale collapses to `1.0` → metrics that divide by it spike ~100-400×, or (b) scale is
computed from a hallucinated far-side hip. Both produce phantom reps/faults in the two consumers.

## Consumers (verified)

Only **glute_bridge** and **curl_up** consume the base-computed `scaleFactor`. ~20 other exercises
overwrite the field in their own `checkingPose` (squat, dead_bug, push_up, all planks, etc.); a few
(prayer_pose, raised_arms, seated_forward_fold) pass a local `scale`. Both consumers are side-facing
(their `checkSafety` returns an error unless `cameraFacing` is left/right).

## The change

### 1. Constant (Constants block, ~line 33)
```dart
const double SCALE_EMA_ALPHA = 0.1; // mid-set scale adaptation rate; tuning knob (see curl_up device pass)
```

### 2. Fields (~line 153) — keep the public field, drop nothing else needed
```dart
double scaleFactor = 1.0; // public; consumers read this. 1.0 = pre-seed sentinel (unreachable once gated)
```
No `_scaleSeeded` flag needed (see lifecycle).

### 3. Replace line 341's `scaleFactor = calScaleFactor(smoothedLandmarks);`
Keep it at this position — BEFORE `checkExerciseState` (line ~343), so `isInStartPosition` reads a
fresh value the same frame. glute_bridge's start check consumes scaleFactor; if the write moves after
`isInStartPosition`, glute_bridge deadlocks (start check can never pass with scaleFactor=1.0).

```dart
_updateScaleFactor(smoothedLandmarks);
```

### 4. New methods (replace `calScaleFactor`, ~line 536)
```dart
/// Two-state calibration write. notActivated: hard-track the current confident measurement so the
/// start check gets a fresh value and the hold measurement is locked at activation. activated: slow
/// EMA so genuine repositioning tracks but a single occluded frame can't spike the value. Bad frames
/// never write, so "reuse last good" is automatic, and the notActivated hard-write seeds the EMA.
void _updateScaleFactor(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
  final raw = _rawScale(smoothedLandmarks);
  if (raw == null) return; // not confidently measurable this frame → keep prior value
  if (exerciseState == ExerciseState.notActivated) {
    scaleFactor = raw;
  } else if (exerciseState == ExerciseState.activated) {
    scaleFactor = SCALE_EMA_ALPHA * raw + (1 - SCALE_EMA_ALPHA) * scaleFactor;
  }
  // completed: no-op (nothing reads it)
}

/// Side-aware shoulder→hip distance, gated on landmark confidence (not mere non-null). Returns null
/// when the source landmarks aren't confidently measurable this frame.
double? _rawScale(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
  if (cameraFacing == CameraFacing.left || cameraFacing == CameraFacing.right) {
    final s = getSideLandmark(landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightShoulder, leftType: PoseLandmarkType.leftShoulder);
    final h = getSideLandmark(landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightHip, leftType: PoseLandmarkType.leftHip);
    if (s == null || h == null) return null;
    if (!isLandmarkConfident(s) || !isLandmarkConfident(h)) return null;
    return _distance(s, h);
  }
  // front / angled / undefined: midpoints, confidence-gated (was the old all-4 path, now gated)
  final ls = smoothedLandmarks[PoseLandmarkType.leftShoulder];
  final rs = smoothedLandmarks[PoseLandmarkType.rightShoulder];
  final lh = smoothedLandmarks[PoseLandmarkType.leftHip];
  final rh = smoothedLandmarks[PoseLandmarkType.rightHip];
  if (ls == null || rs == null || lh == null || rh == null) return null;
  if (!isLandmarkConfident(ls) || !isLandmarkConfident(rs) ||
      !isLandmarkConfident(lh) || !isLandmarkConfident(rh)) return null;
  final shoulderMidX = (ls.x + rs.x) / 2, shoulderMidY = (ls.y + rs.y) / 2;
  final hipMidX = (lh.x + rh.x) / 2, hipMidY = (lh.y + rh.y) / 2;
  final dx = shoulderMidX - hipMidX, dy = shoulderMidY - hipMidY;
  return math.sqrt(dx * dx + dy * dy);
}
```
Use the existing distance helper if one exists in `pose_math_helpers.dart` (`calculateDistance`) rather
than a private `_distance`; verify its signature before wiring.

## Why no seeded flag / why hard-write pre-activation
- Activation needs 3s of `isInStartPosition`, which needs `checkSafety` passing (confidence). So by
  activation, many confident notActivated frames have hard-written scaleFactor → it's a real value,
  never 1.0, when the EMA takes over. The hard-write is the seed.
- EMA pre-activation would lag from 1.0 for ~30 frames and hand glute_bridge a wrong start tolerance.
  Hard-write is accurate immediately.

## Demolition / fences
- **Delete:** `calScaleFactor` and its `return 1.0`. Confirm no caller but line 341 (`grep calScaleFactor lib/`).
- **Leave untouched (fence):** glute_bridge's `scaleFactor > 0 ? … : PIXELS` guards
  (`glute_bridge.dart` ~223, 369, 382, 522). Now dead (seed-before-activation invariant), but removing
  them retunes a consumer's thresholds — out of scope. Optional later cleanup, not this change.
- **Do NOT touch (fence):** posture_stack's `< 1.0` check — reads prayer_pose's LOCAL scale, unrelated.
- **Do NOT touch (fence):** the ~20 overwriter exercises. They keep their raw per-frame calc. Migrating
  them to a shared EMA helper is a separate future project.

## Test / verify (execution + device)
1. Side-lying, far-side hip hallucinated (low confidence, kept coords) → `_rawScale` returns null,
   scaleFactor holds prior. THE core regression case. Was: measured the bad hip.
2. Mid-rep single-frame side-hip drop (glute bridge top) → no spike, no phantom rep. EMA + null-skip.
3. Cold start → confirm scaleFactor is a real value by the time `isInStartPosition` first reads it
   (checkSafety gates confidence before line 341, so the first reachable frame hard-writes).
4. Un-paused mid-set repositioning → scale tracks over ~1-2s (EMA). Not frozen.
5. **curl_up device pass (ADR flag):** metrics now normalize against an adaptive-but-stable torso
   length instead of one that shrank as the trunk flexed. Watch depth/ROM thresholds; likely better,
   tuned against old behavior. This sets the final `SCALE_EMA_ALPHA`.
6. A front-facing overwriter (e.g. squat) → unaffected post-activation (it overwrites); confirm no
   regression during its hold (it now sees the EMA/hard-write base value pre-overwrite — strictly ≥ as
   stable, low risk, but verify it isn't read raw in that exercise's `isInStartPosition`).

## Open items
- `SCALE_EMA_ALPHA = 0.1` is a starting guess; the curl_up device pass finalizes it.
- Verify `calculateDistance` in `pose_math_helpers.dart` before using it in `_rawScale`.
- Resume-rehold feature is NOT built here. When it lands, it must route state back to `notActivated`
  (which it does anyway to re-run the hold); re-seeding then happens for free. No work needed now.
