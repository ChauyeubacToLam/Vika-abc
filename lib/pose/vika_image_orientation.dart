import 'dart:ui' show Size;

import 'package:native_device_orientation/native_device_orientation.dart';

enum VikaImageOrientation {
  portrait,
  landscapeLeft,
  landscapeRight,
  portraitUpsideDown;

  static VikaImageOrientation fromNative(
    NativeDeviceOrientation orientation,
  ) {
    switch (orientation) {
      case NativeDeviceOrientation.portraitUp:
        return VikaImageOrientation.portrait;
      case NativeDeviceOrientation.landscapeLeft:
        return VikaImageOrientation.landscapeLeft;
      case NativeDeviceOrientation.landscapeRight:
        return VikaImageOrientation.landscapeRight;
      case NativeDeviceOrientation.portraitDown:
        return VikaImageOrientation.portraitUpsideDown;
      case NativeDeviceOrientation.unknown:
        return VikaImageOrientation.portrait;
    }
  }
}

extension VikaImageOrientationCodes on VikaImageOrientation {
  String get channelCode {
    switch (this) {
      case VikaImageOrientation.portrait:
        return 'portrait';
      case VikaImageOrientation.landscapeLeft:
        return 'landscapeLeft';
      case VikaImageOrientation.landscapeRight:
        return 'landscapeRight';
      case VikaImageOrientation.portraitUpsideDown:
        return 'portraitUpsideDown';
    }
  }

  int get previewQuarterTurns {
    switch (this) {
      case VikaImageOrientation.portrait:
        return 0;
      case VikaImageOrientation.landscapeLeft:
        return 3;
      case VikaImageOrientation.landscapeRight:
        return 1;
      case VikaImageOrientation.portraitUpsideDown:
        return 2;
    }
  }

  /// Quarter-turns to apply with `RotatedBox` to rotate the *entire UI* into
  /// alignment with the user's view, when the OS is locked to portraitUp and
  /// we're driving rotation manually from the sensor.
  ///
  /// Reasoning per orientation (the OS keeps the screen pixel grid pinned to
  /// device-portrait; we rotate the painted UI to compensate):
  /// - **landscapeLeft** (sensor): bottom of device on user's RIGHT = device
  ///   rotated 90° CCW from portrait. The user's top corresponds to the
  ///   device's natural RIGHT edge, so we rotate the UI 90° CW
  ///   (`quarterTurns:1`) to put child y=0 at screen x=max_x.
  /// - **landscapeRight**: bottom of device on user's LEFT = device 90° CW.
  ///   User's top is the device's LEFT edge → 90° CCW rotation
  ///   (`quarterTurns:3`).
  /// - **portraitUpsideDown**: 180° rotation (`quarterTurns:2`).
  /// - **portrait**: no rotation (`quarterTurns:0`).
  int get uiQuarterTurns {
    switch (this) {
      case VikaImageOrientation.portrait:
        return 0;
      case VikaImageOrientation.landscapeLeft:
        return 1;
      case VikaImageOrientation.landscapeRight:
        return 3;
      case VikaImageOrientation.portraitUpsideDown:
        return 2;
    }
  }

  /// Degrees corresponding to `Surface.ROTATION_X` for this orientation.
  ///
  /// Android CameraX follows Flutter's camera plugin convention:
  /// `DeviceOrientation.landscapeLeft` maps to `Surface.ROTATION_90`, and
  /// `DeviceOrientation.landscapeRight` maps to `Surface.ROTATION_270`.
  /// The native pose plugin uses the same table for Preview/ImageAnalysis, so
  /// the ML Kit fallback must use the same degrees when building InputImages.
  int get androidSurfaceRotationDegrees {
    switch (this) {
      case VikaImageOrientation.portrait:
        return 0;
      case VikaImageOrientation.landscapeLeft:
        return 90;
      case VikaImageOrientation.landscapeRight:
        return 270;
      case VikaImageOrientation.portraitUpsideDown:
        return 180;
    }
  }

  bool get isLandscape {
    switch (this) {
      case VikaImageOrientation.landscapeLeft:
      case VikaImageOrientation.landscapeRight:
        return true;
      case VikaImageOrientation.portrait:
      case VikaImageOrientation.portraitUpsideDown:
        return false;
    }
  }

  VikaImageOrientation resolveForSurface(
    Size? surfaceSize, {
    required VikaImageOrientation fallbackLandscape,
  }) {
    if (surfaceSize == null ||
        surfaceSize.width <= 0 ||
        surfaceSize.height <= 0 ||
        surfaceSize.width == surfaceSize.height) {
      return this;
    }

    if (surfaceSize.width > surfaceSize.height) {
      return isLandscape ? this : fallbackLandscape;
    }

    return this == VikaImageOrientation.portraitUpsideDown
        ? VikaImageOrientation.portraitUpsideDown
        : VikaImageOrientation.portrait;
  }
}

extension NativeDeviceOrientationVikaConversion on NativeDeviceOrientation {
  VikaImageOrientation toVikaImageOrientation() {
    return VikaImageOrientation.fromNative(this);
  }
}
