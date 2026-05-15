# iOS Native Pose Plugin Rewrite Report

## 1. Files changed

Rewrite files:

- `ios/Runner/AppDelegate.swift`: Replaced the legacy `com.vika.pose/*` channel registration with the Dart/Android channel names, constructs `PoseLandmarkerService` with a Flutter texture registry, and exposes the Dart-expected method surface.
- `ios/Runner/PoseLandmarkerService.swift`: Reworked the service into a native camera + Flutter texture + MediaPipe live-stream pose pipeline, with Android-style event payload fields for Dart overlay parsing.
- `ios/Runner.xcodeproj/project.pbxproj`: Added `pose_landmarker_lite.task` to the Runner target resources so `Bundle.main.path(forResource:ofType:)` can resolve it on device.
- `lib/services/ios_pose_service.dart`: Deleted the unused legacy Dart wrapper for `com.vika.pose/methods` and `com.vika.pose/stream`.

Report-only file:

- `docs/ios_native_pose_rewrite_report.md`: This self-review report.

## 2. Channel naming

iOS now registers:

- Method channel: `com.vikavn.app/pose_landmarker`
- Event channel: `com.vikavn.app/pose_landmarker_stream`

`lib/pose/pose_landmarker_channel.dart` subscribes to exactly the same names:

- `MethodChannel('com.vikavn.app/pose_landmarker')`
- `EventChannel('com.vikavn.app/pose_landmarker_stream')`

This fixes the previous mismatch where iOS registered `com.vika.pose/methods` and `com.vika.pose/stream`, while active Dart code listened on the Android-aligned `com.vikavn.app/*` names.

## 3. Method contract

The iOS method channel now implements the same surface that `PoseLandmarkerChannel` calls from Dart.

### `initialize`

Arguments:

- `useFrontCamera: bool`, read from the method-call argument map. Defaults to `false` if missing.

Behavior:

- Initializes MediaPipe Pose Landmarker if needed.
- Uses GPU delegate first, then falls back to CPU if GPU initialization throws.
- Sets the requested camera position.
- Registers a Flutter texture if one does not already exist.
- Configures and starts `AVCaptureSession`.

Return:

- On success, returns the Flutter texture id as an integer (`Int64` native, Dart `int`).

Error behavior:

- On failure, completes the method call with `FlutterError(code: "pose_landmarker_init", message: error.localizedDescription, details: nil)`.

Matches Dart:

- Yes. Dart expects `initialize({required bool useFrontCamera})` to return a non-null `int` texture id.

### `dispose`

Arguments:

- None.

Behavior:

- Disables detection.
- Stops the capture session if running.
- Clears the sample-buffer delegate.
- Removes capture inputs and outputs.
- Clears `poseLandmarker`, pending frame metadata, last submitted timestamp, and latest texture pixel buffer.
- Unregisters the Flutter texture on the main queue.
- Clears the event sink.

Return:

- `nil` / Dart `void`.

Error behavior:

- No explicit error path.

Matches Dart:

- Yes. Dart calls `dispose()` and expects `Future<void>`.

### `switchCamera`

Arguments:

- None.

Behavior:

- Toggles between front and back camera.
- Reconfigures the capture session for the new camera.
- Restarts capture if needed.
- Reverts the stored camera position if reconfiguration fails.

Return:

- `nil` / Dart `void` on success.

Error behavior:

- On failure, returns `FlutterError(code: "pose_landmarker_switch_camera", message: error.localizedDescription, details: nil)`.

Matches Dart:

- Yes. Dart calls `switchCamera()` and expects `Future<void>`.

### `startDetection`

Arguments:

- None.

Behavior:

- Schedules `detectionEnabled = true` on the capture/session queue.

Return:

- `nil` / Dart `void`.

Error behavior:

- No explicit error path.

Matches Dart:

- Yes. Dart calls `startDetection()` and expects `Future<void>`.

### `stopDetection`

Arguments:

- None.

Behavior:

- Schedules `detectionEnabled = false` on the capture/session queue.
- Camera preview can keep running while pose inference is skipped.

Return:

- `nil` / Dart `void`.

Error behavior:

- No explicit error path.

Matches Dart:

- Yes. Dart calls `stopDetection()` and expects `Future<void>`.

### Unknown methods

Behavior:

- Returns `FlutterMethodNotImplemented`.

## 4. Event payload schema

iOS now emits one event map per MediaPipe live-stream result, after matching the result timestamp back to stored frame metadata.

Exact iOS payload:

```text
{
  "landmarks": List<Map<String, Any>>,
  "worldLandmarks": List<Map<String, Any>>,
  "imageWidth": Int,
  "imageHeight": Int,
  "frameWidth": Int,
  "frameHeight": Int,
  "rotationDegrees": Int,
  "isFrontCamera": Bool,
  "timestampMs": Int
}
```

Each item in `landmarks`:

```text
{
  "type": Int,
  "x": Float,
  "y": Float,
  "z": Float,
  "likelihood": Float
}
```

Field details:

- `landmarks`: Pose landmarks for the first detected pose. Empty list means no pose. Landmark `x` and `y` are normalized MediaPipe image coordinates. `z` is MediaPipe normalized depth, not pixels.
- `worldLandmarks`: World landmarks for the first detected pose. Empty list if unavailable. MediaPipe world landmark coordinates are in the model's world coordinate space, generally meters with origin around the hips.
- `type`: Landmark index. This follows the same index-based convention as Android, and Dart maps it through `PoseLandmarkType.values[type]`.
- `x`: Normalized x coordinate for `landmarks`; world x coordinate for `worldLandmarks`.
- `y`: Normalized y coordinate for `landmarks`; world y coordinate for `worldLandmarks`.
- `z`: MediaPipe z coordinate.
- `likelihood`: `visibility` if present, otherwise `presence`, otherwise `0.0`.
- `imageWidth`: Width in pixels of the oriented image space used by Dart overlay math. Currently equal to the captured pixel buffer width.
- `imageHeight`: Height in pixels of the oriented image space used by Dart overlay math. Currently equal to the captured pixel buffer height.
- `frameWidth`: Width in pixels of the native `CVPixelBuffer`.
- `frameHeight`: Height in pixels of the native `CVPixelBuffer`.
- `rotationDegrees`: Degrees of rotation for Dart metadata. Currently always `0`.
- `isFrontCamera`: `true` when the current AVCapture device position is front.
- `timestampMs`: Presentation timestamp converted to milliseconds. This is stream-relative camera/media time, not wall-clock epoch time.

Android comparison:

- Matching fields: `landmarks`, `worldLandmarks`, `imageWidth`, `imageHeight`, `frameWidth`, `frameHeight`, `rotationDegrees`, `isFrontCamera`, and `timestampMs` use the same names and same general types as Android.
- Important difference: Android also emits `frameBytes` as an NV21 `ByteArray`. iOS intentionally does not emit `frameBytes`. Dart treats this as optional for pose/overlay parsing, but the full iOS payload is not byte-for-byte identical to Android.
- Consequence: Native iOS pose and overlay can work without Dart branching, but Dart-side person detection from native pose events will not receive an `InputImage` from iOS events. This was deliberate to avoid reintroducing camera-frame traffic over the platform channel and because the Dart adapter currently assumes `InputImageFormat.nv21`, which is Android-specific.

## 5. Texture preview architecture

`PoseLandmarkerService` now conforms to `FlutterTexture`.

Creation and registration:

- `AppDelegate` obtains a texture registry from `registrar(forPlugin: "PoseLandmarkerService").textures()`.
- `PoseLandmarkerService` stores that registry.
- `initialize` calls `ensureTexture()`.
- `ensureTexture()` registers `self` with `textureRegistry.register(self)` on the main queue and stores the returned texture id.
- The texture id is returned to Dart, where `ActiveExercisePage` can render it with `Texture(textureId: _textureId!)`.

Frame delivery:

- AVCapture delivers `CMSampleBuffer` frames to `captureOutput`.
- The service extracts the `CVPixelBuffer` with `CMSampleBufferGetImageBuffer`.
- The latest pixel buffer is stored behind `pixelBufferQueue`.
- The service calls `textureRegistry.textureFrameAvailable(textureId)` on the main queue.
- Flutter later calls `copyPixelBuffer()`.

CVPixelBuffer ownership model:

- `copyPixelBuffer()` synchronously takes the latest stored buffer, sets `latestPixelBuffer = nil`, and returns `Unmanaged.passRetained(pixelBuffer)`.
- This mirrors Flutter camera plugin behavior: each delivered buffer is retained for Flutter, and Flutter is expected to release it after consuming it.
- Setting `latestPixelBuffer = nil` avoids repeatedly returning the same retained buffer.

Disposal:

- `dispose()` stops the session, removes inputs and outputs, clears the sample-buffer delegate, clears the latest pixel buffer, and unregisters the texture on the main queue.

Memory management uncertainty:

- The service stores the `CVPixelBuffer` obtained from the sample buffer without an explicit `CVPixelBufferRetain` at storage time. This matches Flutter camera plugin style, but it is still a place I would want validated on real iOS hardware under load.

## 6. Threading model

Queues and threads:

- `sessionQueue` (`com.vikavn.app.pose.session`): Runs capture session setup/teardown, camera switching, detection enable/disable, AVCapture sample-buffer callbacks, and `detectAsync` submission.
- `pixelBufferQueue` (`com.vikavn.app.pose.texture`): Guards `latestPixelBuffer`.
- `pendingFrameQueue` (`com.vikavn.app.pose.pending_frames`): Guards `pendingFrames`, which maps `timestampMs` to frame metadata.
- Main queue: Registers and unregisters the Flutter texture, calls `textureFrameAvailable`, emits events/errors to Flutter, and completes async method-channel results from AppDelegate.
- MediaPipe internal queue/thread: `detectAsync` is submitted from `sessionQueue`, but the live-stream delegate callback can arrive on a MediaPipe-managed thread. The code does not assume it is main or `sessionQueue`.

Cross-thread state:

- `latestPixelBuffer` is protected by `pixelBufferQueue`.
- `pendingFrames` is protected by `pendingFrameQueue`.
- `eventSink` is set from Flutter stream callbacks and used/cleared on the main queue for emitted results and dispose.
- `detectionEnabled`, `poseLandmarker`, `currentCameraPosition`, and `lastSubmittedTimestampMs` are intended to be owned by `sessionQueue`.

Residual threading concerns:

- `textureId` is read from capture code and mutated from main-queue registration/unregistration. The intended ordering makes this low risk, but it is not protected by a dedicated lock.
- Static diagnostic counters (`didFinishDiagnosticLogging`, `diagnosticFrameIndex`) are mutated from the MediaPipe callback without synchronization.
- A late MediaPipe callback can arrive after `dispose()`. The pending-frame lookup should usually drop it, and event emission goes through the main queue/event sink, but this still deserves device testing.

## 7. Build/test status

Commands run:

- `git diff --check -- ios/Runner.xcodeproj/project.pbxproj ios/Runner/AppDelegate.swift ios/Runner/PoseLandmarkerService.swift lib/services/ios_pose_service.dart`
  - Passed. Only line-ending warnings from Git on Windows.
- `flutter analyze --no-pub`
  - Completed with 5 pre-existing unrelated issues:
    - unused `iconColor` and `labelColor` in `lib/screens/main_shell.dart`
    - `avoid_print` in `lib/services/auth_service.dart`
    - missing `@override` annotations in `lib/services/squat_voice_coach.dart`
- `flutter build apk --debug --no-pub`
  - Passed. This validates the shared Dart path and confirms Android still builds after the Dart dead-code deletion and project changes.

Commands not run / not testable here:

- `pod install`: Not run. `pod` is not installed on this Windows host.
- `xcodebuild`: Not run. `xcodebuild` is not available on this Windows host.
- Swift compile: Not run. `swift` is not installed here.
- Real iOS app launch: Not run from this environment.
- Real overlay alignment/device camera validation: Not testable from this environment.

I also ran `flutter analyze` once without `--no-pub`; it updated transient lockfile entries, and I reverted that lockfile churn before finishing the code diff.

## 8. What I did not do or punted on

- Did not change Android source.
- Did not change `lib/pose/pose_landmarker_channel.dart`.
- Did not remove `google_mlkit_pose_detection`; it is still used by exercise logic, fallback camera paths, adapters, and overlay types.
- Did not emit iOS `frameBytes`. This was intentional to avoid platform-channel frame traffic and because the current Dart adapter constructs NV21 `InputImage` metadata, which is wrong for iOS BGRA frames.
- Did not wire native iOS pose events into native segmentation or person-confirmation gating. Existing Dart code can still process pose/overlay without `frameBytes`; person detection from native iOS pose frames remains deferred.
- Did not implement trigger orchestration or any segmentation scheduling.
- Did not prove iOS compile or runtime behavior on macOS/device.
- Did not tune orientation/mirroring beyond a portrait-first implementation with `AVCaptureConnection.videoOrientation = .portrait`, front-camera mirroring enabled, and `MPImage(... orientation: .up)`.

## 9. Risk surface

### Memory leaks

- Texture lifecycle is explicit: register on initialize, unregister on dispose. Risk remains if `initialize` is called repeatedly without `dispose`, although `ensureTexture()` reuses the existing texture id.
- `copyPixelBuffer()` uses `Unmanaged.passRetained`, which is the correct Flutter texture pattern, but this must be validated by actual rendering under load.
- `latestPixelBuffer` is cleared when copied and on dispose.
- `poseLandmarker` is set to `nil` on dispose. I did not call an explicit close method; if the Swift MediaPipe API exposes or requires one, this is worth fixing.

### Race conditions

- `pendingFrames` and `latestPixelBuffer` have dedicated queues.
- `textureId` and static diagnostic counters are not fully synchronized.
- Dispose while inference is in flight can produce late callbacks. The implementation should mostly drop them because pending frame metadata is cleared, but that path needs iOS runtime validation.
- `AppDelegate` stores `poseService` as optional. It is assigned during app launch, so nil is not expected. If it were nil, some method calls could return without completing the Flutter result.

### Payload schema drift

- Full parity with Android is not exact because iOS omits `frameBytes`.
- iOS `rotationDegrees` is always `0`; Android emits CameraX rotation degrees.
- iOS `imageWidth`/`imageHeight` currently equal the `CVPixelBuffer` dimensions. Android uses dimensions after bitmap rotation. This should be okay if iOS capture is truly portrait-oriented, but overlay alignment is a likely bug area.
- iOS `likelihood` uses visibility, then presence. Android uses visibility only. Usually harmless, but not identical.
- iOS `minTrackingConfidence` is `0.7`; Android currently uses `0.5`. That can create behavioral differences.

### Resource leaks

- AVCaptureSession inputs/outputs are removed on dispose and reconfiguration.
- Sample-buffer delegate is cleared on dispose.
- No observers were registered by this service, so there is no observer cleanup.
- Camera switching removes and recreates output/input. The old `AVCaptureVideoDataOutput` delegate should be released with the removed output, but this deserves a switch-camera stress test.

### Other concerns

- Swift type/API compatibility was inferred from current project imports and MediaPipe Swift naming, but I could not compile Swift here.
- The Xcode project now includes the task model resource, but the final proof is an iOS build and confirming `Bundle.main.path(forResource: "pose_landmarker_lite", ofType: "task")` succeeds.
- The overlay may be horizontally double-mirrored for front camera depending on how AVCapture mirroring affects the texture versus how `PoseOverlayPainter` mirrors front-camera landmarks. This is a high-priority visual test.

## 10. Senior-review focus

1. iOS compile and runtime lifecycle: Build on macOS, launch on a physical iPhone, confirm `initialize` returns a texture id, `[VIKA-DIAG]` logs fire, and dispose/switch camera do not leak or crash.
2. Coordinate space and mirroring: Verify front/back camera overlay alignment, especially whether `imageWidth`/`imageHeight`, `rotationDegrees = 0`, `MPImage.orientation = .up`, and front-camera mirroring produce the same skeleton position as the preview.
3. Payload parity decision: Decide whether omitting `frameBytes` on iOS is acceptable for this phase, or whether Dart needs a platform-aware native person/segmentation path before removing the ML Kit fallback behavior more aggressively.
