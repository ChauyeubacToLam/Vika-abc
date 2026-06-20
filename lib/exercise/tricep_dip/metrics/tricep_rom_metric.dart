import 'tricep_metric_base.dart';
import '../tricep_dip.dart';

class TricepRomMetric extends TricepMetricBase {
  static const double MIN_DEPTH_ANGLE =
      145.0; // If angle > 130 at bottom, it's too shallow

  bool _reachedDepth = false;
  double? _currentElbowAngle;

  @override
  double? get value => _currentElbowAngle;

  @override
  ThresholdBand? get threshold => const ThresholdBand(
        warningAbove: MIN_DEPTH_ANGLE + 8.0,
        faultAbove: MIN_DEPTH_ANGLE + 16.0,
      );

  @override
  void update(TricepRepContext ctx) {
    _currentElbowAngle = ctx.elbowAngle;
    debugData['elbowAngle'] = ctx.elbowAngle;
    debugData['reachedDepth'] = _reachedDepth ? 1 : 0;

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
