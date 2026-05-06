import 'package:vika/utils/exercise_logger.dart';
import 'metrics/limb_elevation_metric.dart';
import 'metrics/hip_grounding_metric.dart';
import 'metrics/hold_time_metric.dart';

class SupermanReportBuilder {
  static Map<String, dynamic> build({
    required List<RepLog> repLogs,
    required Map<String, dynamic> setLogs,
    required LimbElevationMetric elevationMetric,
    required HipGroundingMetric hipMetric,
    required HoldTimeMetric holdMetric,
  }) {
    final totalReps = repLogs.length;
    final goodReps = repLogs.where((r) => r.correctForm).length;

    return {
      'total_reps': totalReps,
      'good_reps': goodReps,
      'quality_pct': totalReps > 0 ? ((goodReps / totalReps) * 100).round() : 0,
      'elevation_fails': elevationMetric.faultsCount,
      'hip_fails': hipMetric.faultsCount,
      'hold_fails': holdMetric.faultsCount,
    };
  }
}
