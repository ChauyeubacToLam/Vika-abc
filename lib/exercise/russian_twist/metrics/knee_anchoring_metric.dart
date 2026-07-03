import 'dart:math' as math;

import 'russian_metric_base.dart';
import '../russian_twist.dart';

/// Detects knee/leg wobble during the twist.
///
/// In front-view both knees are visible. Their midpoint should remain stable
/// — if it drifts significantly relative to setup, the user is using their
/// legs to generate momentum instead of rotating the torso.
class KneeAnchoringMetric extends RussianMetricBase {
  static const double KNEE_WOBBLE_RATIO_LIMIT = 0.32;

  double? _setupKneeX;
  double? _setupKneeY;

  @override
  void update(RussianRepContext ctx) {
    if (ctx.state == RussianTwistState.center_setup) {
      _setupKneeX = ctx.midKneeX;
      _setupKneeY = ctx.midKneeY;
      return;
    }

    if (_setupKneeX == null || _setupKneeY == null) return;

    final driftX = ctx.midKneeX - _setupKneeX!;
    final driftY = ctx.midKneeY - _setupKneeY!;
    final drift = math.sqrt(driftX * driftX + driftY * driftY);
    final driftRatio = ctx.shoulderWidth > 1e-6
        ? drift / ctx.shoulderWidth
        : 0.0;

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

  @override
  void resetAndCountFault() {
    _setupKneeX = null;
    _setupKneeY = null;
    super.resetAndCountFault();
  }
}
