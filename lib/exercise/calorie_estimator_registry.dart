import '../models/post_exercise_data.dart';
import '../models/exercise_lookup.dart';
import '../utils/exercise_logger.dart';

/// Base contract for exercise-specific calorie estimation.
///
/// Keep estimators conservative: these numbers are UI estimates, not lab-grade
/// measurements. The generic fallback uses MET, while exercise-specific
/// implementations can adjust that baseline with movement-specific signals.
abstract class ExerciseCalorieEstimator {
  const ExerciseCalorieEstimator();

  int estimateCalories({
    required List<ExerciseLogger> setLoggers,
    required PostExerciseData report,
    required double userWeightKg,
    required Duration totalDuration,
  });
}

class GenericMetCalorieEstimator extends ExerciseCalorieEstimator {
  const GenericMetCalorieEstimator();

  @override
  int estimateCalories({
    required List<ExerciseLogger> setLoggers,
    required PostExerciseData report,
    required double userWeightKg,
    required Duration totalDuration,
  }) {
    final hours = totalDuration.inSeconds <= 0
        ? 0.0
        : totalDuration.inSeconds / Duration.secondsPerHour;
    return (report.metValue * userWeightKg * hours * 1.05).round();
  }
}

/// Squat-specific estimator:
/// 1. Start from the generic MET estimate for total metabolic cost.
/// 2. Estimate per-rep displacement from measured squat depth.
/// 3. Scale the MET baseline modestly up/down based on actual depth.
///
/// This keeps the estimate stable while still rewarding deeper squats more than
/// shallow reps. It is intentionally conservative.
class SquatDepthCalorieEstimator extends ExerciseCalorieEstimator {
  const SquatDepthCalorieEstimator();

  static const double _standingKneeAngle = 170.0;
  static const double _deepSquatKneeAngle = 70.0;
  static const double _referenceDisplacementMeters = 0.30;
  static const double _minDisplacementMeters = 0.16;
  static const double _maxDisplacementMeters = 0.38;

  @override
  int estimateCalories({
    required List<ExerciseLogger> setLoggers,
    required PostExerciseData report,
    required double userWeightKg,
    required Duration totalDuration,
  }) {
    final baseline = const GenericMetCalorieEstimator().estimateCalories(
      setLoggers: setLoggers,
      report: report,
      userWeightKg: userWeightKg,
      totalDuration: totalDuration,
    );

    final peakAngles = setLoggers
        .expand((logger) => logger.repLogs)
        .map((rep) => (rep.data['peak_knee_angle'] as num?)?.toDouble())
        .whereType<double>()
        .where((value) => value > 0)
        .toList();

    if (peakAngles.isEmpty || baseline <= 0) return baseline;

    final avgDisplacement =
        peakAngles.map(_estimateDisplacementMeters).reduce((a, b) => a + b) /
            peakAngles.length;
    final depthFactor =
        (avgDisplacement / _referenceDisplacementMeters).clamp(0.78, 1.22);

    return (baseline * depthFactor).round();
  }

  double _estimateDisplacementMeters(double peakKneeAngle) {
    final normalizedDepth = ((_standingKneeAngle - peakKneeAngle) /
            (_standingKneeAngle - _deepSquatKneeAngle))
        .clamp(0.0, 1.0);
    return _minDisplacementMeters +
        ((_maxDisplacementMeters - _minDisplacementMeters) * normalizedDepth);
  }
}

/// Register a custom estimator per exercise id.
///
/// When adding a new exercise:
/// 1. Create `FooCalorieEstimator extends ExerciseCalorieEstimator`
/// 2. Add an entry here with the exercise id
/// 3. The UI will automatically use it in the executive summary
final Map<String, ExerciseCalorieEstimator> calorieEstimators = {
  'squat': const SquatDepthCalorieEstimator(),
  'squat_assessment': const SquatDepthCalorieEstimator(),
  // 'plank': const PlankCalorieEstimator(),
};

ExerciseCalorieEstimator? resolveCalorieEstimator(String exerciseId) {
  final direct = calorieEstimators[exerciseId];
  if (direct != null) return direct;

  final normalizedId = normalizeExerciseKey(exerciseId);
  for (final entry in calorieEstimators.entries) {
    if (normalizeExerciseKey(entry.key) == normalizedId) {
      return entry.value;
    }
  }
  return null;
}
