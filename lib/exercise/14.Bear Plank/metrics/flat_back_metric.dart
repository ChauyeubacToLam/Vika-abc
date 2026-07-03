import 'bear_plank_metric_base.dart';

class FlatBackMetric extends BearMetricBase {
  @override
  void update(BearRepContext ctx) {
    debugData['back_y_offset'] = ctx.backYOffset.toStringAsFixed(3);

    isFaultingNow = false;
    if (ctx.currentState != BearState.hovering) return;

    // Võng lưng (Sagging): shoulder.y > hip.y → backYOffset dương lớn
    if (ctx.backYOffset > BearConfig.BACK_SAG_THRESHOLD) {
      isFaultingNow = true;
      if (!faults.any((f) => f.type == 'BackSagging')) {
        addFault(FaultRecord(
          phase: ctx.currentState.name,
          type: 'BackSagging',
          message: 'Lưng bị võng, giữ lưng phẳng!',
          voiceMessage: 'Siết cơ bụng, giữ lưng thẳng, đừng để lưng bị võng!',
          affectsForm: true,
          priority: BearVoicePriority.backFlat,
        ));
      }
    }
    // Gù lưng (Arching): hip.y > shoulder.y → backYOffset âm lớn
    else if (ctx.backYOffset < -BearConfig.BACK_ARCH_THRESHOLD) {
      isFaultingNow = true;
      if (!faults.any((f) => f.type == 'BackArching')) {
        addFault(FaultRecord(
          phase: ctx.currentState.name,
          type: 'BackArching',
          message: 'Lưng gù lên, hạ lưng phẳng!',
          voiceMessage: 'Lưng đang gù, hạ lưng xuống cho phẳng',
          affectsForm: true,
          priority: BearVoicePriority.backFlat,
        ));
      }
    }
  }
}
