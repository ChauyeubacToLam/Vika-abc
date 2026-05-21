import 'cossack_metric_base.dart';
import '../cossack_squat.dart';

class CossackWorkingDepthMetric extends CossackMetricBase {
  static const double MIN_DEPTH_ANGLE = 60.0;
  static const double MAX_DEPTH_ANGLE = 95.0; // Allow a bit more than 90 for leniency

  bool _reachedDepth = false;

  @override
  void update(CossackRepContext ctx) {
    if (ctx.state == CossackState.standing) return;

    if (ctx.workingKneeAngle <= MAX_DEPTH_ANGLE) {
      _reachedDepth = true;
    }

    if (ctx.state == CossackState.bottom) {
      if (ctx.workingKneeAngle < MIN_DEPTH_ANGLE) {
        addFault(
          FaultRecord(
            type: 'too_deep',
            message: 'Xuống quá sâu, có thể gây áp lực lên khớp gối.',
            affectsForm: false, // Don't fail the rep for going too deep, just a warning
            phase: ctx.state.name,
            priority: 4,
          ),
        );
      }
    }
  }

  @override
  void onStateTransition(CossackState oldState, CossackState newState, int timestampMs) {
    if (newState == CossackState.standing && oldState != CossackState.standing) {
      if (!_reachedDepth) {
        addFault(
          FaultRecord(
            type: 'shallow_depth',
            message: 'Squat chưa đủ sâu! Cố gắng hạ hông thấp hơn.',
            affectsForm: true,
            phase: 'ascending',
            priority: 3,
            voiceMessage: 'Xuống sâu hơn chút nữa!',
          ),
        );
      }
      _reachedDepth = false;
    }
  }
}
