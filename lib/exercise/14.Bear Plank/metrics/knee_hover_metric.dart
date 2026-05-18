import 'bear_plank_metric_base.dart';

class KneeHoverMetric extends BearMetricBase {
  @override
  void update(BearRepContext ctx) {
    debugData['knee_hover_height'] = ctx.kneeHeightOffset.toStringAsFixed(3);

    if (ctx.currentState != BearState.hovering) return;

    if (ctx.kneeHeightOffset < BearConfig.KNEE_HOVER_MIN) {
      if (!faults.any((f) => f.type == 'KneeTouchingFloor')) {
        addFault(FaultRecord(
          phase: ctx.currentState.name,
          type: 'KneeTouchingFloor',
          message: 'Gối đang chạm sàn, nâng gối lên!',
          voiceMessage: 'Nâng gối lên khỏi mặt sàn',
          affectsForm: true,
          priority: BearVoicePriority.kneeHover,
        ));
      }
    } else if (ctx.kneeHeightOffset > BearConfig.KNEE_HOVER_MAX) {
      if (!faults.any((f) => f.type == 'ButtTooHigh')) {
        addFault(FaultRecord(
          phase: ctx.currentState.name,
          type: 'ButtTooHigh',
          message: 'Mông vổng quá cao, hạ xuống!',
          voiceMessage: 'Hạ mông xuống, giữ lưng phẳng',
          affectsForm: true,
          priority: BearVoicePriority.kneeHover,
        ));
      }
    }
  }
}
