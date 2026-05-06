import 'bear_plank_metric_base.dart';

class FlatBackMetric extends BearMetricBase {
  @override
  void update(BearRepContext ctx) {
    debugData['back_y_diff'] = ctx.backYDifference.toStringAsFixed(3);

    if (ctx.currentState != BearState.hovering) return;

    if (ctx.backYDifference > BearConfig.BACK_SAG_THRESHOLD) {
      if (!faults.any((f) => f.type == 'BackSagging')) {
        addFault(FaultRecord(
          phase: ctx.currentState.name,
          type: 'BackSagging',
          message: 'Lưng bị võng, giữ lưng phẳng!',
          voiceMessage: 'Siết cơ bụng, giữ lưng thẳng',
          affectsForm: true,
          priority: BearVoicePriority.backFlat,
        ));
      }
    }
  }
}
