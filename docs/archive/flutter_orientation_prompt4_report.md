# Flutter Orientation Prompt 4 Report

## Executive Summary

Implemented Prompt 4 (Revised); painter mirror gate intentionally not added per Option A decision.

Changed files:

- `lib/screens/exercise/active_exercise_page.dart`
- `lib/pose/vika_image_orientation.dart`
- `lib/utils/orientation_lock.dart`
- `lib/main.dart`
- `lib/screens/main_shell.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/plan_screen.dart`
- `lib/screens/profile_screen.dart`
- `lib/screens/onboarding/v5/v5_onboarding_navigator.dart`
- `lib/screens/auth/magic_link_sent_screen.dart`
- `lib/screens/exercise/exercise_experience_screen.dart`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

## What Changed

`ActiveExercisePage` now listens to `native_device_orientation` sensor updates when `ExerciseBase.kLandscapeRotationEnabled` is enabled. Supported orientations are sent to both native pose and native segmentation with the current camera direction. Unsupported orientations are not sent to native.

The active exercise loop now has an orientation activation gate before exercise inference. If the device drifts into an unsupported orientation, the page writes `wrong_orientation_landscape` or `wrong_orientation_portrait` into `feedback['System']`, blocks exercise processing, and pauses active sets. When the device returns to a supported orientation, the feedback is cleared and the orientation pause resumes automatically unless the user also manually paused.

The native `Texture` preview is wrapped in `RotatedBox` only when the landscape flag is enabled. The ML Kit fallback `CameraPreview` is left untouched because Flutter's camera preview should track controller rotation automatically and I could not verify real-device distortion here.

Vietnamese banner copy was added for the two new orientation system messages.

Manifest locks were loosened:

- iOS now declares portrait plus landscape left/right.
- Android no longer hard-locks `MainActivity` to portrait.

Runtime orientation locks preserve production behavior with the flag off: app entry, main shell and tab screens, onboarding, auth callback screen, and the exercise experience shell request portrait; `ActiveExercisePage` requests all orientations only through the flag-gated `OrientationLock.all()`.

## Logic

Native pose and segmentation work is already wired from Prompts 2 and 3. This change makes Flutter the source of session orientation truth: it observes device orientation, validates it against `exercise.supportedOrientations`, and only then updates native.

When an orientation is unsupported, native is intentionally left on its last supported orientation because exercise activation is blocked anyway. This avoids sending a landscape frame contract to portrait-only exercises or vice versa.

Front-camera painter mirroring was not changed. Under the Prompt 3 Option A decision, both platforms run pose on un-mirrored input, so visual mirroring remains the presentation-layer responsibility in the existing painter path.

## Pushback

The prompt's ML Kit fallback note asked whether device orientation alone is sufficient. It is not for Android. Google's ML Kit Android guidance calculates rotation from both display/device rotation and camera sensor orientation, with different formulas for front and back cameras.

What I changed instead: `_imageRotationFromVikaOrientation` combines `VikaImageOrientation.androidSurfaceRotationDegrees` with `camera.sensorOrientation` and lens direction.

Why: sensor orientation is commonly 90 or 270 degrees on phones, so a device-only rotation would regress portrait fallback on many Android cameras.

## Verification

Passed:

- `flutter analyze`
- `plutil -lint ios/Runner/Info.plist`
- `xmllint --noout android/app/src/main/AndroidManifest.xml`
- `flutter build ios --simulator`

Not completed:

- `flutter test` still fails on existing harness issues: missing Flutter binding/native segmentation channel mocks in exercise tests and the existing widget test's uninitialized `_hasCompletedOnboarding` / stale `VIKA` expectation.
- `flutter build apk --debug` could not run because this machine has no Android SDK configured (`ANDROID_HOME` is unset).
- Manual device smoke tests and Android rotation p99 timing were not run in this environment.
