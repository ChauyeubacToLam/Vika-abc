import 'superman_metric_base.dart';

class HipGroundingMetric extends SupermanMetricBase {
  @override
  String get name => 'HipGrounding';

  @override
  void update(SupermanRepContext ctx) {
    debugData['spine_angle'] = ctx.spineAngle.toStringAsFixed(1);

    if (ctx.currentState != SupermanState.hold) return;

    if (ctx.spineAngle.abs() > SupermanConfig.SPINE_NEUTRAL_RANGE) {
      if (!faults.any((f) => f.type == 'SpineNotNeutral')) {
        addFault(FaultRecord(
          phase: ctx.currentState.name,
          type: 'SpineNotNeutral',
          message: 'Giữ cột sống thẳng và trung tính!',
          voiceMessage: 'Lấy hông làm điểm tựa, đừng nhấc hông lên',
          affectsForm: false,
          priority: SupermanVoicePriority.hipGrounding,
        ));
      }
    }
  }
}