# Native Segmentation 2a Self-Review Report

## 1. Files changed

Native Android:

- `android/app/src/main/kotlin/com/vikavn/app/MainActivity.kt`: Registers the segmentation method channel and event channel, then shares the segmentation helper with the pose plugin.
- `android/app/src/main/kotlin/com/vikavn/app/PoseLandmarkerPlugin.kt`: Switches CameraX analysis to `OUTPUT_IMAGE_FORMAT_RGBA_8888`, converts the analyzer frame to one rotated bitmap, and fans that frame out to pose and segmentation.
- `android/app/src/main/kotlin/com/vikavn/app/PoseLandmarkerHelper.kt`: Removes the NV21 byte extraction and YUV to JPEG to bitmap path. Pose events no longer include `frameBytes`.
- `android/app/src/main/kotlin/com/vikavn/app/SelfieSegmentationHelper.kt`: Reworks the idle scaffold into the native ML Kit Selfie Segmentation method/event service.

Native iOS:

- `ios/Runner/AppDelegate.swift`: Registers `com.vikavn.app/segmentation` and `com.vikavn.app/segmentation_stream`, and passes the segmentation service into the pose service.
- `ios/Runner/PoseLandmarkerService.swift`: Fans camera frames from the pose-owned capture pipeline into native segmentation.
- `ios/Runner/SegmentationService.swift`: Reworks the scaffold into the native ML Kit Selfie Segmentation method/event service.
- `ios/Podfile.lock`: Removes the Flutter `google_mlkit_selfie_segmentation` plugin pod while keeping the direct `GoogleMLKit/SegmentationSelfie` pod.

Flutter:

- `lib/utils/person_detector.dart`: Removes the Flutter SelfieSegmenter wrapper and consumes native aggregate segmentation events.
- `lib/utils/segmentation_channel.dart`: Adds the Dart method/event channel wrapper.
- `lib/pose/pose_landmarker_adapter.dart`: Removes `frameBytes` to `InputImage` reconstruction.
- `lib/screens/exercise/active_exercise_page.dart`: Stops expecting native pose events to contain an `InputImage`; dispose now stops segmentation before pose.
- `lib/exercise/exercise_base.dart`: Keeps the person detection call surface source-compatible with an optional ignored image argument.
- `pubspec.yaml` and `pubspec.lock`: Remove `google_mlkit_selfie_segmentation`.

## 2. Channel contract

Method channel:

```text
com.vikavn.app/segmentation
```

Methods:

- `initialize({ pixelConfidenceThreshold, softPixelConfidenceThreshold, minProcessIntervalMs }) -> { success: true }`
- `start() -> { success: true }`
- `stop() -> { success: true }`
- `dispose() -> { success: true }`

The prompt proposed no initialize arguments. I kept the arguments optional on native and supplied them from Flutter so the tuned pixel thresholds remain Flutter-owned instead of being hard-coded as the source of truth in native code.

Event channel:

```text
com.vikavn.app/segmentation_stream
```

Payload:

```text
{
  timestampMs: int,
  imageWidth: int,
  imageHeight: int,
  personRatio: double,
  softPersonRatio: double
}
```

No raw camera bytes, raw masks, or bbox are emitted.

## 3. Android notes

CameraX analysis now requests `ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888`. The analyzer copies the single RGBA plane into a bitmap, rotates it once, and passes that bitmap to:

- MediaPipe pose through `BitmapImageBuilder`.
- ML Kit Selfie Segmentation through `InputImage.fromBitmap`.

The old Android path copied YUV planes into NV21, compressed to JPEG, decoded to bitmap, and emitted the same NV21 bytes over the pose platform channel. That path is gone.

The analyzer shares one rotated RGBA bitmap between MediaPipe pose and ML Kit segmentation. `SharedBitmapFrame` reference-counts that bitmap and recycles it only after both async native engines have completed, or immediately if a consumer is throttled/skipped. `PoseLandmarkerHelper` also releases pending frame ownership when pending frames are trimmed or the landmarker is cleared.

`rg` verification after the port found no `frameBytes`, `inputImageFromChannelData`, `maskData`, or `google_mlkit_selfie_segmentation` references in app source or lockfiles.

Android compile was not runnable in this workspace because Flutter reported:

```text
[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.
```

## 4. iOS notes

iOS uses the existing pose-owned `AVCaptureVideoDataOutput` stream. `PoseLandmarkerService.captureOutput` forwards the same `CMSampleBuffer` to `SegmentationService` when pose detection is active and segmentation has been started.

`SegmentationService` uses:

- `SelfieSegmenterOptions.segmenterMode = .stream`
- `shouldEnableRawSizeMask = true`
- `VisionImage(buffer:)`

The service computes aggregate ratios from the returned mask and immediately drops the mask. It does not create a texture and does not emit any frame bytes.

Crash fix after device testing: ML Kit segmentation processes `VisionImage(buffer:)` asynchronously, while the capture callback owns the original `CMSampleBuffer` lifetime. Retaining was not defensive enough because pose and segmentation could still touch the same `CVPixelBuffer` concurrently. `SegmentationService` now copies the camera frame into an independent `CMSampleBuffer`, wraps that copied input in `RetainedSampleBuffer`, and releases it after ML Kit completes. This is intended to fix:

```text
CVPixelBufferUnlockBaseAddress failed: -6660
```

The Flutter texture preview slot now stores an explicitly retained `Unmanaged<CVPixelBuffer>` and releases replaced or discarded buffers, so preview rendering does not rely on capture-callback pixel buffer lifetime either.

The iOS simulator build compiled the project and native Swift, then failed in Flutter's backend packaging phase:

```text
Project ... built and packaged successfully.
Unhandled exception:
Null check operator used on a null value
#0 Context._embedNativeAssets (.../xcode_backend.dart:345:68)
```

So Swift compilation got past the app code, but the full Flutter simulator build did not complete.

## 5. PersonDetector behavior

The Flutter-side behavior that remains unchanged:

- EMA smoothing alpha: `0.28`
- Presence blend: `smoothedPersonRatio * 0.75 + softRatio * 0.25`
- Entry threshold: `0.5`
- Exit threshold: `0.30`
- Strict pixel threshold: `0.92`
- Soft pixel threshold: `0.55`

Native code only counts strict and soft mask pixels and sends ratios. The stateful detection result stays in Dart.

Native segmentation is throttled by `PersonDetectorConfig.MIN_PROCESS_INTERVAL` at 140 ms. The active page still calls `runPersonDetection` on its existing timer, but that call now returns the cached native state; native frame processing is controlled by the segmentation service.

## 6. iOS activation mystery

The current activation path does not require segmentation to be true when pose landmarks exist. `ExerciseBase._syncPresenceState` computes:

```text
presentNow = hasPose || segmentationPresent
```

On iOS after the pose rewrite, native pose events did not include `frameBytes`, so `PoseLandmarkerAdapter.inputImageFromChannelData` returned null and Flutter selfie segmentation did not run from native iOS pose events. Nam's iPhone 14 validation still worked because pose landmarks alone can satisfy the person-present gate.

This means iOS activation was effectively pose-presence driven, not segmentation-driven, before this 2a port. I did not change that orchestration because hybrid trigger/validator behavior is explicitly 2b scope.

## 7. Dispose lifecycle

The active exercise page now disposes native segmentation through `widget.exercise.disposeDetectors()` before stopping and disposing the pose channel. That ordering matters because pose owns the camera frame stream and segmentation consumes frames from pose.

Native dispose behavior:

- `PersonDetector.close()` cancels the segmentation event subscription, calls native `stop`, then native `dispose`.
- Android `SelfieSegmentationHelper.dispose()` stops emission, closes the ML Kit segmenter, and resets throttling state.
- iOS `SegmentationService.dispose()` stops emission, clears processing state, and releases the segmenter.
- Pose camera teardown happens after the Dart detector disposal path is started.

## 8. Verification

Commands run:

```text
flutter pub get
pod install
flutter analyze
flutter build apk --debug
flutter build ios --debug --simulator --no-codesign
rg -n "google_mlkit_selfie_segmentation|SelfieSegmenter\\(|frameBytes|inputImageFromChannelData|maskData|maskWidth" ...
```

Results:

- `flutter pub get`: passed.
- `pod install`: passed after sandbox escalation for CocoaPods cache writes.
- `flutter analyze`: completed with 5 pre-existing unrelated warnings/infos in `main_shell.dart`, `auth_service.dart`, and `squat_voice_coach.dart`.
- `flutter build apk --debug`: blocked by missing Android SDK / `ANDROID_HOME`.
- `flutter build ios --debug --simulator --no-codesign`: native project compiled, then failed in Flutter backend native-assets embedding with a null-check exception.
- Source/lockfile search: no app references to the removed Flutter selfie segmentation plugin or pose `frameBytes` remain.

Not verified on device:

- Android pre/post activation timing.
- Android frame payload byte-size delta.
- Android presence-score curve overlap.
- iOS physical-device activation sanity.
- Chair hallucination test.

## 9. 2b assumptions

2b can assume segmentation is now a native sidecar fed by the pose-owned camera stream on both platforms, with one aggregate event channel and no frame bytes crossing Flutter.

2b should still add bbox, state-aware throttling, and hybrid trigger orchestration explicitly. This PR does not add those fields or gates.
