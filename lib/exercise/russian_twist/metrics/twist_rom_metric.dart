import 'dart:math' as math;

import 'russian_metric_base.dart';
import '../russian_twist.dart';

/// Measures how far the hands travel laterally during a twist.
///
/// In front-view the wrist is the most reliable signal: hands stay in frame
/// while twisting both ways, unlike the side-view shoulder which was fully
/// occluded. ROM is measured as the peak |lateral offset| reached during the
/// twisting phase, normalized by shoulder width.
class TwistRomMetric extends RussianMetricBase {
  double? _bestAbsOffset;
  double? _centerOffset;
  bool _evaluatedThisHalf = false;

  @override
  void update(RussianRepContext ctx) {
    if (ctx.shoulderWidth <= 1e-6) return;

    if (ctx.state == RussianTwistState.center_setup) {
      _centerOffset = ctx.wristLateralOffset;
    }

    final delta =
        ctx.wristLateralOffset - (_centerOffset ?? ctx.wristLateralOffset);
    debugData['twistRomDelta'] = delta.toStringAsFixed(2);

    if (ctx.state == RussianTwistState.twisting ||
        ctx.state == RussianTwistState.max_point) {
      _bestAbsOffset = _bestAbsOffset == null
          ? delta.abs()
          : math.max(_bestAbsOffset!, delta.abs());
    }

    if (ctx.state == RussianTwistState.returning && !_evaluatedThisHalf) {
      final sufficientRom =
          (_bestAbsOffset ?? delta.abs()) >= RussianTwistConfig.GOOD_ROM_DELTA;

      if (!sufficientRom) {
        addFault(
          FaultRecord(
            type: 'rom',
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
    _bestAbsOffset = null;
    _centerOffset = null;
    _evaluatedThisHalf = false;
    super.resetAndCountFault();
  }
}
