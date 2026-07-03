import 'walking_metric_base.dart';
import '../walking_lunge.dart';

class FrontKneeControlMetric extends WalkingMetricBase {
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

      // Keep this value for diagnostics only. Knee travel past the toes does
      // not, by itself, prove that the step is too short, so it must not fail
      // the rep or tell the user to lengthen the step.
    }
  }
}
