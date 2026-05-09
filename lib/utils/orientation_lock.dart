import 'package:flutter/services.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/pose/vika_image_orientation.dart';

class OrientationLock {
  static Future<void> portraitOnly() async {
    await SystemChrome.setPreferredOrientations(
      <DeviceOrientation>[DeviceOrientation.portraitUp],
    );
  }

  static Future<void> all() async {
    if (!ExerciseBase.kLandscapeRotationEnabled) {
      await portraitOnly();
      return;
    }
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  /// Apply the preferred-orientation list that matches the exercise's
  /// supported orientations. For landscape-only exercises this forces iOS
  /// to rotate the Flutter surface into landscape — necessary because
  /// `setPreferredOrientations(values)` allows rotation but does not force
  /// it, and on iOS the surface can otherwise stay portrait even after
  /// the user physically rotates the device.
  static Future<void> forSupported(
    Set<VikaImageOrientation> supported,
  ) async {
    if (!ExerciseBase.kLandscapeRotationEnabled) {
      await portraitOnly();
      return;
    }

    final orientations = <DeviceOrientation>[];
    if (supported.contains(VikaImageOrientation.portrait)) {
      orientations.add(DeviceOrientation.portraitUp);
    }
    if (supported.contains(VikaImageOrientation.landscapeLeft)) {
      orientations.add(DeviceOrientation.landscapeLeft);
    }
    if (supported.contains(VikaImageOrientation.landscapeRight)) {
      orientations.add(DeviceOrientation.landscapeRight);
    }
    if (supported.contains(VikaImageOrientation.portraitUpsideDown)) {
      orientations.add(DeviceOrientation.portraitDown);
    }

    await SystemChrome.setPreferredOrientations(
      orientations.isEmpty ? DeviceOrientation.values : orientations,
    );
  }
}
