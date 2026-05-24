import '../../models/exercise_definition.dart';
import '../../services/recommendation/models/plan.dart';

class ExerciseSequenceItem {
  const ExerciseSequenceItem({
    required this.definition,
    this.catalogExerciseId,
    this.prescription,
    this.recommendationId,
    this.weekNumber,
    this.sessionIndex,
    this.slotName,
  });

  final ExerciseDefinition definition;
  final String? catalogExerciseId;
  final VolumePrescription? prescription;
  final String? recommendationId;
  final int? weekNumber;
  final int? sessionIndex;
  final String? slotName;
}

class ExerciseLaunchArgs {
  const ExerciseLaunchArgs({
    required this.definition,
    this.catalogExerciseId,
    this.prescription,
    this.recommendationId,
    this.weekNumber,
    this.sessionIndex,
    this.slotName,
    this.sequence = const [],
    this.sequenceIndex = 0,
  });

  final ExerciseDefinition definition;
  final String? catalogExerciseId;
  final VolumePrescription? prescription;
  final String? recommendationId;
  final int? weekNumber;
  final int? sessionIndex;
  final String? slotName;
  final List<ExerciseSequenceItem> sequence;
  final int sequenceIndex;

  ExerciseLaunchArgs? nextInSequence() {
    final nextIndex = sequenceIndex + 1;
    if (nextIndex >= sequence.length) return null;
    final next = sequence[nextIndex];
    return ExerciseLaunchArgs(
      definition: next.definition,
      catalogExerciseId: next.catalogExerciseId,
      prescription: next.prescription,
      recommendationId: next.recommendationId,
      weekNumber: next.weekNumber,
      sessionIndex: next.sessionIndex,
      slotName: next.slotName,
      sequence: sequence,
      sequenceIndex: nextIndex,
    );
  }
}
