import 'walking_metric_base.dart';
import '../walking_lunge.dart';

class TorsoVerticalityMetric extends WalkingMetricBase {
  static const double MAX_FORWARD_LEAN =
      20.0; // 10 degrees is too strict, use 20.

  @override
  void update(WalkingRepContext ctx) {
    if (ctx.state == WalkingState.standing) return;

    if (ctx.torsoAngle > MAX_FORWARD_LEAN) {
      addFault(
        FaultRecord(
          type: 'torso_lean',
          message: 'Lưng bị gập quá nhiều. Hãy giữ thân thẳng đứng.',
          affectsForm: false,
          phase: ctx.state.name,
          priority: WalkingFaultPriority.torsoLean,
          voiceMessage: 'Giữ lưng thẳng lên!',
        ),
      );
    }
  }
}
