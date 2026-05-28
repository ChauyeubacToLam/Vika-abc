import 'standing_kte_metric_base.dart';
import '../standing_knee_to_elbow.dart';

class CrossRomMetric extends StandingKteMetricBase {
  static const double MAX_TOUCH_DISTANCE_RATIO = 0.5; // Distance D > 50% of torso length

  double _minDistanceRatio = 100.0;

  @override
  void update(StandingKteRepContext ctx) {
    if (ctx.state == KteState.touch || ctx.state == KteState.approaching) {
      if (ctx.torsoLength <= 0) return;

      double distanceRatio = ctx.distanceD / ctx.torsoLength;
      if (distanceRatio < _minDistanceRatio) {
        _minDistanceRatio = distanceRatio;
      }
      
      debugData['crossRomDistanceRatio'] = distanceRatio;
      debugData['minCrossRomDistanceRatio'] = _minDistanceRatio;
    }
  }

  @override
  void onStateTransition(KteState oldState, KteState newState, int timestampMs) {
    if (oldState == KteState.touch && newState == KteState.returning) {
      if (_minDistanceRatio > MAX_TOUCH_DISTANCE_RATIO) {
        addFault(
          FaultRecord(
            type: 'shallow_cross_rom',
            message: 'Vặn người mạnh hơn, cho khuỷu tay và đầu gối chạm nhau!',
            affectsForm: false, // Medium priority
            phase: oldState.name,
            priority: 3,
            voiceMessage: 'Vặn người sâu hơn!',
          ),
        );
      }
    } else if (newState == KteState.standing_base) {
      _minDistanceRatio = 100.0;
    }
  }
}
