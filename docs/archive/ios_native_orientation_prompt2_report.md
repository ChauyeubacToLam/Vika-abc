# iOS Native Orientation Prompt 2 Report

## Executive Summary

This change wires the orientation controls introduced by the Dart channel layer into the iOS native pose and segmentation pipelines while keeping production behavior unchanged while `ExerciseBase.kLandscapeRotationEnabled` is `false`.

Changed files:

- `ios/Runner/PoseLandmarkerService.swift`
- `ios/Runner/SegmentationService.swift`
- `ios/Runner/AppDelegate.swift`

## What Changed

`PoseLandmarkerService` now keeps per-session image orientation state. `initialize` accepts optional `initialOrientation` and `isFrontCamera` values, and `setOrientation` can update the state later through the pose method channel.

Pose inference now creates frames with:

```swift
MPImage(sampleBuffer: sampleBuffer, orientation: currentOrientation)
```

instead of hard-coding `.up`.

The pose event payload now emits `imageWidth` and `imageHeight` for the gravity-aligned image dimensions. Landscape orientation codes swap the raw frame dimensions before Dart scales normalized landmarks.

`SegmentationService` now mirrors the same orientation method surface and applies the orientation to ML Kit:

```swift
let image = VisionImage(buffer: retainedSampleBuffer.value)
image.orientation = imageOrientation
```

`AppDelegate` now passes `initialOrientation` / `isFrontCamera` during pose initialization and handles `setOrientation` on `com.vikavn.app/pose_landmarker`. The existing segmentation method handler delegates `setOrientation` through `SegmentationService.handle`.

## Logic

Google's current MediaPipe iOS Pose Landmarker guide still uses `MPImage` for camera frames, and the current `MPImage` reference still documents `init(sampleBuffer:orientation:)`. That supports the spec's main design choice: hand orientation to MediaPipe instead of rotating `CMSampleBuffer` data in app code.

ML Kit's current iOS pose docs still publish the canonical device-orientation plus camera-position mapping:

- `portrait`: back `.right`, front `.leftMirrored`
- `landscapeLeft`: back `.up`, front `.downMirrored`
- `landscapeRight`: back `.down`, front `.upMirrored`
- `portraitUpsideDown`: back `.left`, front `.rightMirrored`

That mapping is implemented in `PoseLandmarkerService.imageOrientation(from:isFrontCamera:)` and reused by segmentation.

## Pushback

The spec's ML Kit table is correct for ML Kit `VisionImage`, but applying the mirrored variants directly to MediaPipe Pose would conflict with Google's current Pose Landmarker guide: it says Pose Landmarker does not support `.upMirrored`, `.downMirrored`, `.leftMirrored`, or `.rightMirrored`.

What I changed instead: `PoseLandmarkerService` resolves the canonical table, then strips only the mirror component before passing orientation into `MPImage` for pose. Segmentation keeps the full canonical ML Kit orientation, including mirrored front-camera variants.

Why: this preserves the intended rotation hint for Pose Landmarker while avoiding a documented unsupported input mode. The front-camera mirror still remains represented in the channel payload through `isFrontCamera`.

## Notes

`rotationDegrees` remains `0` on iOS. The existing iOS native pipeline reports MediaPipe-ready, upright landmark space through `imageWidth` / `imageHeight`; Android still reports CameraX rotation metadata because that pipeline physically rotates the shared bitmap before inference.

The `native_device_orientation` package still appears active on pub.dev as of this work: version `2.1.0` was published in late 2025 and the changelog shows recent Android and Swift Package Manager maintenance.

I did not benchmark Android per-frame bitmap rotation in this change. The Android code still rotates a `960x540` RGBA bitmap before pose and segmentation, so the 3-8 ms estimate should be treated as unverified until measured on a mid-tier physical device.
