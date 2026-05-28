import 'dart:math';
import 'russian_metric_base.dart';
import '../russian_twist.dart';

class SpinalFlexionMetric extends RussianMetricBase {
  static const double HUNCH_RATIO_LIMIT = 0.8; // If shoulder-hip distance drops below 80% of setup

  double? _setupShoulderToHipDist;

  @override
  void update(RussianRepContext ctx) {
    double currentDist = sqrt(pow(ctx.shoulderX - ctx.hipX, 2) + pow(ctx.shoulderY - ctx.hipY, 2));

    if (ctx.state == RussianTwistState.center_setup) {
      _setupShoulderToHipDist = currentDist;
    } else {
      if (_setupShoulderToHipDist != null && _setupShoulderToHipDist! > 0) {
        double currentRatio = currentDist / _setupShoulderToHipDist!;
        
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
