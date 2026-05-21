import 'russian_metric_base.dart';
import '../russian_twist.dart';

class KneeAnchoringMetric extends RussianMetricBase {
  static const double KNEE_WOBBLE_RATIO_LIMIT = 0.20; // 20% of hip width

  double? _setupKneeX;

  @override
  void update(RussianRepContext ctx) {
    if (ctx.state == RussianTwistState.center_setup) {
      _setupKneeX = ctx.midKneeX;
    } else {
      if (_setupKneeX != null && ctx.hipWidth > 0) {
        double drift = (ctx.midKneeX - _setupKneeX!).abs();
        double driftRatio = drift / ctx.hipWidth;
        
        debugData['kneeDriftRatio'] = driftRatio;

        if (driftRatio > KNEE_WOBBLE_RATIO_LIMIT) {
          addFault(
            FaultRecord(
              type: 'knee_wobble',
              message: 'Khóa chặt đầu gối lại! Giữ thân dưới đứng im!',
              affectsForm: true, // Critical
              phase: ctx.state.name,
              priority: 1,
              voiceMessage: 'Khóa chặt đầu gối!',
            ),
          );
        }
      }
    }
  }
}
