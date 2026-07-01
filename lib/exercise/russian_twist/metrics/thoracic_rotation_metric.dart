import 'russian_metric_base.dart';
import '../russian_twist.dart';

/// Detects "arm swinging" — where the hands move but the torso/chest does
/// not rotate with them.
///
/// In front-view, reliable trunk-rotation depth (z) is not available, so this
/// metric uses a weaker proxy: how far the hands travel laterally relative to
/// the shoulders. If the wrist barely crosses the shoulder line during a full
/// twist, the user is mostly swinging the arms rather than rotating the
/// chest.
///
/// This is a NON-blocking quality warning (affectsForm: false): the front-view
/// signal is too indirect to reject reps on its own, and the primary goal is
/// reliable rep counting.
class ThoracicRotationMetric extends RussianMetricBase {
  static const double SHOULDER_CROSS_MIN = 0.02;

  double? _setupShoulderX;

  @override
  void update(RussianRepContext ctx) {
    if (ctx.shoulderWidth <= 1e-6) return;

    if (ctx.state == RussianTwistState.center_setup) {
      _setupShoulderX = ctx.midShoulderX;
    }

    if (ctx.state == RussianTwistState.max_point &&
        _setupShoulderX != null) {
      // How far the wrist has moved laterally relative to setup, normalized
      // by shoulder width. A genuine twist moves the hands well past the
      // shoulder line; arm-only swings stay close to center.
      final signedMovement = (ctx.wristX - _setupShoulderX!) / ctx.shoulderWidth;
      final movementRatio = signedMovement.abs();

      debugData['shoulderMovementRatio'] = movementRatio.toStringAsFixed(2);

      if (movementRatio < SHOULDER_CROSS_MIN) {
        addFault(
          FaultRecord(
            type: 'arm_swinging',
            message:
                'Đừng chỉ vung tay, hãy xoay cả vai và ngực theo hướng tay.',
            affectsForm: false,
            phase: ctx.direction.name,
            priority: 1,
            voiceMessage: 'Xoay cả vai theo tay.',
          ),
        );
      }
    }
  }

  @override
  void resetAndCountFault() {
    _setupShoulderX = null;
    super.resetAndCountFault();
  }
}
