import 'cossack_metric_base.dart';
import '../cossack_squat.dart';

class CossackStraightLegMetric extends CossackMetricBase {
  static const double STRAIGHT_LEG_MIN_ANGLE =
      160.0; // Lenient threshold for straight leg

  @override
  void update(CossackRepContext ctx) {
    if (ctx.state == CossackState.standing ||
        ctx.workingLeg == WorkingLeg.none) {
      return;
    }

    if (ctx.straightKneeAngle < STRAIGHT_LEG_MIN_ANGLE) {
      addFault(
        FaultRecord(
          type: 'bent_straight_leg',
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
