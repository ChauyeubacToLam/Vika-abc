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
