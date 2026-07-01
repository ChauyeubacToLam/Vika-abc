import 'tricep_metric_base.dart';
import '../../exercise_base.dart';

class ScapularElevationMetric extends TricepMetricBase {
  static const double SHRUG_THRESHOLD_RATIO =
      0.35; // Ear to shoulder distance is very small relative to forearm
  double? _earShoulderRatio;

  @override
  double? get value => _earShoulderRatio;

  @override
  ThresholdBand? get threshold => const ThresholdBand(
        warningBelow: SHRUG_THRESHOLD_RATIO + 0.08,
        faultBelow: SHRUG_THRESHOLD_RATIO,
      );

  @override
  void update(TricepRepContext ctx) {
    if (ctx.ear == null || !ExerciseBase.isLandmarkConfident(ctx.ear!)) {
      debugData['earVisible'] = 0;
      return;
    }
    debugData['earVisible'] = 1;

    final earToShoulderY = (ctx.ear!.y - ctx.shoulder.y).abs();

    // Normalize using forearm length
    final ratio =
        ctx.forearmLength > 0 ? (earToShoulderY / ctx.forearmLength) : 1.0;
    _earShoulderRatio = ratio;
    debugData['earShoulderRatio'] = ratio;

    // If ear is very close to shoulder vertically
    if (ratio < SHRUG_THRESHOLD_RATIO) {
      addFault(
        FaultRecord(
          type: 'shrugging',
          message: 'Ưỡn ngực, hạ vai xuống, cách xa mang tai!',
          affectsForm: false, // Don't fail rep, but warn
          phase: ctx.state.name,
          priority: 2, // High priority warning for neck safety
          voiceMessage: 'Hạ vai xuống!',
        ),
      );
    }
  }
}
