# Presence Filter Swap Self-Review Report

## 1. Files changed

Flutter:

- `lib/exercise/exercise_base.dart`: Replaced `MIN_CONFIDENCE` with `MIN_PRESENCE = 0.7`, `MIN_VISIBILITY = 0.3`, and `isLandmarkConfident()`. Added `kDiagnosticMode = false` with production-warning comments. The existing person-loss auto-pause path now respects `!kDiagnosticMode`.
- `lib/pose/vika_pose_landmark.dart`: Added Vika-side landmark confidence metadata so `PoseLandmark.likelihood` can remain visibility while Vika code can also read presence.
- `lib/pose/pose_landmarker_adapter.dart`: Reads `presence` and `visibility` from native pose payloads. Keeps `likelihood` as visibility for legacy overlay/side-selection consumers.
- `lib/utils/pose_smoother.dart`: Preserves Vika landmark confidence metadata when smoothing creates new `PoseLandmark` instances.
- `lib/exercise/squat/squat.dart`, `lib/exercise/curl_up/curl_up.dart`, `lib/exercise/plank/plank.dart`, `lib/exercise/push up/push_up.dart`, `lib/exercise/glute bridge/glute_bridge.dart`, `lib/exercise/jumping jack/jumping_jack.dart`, `lib/exercise/lunge/lunge.dart`: Migrated old `ExerciseBase.MIN_CONFIDENCE` checks to `ExerciseBase.isLandmarkConfident()`.
- `lib/utils/segmentation_channel.dart`: Added best-effort `debugLog(String message)`.
- `lib/utils/person_detector.dart`: Removed `dart:developer` logging and routes presence state transitions through segmentation channel `debugLog`.
- `lib/screens/exercise/active_exercise_page.dart`: Gated the pose-event/fallback-frame backpressure drop on `!ExerciseBase.kDiagnosticMode`.

Native iOS:

- `ios/Runner/PoseLandmarkerService.swift`: Adds `presence` and `visibility` to normalized and world landmark payloads.
- `ios/Runner/SegmentationService.swift`: Handles `debugLog` and prints messages with `[VIKA-DIAG]`.

Native Android:

- `android/app/src/main/kotlin/com/vikavn/app/PoseLandmarkerHelper.kt`: Adds `presence` and `visibility` to normalized and world landmark payloads.
- `android/app/src/main/kotlin/com/vikavn/app/SelfieSegmentationHelper.kt`: Handles `debugLog` via `Log.d` with `[VIKA-DIAG]`.

## 2. Landmark confidence behavior

`PoseLandmark` comes from `google_mlkit_pose_detection` and only exposes one score field, `likelihood`. I did not set `likelihood = presence`, because that would lose visibility and silently change existing consumers.

The adapter now creates landmarks with:

- `likelihood`: native visibility, for legacy code that still expects ML Kit-style confidence.
- `presence`: stored in Vika metadata extension.
- `visibility`: stored in Vika metadata extension.

The exercise gate is now:

```dart
landmark.presence >= ExerciseBase.MIN_PRESENCE &&
    landmark.visibility >= ExerciseBase.MIN_VISIBILITY
```

For ML Kit fallback landmarks that do not carry separate native presence, the extension falls back to `likelihood` for both fields. That keeps fallback behavior source-compatible, but it cannot gain the MediaPipe presence/visibility separation until that runtime supplies both values.

## 3. Old `MIN_CONFIDENCE` consumers migrated

Direct `ExerciseBase.MIN_CONFIDENCE` consumers were found in:

- Squat required side-tracked landmarks.
- Push-up required camera-side shoulder/elbow/wrist/hip.
- Curl-up required landmarks plus optional ankle availability.
- Glute bridge required landmarks plus optional head/ankle fallback checks.
- Plank required shoulder/hip/ear plus optional ankle/knee availability.
- Lunge full-body required landmark list.
- Jumping jack required bilateral shoulder/wrist/ankle checks.

All direct consumers now call `ExerciseBase.isLandmarkConfident()`.

## 4. Diagnostic logging

`PersonDetector` now logs only presence state transitions:

- `PRESENCE_GAINED`
- `PRESENCE_LOST`

Those logs go through `SegmentationChannel.debugLog`, then native `print` on iOS or `Log.d` on Android, both with `[VIKA-DIAG]`. The method is best-effort and catches failures on the Dart side so logging cannot affect detection.

## 5. Secondary pause path

I did not find another person-loss path that directly calls `PoseLandmarkerChannel.stopDetection()`. The only `stopDetection()` calls in `active_exercise_page.dart` are teardown/completion paths, not person-loss.

The secondary path I found is the active-page backpressure guard:

```dart
if (_isProcessingFrame || _didComplete) return;
```

For native MediaPipe, this means Dart can drop incoming pose events while the previous event is still being handled. In normal production use that is useful throttling. In a diagnostic run, though, it can create apparent frame gaps in Dart-side pose processing even when native pose is still producing events.

I gated that drop with `!ExerciseBase.kDiagnosticMode` in both native-event and ML Kit fallback paths. Production behavior is unchanged while `kDiagnosticMode = false`.

## 6. Punt / risk

Android native compile could not be verified in this workspace because no Java runtime is installed:

```text
The operation couldn’t be completed. Unable to locate a Java Runtime.
```

The Android MediaPipe Tasks version is pinned to `0.20230731`. The code uses `landmark.presence()`, which is the expected Tasks Vision API shape; this still needs a real Android compile on a machine with Java/Android tooling.

No HYBRID trigger/validator work was added.

## 7. Verification

Commands run:

```text
dart format ...
flutter analyze
bash gradlew :app:compileDebugKotlin
```

Results:

- `dart format`: passed after sandbox approval for Flutter SDK cache access.
- `flutter analyze`: completed with 3 existing unrelated issues:
  - `lib/screens/main_shell.dart:279` unused `iconColor`
  - `lib/screens/main_shell.dart:280` unused `labelColor`
  - `lib/services/auth_service.dart:75` `avoid_print`
- `bash gradlew :app:compileDebugKotlin`: blocked by missing Java runtime.

Device verification was not run here. Nam should smoke-test on iPhone 14 with `kDiagnosticMode` temporarily set true only for the diagnostic build, then restore false before production.
