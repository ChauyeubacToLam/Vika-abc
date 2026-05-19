import 'exercise_definition.dart';

ExerciseDefinition? lookupExerciseDefinition(String query) {
  final normalizedQuery = _normalizeExerciseKey(_exerciseAlias(query));

  for (final definition in exerciseDefinitions) {
    if (_normalizeExerciseKey(definition.id) == normalizedQuery ||
        _normalizeExerciseKey(definition.name) == normalizedQuery) {
      return definition;
    }
  }

  return null;
}

String _exerciseAlias(String value) {
  return switch (value) {
    'squat_bw' => 'squat',
    'bodyweight_squat' => 'squat',
    'wall_pushup' => 'push_up',
    'wall_push_up' => 'push_up',
    'pushup_wall' => 'push_up',
    'glute_bridge_bw' => 'glute_bridge',
    'mcgill_curl_up' => 'curl_up',
    'mcgill_curlup' => 'curl_up',
    _ => value,
  };
}

String _normalizeExerciseKey(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
