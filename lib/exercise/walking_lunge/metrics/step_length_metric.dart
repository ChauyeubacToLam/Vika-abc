import 'walking_metric_base.dart';
import '../walking_lunge.dart';

class StepLengthMetric extends WalkingMetricBase {
  double? firstRepNormalizedStepLength;
  static const double TOLERANCE = 0.25; // 15% tolerance

  @override
  void update(WalkingRepContext ctx) {
    // Only evaluate at bottom
  }

  @override
  void onStateTransition(
      WalkingState oldState, WalkingState newState, int timestampMs) {
    if (newState == WalkingState.bottom) {}
  }

  void evaluateRep(WalkingRepContext ctx) {
    if (ctx.thighLength == 0) return;

    final normalizedStep = ctx.stepLengthX / ctx.thighLength;

    debugData['normalizedStep'] = normalizedStep;

    if (firstRepNormalizedStepLength == null) {
      firstRepNormalizedStepLength = normalizedStep;
      return;
    }

    final diff = (normalizedStep - firstRepNormalizedStepLength!).abs() /
        firstRepNormalizedStepLength!;
    if (diff > TOLERANCE) {
      addFault(
        FaultRecord(
          type: 'step_length',
          message:
              'Sải bước không đều! Hãy cố gắng duy trì độ dài bước chân ổn định.',
          affectsForm: false,
          phase: ctx.state.name,
          priority: WalkingFaultPriority.stepConsistency,
          voiceMessage: 'Giữ sải bước đều nhau!',
        ),
      );
    }
  }
}
