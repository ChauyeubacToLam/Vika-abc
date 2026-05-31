import 'tricep_metric_base.dart';
import '../tricep_dip.dart';

class HipThrustMetric extends TricepMetricBase {
  static const double HIP_Y_RATIO_THRESHOLD =
      0.3; // Hip moved by 30% of forearm length
  static const double ELBOW_ANGLE_THRESHOLD =
      10.0; // Elbow changed by less than 10 degrees

  double? _startHipY;
  double? _startElbowAngle;

  @override
  void update(TricepRepContext ctx) {
    if (ctx.state == TricepDipState.descending) {
      if (_startHipY == null || _startElbowAngle == null) {
        _startHipY = ctx.hip.y;
        _startElbowAngle = ctx.elbowAngle;
        return;
      }

      double deltaHipY = (ctx.hip.y - _startHipY!).abs();
      double deltaElbowAngle = (_startElbowAngle! - ctx.elbowAngle).abs();

      double hipRatio =
          ctx.forearmLength > 0 ? (deltaHipY / ctx.forearmLength) : 0;

      if (hipRatio > HIP_Y_RATIO_THRESHOLD &&
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
