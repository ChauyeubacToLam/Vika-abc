import 'russian_metric_base.dart';
import '../russian_twist.dart';

class SpinalFlexionMetric extends RussianMetricBase {
  static const double HUNCH_RATIO_LIMIT = 0.8; // If shoulder-hip distance drops below 80% of setup

  double? _setupShoulderToHipY;

  @override
  void update(RussianRepContext ctx) {
    if (ctx.state == RussianTwistState.center_setup) {
      _setupShoulderToHipY = ctx.shoulderToHipY;
    } else {
      if (_setupShoulderToHipY != null && _setupShoulderToHipY! > 0) {
        double currentRatio = ctx.shoulderToHipY / _setupShoulderToHipY!;
        
        debugData['torsoHeightRatio'] = currentRatio;

        if (currentRatio < HUNCH_RATIO_LIMIT) {
          addFault(
            FaultRecord(
              type: 'spinal_flexion',
              message: 'Ưỡn ngực lên, giữ lưng thẳng, không được gù lưng!',
              affectsForm: false, // High priority warning
              phase: ctx.state.name,
              priority: 3,
              voiceMessage: 'Thẳng lưng lên!',
            ),
          );
        }
      }
    }
  }
}
