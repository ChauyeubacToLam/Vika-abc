import 'standing_kte_metric_base.dart';
import '../standing_knee_to_elbow.dart';

class KneeValgusMetric extends StandingKteMetricBase {
  static const double VALGUS_RATIO_LIMIT = 0.25; // 15% of hip width

  @override
  void update(StandingKteRepContext ctx) {
    if (ctx.state == KteState.approaching || ctx.state == KteState.touch) {
      if (ctx.hipWidth <= 0) return;

      // Standing knee should be vertically aligned with standing ankle.
      // If knee collapses inward (towards the midline), its X coordinate will deviate from ankle X.

      // We must determine "inward".
      // Left leg (user's left) collapsing inward means moving to the right.
      // Right leg collapsing inward means moving to the left.
      // We can just use absolute distance between ankle and knee X as a proxy for collapse,
      // but to be precise about "inward", let's check direction.

      // Let's assume standard unmirrored coordinates:
      // X increases to the right of the image.
      // If standingLeg is Left (user's left, which is usually right side of screen if mirrored, or left side if not).
      // We can just use absolute distance to be safe and simple, since valgus is the most common deviation.
      // But let's check distance between standing knee and standing ankle.
      double deviationX = (ctx.standingKnee.x - ctx.standingAnkle.x).abs();
      double deviationRatio = deviationX / ctx.hipWidth;

      debugData['kneeValgusRatio'] = deviationRatio;

      if (deviationRatio > VALGUS_RATIO_LIMIT) {
        // To be strictly correct about "inward", we could check if the knee is closer to the midline than the ankle.
        // The midline can be approximated by (standingHip.x + liftingHip.x)/2
        double midlineX = (ctx.standingHip.x + ctx.liftingHip.x) / 2;
        bool isInward = (ctx.standingKnee.x - midlineX).abs() <
            (ctx.standingAnkle.x - midlineX).abs();

        if (isInward) {
          addFault(
            FaultRecord(
              type: 'standing_knee_valgus',
              message:
                  'Gồng chặt chân trụ! Mở đầu gối ra, đừng để sụp vào trong!',
              affectsForm: true, // Critical error
              phase: ctx.state.name,
              priority: 1,
              voiceMessage: 'Mở gối chân trụ ra!',
            ),
          );
        }
      }
    }
  }
}
