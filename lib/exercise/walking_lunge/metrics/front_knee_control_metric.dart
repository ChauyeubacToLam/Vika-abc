import 'walking_metric_base.dart';
import '../walking_lunge.dart';

class FrontKneeControlMetric extends WalkingMetricBase {
  static const double MAX_KNEE_OVER_TOE_X = 0.05; // allow small margin

  @override
  void update(WalkingRepContext ctx) {
    if (ctx.state == WalkingState.standing ||
        ctx.state == WalkingState.stepping) {
      return;
    }

    // Check if knee is pushing past toe
    // We assume the character is facing the camera direction correctly.
    // If we take absolute difference between Knee X and Toe X, we must be careful.
    // Let's use horizontal distance relative to the heel/toe.
    // A simpler way is to look at the frontKneeAngle: if it's way below 90, like <70, they're probably pushing forward.

    // Knee Angle check
    if (ctx.state == WalkingState.bottom) {
      if (ctx.frontKneeAngle < 70) {
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
