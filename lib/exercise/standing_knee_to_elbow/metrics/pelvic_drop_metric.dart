import 'dart:math';
import 'standing_kte_metric_base.dart';
import '../standing_knee_to_elbow.dart';

class PelvicDropMetric extends StandingKteMetricBase {
  static const double MAX_PELVIC_TILT_DEGREES = 15.0;

  @override
  void update(StandingKteRepContext ctx) {
    if (ctx.state == KteState.approaching || ctx.state == KteState.touch) {
      // Calculate angle of the line connecting the two hips relative to the horizontal
      double dx = (ctx.liftingHip.x - ctx.standingHip.x).abs();
      double dy = (ctx.liftingHip.y - ctx.standingHip.y).abs(); // We only care about magnitude of tilt
      
      if (dx == 0) return; // Edge case, perfectly vertical (which shouldn't happen for hips)
      
      double tiltAngleRadians = atan2(dy, dx);
      double tiltAngleDegrees = tiltAngleRadians * 180 / pi;
      
      debugData['pelvicTiltDegrees'] = tiltAngleDegrees;

      // Specifically check if the lifting hip dropped (Trendelenburg sign).
      // Y increases downwards. So if liftingHip.y > standingHip.y, the lifting hip is lower (dropped).
      bool liftingHipDropped = ctx.liftingHip.y > ctx.standingHip.y;

      if (tiltAngleDegrees > MAX_PELVIC_TILT_DEGREES && liftingHipDropped) {
        addFault(
          FaultRecord(
            type: 'pelvic_drop',
            message: 'Rớt hông bên chân giơ lên! Gồng chặt cơ mông chân trụ.',
            affectsForm: false, // High priority warning
            phase: ctx.state.name,
            priority: 2,
            voiceMessage: 'Giữ hông thăng bằng!',
          ),
        );
      }
    }
  }
}
