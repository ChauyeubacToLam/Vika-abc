import 'cossack_metric_base.dart';
import '../cossack_squat.dart';

class CossackTorsoVerticalityMetric extends CossackMetricBase {
  static const double MAX_TORSO_FORWARD_LEAN = 50.0; // Allowed degrees of forward lean

  @override
  void update(CossackRepContext ctx) {
    if (ctx.state == CossackState.standing) return;

    if (ctx.torsoAngle > MAX_TORSO_FORWARD_LEAN) {
      addFault(
        FaultRecord(
          type: 'torso_lean',
          message: 'Tránh rạp ngực hoàn toàn xuống đất. Cố gắng giữ lưng thẳng hơn.',
          affectsForm: false, // Don't fail the rep, but warn
          phase: ctx.state.name,
          priority: 4, // Low
          voiceMessage: 'Nâng ngực lên!',
        ),
      );
    }
  }
}
