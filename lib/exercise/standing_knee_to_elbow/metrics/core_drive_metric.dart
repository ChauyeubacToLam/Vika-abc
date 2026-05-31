import 'standing_kte_metric_base.dart';
import '../standing_knee_to_elbow.dart';

class CoreDriveMetric extends StandingKteMetricBase {
  static const double SHOULDER_DROP_RATIO_LIMIT =
      0.3; // Shoulder dropped >30% of torso length

  double? _setupShoulderY;

  @override
  void update(StandingKteRepContext ctx) {
    if (ctx.state == KteState.standing_base) {
      _setupShoulderY = ctx.liftingShoulder.y;
    } else if (ctx.state == KteState.touch) {
      // Y increases downwards
      bool kneeBelowHip = ctx.liftingKnee.y >
          ctx.liftingHip.y; // Knee is physically lower than hip

      if (_setupShoulderY != null && ctx.torsoLength > 0) {
        double shoulderDrop = ctx.liftingShoulder.y -
            _setupShoulderY!; // positive if dropped down
        double dropRatio = shoulderDrop / ctx.torsoLength;

        debugData['shoulderDropRatio'] = dropRatio;

        if (kneeBelowHip && dropRatio > SHOULDER_DROP_RATIO_LIMIT) {
          addFault(
            FaultRecord(
              type: 'neck_pulling',
              message:
                  'Hãy nhấc cao đùi lên! Đừng bẻ gập cổ và lưng chúi xuống!',
              affectsForm: false, // High priority warning
              phase: ctx.state.name,
              priority: 2,
              voiceMessage: 'Nhấc đùi cao lên!',
            ),
          );
        }
      }
    }
  }
}
