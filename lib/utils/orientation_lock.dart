import 'package:flutter/services.dart';
import 'package:vika/pose/vika_image_orientation.dart';

/// The Flutter window stays locked to portraitUp on every screen — including
/// the active exercise page. Rotation for landscape-supporting exercises is
/// applied by the page itself via `RotatedBox`, driven by the device sensor.
///
/// Why we don't use `SystemChrome.setPreferredOrientations` to allow landscape
/// rotation:
/// - iOS skips the rotation transition when the user flips 180° between
///   landscapeLeft and landscapeRight (it considers the new orientation
///   already-allowed and does nothing), and Flutter's
///   `setPreferredOrientations` hint does not force a re-evaluation.
/// - The `native_device_orientation` package reports orientation in
///   `UIDeviceOrientation` terms (e.g. landscapeLeft = home button on RIGHT),
///   while Flutter's `DeviceOrientation` enum maps to
///   `UIInterfaceOrientation` on iOS (landscapeLeft = home button on LEFT) —
///   these conventions are inverted, so any code that *forces* the OS to a
///   specific landscape via Flutter has to swap the mapping per-platform and
///   stays brittle.
///
/// By locking the OS to portraitUp and applying rotation manually we get one
/// source of truth (the sensor), one rotation path (`RotatedBox` driven by
/// `VikaImageOrientation.uiQuarterTurns`), and identical behavior on iOS and
/// Android.
class OrientationLock {
  static Future<void> portraitOnly() async {
    await SystemChrome.setPreferredOrientations(
      <DeviceOrientation>[DeviceOrientation.portraitUp],
    );
  }

  /// Same as [portraitOnly] — kept for call-site compatibility. Exercises that
  /// support landscape rotate their own UI via `RotatedBox`; the OS stays
  /// portrait.
  static Future<void> forSupported(
    Set<VikaImageOrientation> supported,
  ) async {
    await portraitOnly();
  }

  /// All four orientations on the device. Only used in narrow cases (e.g. a
  /// fullscreen viewer that wants the OS itself to rotate); the active
  /// exercise page does NOT use this.
  static Future<void> all() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }
}
