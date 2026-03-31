import 'exercise_definition.dart';

ExerciseDefinition? lookupExerciseDefinition(String query) {
  final normalizedQuery = _normalizeExerciseKey(query);

  for (final definition in exerciseDefinitions) {
    if (_normalizeExerciseKey(definition.id) == normalizedQuery ||
        _normalizeExerciseKey(definition.name) == normalizedQuery) {
      return definition;
    }
  }

  return null;
}

String _normalizeExerciseKey(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
