import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/report_builder_registry.dart';

void main() {
  group('resolveReportBuilder', () {
    test('resolves direct registry ids for scoped exercises', () {
      final cases = <String, String>{
        'bird_dog': 'BirdDogReportBuilder',
        'sit_up': 'SitUpReportBuilder',
        'high_plank': 'HighPlankReportBuilder',
        'superman': 'SupermanReportBuilder',
        'butterfly_stretch': 'ButterflyReportBuilder',
        'v_up': 'VUpReportBuilder',
        'dead_bug': 'DeadBugReportBuilder',
        'plank_up_down': 'PlankUpDownReportBuilder',
        'bear_plank': 'BearPlankReportBuilder',
        'plank': 'PlankReportBuilder',
        'warrior_one': 'WarriorOneReportBuilder',
        'sphinx_': 'SphinxReportBuilder',
        'walking_lunge': 'WalkingLungeReportBuilder',
      };

      for (final entry in cases.entries) {
        expect(
          resolveReportBuilder(entry.key)?.builder.runtimeType.toString(),
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
        'butterfly__stretch': 'ButterflyReportBuilder',
        'v__up': 'VUpReportBuilder',
        'dead__bug': 'DeadBugReportBuilder',
        'plank__up__down': 'PlankUpDownReportBuilder',
        'bear__plank': 'BearPlankReportBuilder',
        'warrior__one': 'WarriorOneReportBuilder',
        'sphinx_': 'SphinxReportBuilder',
        'walking__lunge': 'WalkingLungeReportBuilder',
      };

      for (final entry in cases.entries) {
        expect(
          resolveReportBuilder(entry.key)?.builder.runtimeType.toString(),
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
        'Sphinx Pose': 'SphinxReportBuilder',
        'Walking Lunge': 'WalkingLungeReportBuilder',
        'walkinglunge': 'WalkingLungeReportBuilder',
      };

      for (final entry in cases.entries) {
        expect(
          resolveReportBuilder(entry.key)?.builder.runtimeType.toString(),
          entry.value,
          reason: '${entry.key} should resolve ${entry.value}',
        );
      }
    });

    test('returns null for unknown exercise id', () {
      expect(resolveReportBuilder('not_a_real_exercise'), isNull);
    });
  });
}
