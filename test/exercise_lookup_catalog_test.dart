import 'package:flutter_test/flutter_test.dart';
import 'package:vika/models/exercise_lookup.dart';

void main() {
  test('all form-checked catalog exercise ids resolve to definitions', () {
    // Mirrors the currently form-checked catalog rows.
    const catalogIds = [
      'bird_dog',
      'dead_bug',
      'glute_bridge',
      'high_plank',
      'jumping_jack',
      'mcgill_curlup',
      'plank',
      'reverse_crunch',
      'situp',
      'standing_knee_to_elbow',
      'superman',
      'wall_pushup',
      'bear_plank',
      'leg_raises',
      'lunge',
      'mountain_climber',
      'plank_shoulder_tap',
      'plank_up_down',
      'push_up',
      'russian_twist',
      'side_plank_dip',
      'squat',
      'step_back_burpee',
      'tricep_dip',
      'walking_lunge',
      'cossack_squat',
      'jump_squat',
      'vup',
      'butterfly',
      'cobra',
      'seated_forward_fold',
      'sphinx',
      'bow_pose',
      'warrior_one',
    ];

    final unresolved = [
      for (final id in catalogIds)
        if (lookupExerciseDefinition(id) == null) id,
    ];

    expect(unresolved, isEmpty);
  });

  test('catalog id aliases resolve to stable definition ids', () {
    expect(lookupExerciseDefinition('butterfly')!.id, 'butterfly__stretch');
    expect(lookupExerciseDefinition('tricep_dip')!.id, 'tricep__dip_(_floor)');
    expect(
      lookupExerciseDefinition('side_plank_dip')!.id,
      'side__plank_with__hip__dip',
    );
    expect(lookupExerciseDefinition('bow_pose')!.id, 'bow_');
  });
}
