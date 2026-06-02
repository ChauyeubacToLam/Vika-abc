import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/models/exercise_definition.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/models/workout_session_report.dart';
import 'package:vika/services/session_trophy_picker.dart';

void main() {
  test('all-time session PB fires', () {
    final trophy = SessionTrophyPicker.pick(
      reports: [
        _report(name: 'Squat', formScore: 72, totalReps: 10),
      ],
      sessionRawFormScore: 84,
      streakDays: 0,
      priorSessionForms: const [68, 76, 80],
      priorExerciseForms: const {},
    );

    expect(trophy.tier, TrophyTier.allTimePb);
    expect(trophy.value, '84');
    expect(trophy.label, 'Buổi sạch nhất từ trước tới giờ');
    expect(trophy.tag, 'KỶ LỤC');
    expect(trophy.exerciseName, isNull);
  });

  test('larger all-time exercise PB beats session PB', () {
    final trophy = SessionTrophyPicker.pick(
      reports: [
        _report(name: 'Squat', formScore: 90, totalReps: 10),
      ],
      sessionRawFormScore: 74,
      streakDays: 0,
      priorSessionForms: const [70],
      priorExerciseForms: const {
        'squat': [75, 82],
      },
    );

    expect(trophy.tier, TrophyTier.allTimePb);
    expect(trophy.value, '90');
    expect(trophy.label, 'Squat sạch nhất từ trước tới giờ');
    expect(trophy.tag, 'KỶ LỤC');
    expect(trophy.exerciseName, 'Squat');
  });

  test('exercise PB history uses persisted exercise key, not definition id',
      () {
    final trophy = SessionTrophyPicker.pick(
      reports: [
        _report(
          id: 'curl_up',
          exerciseKey: 'mcgill_curlup',
          name: 'Curl Up',
          formScore: 75,
          totalReps: 10,
        ),
      ],
      sessionRawFormScore: 75,
      streakDays: 0,
      priorSessionForms: const [100],
      priorExerciseForms: const {
        'mcgill_curlup': [68],
      },
    );

    expect(trophy.tier, TrophyTier.allTimePb);
    expect(trophy.value, '75');
    expect(trophy.exerciseName, 'Curl Up');
  });

  test('recent PB fires when recent bar is beaten but all-time is not', () {
    final trophy = SessionTrophyPicker.pick(
      reports: [
        _report(name: 'Squat', formScore: 50, totalReps: 10),
      ],
      sessionRawFormScore: 78,
      streakDays: 0,
      priorSessionForms: const [95, 70, 72, 73, 74, 75],
      priorExerciseForms: const {},
    );

    expect(trophy.tier, TrophyTier.recentPb);
    expect(trophy.value, '78');
    expect(trophy.label, 'Phong độ cao nhất 5 buổi gần đây');
    expect(trophy.tag, 'PHONG ĐỘ');
    expect(trophy.exerciseName, isNull);
  });

  test('streak milestone fires exactly at 7 but not at 5 or 6', () {
    final milestone = SessionTrophyPicker.pick(
      reports: [
        _report(name: 'Squat', formScore: 40, totalReps: 10),
      ],
      sessionRawFormScore: 40,
      streakDays: 7,
      priorSessionForms: const [],
      priorExerciseForms: const {},
    );

    final fiveDays = SessionTrophyPicker.pick(
      reports: [
        _report(name: 'Squat', formScore: 40, totalReps: 10),
      ],
      sessionRawFormScore: 40,
      streakDays: 5,
      priorSessionForms: const [],
      priorExerciseForms: const {},
    );

    final sixDays = SessionTrophyPicker.pick(
      reports: [
        _report(name: 'Squat', formScore: 40, totalReps: 10),
      ],
      sessionRawFormScore: 40,
      streakDays: 6,
      priorSessionForms: const [],
      priorExerciseForms: const {},
    );

    expect(milestone.tier, TrophyTier.streakMilestone);
    expect(milestone.value, '7');
    expect(milestone.label, '7 ngày liên tiếp');
    expect(milestone.tag, 'CHUỖI');

    expect(fiveDays.tier, isNot(TrophyTier.streakMilestone));
    expect(sixDays.tier, isNot(TrophyTier.streakMilestone));
  });

  test('week-1 no-history falls through to within-session tier', () {
    final trophy = SessionTrophyPicker.pick(
      reports: [
        _report(name: 'Squat', formScore: 90, totalReps: 10),
      ],
      sessionRawFormScore: 90,
      streakDays: 0,
      priorSessionForms: const [],
      priorExerciseForms: const {},
    );

    expect(trophy.tier, TrophyTier.cleanSession);
    expect(trophy.value, '90');
    expect(trophy.label, 'Cả buổi sạch form');
  });

  test('clean session distinguishes flawless from standout', () {
    final flawless = SessionTrophyPicker.pick(
      reports: [
        _report(name: 'Squat', formScore: 85, totalReps: 10),
        _report(name: 'Push Up', formScore: 90, totalReps: 10),
      ],
      sessionRawFormScore: 88,
      streakDays: 0,
      priorSessionForms: const [],
      priorExerciseForms: const {},
    );

    final standout = SessionTrophyPicker.pick(
      reports: [
        _report(name: 'Squat', formScore: 84, totalReps: 10),
        _report(name: 'Push Up', formScore: 86, totalReps: 10),
      ],
      sessionRawFormScore: 84,
      streakDays: 0,
      priorSessionForms: const [],
      priorExerciseForms: const {},
    );

    expect(flawless.tier, TrophyTier.cleanSession);
    expect(flawless.value, '88');
    expect(flawless.label, 'Cả buổi sạch form');
    expect(flawless.tag, 'SẠCH');
    expect(flawless.exerciseName, isNull);

    expect(standout.tier, TrophyTier.cleanSession);
    expect(standout.value, '86');
    expect(standout.label, 'Push Up form đỉnh');
    expect(standout.tag, 'ĐỈNH');
    expect(standout.exerciseName, 'Push Up');
  });

  test('volume fires at the floor but not just below it', () {
    final belowFloor = SessionTrophyPicker.pick(
      reports: [
        _report(name: 'Squat', formScore: 40, totalReps: 40, goodReps: 29),
      ],
      sessionRawFormScore: 40,
      streakDays: 0,
      priorSessionForms: const [],
      priorExerciseForms: const {},
    );

    final atFloor = SessionTrophyPicker.pick(
      reports: [
        _report(name: 'Squat', formScore: 40, totalReps: 40, goodReps: 30),
      ],
      sessionRawFormScore: 40,
      streakDays: 0,
      priorSessionForms: const [],
      priorExerciseForms: const {},
    );

    expect(belowFloor.tier, TrophyTier.showedUp);
    expect(atFloor.tier, TrophyTier.volume);
    expect(atFloor.value, '30');
    expect(atFloor.label, '30 rep đúng form');
    expect(atFloor.tag, 'KHỐI LƯỢNG');
  });

  test('zero-work fallback returns showedUp without throwing', () {
    final trophy = SessionTrophyPicker.pick(
      reports: const [],
      sessionRawFormScore: 0,
      streakDays: 0,
      priorSessionForms: const [],
      priorExerciseForms: const {},
    );

    expect(trophy.tier, TrophyTier.showedUp);
    expect(trophy.value, '1');
    expect(trophy.label, 'Có mặt là thắng rồi');
    expect(trophy.tag, 'CÓ MẶT');
    expect(trophy.exerciseName, isNull);
  });
}

ExerciseSessionReport _report({
  required String name,
  required int formScore,
  String? id,
  String? exerciseKey,
  int? totalReps,
  int? goodReps,
}) {
  final definitionId = id ?? name.toLowerCase().replaceAll(' ', '_');
  return ExerciseSessionReport(
    definition: _definition(
      id: definitionId,
      name: name,
    ),
    exerciseKey: exerciseKey ?? definitionId,
    report: PostExerciseData(
      exerciseName: name,
      metValue: 1,
      sets: [
        SetReportData(
          setIndex: 0,
          score: formScore,
          totalReps: totalReps,
          goodReps: goodReps ?? totalReps,
          repResults: List<bool>.filled(totalReps ?? 0, true),
        ),
      ],
      formScore: formScore,
      coachText: '',
    ),
    duration: Duration.zero,
    calories: 0,
  );
}

ExerciseDefinition _definition({
  required String id,
  required String name,
}) {
  return ExerciseDefinition(
    id: id,
    name: name,
    subtitle: '',
    description: '',
    icon: Icons.fitness_center,
    primaryColor: Colors.black,
    secondaryColor: Colors.white,
    difficulty: '',
    targetMuscles: const [],
    duration: '',
    cameraHint: '',
    framingHint: '',
    setupTips: const [],
    createExercise: () => throw UnimplementedError(),
    phaseColors: const {},
  );
}
