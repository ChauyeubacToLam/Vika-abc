import 'russian_metric_base.dart';
import '../russian_twist.dart';

class TwistRomMetric extends RussianMetricBase {
  double? _bestForwardRatio;
  double? _bestBackwardRatio;
  bool _evaluatedThisHalf = false;

  @override
  void update(RussianRepContext ctx) {
    if (ctx.kneeHipDx <= 1e-6) return;

    final ratio = ctx.wristHipDx / ctx.kneeHipDx;
    debugData['twistRomRatio'] = ratio.toStringAsFixed(2);

    if (ctx.state == RussianTwistState.twisting ||
        ctx.state == RussianTwistState.max_point) {
      if (ctx.direction == TwistDirection.forward) {
        _bestForwardRatio =
            _bestForwardRatio == null ? ratio : _max(_bestForwardRatio!, ratio);
      } else if (ctx.direction == TwistDirection.backward) {
        _bestBackwardRatio = _bestBackwardRatio == null
            ? ratio
            : _min(_bestBackwardRatio!, ratio);
      }
    }

    if (ctx.state == RussianTwistState.returning && !_evaluatedThisHalf) {
      var sufficientRom = true;
      if (ctx.direction == TwistDirection.forward) {
        sufficientRom = (_bestForwardRatio ?? ratio) >=
            RussianTwistConfig.FORWARD_GOOD_ROM_RATIO;
      } else if (ctx.direction == TwistDirection.backward) {
        sufficientRom = (_bestBackwardRatio ?? ratio) <=
            RussianTwistConfig.BACKWARD_GOOD_ROM_RATIO;
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
    _bestForwardRatio = null;
    _bestBackwardRatio = null;
    _evaluatedThisHalf = false;
    super.resetAndCountFault();
  }

  double _max(double a, double b) => a > b ? a : b;
  double _min(double a, double b) => a < b ? a : b;
}
