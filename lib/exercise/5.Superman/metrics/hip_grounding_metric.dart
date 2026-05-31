import 'superman_metric_base.dart';

class HipGroundingMetric extends SupermanMetricBase {
  @override
  String get name => 'HipGrounding';

  @override
  void update(SupermanRepContext ctx) {
    debugData['hip_elevation'] = ctx.hipElevation
        .toStringAsFixed(3); // Log hip_elevation thay cho spine_angle

    if (ctx.currentState != SupermanState.hold) return;

    // Fix #4: Check hông nhấc khỏi sàn (Dùng LIFT_THRESHOLD làm ngưỡng tham khảo, bạn có thể chỉnh tuỳ specs)
    if (ctx.hipElevation > SupermanConfig.LIFT_THRESHOLD) {
      if (!faults.any((f) => f.type == 'HipNotGrounded')) {
        addFault(FaultRecord(
          phase: ctx.currentState.name,
          type: 'HipNotGrounded',
          message: 'Không nhấc hông khỏi sàn!',
          voiceMessage: 'Lấy hông làm điểm tựa, đừng nhấc hông lên',
          affectsForm: false,
          priority: SupermanVoicePriority.hipGrounding,
        ));
      }
    }
  }
}
