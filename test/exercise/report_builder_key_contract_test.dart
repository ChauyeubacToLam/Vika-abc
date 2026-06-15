import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/report_builder_registry.dart';
import 'package:vika/models/post_exercise_data.dart';

const _canonicalPainRegions = {
  'shoulder_neck',
  'back',
  'lower_back',
  'hip',
  'wrist',
  'knee',
  'ankle',
  'other',
};

const _loggedFaultKeysByExercise = <String, Set<String>>{
  'squat': {
    'heel_fails_count',
    'depth_fails_count',
    'trunk_lean_fails_count',
    'tempo_fails_count',
    'hip_shoulder_sync_fails_count',
  },
  'squat_assessment': {
    'heel_fails_count',
    'depth_fails_count',
    'trunk_lean_fails_count',
    'tempo_fails_count',
    'hip_shoulder_sync_fails_count',
  },
  'lunge': {
    'depth_fails_count',
    'trunk_lean_fails_count',
    'heel_lift_fails_count',
    'lumbar_proxy_fails_count',
  },
  'jumping_jack': {
    'arm_fails_count',
    'leg_fails_count',
    'tempo_fails_count',
  },
  'bird_dog': {
    'lumbar_fails_count',
    'alignment_fails_count',
    'trunk_fails_count',
    'tempo_fails_count',
  },
  'sit_up': {
    'rom_fails_count',
    'jerking_fails_count',
    'stability_fails_count',
    'tempo_fails_count',
  },
  'high_plank': {
    'sagging_seconds',
    'piked_seconds',
    'elbow_seconds',
  },
  'cobra': {
    'elbow_flexion_seconds',
    'hand_placement_seconds',
    'cervical_neutrality_seconds',
    'pelvic_grounding_seconds',
  },
  'glute_bridge': {
    'hip_extension_fails_count',
    'knee_angle_fails_count',
    'speed_control_fails_count',
    'neck_head_fails_count',
  },
  'curl_up': {
    'trunk_elev_fails_count',
    'neck_pull_fails_count',
    'knee_ext_fails_count',
  },
  'bow_pose': {
    'connection_seconds',
    'lift_form_seconds',
  },
  'mountain_climber': {
    'trunk_fails_count',
    'rom_fails_count',
  },
  'plank_shoulder_tap': {
    'rotation_fails_count',
    'alignment_fails_count',
    'tap_fails_count',
    'tempo_fails_count',
  },
  'push_up': {
    'trunk_alignment_fails_count',
    'depth_fails_count',
    'tempo_fails_count',
  },
  'superman': {
    'elevation_fails_count',
    'hip_fails_count',
    'hold_fails_count',
    'lumbar_fails_count',
  },
  'leg_raise': {
    'pelvic_fails_count',
    'rom_fails_count',
    'knee_fails_count',
    'tempo_fails_count',
    'arm_position_fails_count',
  },
  'reverse_crunch': {
    'momentum_fails_count',
    'curl_fails_count',
    'tempo_fails_count',
    'arm_position_fails_count',
  },
  'v_up': {
    'sync_fails_count',
    'rom_fails_count',
    'jerking_fails_count',
    'knee_fails_count',
    'tempo_fails_count',
  },
  'dead_bug': {
    'anti_extension_fails_count',
    'coordination_fails_count',
    'stable_limbs_fails_count',
    'floor_contact_fails_count',
    'tempo_fails_count',
  },
  'plank_up_down': {
    'trunk_sagging_fails_count',
    'hip_rotation_fails_count',
    'arm_extension_fails_count',
  },
  'bear_plank': {
    'knee_seconds',
    'back_seconds',
    'weight_seconds',
  },
  'plank': {
    'trunk_seconds',
    'neck_seconds',
    'knee_seconds',
  },
  'warrior_one': {
    'trunk_lean_seconds',
    'cervical_seconds',
    'arm_seconds',
    'back_knee_seconds',
    'back_straight_seconds',
  },
  'butterfly_stretch': {
    'knee_seconds',
    'posture_seconds',
    'foot_placement_seconds',
  },
  'seated_forward_fold': {
    'knee_bent_seconds',
    'spine_round_seconds',
  },
  'cossack_squat': {
    'knee_valgus_fails_count',
    'heel_lift_fails_count',
    'depth_fails_count',
    'straight_leg_fails_count',
    'torso_lean_fails_count',
  },
  'walking_lunge': {
    'step_consistency_fails_count',
    'front_knee_fails_count',
    'rear_depth_fails_count',
    'torso_lean_fails_count',
  },
  'tricep_dip': {
    'hip_thrust_fails_count',
    'rom_fails_count',
    'extension_fails_count',
    'shrugging_fails_count',
  },
  'russian_twist': {
    'thoracic_fails_count',
    'knee_wobble_fails_count',
    'rom_fails_count',
  },
  'sphinx': {
    'hip_seconds',
    'straight_arm_seconds',
    'shrug_neck_seconds',
  },
  'standing_knee_to_elbow': {
    'knee_valgus_fails_count',
    'core_drive_fails_count',
    'cross_rom_fails_count',
    'pelvic_drop_fails_count',
  },
  'surya_namaskar': {
    'total_safety_triggers',
  },
  'wall_push_up': {
    'body_line_fails_count',
    'shoulder_shrug_fails_count',
    'forward_head_fails_count',
    'elbow_flare_fails_count',
    'cervical_extension_fails_count',
    'foot_stationary_fails_count',
    'wall_contact_fails_count',
    'tempo_fails_count',
  },
  'downward_dog': {
    'spine_round_seconds',
    'shoulder_shrug_seconds',
    'leg_straightness_seconds',
  },
  'ashtanga_namaskara': {
    'hip_collapse_fails_count',
    'cervical_fails_count',
  },
  'low_lunge': {
    'knee_travel_fails_count',
    'cervical_fails_count',
  },
  'prayer_pose': {
    'posture_stack_fails_count',
  },
  'raised_arms': {
    'lumbar_backbend_fails_count',
    'cervical_fails_count',
    'arm_position_fails_count',
  },
  'jump_squat': {
    'stiff_landing_fails_count',
    'shallow_dip_fails_count',
    'trunk_lean_fails_count',
  },
  'side_plank_dip': {
    'shoulder_align_fails_count',
    'rotation_fails_count',
    'dip_depth_fails_count',
  },
  'step_back_burpee': {
    'spine_fails_count',
    'plank_form_fails_count',
  },
};

const _secondBasedExerciseIds = {
  'high_plank',
  'cobra',
  'bear_plank',
  'plank',
  'warrior_one',
  'butterfly_stretch',
  'seated_forward_fold',
  'sphinx',
  'downward_dog',
  'bow_pose',
};

void main() {
  group('report builder key contract', () {
    test('covers every registered report builder entry', () {
      expect(
        _loggedFaultKeysByExercise.keys,
        unorderedEquals(reportBuilders.keys),
      );
    });

    test('builder fault keys are written by their exercise logger', () {
      for (final entry in reportBuilders.entries) {
        final builder = entry.value.builder;
        final loggedKeys = _loggedFaultKeysByExercise[entry.key]!;
        final readKeys = <String>{
          ...builder.faultToTipMap().keys,
          ...builder.praiseMetricNames().keys,
          ...builder.criticalMetrics(),
          for (final keys in builder.painToFaultMap().values) ...keys,
        };

        expect(
          readKeys.difference(loggedKeys),
          isEmpty,
          reason: '${entry.key} reads keys not pushed in onSetComplete',
        );

        final loggedFaultCountKeys =
            loggedKeys.where((key) => key.endsWith('_fails_count')).toSet();
        expect(
          loggedFaultCountKeys.difference(readKeys),
          isEmpty,
          reason: '${entry.key} pushes fault-count keys not used by builder',
        );
      }
    });

    test('pain maps use canonical pain region ids', () {
      for (final entry in reportBuilders.entries) {
        final painKeys = builderPainKeys(entry.value.builder);

        expect(
          painKeys.difference(_canonicalPainRegions),
          isEmpty,
          reason: '${entry.key} has non-canonical pain keys',
        );
      }
    });

    test('second-based builders match exercises that log seconds', () {
      for (final entry in reportBuilders.entries) {
        expect(
          entry.value.builder.isSecondBased,
          _secondBasedExerciseIds.contains(entry.key),
          reason: '${entry.key} has wrong report scoring modality',
        );
      }
    });

    test('custom praise sentence keys match praise metric labels', () {
      for (final entry in reportBuilders.entries) {
        final builder = entry.value.builder;
        final sentenceKeys = builder.praiseSentenceMap().keys.toSet();
        if (sentenceKeys.isEmpty) continue;

        expect(
          sentenceKeys,
          builder.praiseMetricNames().values.toSet(),
          reason: '${entry.key} praiseSentenceMap keys must be metric labels',
        );
      }
    });
  });
}

Set<String> builderPainKeys(ExerciseReportBuilder builder) =>
    builder.painToFaultMap().keys.toSet();
