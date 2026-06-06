import 'exercise_definition.dart';

ExerciseDefinition? lookupExerciseDefinition(String query) {
  final normalizedQuery = normalizeExerciseKey(_exerciseAlias(query));

  for (final definition in exerciseDefinitions) {
    if (normalizeExerciseKey(definition.id) == normalizedQuery ||
        normalizeExerciseKey(definition.name) == normalizedQuery) {
      return definition;
    }
  }

  return null;
}

String _exerciseAlias(String value) {
  return switch (normalizeExerciseKey(value)) {
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
    'wallpushup' => 'wall_push_up',
    'wallpushups' => 'wall_push_up',
    'wallpushupbw' => 'wall_push_up',
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
    'birddog' => 'bird__dog',
    'vup' => 'v__up',
    'deadbug' => 'dead__bug',
    'plankupdown' => 'plank__up__down',
    'bearplank' => 'bear__plank',
    'situp' => 'sit__up',
    'highplank' => 'high__plank',
    'mountainclimber' => 'mountain__climber',
    'superman' => 'superman',
    'plankshouldertap' => 'plank__shoulder__tap',
    'legraises' => 'leg__raises',
    'reversecrunch' => 'reverse__crunch',
    'bowpose' => 'bow_',
    'butterflystretch' => 'butterfly__stretch',
    'cobrapose' => 'cobra_',
    'cossacksquat' => 'cossack__squat',
    'jumpsquat' => 'jump__squat',
    'russiantwist' => 'russian__twist',
    'seatedforwardfold' => 'seated__forward__fold',
    'sideplankwithhipdip' => 'side__plank_with__hip__dip',
    'sphinxpose' => 'sphinx_',
    'standingkneetoelbow' => 'standing__knee_to__elbow',
    'stepbackburpee' => 'step__back__burpee',
    'tricepdipfloor' => 'tricep__dip_(_floor)',
    'walkinglunge' => 'walking__lunge',
    _ => value,
  };
}

String normalizeExerciseKey(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
