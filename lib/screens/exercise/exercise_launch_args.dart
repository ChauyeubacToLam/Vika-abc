import '../../models/exercise_definition.dart';
import '../../services/recommendation/models/plan.dart';

class ExerciseLaunchArgs {
  const ExerciseLaunchArgs({
    required this.definition,
    this.catalogExerciseId,
    this.prescription,
    this.recommendationId,
    this.weekNumber,
    this.slotName,
  });

  final ExerciseDefinition definition;
  final String? catalogExerciseId;
  final VolumePrescription? prescription;
  final String? recommendationId;
  final int? weekNumber;
  final String? slotName;
}
