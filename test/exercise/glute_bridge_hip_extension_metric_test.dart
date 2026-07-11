import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/glute bridge/glute_bridge.dart';
import 'package:vika/exercise/glute bridge/metrics/glute_bridge_hip_extension.dart';
import 'package:vika/exercise/glute bridge/metrics/glute_bridge_knee_angle.dart';
import 'package:vika/exercise/glute bridge/metrics/glute_bridge_speed_control.dart';

void main() {
  group('hip extension', () {
    test('pins the tightened thresholds', () {
      expect(HipExtensionConfig.GOOD_MIN_ANGLE, 152.0);
      expect(HipExtensionConfig.WARNING_MIN_ANGLE, 140.0);
      expect(HipExtensionConfig.HYPEREXT_THRESHOLD, 0.045);
    });

    test('is clean at the tightened good threshold', () {
      final metric = HipExtensionMetric();

      metric.checkRepCompletion(HipExtensionConfig.GOOD_MIN_ANGLE, null);

      expect(metric.faults, isEmpty);
    });

    test('emits a soft fault below the tightened good threshold', () {
      final metric = HipExtensionMetric();

      metric.checkRepCompletion(
        HipExtensionConfig.GOOD_MIN_ANGLE - 0.1,
        null,
      );

      expect(metric.faults, hasLength(1));
      expect(metric.faults.single.type, 'hip_extension');
      expect(metric.faults.single.affectsForm, isFalse);
    });

    test('emits a hard fault below the tightened warning threshold', () {
      final metric = HipExtensionMetric();

      metric.checkRepCompletion(
        HipExtensionConfig.WARNING_MIN_ANGLE - 0.1,
        null,
      );

      expect(metric.faults, hasLength(1));
      expect(metric.faults.single.type, 'hip_extension');
      expect(metric.faults.single.affectsForm, isTrue);
    });
  });

  group('knee angle', () {
    test('pins the tightened bands', () {
      expect(KneeAngleConfig.GOOD_MIN, 85.0);
      expect(KneeAngleConfig.GOOD_MAX, 135.0);
      expect(KneeAngleConfig.ACCEPTABLE_UPPER_MAX, 145.0);
      expect(KneeAngleConfig.WARNING_MIN, 55.0);
    });

    test('flags too-close feet as a soft fault before the hard cutoff', () {
      final metric = KneeAngleMetric();

      metric.checkRepCompletion(KneeAngleConfig.GOOD_MIN - 0.1);

      expect(metric.faults, hasLength(1));
      expect(metric.faults.single.type, 'knee_angle');
      expect(metric.faults.single.affectsForm, isFalse);
    });

    test('flags very-close feet as a hard fault', () {
      final metric = KneeAngleMetric();

      metric.checkRepCompletion(KneeAngleConfig.WARNING_MIN - 0.1);

      expect(metric.faults, hasLength(1));
      expect(metric.faults.single.type, 'knee_angle');
      expect(metric.faults.single.affectsForm, isTrue);
    });

    test('flags too-far feet above the acceptable upper band', () {
      final metric = KneeAngleMetric();

      metric.checkRepCompletion(KneeAngleConfig.ACCEPTABLE_UPPER_MAX + 0.1);

      expect(metric.faults, hasLength(1));
      expect(metric.faults.single.type, 'knee_angle');
      expect(metric.faults.single.affectsForm, isFalse);
    });
  });

  group('speed control', () {
    test('pins the tightened descent-control thresholds', () {
      expect(SpeedControlConfig.MIN_ECCENTRIC_RATIO, 1.3);
      expect(SpeedControlConfig.RAPID_VELOCITY_WARNING, 0.08);
      expect(SpeedControlConfig.RAPID_VELOCITY_ERROR, 0.15);
    });

    test('emits a soft pacing fault below the tightened eccentric ratio', () {
      final metric = SpeedControlMetric();

      metric.onStateTransition(
        GluteBridgeState.bottom,
        GluteBridgeState.ascending,
        0,
      );
      metric.onStateTransition(
        GluteBridgeState.ascending,
        GluteBridgeState.topHold,
        1000,
      );
      metric.onStateTransition(
        GluteBridgeState.topHold,
        GluteBridgeState.descending,
        1000,
      );
      metric.checkRepCompletion(2200);

      expect(metric.faults, hasLength(1));
      expect(metric.faults.single.type, 'speed_control');
      expect(metric.faults.single.affectsForm, isFalse);
    });
  });
}
