import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/4.Mountain Climber/metrics/mountain_climber_metric_base.dart';

void main() {
  group('KneePeakRepCounter', () {
    test('counts a fast knee drive with a single tuck frame', () {
      final counter = KneePeakRepCounter(side: KneeSide.left)..calibrate(2.0);

      expect(
        counter.update(
          kneeShoulderDistNorm: 2.0,
          kneeAngle: 170.0,
          nowMs: 0,
        ),
        0,
      );
      expect(
        counter.update(
          kneeShoulderDistNorm: 1.22,
          kneeAngle: 116.0,
          nowMs: 70,
        ),
        0,
      );

      expect(
        counter.update(
          kneeShoulderDistNorm: 1.72,
          kneeAngle: 154.0,
          nowMs: 220,
        ),
        1,
      );
      expect(counter.lastCompletedPeakDist, lessThanOrEqualTo(1.22));
      expect(counter.lastCompletedPeakAngle, 116.0);
    });

    test('uses knee flexion as a fallback when distance is shallow', () {
      final counter = KneePeakRepCounter(side: KneeSide.right)..calibrate(2.0);

      counter.update(
        kneeShoulderDistNorm: 1.95,
        kneeAngle: 170.0,
        nowMs: 0,
      );
      counter.update(
        kneeShoulderDistNorm: 1.55,
        kneeAngle: 125.0,
        nowMs: 80,
      );

      expect(
        counter.update(
          kneeShoulderDistNorm: 1.65,
          kneeAngle: 154.0,
          nowMs: 230,
        ),
        1,
      );
    });

    test('does not count repeated jitter inside one drive', () {
      final counter = KneePeakRepCounter(side: KneeSide.left)..calibrate(2.0);

      counter.update(
        kneeShoulderDistNorm: 1.20,
        kneeAngle: 118.0,
        nowMs: 20,
      );
      expect(
        counter.update(
          kneeShoulderDistNorm: 1.18,
          kneeAngle: 116.0,
          nowMs: 70,
        ),
        0,
      );
      expect(
        counter.update(
          kneeShoulderDistNorm: 1.19,
          kneeAngle: 117.0,
          nowMs: 120,
        ),
        0,
      );
      expect(
        counter.update(
          kneeShoulderDistNorm: 1.72,
          kneeAngle: 153.0,
          nowMs: 230,
        ),
        1,
      );
    });
  });
}
