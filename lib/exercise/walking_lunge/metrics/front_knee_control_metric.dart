import 'walking_metric_base.dart';
import '../walking_lunge.dart';

class FrontKneeControlMetric extends WalkingMetricBase {
  static const double MAX_KNEE_OVER_TOE_X = 0.12; // allow small margin

  @override
  void update(WalkingRepContext ctx) {
    if (ctx.state == WalkingState.standing ||
        ctx.state == WalkingState.stepping) {
      return;
    }

    if (ctx.state == WalkingState.bottom) {
      if (ctx.thighLength <= 1e-6) return;
      final toeDirection = (ctx.frontFoot.x - ctx.frontAnkle.x).sign;
      if (toeDirection == 0) return;
      final kneeOverToe = ((ctx.frontKnee.x - ctx.frontFoot.x) * toeDirection) /
          ctx.thighLength;
      debugData['kneeOverToeX'] = kneeOverToe.toStringAsFixed(2);

      if (kneeOverToe > MAX_KNEE_OVER_TOE_X) {
        addFault(
          FaultRecord(
            type: 'knee_over_toe',
            message: 'Đầu gối đâm về trước quá nhiều! Bước chân dài ra.',
            affectsForm: true,
            phase: ctx.state.name,
            priority: 1, // Critical
            voiceMessage: 'Bước dài ra, đừng để gối đâm về trước!',
          ),
        );
      }
    }
  }
}
