import 'russian_metric_base.dart';
import '../russian_twist.dart';

class KneeAnchoringMetric extends RussianMetricBase {
  // Allow small movements (20% of hip-to-knee distance)
  static const double KNEE_WOBBLE_RATIO_LIMIT = 0.20;

  double? _setupKneeX;
  double? _setupKneeY;
  double? _setupHipKneeDistance;

  @override
  void update(RussianRepContext ctx) {
    if (ctx.state == RussianTwistState.center_setup) {
      _setupKneeX = ctx.kneeX;
      _setupKneeY = ctx.kneeY;
      // Calculate euclidian distance as a scale reference
      _setupHipKneeDistance =
          (ctx.kneeX - ctx.hipX).abs() + (ctx.kneeY - ctx.hipY).abs();
      if (_setupHipKneeDistance == 0) _setupHipKneeDistance = 1.0;
    } else {
      if (_setupKneeX != null &&
          _setupKneeY != null &&
          _setupHipKneeDistance != null) {
        double driftX = (ctx.kneeX - _setupKneeX!).abs();
        double driftY = (ctx.kneeY - _setupKneeY!).abs();

        // Total drift vs setup distance
        double driftRatio = (driftX + driftY) / _setupHipKneeDistance!;

        debugData['kneeDriftRatio'] = driftRatio;

        if (driftRatio > KNEE_WOBBLE_RATIO_LIMIT) {
          addFault(
            FaultRecord(
              type: 'knee_wobble',
              message: 'Khóa chặt đầu gối lại! Giữ phần chân đứng im!',
              affectsForm: true, // Critical
              phase: ctx.state.name,
              priority: 1,
              voiceMessage: 'Khóa chặt đầu gối!',
            ),
          );
        }
      }
    }
  }
}
