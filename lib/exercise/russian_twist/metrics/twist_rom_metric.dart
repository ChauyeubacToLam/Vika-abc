import 'russian_metric_base.dart';
import '../russian_twist.dart';

class TwistRomMetric extends RussianMetricBase {
  double? _bestForwardAngleDelta;
  double? _bestBackwardAngleDelta;
  double? _centerAngle;
  bool _evaluatedThisHalf = false;

  @override
  void update(RussianRepContext ctx) {
    if (ctx.kneeHipDx <= 1e-6) return;

    if (ctx.state == RussianTwistState.center_setup) {
      _centerAngle = ctx.shoulderAngle;
    }

    if (_centerAngle == null) return;

    final angleDelta = ctx.shoulderAngle - _centerAngle!;
    debugData['twistRomDelta'] = angleDelta.toStringAsFixed(1);

    if (ctx.state == RussianTwistState.twisting ||
        ctx.state == RussianTwistState.max_point) {
      if (ctx.direction == TwistDirection.forward) {
        // Forward: angle decreases, so delta is negative
        _bestForwardAngleDelta =
            _bestForwardAngleDelta == null ? angleDelta : _min(_bestForwardAngleDelta!, angleDelta);
      } else if (ctx.direction == TwistDirection.backward) {
        // Backward: angle increases, so delta is positive
        _bestBackwardAngleDelta = _bestBackwardAngleDelta == null
            ? angleDelta
            : _max(_bestBackwardAngleDelta!, angleDelta);
      }
    }

    if (ctx.state == RussianTwistState.returning && !_evaluatedThisHalf) {
      var sufficientRom = true;
      if (ctx.direction == TwistDirection.forward) {
        // Need to decrease by at least FORWARD_GOOD_ROM_DELTA
        sufficientRom = (_bestForwardAngleDelta ?? angleDelta) <=
            -RussianTwistConfig.FORWARD_GOOD_ROM_DELTA;
      } else if (ctx.direction == TwistDirection.backward) {
        // Need to increase by at least BACKWARD_GOOD_ROM_DELTA
        sufficientRom = (_bestBackwardAngleDelta ?? angleDelta) >=
            RussianTwistConfig.BACKWARD_GOOD_ROM_DELTA;
      }

      if (!sufficientRom) {
        addFault(
          FaultRecord(
            type: 'shallow_twist',
            message: 'Vặn chưa đủ sâu, tay cần đi dứt khoát qua hai hướng.',
            affectsForm: true,
            phase: ctx.direction.name,
            priority: 4,
            voiceMessage: 'Vặn sâu hơn nhé.',
          ),
        );
      }
      _evaluatedThisHalf = true;
    }
  }

  @override
  void resetAndCountFault() {
    _bestForwardAngleDelta = null;
    _bestBackwardAngleDelta = null;
    _centerAngle = null;
    _evaluatedThisHalf = false;
    super.resetAndCountFault();
  }

  double _max(double a, double b) => a > b ? a : b;
  double _min(double a, double b) => a < b ? a : b;
}
