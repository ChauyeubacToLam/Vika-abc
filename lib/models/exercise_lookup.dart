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
  return switch (_normalizeExerciseKey(value)) {
    'airsquat' => 'squat',
    'squats' => 'squat',
    'squatbw' => 'squat',
    'bodyweightsquat' => 'squat',
    'bodyweightsquattobox' => 'squat',
    'chairsquat' => 'squat',
    'wallsquat' => 'squat',
    'squatexercise' => 'squat',
    'pushup' => 'push_up',
    'pushups' => 'push_up',
    'pushupbw' => 'push_up',
    'wallpushup' => 'push_up',
    'wallpushups' => 'push_up',
    'wallpushupbw' => 'push_up',
    'pushupwall' => 'push_up',
    'inclinepushup' => 'push_up',
    'pushupexercise' => 'push_up',
    'glutebridge' => 'glute_bridge',
    'glutebridges' => 'glute_bridge',
    'glutebridgebw' => 'glute_bridge',
    'floorglutebridge' => 'glute_bridge',
    'hipbridge' => 'glute_bridge',
    'bridge' => 'glute_bridge',
    'forearmplank' => 'plank',
    'frontplank' => 'plank',
    'plankshorthold' => 'plank',
    'plankhold' => 'plank',
    'reverse_lunge' => 'lunge',
    'reverselunge' => 'lunge',
    'split_squat' => 'lunge',
    'splitsquat' => 'lunge',
    'lunges' => 'lunge',
    'jumpingjack' => 'jumping_jack',
    'jumpingjacks' => 'jumping_jack',
    'jumpingjackexercise' => 'jumping_jack',
    'mcgillcurlup' => 'curl_up',
    'mcgillcurlups' => 'curl_up',
    'curlup' => 'curl_up',
    'warriori' => 'warrior_one',
    'warriorone' => 'warrior_one',
    'warrior1' => 'warrior_one',
    _ => value,
  };
}

String _normalizeExerciseKey(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
