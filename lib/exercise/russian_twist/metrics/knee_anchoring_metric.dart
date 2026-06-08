import 'dart:math' as math;

import 'russian_metric_base.dart';
import '../russian_twist.dart';

class KneeAnchoringMetric extends RussianMetricBase {
  static const double KNEE_WOBBLE_RATIO_LIMIT = 0.20;

  double? _setupKneeX;
  double? _setupKneeY;
  double? _setupHipKneeDistance;

  @override
  void update(RussianRepContext ctx) {
    if (ctx.state == RussianTwistState.center_setup) {
      _setupKneeX = ctx.kneeX;
      _setupKneeY = ctx.kneeY;
      _setupHipKneeDistance = math.sqrt(math.pow(ctx.kneeX - ctx.hipX, 2) +
          math.pow(ctx.kneeY - ctx.hipY, 2));
      if (_setupHipKneeDistance! <= 1e-6) {
        _setupHipKneeDistance = null;
      }
      return;
    }

    if (_setupKneeX == null ||
        _setupKneeY == null ||
        _setupHipKneeDistance == null) {
      return;
    }

    final driftX = ctx.kneeX - _setupKneeX!;
    final driftY = ctx.kneeY - _setupKneeY!;
    final drift = math.sqrt(math.pow(driftX, 2) + math.pow(driftY, 2));
    final driftRatio = drift / _setupHipKneeDistance!;

    debugData['kneeDriftRatio'] = driftRatio.toStringAsFixed(2);

    if (driftRatio > KNEE_WOBBLE_RATIO_LIMIT) {
      addFault(
        FaultRecord(
          type: 'knee_wobble',
          message: 'Giữ đầu gối ổn định, đừng dùng chân lấy đà.',
          affectsForm: true,
          phase: ctx.state.name,
          priority: 1,
          voiceMessage: 'Giữ chân vững nhé.',
        ),
      );
    }
  }
}
