import 'tricep_metric_base.dart';
import '../tricep_dip.dart';

class TricepRomMetric extends TricepMetricBase {
  static const double MIN_DEPTH_ANGLE =
      130.0; // If angle > 130 at bottom, it's too shallow

  bool _reachedDepth = false;

  @override
  void update(TricepRepContext ctx) {
    if (ctx.state == TricepDipState.setup_top) return;

    if (ctx.elbowAngle <= MIN_DEPTH_ANGLE) {
      _reachedDepth = true;
    }
  }

  @override
  void onStateTransition(
      TricepDipState oldState, TricepDipState newState, int timestampMs) {
    if (newState == TricepDipState.descending) {
      _reachedDepth = false;
    }
    if (newState == TricepDipState.ascending &&
        oldState == TricepDipState.bottom) {
      if (!_reachedDepth) {
        addFault(
          FaultRecord(
            type: 'shallow_dip',
            message: 'Gập tay sâu hơn cho đến khi mông gần chạm sàn.',
            affectsForm:
                false, // Medium priority, doesn't necessarily fail the rep if they are weak
            phase: 'bottom',
            priority: 3,
            voiceMessage: 'Xuống sâu hơn chút nữa!',
          ),
        );
      }
      _reachedDepth = false;
    }
  }
}
