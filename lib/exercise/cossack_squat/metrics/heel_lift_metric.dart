import 'cossack_metric_base.dart';
import '../cossack_squat.dart';

class CossackHeelLiftMetric extends CossackMetricBase {
  static const double HEEL_LIFT_THRESHOLD = 0.08; // Normalized distance

  @override
  double? get value => debugData['workingHeelDistance'] as double?;

  @override
  ThresholdBand? get threshold =>
      const ThresholdBand(warningAbove: 0.06, faultAbove: HEEL_LIFT_THRESHOLD);

  @override
  void update(CossackRepContext ctx) {
    debugData['workingHeelDistance'] = ctx.workingHeelDistance;
    debugData['workingLeg'] = ctx.workingLeg.name;

    if (ctx.state == CossackState.standing ||
        ctx.workingLeg == WorkingLeg.none) {
      return;
    }

    if (ctx.workingHeelDistance > HEEL_LIFT_THRESHOLD) {
      addFault(
        FaultRecord(
          type: 'heel_lift',
          message:
              'Gót chân trụ phải chạm sàn. Nếu không làm được, hãy squat nông lại!',
          affectsForm: true,
          phase: ctx.state.name,
          priority: 2, // High
          voiceMessage: 'Hạ gót chân xuống!',
        ),
      );
    }
  }
}
