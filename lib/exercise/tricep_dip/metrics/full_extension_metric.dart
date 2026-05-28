import 'tricep_metric_base.dart';
import '../tricep_dip.dart';

class FullExtensionMetric extends TricepMetricBase {
  static const double FULL_EXTENSION_ANGLE = 160.0;

  @override
  void update(TricepRepContext ctx) {
    // Only check at the transition back to setup_top
  }

  @override
  void onStateTransition(TricepDipState oldState, TricepDipState newState, int timestampMs) {
    // Wait, the transition to setup_top only happens IF angle > 160.
    // If we want to check if they fail to extend, we'd need a timeout or we check if they start descending again before extending.
    // Let's modify: if they start descending from ascending without reaching 160.
    // But how do we know they started descending? The state machine will transition to descending.
    if (newState == TricepDipState.descending && oldState == TricepDipState.ascending) {
      // They didn't reach setup_top (meaning they didn't fully extend).
      // Actually, if the state machine requires angle > 160 to reach setup_top, 
      // transitioning from ascending directly to descending means they missed full extension.
      addFault(
        FaultRecord(
          type: 'no_full_extension',
          message: 'Chưa duỗi thẳng tay hoàn toàn! Hãy đẩy thẳng tay lên để siết cơ.',
          affectsForm: false, // Medium
          phase: 'ascending',
          priority: 3,
          voiceMessage: 'Đẩy thẳng tay lên!',
        ),
      );
    }
  }
}
