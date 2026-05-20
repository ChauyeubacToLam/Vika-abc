import 'bear_plank_metric_base.dart';

class WeightDistributionMetric extends BearMetricBase {
  @override
  void update(BearRepContext ctx) {
    debugData['shoulder_wrist_x'] = ctx.shoulderWristXOffset.toStringAsFixed(3);

    if (ctx.currentState != BearState.hovering) return;

    if (ctx.shoulderWristXOffset > BearConfig.WEIGHT_SHIFT_THRESHOLD) {
      if (!faults.any((f) => f.type == 'WeightForward')) {
        addFault(FaultRecord(
          phase: ctx.currentState.name,
          type: 'WeightForward',
          message: 'Vai đang chúi quá trước cổ tay!',
          voiceMessage: 'Đẩy lùi hông về sau, giữ vai nằm ngay trên cổ tay',
          affectsForm: true,
          priority: BearVoicePriority.weightShift,
        ));
      }
    }
  }
}