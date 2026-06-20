import 'dart:math';
import 'russian_metric_base.dart';
import '../russian_twist.dart';

class SpinalFlexionMetric extends RussianMetricBase {
  static const double HUNCH_RATIO_LIMIT =
      0.68; // If shoulder-hip distance drops below 80% of setup

  double? _setupShoulderToHipDist;

  @override
  void update(RussianRepContext ctx) {
    double currentDist = sqrt(
        pow(ctx.shoulderX - ctx.hipX, 2) + pow(ctx.shoulderY - ctx.hipY, 2));

    debugData['trunkHorizontalAngle'] =
        ctx.trunkHorizontalAngle.toStringAsFixed(1);

    if (ctx.state == RussianTwistState.center_setup) {
      _setupShoulderToHipDist = currentDist;
    } else {
      if (ctx.trunkHorizontalAngle >
          RussianTwistConfig.MAX_TRUNK_HORIZONTAL_ANGLE) {
        addFault(
          FaultRecord(
            type: 'upright_torso',
            message:
                'Không tính: hãy ngả lưng ra sau để siết bụng, không ngồi thẳng 90 độ.',
            affectsForm: true,
            phase: ctx.state.name,
            priority: 1,
            voiceMessage: 'Ngả lưng ra sau!',
          ),
        );
      } else if (ctx.trunkHorizontalAngle <
          RussianTwistConfig.MIN_TRUNK_HORIZONTAL_ANGLE) {
        addFault(
          FaultRecord(
            type: 'collapsed_torso',
            message:
                'Không tính: nâng thân lên một chút, đừng nằm quá thấp khi vặn.',
            affectsForm: true,
            phase: ctx.state.name,
            priority: 1,
            voiceMessage: 'Nâng thân lên!',
          ),
        );
      }

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
