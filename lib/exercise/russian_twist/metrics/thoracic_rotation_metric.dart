import 'russian_metric_base.dart';
import '../russian_twist.dart';

class ThoracicRotationMetric extends RussianMetricBase {
  static const double SHOULDER_WIDTH_DROP_RATIO = 0.8; // Shoulder width must drop to at least 80% of original to count as a twist.

  double? _setupShoulderWidth;

  @override
  void update(RussianRepContext ctx) {
    if (ctx.state == RussianTwistState.center_setup) {
      // Record the baseline shoulder width when facing forward
      _setupShoulderWidth = ctx.shoulderWidth;
    }

    if (ctx.state == RussianTwistState.max_point) {
      if (_setupShoulderWidth != null && _setupShoulderWidth! > 0) {
        double currentRatio = ctx.shoulderWidth / _setupShoulderWidth!;
        debugData['shoulderWidthRatio'] = currentRatio;

        // If ratio is still near 1.0 (e.g. > 0.85), they are just swinging arms
        if (currentRatio > SHOULDER_WIDTH_DROP_RATIO) {
          addFault(
            FaultRecord(
              type: 'arm_swinging',
              message: 'Đừng chỉ vung vẩy tay! Hãy vặn cả bờ vai và ngực của bạn!',
              affectsForm: true, // Critical error
              phase: ctx.direction.name,
              priority: 1,
              voiceMessage: 'Vặn cả vai đi!',
            ),
          );
        }
      }
    }
  }
}
