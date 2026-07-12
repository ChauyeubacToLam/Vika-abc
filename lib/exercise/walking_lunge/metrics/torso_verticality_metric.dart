import 'walking_metric_base.dart';
import '../walking_lunge.dart';

class TorsoVerticalityMetric extends WalkingMetricBase {
  static const double MAX_FORWARD_LEAN =
      35.0; // 10 degrees is too strict, use 20.

  @override
  double? get value => debugData['torsoAngle'] as double?;

  @override
  ThresholdBand? get threshold =>
      const ThresholdBand(warningAbove: 28.0, faultAbove: MAX_FORWARD_LEAN);

  @override
  void update(WalkingRepContext ctx) {
    debugData['torsoAngle'] = ctx.torsoAngle;

    if (ctx.state == WalkingState.standing) return;

    if (ctx.torsoAngle > MAX_FORWARD_LEAN) {
      addFault(
        FaultRecord(
          type: 'torso',
          message: 'Lưng bị gập quá nhiều. Hãy giữ thân thẳng đứng.',
          // Trunk-lean is critical fleet-wide (squat/lunge/jump squat/…); this only
          // fires past MAX_FORWARD_LEAN, i.e. the error band, so soft was miscoded.
          affectsForm: true,
          phase: ctx.state.name,
          priority: WalkingFaultPriority.torsoLean,
          voiceMessage: 'Giữ lưng thẳng lên!',
        ),
      );
    }
  }
}
