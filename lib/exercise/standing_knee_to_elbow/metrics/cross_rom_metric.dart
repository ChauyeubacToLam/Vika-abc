import 'standing_kte_metric_base.dart';
import '../standing_knee_to_elbow.dart';

class CrossRomMetric extends StandingKteMetricBase {
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
  void onStateTransition(
      KteState oldState, KteState newState, int timestampMs) {
    // The state machine already validates ROM from the reduction relative to
    // the user's setup distance. Do not re-apply the old absolute touch gate
    // here; that gate rejected valid reps on wider/taller camera framing.
    if (newState == KteState.standing_base) {
      _minDistanceRatio = 100.0;
    }
  }
}
