import 'superman_metric_base.dart';

class LimbElevationMetric extends SupermanMetricBase {
  @override
  String get name => 'LimbElevation';

  @override
  void update(SupermanRepContext ctx) {
    debugData['arm_elevation'] = ctx.armElevation.toStringAsFixed(3);
    debugData['leg_elevation'] = ctx.legElevation.toStringAsFixed(3);

    if (ctx.currentState != SupermanState.hold) return;

    if (ctx.armElevation < SupermanConfig.LIFT_THRESHOLD) {
      if (!faults.any((f) => f.type == 'ArmTooLow')) {
        addFault(FaultRecord(
          phase: ctx.currentState.name,
          type: 'ArmTooLow',
          message: 'Nâng tay cao hơn!',
          voiceMessage: 'Nâng tay lên cao hơn',
          affectsForm: true,
          priority: SupermanVoicePriority.limbElevation, // Fix #6: Sử dụng priority riêng
        ));
      }
    }
    if (ctx.legElevation < SupermanConfig.LIFT_THRESHOLD) {
      if (!faults.any((f) => f.type == 'LegTooLow')) {
        addFault(FaultRecord(
          phase: ctx.currentState.name,
          type: 'LegTooLow',
          message: 'Nâng chân cao hơn!',
          voiceMessage: 'Nâng chân lên cao hơn',
          affectsForm: true,
          priority: SupermanVoicePriority.limbElevation, // Fix #6: Sử dụng priority riêng
        ));
      }
    }
  }
}