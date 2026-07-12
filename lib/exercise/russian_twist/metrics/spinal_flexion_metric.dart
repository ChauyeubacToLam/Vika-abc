import 'russian_metric_base.dart';
import '../russian_twist.dart';

/// Checks trunk lean angle to ensure the user maintains a leaned-back
/// Russian-twist "V" sit posture rather than sitting bolt upright or
/// collapsing too low.
///
/// In front-view, the trunk angle is measured between the line connecting
/// the shoulder midpoint to the hip midpoint and the horizontal axis.
/// A leaned-back V-sit keeps the shoulders roughly level with or below the
/// hips in the lateral sense; an upright torso reads near-vertical.
class SpinalFlexionMetric extends RussianMetricBase {
  @override
  void update(RussianRepContext ctx) {
    debugData['trunkHorizontalAngle'] =
        ctx.trunkHorizontalAngle.toStringAsFixed(1);

    if (ctx.state == RussianTwistState.center_setup) return;

    if (ctx.trunkHorizontalAngle >
        RussianTwistConfig.MAX_TRUNK_HORIZONTAL_ANGLE) {
      addFault(
        FaultRecord(
          type: 'too_upright',
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
          type: 'too_low',
          message:
              'Không tính: nâng thân lên một chút, đừng nằm quá thấp khi vặn.',
          affectsForm: true,
          phase: ctx.state.name,
          priority: 1,
          voiceMessage: 'Nâng thân lên!',
        ),
      );
    }
  }
}
