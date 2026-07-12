import 'cossack_metric_base.dart';
import '../cossack_squat.dart';

class CossackTorsoVerticalityMetric extends CossackMetricBase {
  static const double MAX_TORSO_FORWARD_LEAN =
      65.0; // Allowed degrees of forward lean

  @override
  double? get value => debugData['torsoAngle'] as double?;

  @override
  ThresholdBand? get threshold => const ThresholdBand(
      warningAbove: 55.0, faultAbove: MAX_TORSO_FORWARD_LEAN);

  @override
  void update(CossackRepContext ctx) {
    debugData['torsoAngle'] = ctx.torsoAngle;

    if (ctx.state == CossackState.standing) return;

    if (ctx.torsoAngle > MAX_TORSO_FORWARD_LEAN) {
      const message = 'Nâng ngực lên, giữ thân trên thẳng hơn.';
      ctx.resultIssues.feedback['torso'] = message;
      addFault(
        FaultRecord(
          type: 'torso',
          message:
              'Tránh rạp ngực hoàn toàn xuống đất. Cố gắng giữ lưng thẳng hơn.',
          affectsForm: false, // Don't fail the rep, but warn
          phase: ctx.state.name,
          priority: 4, // Low
          voiceMessage: 'Nâng ngực lên!',
        ),
      );
    }
  }
}
