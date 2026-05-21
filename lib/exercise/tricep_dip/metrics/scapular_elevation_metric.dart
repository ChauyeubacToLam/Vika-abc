import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'tricep_metric_base.dart';
import '../tricep_dip.dart';
import '../../exercise_base.dart';

class ScapularElevationMetric extends TricepMetricBase {
  static const double SHRUG_THRESHOLD_RATIO = 0.5; // Ear to shoulder distance is very small relative to forearm

  @override
  void update(TricepRepContext ctx) {
    if (ctx.ear == null || !ExerciseBase.isLandmarkConfident(ctx.ear!)) return;

    double earToShoulderY = (ctx.ear!.y - ctx.shoulder.y).abs();
    
    // Normalize using forearm length
    double ratio = ctx.forearmLength > 0 ? (earToShoulderY / ctx.forearmLength) : 1.0;

    // If ear is very close to shoulder vertically
    if (ratio < SHRUG_THRESHOLD_RATIO) {
      addFault(
        FaultRecord(
          type: 'shrugging',
          message: 'Ưỡn ngực, hạ vai xuống, cách xa mang tai!',
          affectsForm: false, // Don't fail rep, but warn
          phase: ctx.state.name,
          priority: 2, // High priority warning for neck safety
          voiceMessage: 'Hạ vai xuống!',
        ),
      );
    }
  }
}
