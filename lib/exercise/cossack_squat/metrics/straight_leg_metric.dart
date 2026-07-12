import 'cossack_metric_base.dart';
import '../cossack_squat.dart';

class CossackStraightLegMetric extends CossackMetricBase {
  static const double STRAIGHT_LEG_MIN_ANGLE =
      145.0; // Lenient threshold for straight leg

  @override
  double? get value => debugData['straightKneeAngle'] as double?;

  @override
  ThresholdBand? get threshold => const ThresholdBand(
      warningBelow: 155.0, faultBelow: STRAIGHT_LEG_MIN_ANGLE);

  @override
  void update(CossackRepContext ctx) {
    debugData['straightKneeAngle'] = ctx.straightKneeAngle;

    if (ctx.state == CossackState.standing ||
        ctx.workingLeg == WorkingLeg.none) {
      return;
    }

    if (ctx.straightKneeAngle < STRAIGHT_LEG_MIN_ANGLE) {
      const message = 'Giữ thẳng chân duỗi, đừng chùng gối bên còn lại.';
      ctx.resultIssues.feedback['straight_leg'] = message;
      addFault(
        FaultRecord(
          type: 'straight_leg',
          message:
              'Bạn đang thu hẹp tư thế, mất tác dụng kéo giãn cơ khép. Hãy giữ thẳng chân còn lại.',
          affectsForm: true,
          phase: ctx.state.name,
          priority: 3, // Medium
          voiceMessage: 'Giữ thẳng chân duỗi!',
        ),
      );
    }
  }
}
