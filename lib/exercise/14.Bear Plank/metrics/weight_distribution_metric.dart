import 'bear_plank_metric_base.dart';

class WeightDistributionMetric extends BearMetricBase {
  @override
  void update(BearRepContext ctx) {
    debugData['wrist_x_diff'] = ctx.wristXDifference.toStringAsFixed(3);

    if (ctx.currentState != BearState.hovering) return;

    if (ctx.wristXDifference > BearConfig.WEIGHT_SHIFT_THRESHOLD) {
      if (!faults.any((f) => f.type == 'WeightShifting')) {
        addFault(FaultRecord(
          phase: ctx.currentState.name,
          type: 'WeightShifting',
          message: 'Hông đang lắc, giữ ổn định!',
          voiceMessage: 'Giữ hông cân bằng, không lắc sang hai bên',
          affectsForm: true,
          priority: BearVoicePriority.weightShift,
        ));
      }
    }
  }
}