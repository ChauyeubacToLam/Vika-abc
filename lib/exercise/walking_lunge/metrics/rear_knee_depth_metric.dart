import 'walking_metric_base.dart';
import '../walking_lunge.dart';

class RearKneeDepthMetric extends WalkingMetricBase {
  static const double DEPTH_TOLERANCE = 0.25; // normalized distance from floor
  double? _normalizedDistanceToFloor;

  @override
  double? get value => _normalizedDistanceToFloor;

  @override
  ThresholdBand? get threshold => const ThresholdBand(
        warningAbove: DEPTH_TOLERANCE * 0.75,
        faultAbove: DEPTH_TOLERANCE,
      );

  @override
  void update(WalkingRepContext ctx) {
    if (ctx.state == WalkingState.standing ||
        ctx.state == WalkingState.stepping) {
      return;
    }

    // Check hard hit on the floor by looking at velocity
    // Assuming Y increases downwards. If velocity is very high positive, and then suddenly stops

    // Assuming Y increases downwards. If velocity is very high positive, and then suddenly stops
    // Wait, simple check: if at BOTTOM phase, check if it's deep enough.

    if (ctx.state == WalkingState.bottom) {
      final distanceToFloor = (ctx.frontFoot.y - ctx.rearKnee.y)
          .abs(); // approx using front foot as floor level
      final normalizedDist =
          distanceToFloor / (ctx.thighLength == 0 ? 1 : ctx.thighLength);
      _normalizedDistanceToFloor = normalizedDist;
      debugData['rearKneeFloorDistance'] = normalizedDist;
      debugData['rearKneeAngle'] = ctx.rearKneeAngle;

      if (normalizedDist > DEPTH_TOLERANCE) {
        addFault(
          FaultRecord(
            type: 'rear_depth',
            message: 'Đầu gối sau chưa đủ sâu! Hạ sát mặt đất hơn.',
            affectsForm: false, // Don't fail the rep, just warn
            phase: ctx.state.name,
            priority: 4,
            voiceMessage: 'Hạ gối thấp xuống!',
          ),
        );
      }
    }
  }
}
