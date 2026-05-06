# MIN_CONFIDENCE Audit

## 1. Constant Location

- `lib/exercise/exercise_base.dart:67`

```dart
static const MIN_CONFIDENCE = 0.92;
```

## 2. Direct Call Sites

All direct call sites compare `ExerciseBase.MIN_CONFIDENCE` against `PoseLandmark.likelihood`. None of the direct Dart call sites compare it against `minPoseDetectionConfidence`, `minTrackingConfidence`, `personPresenceScore`, selfie-segmentation confidence, or another SDK-level aggregate.

| Location | Compared value | Failure behavior |
|---|---|---|
| `lib/exercise/squat/squat.dart:295` | Aggregate `.every(...)` over the selected side-tracked required landmarks' individual `lm.likelihood` values. This includes the squat side bundle resolved by `SideTrackedExerciseMixin` from required landmarks such as hip, shoulder, knee, ankle, foot, and heel. | `checkSafety()` returns an adjust-lighting/position warning. In `ExerciseBase.processPose()` this becomes `resultIssues.feedback["System"]`, base debug tracking runs, and the method returns `[repCount, feedback]`; the state machine and `checkingPose()` are skipped for that frame. |
| `lib/exercise/push up/push_up.dart:162` | Camera-side shoulder `PoseLandmark.likelihood`. | If this or any line in the same block fails, `checkSafety()` returns a low-clarity warning. `ExerciseBase.processPose()` then sets System feedback and returns early, skipping the active pose update for that frame. |
| `lib/exercise/push up/push_up.dart:163` | Camera-side elbow `PoseLandmark.likelihood`. | Same push-up `checkSafety()` failure path: warning returned, frame pose logic skipped. |
| `lib/exercise/push up/push_up.dart:164` | Camera-side wrist `PoseLandmark.likelihood`. | Same push-up `checkSafety()` failure path: warning returned, frame pose logic skipped. |
| `lib/exercise/push up/push_up.dart:165` | Camera-side hip `PoseLandmark.likelihood`. | Same push-up `checkSafety()` failure path: warning returned, frame pose logic skipped. |
| `lib/exercise/curl_up/curl_up.dart:251` | Optional camera-side ankle `PoseLandmark.likelihood` during start-position validation. | If ankle is missing or below `0.92`, curl-up does not immediately fail the start position. It leaves `hka` null, skips the strict ankle-based knee-angle gate, and later stores `_holdStillHipKneeAnkle = null`. |
| `lib/exercise/curl_up/curl_up.dart:323` | Aggregate `.every(...)` over curl-up's selected side-tracked required landmark bundle. | `checkSafety()` returns an adjust-lighting/position warning. `ExerciseBase.processPose()` sets System feedback and returns early, so curl-up's active frame logic is skipped. |
| `lib/exercise/curl_up/curl_up.dart:345` | Optional camera-side ankle `PoseLandmark.likelihood` during active curl-up processing. | If ankle is missing or below `0.92`, `ankleVisible` is false and `hipKneeAnkleAngle` becomes null. The frame still processes; ankle/knee-extension logic that needs that angle is skipped or receives null. |
| `lib/exercise/glute bridge/glute_bridge.dart:243` | Camera-side shoulder `PoseLandmark.likelihood`. | If this or any line in the same safety block fails, `checkSafety()` returns a low-clarity warning. `ExerciseBase.processPose()` sets System feedback and returns early, skipping glute-bridge `checkingPose()` for that frame. |
| `lib/exercise/glute bridge/glute_bridge.dart:244` | Camera-side hip `PoseLandmark.likelihood`. | Same glute-bridge `checkSafety()` failure path: warning returned, frame pose logic skipped. |
| `lib/exercise/glute bridge/glute_bridge.dart:245` | Camera-side knee `PoseLandmark.likelihood`. | Same glute-bridge `checkSafety()` failure path: warning returned, frame pose logic skipped. |
| `lib/exercise/glute bridge/glute_bridge.dart:286` | Camera-side ear `PoseLandmark.likelihood` for optional head-position selection. | If ear is missing or below `0.92`, code falls back to checking nose confidence. It does not skip the frame. |
| `lib/exercise/glute bridge/glute_bridge.dart:288` | Nose `PoseLandmark.likelihood` for optional head-position selection. | If nose is also missing or below `0.92`, `headY` falls back to `shoulder.y`. The frame continues; the fallback prevents a metric crash but loses real head tracking for that frame. |
| `lib/exercise/glute bridge/glute_bridge.dart:316` | Optional camera-side ankle `PoseLandmark.likelihood` for knee-angle calculation. | If ankle is missing or below `0.92`, `kneeAngle` becomes null. The frame continues; knee-angle-dependent logic receives null or skips. |
| `lib/exercise/plank/plank.dart:155` | Camera-side shoulder `PoseLandmark.likelihood`. | If this or any line in the same safety block fails, `checkSafety()` returns a low-clarity warning. `ExerciseBase.processPose()` sets System feedback and returns early, skipping plank `checkingPose()` for that frame. |
| `lib/exercise/plank/plank.dart:156` | Camera-side hip `PoseLandmark.likelihood`. | Same plank `checkSafety()` failure path: warning returned, frame pose logic skipped. |
| `lib/exercise/plank/plank.dart:157` | Camera-side ear `PoseLandmark.likelihood`. | Same plank `checkSafety()` failure path: warning returned, frame pose logic skipped. |
| `lib/exercise/plank/plank.dart:168` | Optional ankle `PoseLandmark.likelihood` used to set `_ankleAvailable`. | If ankle is missing or below `0.92`, `_ankleAvailable` becomes false. The frame continues, but knee angle is not computed and `kneeExtensionMetric` is skipped while holding. |
| `lib/exercise/plank/plank.dart:169` | Knee `PoseLandmark.likelihood` used with ankle to set `_ankleAvailable`. | If knee is below `0.92`, `_ankleAvailable` becomes false. The frame continues, but knee angle is not computed and `kneeExtensionMetric` is skipped while holding. |
| `lib/exercise/lunge/lunge.dart:184` | Aggregate `.any(...)` over a list of required bilateral landmarks' individual `l.likelihood` values: hips, shoulders, knees, ankles, feet, and heels. | `checkSafety()` returns an adjust-lighting/position warning. `ExerciseBase.processPose()` sets System feedback and returns early, skipping lunge pose logic for that frame. |
| `lib/exercise/jumping jack/jumping_jack.dart:187` | Left shoulder `PoseLandmark.likelihood`. | If this or any line in the same safety block fails, `checkSafety()` returns a low-clarity warning. `ExerciseBase.processPose()` sets System feedback and returns early, skipping jumping-jack `checkingPose()` for that frame. |
| `lib/exercise/jumping jack/jumping_jack.dart:188` | Right shoulder `PoseLandmark.likelihood`. | Same jumping-jack `checkSafety()` failure path: warning returned, frame pose logic skipped. |
| `lib/exercise/jumping jack/jumping_jack.dart:189` | Left wrist `PoseLandmark.likelihood`. | Same jumping-jack `checkSafety()` failure path: warning returned, frame pose logic skipped. |
| `lib/exercise/jumping jack/jumping_jack.dart:190` | Right wrist `PoseLandmark.likelihood`. | Same jumping-jack `checkSafety()` failure path: warning returned, frame pose logic skipped. |
| `lib/exercise/jumping jack/jumping_jack.dart:191` | Left ankle `PoseLandmark.likelihood`. | Same jumping-jack `checkSafety()` failure path: warning returned, frame pose logic skipped. |
| `lib/exercise/jumping jack/jumping_jack.dart:192` | Right ankle `PoseLandmark.likelihood`. | Same jumping-jack `checkSafety()` failure path: warning returned, frame pose logic skipped. |

### Shared Early-Return Path

Most safety-gate failures above flow through `ExerciseBase.processPose()`:

- `lib/exercise/exercise_base.dart:215` calls the exercise's `checkSafety(...)`.
- `lib/exercise/exercise_base.dart:216-220` handles non-null safety errors by setting `resultIssues.feedback["System"]`, updating base debug data, tracking one debug frame, and returning `[repCount, resultIssues.feedback]`.

That means the active exercise state machine and metric update path are skipped for that frame when `MIN_CONFIDENCE` fails inside `checkSafety()`.

## 3. Plain-English Summary

`MIN_CONFIDENCE = 0.92` gates per-landmark `PoseLandmark.likelihood` checks for exercise safety, optional landmark availability, and a few fallback decisions for head/ankle-derived values. When the value falls below `0.92`, most `checkSafety()` paths show a System warning and skip that frame's exercise logic, while optional-landmark paths keep the frame running but set the dependent angle/value to null or use a fallback.

## 4. SquatConfig.MIN_TRACKING_CONFIDENCE

`SquatConfig.MIN_TRACKING_CONFIDENCE = 0.45` does not exist anywhere in `lib/`, `ios/`, or `android/`.

The only `0.45` hits found are unrelated UI opacity values and `TempoConfig.DESCENT_MIN_GOOD = 0.45` in `lib/exercise/squat/metrics/tempo_metric.dart`.

## 5. iOS Phase 1 `minTrackingConfidence = 0.7`

- `ios/Runner/PoseLandmarkerService.swift:50` sets `options.minPoseDetectionConfidence = 0.5`.
- `ios/Runner/PoseLandmarkerService.swift:51` sets `options.minPosePresenceConfidence = 0.5`.
- `ios/Runner/PoseLandmarkerService.swift:52` sets `options.minTrackingConfidence = 0.7`.

The iOS `minTrackingConfidence = 0.7` setting is independent from `ExerciseBase.MIN_CONFIDENCE = 0.92`; it is an SDK-level MediaPipe Tasks option that affects the pose landmarker before Dart receives landmarks. `MIN_CONFIDENCE` is an app-level Dart gate over each returned `PoseLandmark.likelihood`, so it runs later and is not wired to the iOS SDK setting.
