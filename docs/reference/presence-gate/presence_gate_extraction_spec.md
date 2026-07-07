# PresenceGate extraction — implementation spec

Owning decision: `docs/decisions.md` → "2026-07-05 · PresenceGate: extract presence/pause/
segmentation from ExerciseBase". This doc is the HOW; the ADR is the WHY. Read the ADR first.

Target files: new `lib/exercise/presence_gate.dart`; edits to `lib/exercise/exercise_base.dart`
and `lib/utils/person_detector.dart` (one-line interface add). Executor: Sonnet, T-core change —
write it annotated, Nam reviews every line. **Pure structural refactor, ZERO behavior change** —
the pipeline must behave bit-for-bit identically.

Note: `exercise_base.dart` has in-flight local changes (scaleFactor calibration). Build on the
working tree as-is; do not revert or restructure that work.

## Problem being fixed

`ExerciseBase` mixes one whole responsibility into the exercise base: "is a real person reliably in
frame, should we auto-pause, and when do we poke the segmentation detector for a fresh sample." That
logic is ~200 lines smeared across 12 fields, 4 duration/threshold consts, 4 private methods, and 7
scattered `triggerCheck()` calls inside `processPose`. It can't be unit-tested without a full
`ExerciseBase` subclass pumping fake frames, and it clutters the per-frame pipeline.

Extract it into a `PresenceGate` collaborator that `ExerciseBase` owns and calls once per frame.
Payoff: the confirm/grace/resume timers become unit-testable with an injected clock (pass `DateTime`
values — the repo has no `fake_async`), and `processPose` reads as a clean linear pipeline.

## The new file: `lib/exercise/presence_gate.dart`

```dart
enum GatePhase { seeking, active, done }   // maps from ExerciseState
enum GateBlock { searching, paused }       // base maps to a Vietnamese string

class GateVerdict {
  final bool proceed;          // false → ExerciseBase early-returns this frame
  final GateBlock? block;      // set iff !proceed
  final bool personLostNow;    // seeking: confirmed→unconfirmed this frame
  final int personStableMs;    // seeking-unconfirmed: ms person continuously seen (debug HUD)
  const GateVerdict(...);
}

class PresenceGate {
  PresenceGate({PosePresenceSource? detector, bool diagnosticMode = false});

  // Per-frame entry points. Base passes its frameTimestamp as `now`.
  GateVerdict onPose({
    required DateTime now,
    required GatePhase phase,
    required Map<PoseLandmarkType, PoseLandmark> landmarks,
    Size? imageSize,
  });
  GateVerdict onNoPose({required DateTime now, required GatePhase phase});

  // Lifecycle
  void onActivated();               // reset detectors + useActivatedCadence()
  void manualPause();               // set both pause flags
  void manualResume(DateTime now);  // clear pause, seed resume timer, reset, trigger('manual_resume')
  Future<void> runDetection([InputImage? input]);
  Future<void> close();

  // Read-only surface for ExerciseBase getters
  bool get isPaused;
  bool get personConfirmed;
  bool get personDetected;
  double get presenceScore;
}
```

`GatePhase` is defined here (not imported from exercise_base) to avoid a circular import; `ExerciseBase`
maps `ExerciseState` → `GatePhase` at each call site (`notActivated→seeking`, `activated→active`,
`completed→done`).

## The detector seam (enables fakes)

Add a minimal interface so tests can inject a fake without touching platform channels. This is the
**only** change to `person_detector.dart` — no logic change. Above `PersonDetector`:

```dart
abstract interface class PosePresenceSource {
  bool get personDetected;
  double get presenceScore;
  Future<bool> detect([Object? _]);
  Future<void> triggerCheck({String reason});
  Future<void> useActivatedCadence();
  Future<void> close();
}
```

Then `class PersonDetector implements PosePresenceSource { ... }` — it already has every member; just
add the declaration. `PresenceGate` depends on `PosePresenceSource`, defaulting to `PersonDetector()`
when none is injected. `PresenceAnomalyDetector` is self-contained (no channels) — the gate `new`s one
internally; no interface needed.

## Move map — OUT of `exercise_base.dart` INTO `presence_gate.dart` (private to the gate)

| Item (current) | Notes |
|---|---|
| `_personDetector` (PersonDetector) | becomes injected `PosePresenceSource` |
| `_posePresenceDetector` (PresenceAnomalyDetector) | gate constructs internally |
| `_wasPoseAnomaly`, `_wasPoseFrameEdgeRisk`, `_wasPoseLowPresence`, `_wasNoLandmarks` | edge-trigger flags |
| `_personConfirmed`, `_personSeenSince`, `_personLostSince`, `_resumePresenceSince` | timers |
| `_isPaused`, `_manualPause` | pause flags |
| consts `_PERSON_CONFIRM_DURATION` (900ms), `_PERSON_LOST_GRACE` (900ms), `_PERSON_RESUME_CONFIRM_DURATION` (320ms) | |
| const `AVG_LOW_PRESENCE_THRESHOLD` (0.35) | presence-only; verified no other reader |
| methods `_syncPresenceState`, `_computeAvgPresence`, `_isPoseFrameEdgeRisk`, `_resetPresenceDetectors` | |
| all 7 `_personDetector.triggerCheck(reason: ...)` call sites | |

### Stays in `ExerciseBase` (do NOT move)
- `MIN_PRESENCE` (0.7), `MIN_VISIBILITY` (0.3), `isLandmarkConfident` — used by scale-factor `_rawScale`, not presence.
- `kDiagnosticMode` — static const, read externally as `ExerciseBase.kDiagnosticMode` in `active_exercise_page.dart`. Keep it; pass its value in: `PresenceGate(diagnosticMode: kDiagnosticMode)`.
- FPS tracking (`_currentFps`, `currentFps`, `fpsRatio`, `_lastFrameTime`) — unrelated to presence.
- `_holdStillStartedAt` and all hold-still activation — state-machine, not presence (see coupling below).

## ExerciseBase after extraction — keep the public API identical

Add `final PresenceGate _gate = PresenceGate(diagnosticMode: kDiagnosticMode);` and convert the public
surface to thin delegates. **No external call site may change** (main.dart, active_exercise_page.dart,
all `services/*_voice_coach.dart`, and `surya_namaskar.dart` which overrides `manualPause`/`manualResume`
and calls `super` — the wrappers must stay overridable):

```dart
void manualPause() { if (exerciseState != ExerciseState.activated) return; _gate.manualPause(); }
void manualResume() { _gate.manualResume(DateTime.now()); }   // UI-driven, not a frame → real now
Future<void> runPersonDetection([InputImage? i]) async {
  if (exerciseState == ExerciseState.completed) return;
  await _gate.runDetection(i);
}
Future<void> disposeDetectors() async => _gate.close();
double get personPresenceScore => _gate.presenceScore;
double? get activationProgress {                 // reads gate.personConfirmed + local _holdStillStartedAt
  if (exerciseState != ExerciseState.notActivated) return null;
  if (!_gate.personConfirmed) return null;
  if (_holdStillStartedAt == null) return null;
  // ...unchanged math...
}
```

`processPose` top (current lines ~277–335) collapses to:
```dart
final verdict = _gate.onPose(now: now, phase: _phase, landmarks: smoothedLandmarks, imageSize: imageSize);
if (isDebugModeActive && exerciseState == ExerciseState.notActivated) {
  debugData['personStableMs'] = verdict.personStableMs;
}
if (verdict.personLostNow) _holdStillStartedAt = null;
if (!verdict.proceed) {
  resultIssues.feedback['System'] = _systemStringFor(verdict.block!);  // Vietnamese, stays in base
  return [repCount, resultIssues.feedback];
}
// ... orientation, safety, scale, state machine unchanged ...
```

`processNoPoseFrame` similarly calls `_gate.onNoPose(...)`, applies `personLostNow`, then builds its
feedback string from `_gate.personConfirmed` / `_gate.isPaused` / `_gate.personDetected` (the existing
three-way branch, unchanged wording).

On activation inside `checkExerciseState`, replace `_resetPresenceDetectors()` +
`_personDetector.useActivatedCadence()` with `_gate.onActivated()`. `_holdStillStartedAt = null` and
`onExerciseActivated()` stay in base.

### Detector-plumbing members stay as ExerciseBase delegates (deliberate)

`disposeDetectors()` (→ `close()`), `personPresenceScore` (→ `presenceScore`), and
`runPersonDetection([InputImage?])` (`completed`-guard → `detect()`) are near-pure forwards into the
detector. Decision: they **stay on `ExerciseBase` as 1-line delegates to `_gate`**. The gate owns the
detector; the exercise is the single façade the camera holds (detector lifetime == exercise session
lifetime, and the `completed`-guard is genuinely exercise-state). Do NOT expose the gate publicly and
do NOT change the camera call sites.

Vietnamese copy is unchanged and stays in base — the gate returns enums only:
`GateBlock.searching → "Đang tìm người... Vui lòng đứng trong khung hình."`,
`GateBlock.paused → "⏸ Tạm dừng — Quay lại khung hình để tiếp tục"`.

## Behavior invariants — port these EXACTLY (self-check each in the report)

Ordering inside `onPose` (current top-of-`processPose` order):
1. If `_wasNoLandmarks`: `triggerCheck('pose_returned')`; clear the flag. **Before** any block/return.
2. Sync presence (updates confirmed / pause / timers). Capture `personLostNow` = seeking && was-confirmed && now-unconfirmed.
3. Block decisions: `seeking && !confirmed → block=searching, proceed=false` (also set `personStableMs`);
   `active && isPaused → triggerCheck('paused_pose_present'); block=paused, proceed=false`.
4. If not blocked: compute avg presence; `active && lowPresence && !_wasLowPresence → triggerCheck('pose_low_presence')`;
   update `_wasPoseLowPresence`. Compute edge risk; `active && edge && !_wasEdge → triggerCheck('pose_frame_edge')`;
   update `_wasPoseFrameEdgeRisk`. `anomalyDetector.update(avg)`; `confirmed && !_wasAnomaly → triggerCheck('pose_anomaly')`;
   update `_wasPoseAnomaly`. Return `proceed=true`.

Non-obvious points that MUST be preserved (do NOT "clean up"):
- **`_wasPoseLowPresence`/`_wasPoseFrameEdgeRisk`/anomaly updates run on every NON-BLOCKED frame** —
  including `seeking`-confirmed and `done`, not just `active`. Only the *triggers* for low-presence and
  edge are gated to `active`; the anomaly trigger fires in any non-blocked phase (yes, including `done`).
  Blocked frames (seeking-unconfirmed, active-paused) skip all of step 4 — this is what keeps the anomaly
  window from drifting during a pause and firing phantom triggers on resume.
- **`_syncPresenceState`'s `hasPose` param is currently unused** — presence is driven purely by
  `detector.personDetected`, never by whether pose landmarks exist. Keep it that way: `onPose` and
  `onNoPose` share the same internal sync that reads only the detector. Do not "fix" this.
- `onNoPose` reason: `no_landmarks` if last frame had landmarks, else `no_landmarks_stale_present`, and
  only triggers when `hadLandmarksLastFrame || detector.personDetected`. Then set `_wasNoLandmarks = true`
  and reset the three `_was*` trouble flags to false.
- Manual pause is never cleared by presence, only `manualResume`. Auto-pause fires after 900ms absence
  (unless `diagnosticMode`); auto-resume after 320ms confirmed presence. `??=` = streak-start stamps.
- `manualResume` clears both pause flags, seeds `_resumePresenceSince`, clears `_personLostSince`, resets
  detectors, fires `triggerCheck('manual_resume')`.
- The only debug key is `debugData['personStableMs']`, written only in seeking-unconfirmed when `isDebugModeActive`.

## Hard fences — do not touch
- Public API/behavior of `ExerciseBase` (delegates only). `surya_namaskar.dart` overrides must keep working.
- `PersonDetector` / `PresenceAnomalyDetector` logic — only add the `implements PosePresenceSource` declaration.
- The `_GenericExerciseVoiceCoach` block (L775+). A separate voice redesign is coming; leave it entirely alone.
- Scale factor, orientation detection, FPS tracking, `isLandmarkConfident`.
- No new dependencies. No new packages.

## Tests: `test/exercise/presence_gate_test.dart`

Follow repo convention: `flutter_test`, hand-written fakes (no mockito/mocktail), no `fake_async` — drive
time by passing `DateTime.fromMillisecondsSinceEpoch(...)` as `now`. Provide a
`_FakePresenceSource implements PosePresenceSource` with settable `personDetected`/`presenceScore` that
records `triggerCheck` reasons + `useActivatedCadence`/`close` calls. Local `_landmark()` helper as in
other exercise tests. Cover:
- Confirm at exactly 900ms continuous presence (seeking); un-confirm + `personLostNow` when presence drops.
- Auto-pause at 900ms absence during `active`; auto-resume at 320ms presence; manual pause survives presence until `manualResume`.
- Each trouble trigger (`pose_low_presence`, `pose_frame_edge`, `pose_anomaly`) fires exactly once per false→true transition, and low-presence/edge only in `active`.
- `pose_returned` fires before a blocked early-return; blocked frames skip the anomaly update.
- `diagnosticMode: true` disables auto-pause.

## Verification
- `flutter analyze` clean; `flutter test` green (existing suite unchanged + new gate tests).
- Diff of `exercise_base.dart` shows only: deletions of moved members, the new `_gate` field + delegates,
  and the collapsed `processPose`/`processNoPoseFrame` tops. No metric/scale/orientation lines changed.
- Report a filled-in move map and a line-per-invariant checklist proving each is preserved.
- Manual smoke on device: activate an exercise (hold-still 3s still works), walk out of frame → auto-pause,
  walk back → auto-resume, tap pause → stays paused until resume tapped. Debug HUD still shows `personStableMs`.

## On completion
- Flip the ADR Status to `active` (implemented).
- One line in `docs/state.md` if it tracks in-flight refactors.
