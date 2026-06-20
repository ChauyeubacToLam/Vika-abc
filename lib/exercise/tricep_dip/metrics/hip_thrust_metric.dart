import 'tricep_metric_base.dart';
import '../tricep_dip.dart';

class HipThrustMetric extends TricepMetricBase {
  static const double HIP_Y_RATIO_THRESHOLD =
      0.45; // Hip moved by 30% of forearm length
  static const double ELBOW_ANGLE_THRESHOLD =
      16.0; // Elbow changed by less than 10 degrees

  double? _startHipY;
  double? _startElbowAngle;
  double _hipRatio = 0.0;

  @override
  double? get value => _hipRatio;

  @override
  ThresholdBand? get threshold => const ThresholdBand(
        warningAbove: HIP_Y_RATIO_THRESHOLD * 0.75,
        faultAbove: HIP_Y_RATIO_THRESHOLD,
      );

  @override
  void update(TricepRepContext ctx) {
    debugData['elbowAngle'] = ctx.elbowAngle;

    if (ctx.state == TricepDipState.descending) {
      if (_startHipY == null || _startElbowAngle == null) {
        _startHipY = ctx.hip.y;
        _startElbowAngle = ctx.elbowAngle;
        debugData['hipRatio'] = _hipRatio;
        debugData['deltaElbowAngle'] = 0.0;
        return;
      }

      final deltaHipY = (ctx.hip.y - _startHipY!).abs();
      final deltaElbowAngle = (_startElbowAngle! - ctx.elbowAngle).abs();

      _hipRatio = ctx.forearmLength > 0 ? (deltaHipY / ctx.forearmLength) : 0;
      debugData['hipRatio'] = _hipRatio;
      debugData['deltaElbowAngle'] = deltaElbowAngle;

      if (_hipRatio > HIP_Y_RATIO_THRESHOLD &&
          deltaElbowAngle < ELBOW_ANGLE_THRESHOLD) {
        addFault(
          FaultRecord(
            type: 'hip_thrust',
            message: 'Đừng chỉ đẩy hông! Hãy gập khuỷu tay của bạn lại!',
            affectsForm: true,
            phase: ctx.state.name,
            priority: 1, // Critical
            voiceMessage: 'Gập khuỷu tay lại, đừng chỉ đẩy hông!',
          ),
        );
      }
    }
  }

  @override
  void onStateTransition(
      TricepDipState oldState, TricepDipState newState, int timestampMs) {
    if (newState == TricepDipState.descending) {
      _startHipY = null;
      _startElbowAngle = null;
    }
  }
}
