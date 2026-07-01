import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/report_builder_registry.dart';
import 'package:vika/models/exercise_lookup.dart';

void main() {
  group('resolveReportBuilder', () {
    test('resolves direct registry ids for scoped exercises', () {
      final cases = <String, String>{
        'bird_dog': 'BirdDogReportBuilder',
        'lunge': 'LungeReportBuilder',
        'jumping_jack': 'JumpingJackReportBuilder',
        'sit_up': 'SitUpReportBuilder',
        'high_plank': 'HighPlankReportBuilder',
        'cobra': 'CobraReportBuilder',
        'glute_bridge': 'GluteBridgeReportBuilder',
        'curl_up': 'CurlUpReportBuilder',
        'bow_pose': 'BowPoseReportBuilder',
        'mountain_climber': 'MountainClimberReportBuilder',
        'plank_shoulder_tap': 'PlankShoulderTapReportBuilder',
        'push_up': 'PushUpReportBuilder',
        'superman': 'SupermanReportBuilder',
        'butterfly_stretch': 'ButterflyReportBuilder',
        'v_up': 'VUpReportBuilder',
        'dead_bug': 'DeadBugReportBuilder',
        'plank_up_down': 'PlankUpDownReportBuilder',
        'bear_plank': 'BearPlankReportBuilder',
        'plank': 'PlankReportBuilder',
        'warrior_one': 'WarriorOneReportBuilder',
        'sphinx': 'SphinxReportBuilder',
        'walking_lunge': 'WalkingLungeReportBuilder',
        'surya_namaskar': 'GenericReportBuilder',
        'downward_dog': 'DownwardDogReportBuilder',
        'ashtanga_namaskara': 'AshtangaNamaskaraReportBuilder',
        'low_lunge': 'LowLungeReportBuilder',
        'prayer_pose': 'PrayerPoseReportBuilder',
        'raised_arms': 'RaisedArmsReportBuilder',
        'jump_squat': 'JumpSquatReportBuilderV2',
        'side_plank_dip': 'SidePlankDipReportBuilderV2',
        'step_back_burpee': 'StepBackBurpeeReportBuilderV2',
      };

      for (final entry in cases.entries) {
        expect(
          resolveReportBuilder(entry.key).builder.runtimeType.toString(),
          entry.value,
          reason: '${entry.key} should resolve ${entry.value}',
        );
      }
    });

    test('resolves definition ids with double underscores', () {
      final cases = <String, String>{
        'bird__dog': 'BirdDogReportBuilder',
        'sit__up': 'SitUpReportBuilder',
        'high__plank': 'HighPlankReportBuilder',
        'bow_': 'BowPoseReportBuilder',
        'cobra_': 'CobraReportBuilder',
        'jump__squat': 'JumpSquatReportBuilderV2',
        'mountain__climber': 'MountainClimberReportBuilder',
        'plank__shoulder__tap': 'PlankShoulderTapReportBuilder',
        'butterfly__stretch': 'ButterflyReportBuilder',
        'v__up': 'VUpReportBuilder',
        'dead__bug': 'DeadBugReportBuilder',
        'plank__up__down': 'PlankUpDownReportBuilder',
        'bear__plank': 'BearPlankReportBuilder',
        'side__plank_with__hip__dip': 'SidePlankDipReportBuilderV2',
        'warrior__one': 'WarriorOneReportBuilder',
        'sphinx_': 'SphinxReportBuilder',
        'step__back__burpee': 'StepBackBurpeeReportBuilderV2',
        'tricep__dip_(_floor)': 'TricepDipReportBuilder',
        'walking__lunge': 'WalkingLungeReportBuilder',
      };

      for (final entry in cases.entries) {
        expect(
          resolveReportBuilder(entry.key).builder.runtimeType.toString(),
          entry.value,
          reason: '${entry.key} should normalize to ${entry.value}',
        );
      }
    });

    test('resolves display names and compact aliases', () {
      final cases = <String, String>{
        'V-Up': 'VUpReportBuilder',
        'Dead Bug': 'DeadBugReportBuilder',
        'Bear Plank': 'BearPlankReportBuilder',
        'Warrior I': 'WarriorOneReportBuilder',
        'Warrior 1': 'WarriorOneReportBuilder',
        'Bow Pose': 'BowPoseReportBuilder',
        'Side Plank with Hip Dip': 'SidePlankDipReportBuilderV2',
        'Butterfly': 'ButterflyReportBuilder',
        'Leg Raises': 'LegRaiseReportBuilder',
        'McGill Curl-up': 'CurlUpReportBuilder',
        'Sphinx Pose': 'SphinxReportBuilder',
        'Walking Lunge': 'WalkingLungeReportBuilder',
        'walkinglunge': 'WalkingLungeReportBuilder',
      };

      for (final entry in cases.entries) {
        expect(
          resolveReportBuilder(entry.key).builder.runtimeType.toString(),
          entry.value,
          reason: '${entry.key} should resolve ${entry.value}',
        );
      }
    });

    test('catalog class keys resolve through the live definition path', () {
      final cases = <String, ({String type, double met})>{
        'bear_plank': (type: 'BearPlankReportBuilder', met: 3.5),
        'bird_dog': (type: 'BirdDogReportBuilder', met: 3.5),
        'butterfly': (type: 'ButterflyReportBuilder', met: 2.5),
        'cobra': (type: 'CobraReportBuilder', met: 2.5),
        'dead_bug': (type: 'DeadBugReportBuilder', met: 3.0),
        'glute_bridge': (type: 'GluteBridgeReportBuilder', met: 3.5),
        'bow_pose': (type: 'BowPoseReportBuilder', met: 2.5),
        'high_plank': (type: 'HighPlankReportBuilder', met: 3.5),
        'jump_squat': (type: 'JumpSquatReportBuilderV2', met: 8.0),
        'jumping_jack': (type: 'JumpingJackReportBuilder', met: 8.0),
        'leg_raises': (type: 'LegRaiseReportBuilder', met: 3.5),
        'low_lunge': (type: 'LowLungeReportBuilder', met: 2.5),
        'lunge': (type: 'LungeReportBuilder', met: 5.0),
        'mcgill_curlup': (type: 'CurlUpReportBuilder', met: 3.0),
        'mountain_climber': (type: 'MountainClimberReportBuilder', met: 7.0),
        'plank_shoulder_tap': (type: 'PlankShoulderTapReportBuilder', met: 4.0),
        'plank_up_down': (type: 'PlankUpDownReportBuilder', met: 4.5),
        'prayer_pose': (type: 'PrayerPoseReportBuilder', met: 1.5),
        'push_up': (type: 'PushUpReportBuilder', met: 3.8),
        'raised_arms': (type: 'RaisedArmsReportBuilder', met: 2.0),
        'reverse_crunch': (type: 'ReverseCrunchReportBuilder', met: 3.5),
        'seated_forward_fold': (type: 'SeatedForwardReportBuilder', met: 2.5),
        'Side Plank with Hip Dip': (
          type: 'SidePlankDipReportBuilderV2',
          met: 3.5
        ),
        'situp': (type: 'SitUpReportBuilder', met: 3.8),
        'sphinx': (type: 'SphinxReportBuilder', met: 2.5),
        'squat': (type: 'SquatReportBuilder', met: 5.0),
        'step_back_burpee': (type: 'StepBackBurpeeReportBuilderV2', met: 8.0),
        'superman': (type: 'SupermanReportBuilder', met: 3.5),
        'surya_namaskar': (type: 'GenericReportBuilder', met: 3.5),
        'vup': (type: 'VUpReportBuilder', met: 4.0),
        'wall_pushup': (type: 'WallPushUpReportBuilder', met: 3.0),
        'warrior_one': (type: 'WarriorOneReportBuilder', met: 3.0),
        'downward_dog': (type: 'DownwardDogReportBuilder', met: 3.0),
        'ashtanga_namaskara': (
          type: 'AshtangaNamaskaraReportBuilder',
          met: 2.5
        ),
      };

      for (final entry in cases.entries) {
        final definition = lookupExerciseDefinition(entry.key);
        final resolved = definition == null
            ? resolveReportBuilder(entry.key)
            : resolveReportBuilder(definition.id);

        expect(
          resolved.builder.runtimeType.toString(),
          entry.value.type,
          reason: '${entry.key} should resolve via the live definition path',
        );
        expect(
          resolved.met,
          entry.value.met,
          reason: '${entry.key} should use the registered MET entry',
        );
      }
    });

    test('falls back to GenericReportBuilder for unknown exercise id', () {
      final resolved = resolveReportBuilder('not_a_real_exercise');

      expect(resolved.builder, isA<GenericReportBuilder>());
      expect(resolved.met, 3.5);
    });
  });
}
