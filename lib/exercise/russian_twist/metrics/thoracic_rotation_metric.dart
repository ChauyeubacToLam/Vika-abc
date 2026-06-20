import 'russian_metric_base.dart';
import '../russian_twist.dart';

class ThoracicRotationMetric extends RussianMetricBase {
  static const double SHOULDER_MOVEMENT_MIN = 0.06;

  double? _setupShoulderHipDx;

  @override
  void update(RussianRepContext ctx) {
    if (ctx.kneeHipDx <= 1e-6) return;

    if (ctx.state == RussianTwistState.center_setup) {
      _setupShoulderHipDx = ctx.shoulderHipDx;
    }

    if (ctx.state == RussianTwistState.max_point &&
        _setupShoulderHipDx != null) {
      final signedMovement = ctx.shoulderHipDx - _setupShoulderHipDx!;
      final expectedDirection = ctx.direction == TwistDirection.forward
          ? 1.0
          : ctx.direction == TwistDirection.backward
              ? -1.0
              : 0.0;
      final movementRatio = signedMovement.abs() / ctx.kneeHipDx;
      final movesWithHand =
          expectedDirection == 0.0 || signedMovement * expectedDirection > 0;

      debugData['shoulderMovementRatio'] = movementRatio.toStringAsFixed(2);
      debugData['shoulderMovesWithHand'] = movesWithHand;

      if (movementRatio < SHOULDER_MOVEMENT_MIN || !movesWithHand) {
        addFault(
          FaultRecord(
            type: 'arm_swinging',
            message:
                'Đừng chỉ vung tay, hãy xoay cả vai và ngực theo hướng tay.',
            affectsForm: true,
            phase: ctx.direction.name,
            priority: 1,
            voiceMessage: 'Xoay cả vai theo tay.',
          ),
        );
      }
    }
  }
}
