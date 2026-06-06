import 'russian_metric_base.dart';
import '../russian_twist.dart';

class ThoracicRotationMetric extends RussianMetricBase {
  static const double SHOULDER_MOVEMENT_MIN =
      0.10; // Shoulder must move at least 10% of hip-to-knee distance.

  double? _setupShoulderHipDx;

  @override
  void update(RussianRepContext ctx) {
    if (ctx.state == RussianTwistState.center_setup) {
      // Record the baseline shoulder-to-hip X distance
      _setupShoulderHipDx = ctx.shoulderHipDx;
    }

    if (ctx.state == RussianTwistState.max_point) {
      if (_setupShoulderHipDx != null) {
        double currentShoulderHipDx = ctx.shoulderHipDx;
        double shoulderMovement =
            (currentShoulderHipDx - _setupShoulderHipDx!).abs();

        // Normalize by kneeHipDx to be scale invariant
        double movementRatio = shoulderMovement / ctx.kneeHipDx;
        debugData['shoulderMovementRatio'] = movementRatio;

        // If shoulder didn't move much, they are just swinging arms
        if (movementRatio < SHOULDER_MOVEMENT_MIN) {
          addFault(
            FaultRecord(
              type: 'arm_swinging',
              message:
                  'Đừng chỉ vung vẩy tay! Hãy vặn cả bờ vai và ngực của bạn!',
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
