import 'package:vika/utils/exercise_logger.dart';
import 'metrics/limb_elevation_metric.dart';
import 'metrics/hip_grounding_metric.dart';
import 'metrics/hold_time_metric.dart';
import 'metrics/lumbar_extension_metric.dart'; // Thêm import

class SupermanReportBuilder {
  static Map<String, dynamic> build({
    required List<RepLog> repLogs,
    required Map<String, dynamic> setLogs,
    required LimbElevationMetric elevationMetric,
    required HipGroundingMetric hipMetric,
    required HoldTimeMetric holdMetric,
    required LumbarExtensionMetric lumbarMetric, // Fix #7: Thêm tham số
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
      'lumbar_fails': lumbarMetric.faultsCount, // Fix #7: Thêm stat
    };
  }
}