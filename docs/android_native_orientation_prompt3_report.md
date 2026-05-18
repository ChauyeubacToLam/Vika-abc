# Android Native Orientation Prompt 3 Report

## Executive Summary

Implemented Option A from Prompt 3 (Revised): Android physically rotates camera bitmaps for MediaPipe Pose and ML Kit Selfie Segmentation, but intentionally does not mirror front-camera frames before inference.

Changed files:

- `android/app/src/main/kotlin/com/vikavn/app/PoseLandmarkerPlugin.kt`
- `android/app/src/main/kotlin/com/vikavn/app/PoseLandmarkerHelper.kt`
- `android/app/src/main/kotlin/com/vikavn/app/SelfieSegmentationHelper.kt`
- `lib/screens/exercise/active_exercise_page.dart`

## What Changed

`PoseLandmarkerPlugin` now accepts `initialOrientation` during `initialize` and handles `setOrientation` on `com.vikavn.app/pose_landmarker`.

When Dart sends an orientation, the plugin updates CameraX `targetRotation` for both `Preview` and `ImageAnalysis`. When Dart does not send one, the Android path keeps the existing CameraX `imageInfo.rotationDegrees` behavior.

The bitmap processing path remains rotate-only:

```kotlin
val matrix = Matrix().apply {
    postRotate(rotationDegrees.toFloat())
    // intentionally no front-camera mirror
}
```

The processed bitmap is still shared by pose and segmentation, so both engines see the same rotated, un-mirrored frame.

`PoseLandmarkerHelper` stores the orientation state, keeps `isFrontCamera` in the event payload, and now emits `rotationDurationMs` for diagnostics.

`SelfieSegmentationHelper` now accepts `initialOrientation` / `setOrientation` on its method channel and stores `isFrontCamera` for diagnostics and future mirror support, but does not mirror or rotate independently because pose owns the shared bitmap preprocessing.

`ActiveExercisePage` copies native rotation diagnostics into `debugData` only when `ExerciseBase.kDiagnosticMode` is enabled.

## Logic

This keeps Android aligned with iOS Prompt 2 behavior:

- Pose input is un-mirrored on both platforms.
- Front-camera landmark anatomical side labels remain flipped on both platforms.
- The painter remains responsible for visual mirroring.
- ML Kit segmentation on Android receives the same processed bitmap as pose, so Android pose and segmentation stay spatially aligned.

## Side-Specific Exercise Scan

I grepped `lib/exercise/` for left/right landmark access before implementing Option A.

Findings:

- Squat, push-up, curl-up, glute bridge, and plank select a camera-visible side or average/compare both sides.
- Jumping jack tracks left/right arm values internally, but current metrics use bilateral minimums/averages rather than anatomical side-specific coaching.
- Lunge has lead/trail leg logic and debug labels, but the active checks are based on lead/trail geometry rather than reporting a hard-coded anatomical left/right fault.

I did not find a launched exercise that contradicts Option A by depending on anatomically correct front-camera left/right labels.

## Notes

The Android Matrix deliberately omits `postScale(-1f, 1f)`. If future per-side coaching requires anatomical correctness, the platform-consistent path is Option B: mirror iOS input before Pose Landmarker as well, then revisit Android mirroring at the same time.

I did not complete a physical mid-tier Android p99 rotation benchmark in this change. The app now emits `rotationDurationMs` in pose events and logs sampled Android rotation timings when orientation override is active or a frame exceeds 12 ms.
