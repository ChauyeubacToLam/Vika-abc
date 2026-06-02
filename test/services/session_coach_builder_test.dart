import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/session_coach_builder.dart';
import 'package:vika/services/session_trophy_picker.dart';

void main() {
  test('pain-linked fault headlines over higher-rate non-pain fault', () {
    final coach = SessionCoachBuilder.build(
      candidates: [
        _candidate(
          faultKey: 'tempo',
          rate: 0.70,
          watchCopy: 'Tempo watch',
          nextCopy: 'Tempo next',
        ),
        _candidate(
          faultKey: 'depth',
          rate: 0.20,
          isPainLinked: true,
          watchCopy: 'Depth watch',
          nextCopy: 'Depth next',
        ),
      ],
      trophy: _trophy(),
      difficulty: SessionDifficulty.moderate,
    );

    expect(coach.kind, CoachWatchKind.fault);
    expect(coach.watch, 'Depth watch');
    expect(coach.next, 'Depth next');
  });

  test(
      'cross-exercise pain fault beats non-pain fault in lower-form-score exercise',
      () {
    final coach = SessionCoachBuilder.build(
      candidates: [
        _candidate(
          exerciseId: 'squat',
          exerciseName: 'Squat',
          exerciseFormScore: 40,
          faultKey: 'depth',
          rate: 0.60,
          watchCopy: 'Squat watch',
        ),
        _candidate(
          exerciseId: 'lunge',
          exerciseName: 'Lunge',
          exerciseFormScore: 90,
          faultKey: 'heel',
          rate: 0.20,
          isPainLinked: true,
          watchCopy: 'Lunge watch',
        ),
      ],
      trophy: _trophy(),
      difficulty: SessionDifficulty.moderate,
    );

    expect(coach.watch, 'Lunge watch');
    expect(coach.watchExerciseName, 'Lunge');
  });

  test('no pain faults picks the lowest-form-score exercise top fault', () {
    final coach = SessionCoachBuilder.build(
      candidates: [
        _candidate(
          exerciseId: 'squat',
          exerciseName: 'Squat',
          exerciseFormScore: 80,
          faultKey: 'depth',
          rate: 0.90,
          watchCopy: 'Squat watch',
        ),
        _candidate(
          exerciseId: 'push_up',
          exerciseName: 'Push Up',
          exerciseFormScore: 50,
          faultKey: 'elbow',
          rate: 0.20,
          watchCopy: 'Push Up watch',
        ),
      ],
      trophy: _trophy(),
      difficulty: SessionDifficulty.moderate,
    );

    expect(coach.watch, 'Push Up watch');
    expect(coach.watchExerciseName, 'Push Up');
  });

  test('equal pain form and rate uses criticality then sort index', () {
    final criticalityCoach = SessionCoachBuilder.build(
      candidates: [
        _candidate(
          faultKey: 'tempo',
          rate: 0.40,
          criticalityRank: 2,
          sortIndex: 0,
          watchCopy: 'Tempo watch',
        ),
        _candidate(
          faultKey: 'depth',
          rate: 0.40,
          criticalityRank: 1,
          sortIndex: 3,
          watchCopy: 'Depth watch',
        ),
      ],
      trophy: _trophy(),
      difficulty: SessionDifficulty.moderate,
    );

    final sortIndexCoach = SessionCoachBuilder.build(
      candidates: [
        _candidate(
          faultKey: 'tempo',
          rate: 0.40,
          criticalityRank: 1,
          sortIndex: 5,
          watchCopy: 'Tempo watch',
        ),
        _candidate(
          faultKey: 'heel',
          rate: 0.40,
          criticalityRank: 1,
          sortIndex: 2,
          watchCopy: 'Heel watch',
        ),
      ],
      trophy: _trophy(),
      difficulty: SessionDifficulty.moderate,
    );

    expect(criticalityCoach.watch, 'Depth watch');
    expect(sortIndexCoach.watch, 'Heel watch');
  });

  test('faults below gate take perfect path with difficulty nudge', () {
    final easyCoach = SessionCoachBuilder.build(
      candidates: [
        _candidate(rate: 0.09),
      ],
      trophy: _trophy(),
      difficulty: SessionDifficulty.easy,
    );

    final moderateCoach = SessionCoachBuilder.build(
      candidates: const [],
      trophy: _trophy(),
      difficulty: SessionDifficulty.moderate,
    );

    final hardCoach = SessionCoachBuilder.build(
      candidates: [
        _candidate(rate: 0.01),
      ],
      trophy: _trophy(),
      difficulty: SessionDifficulty.hard,
    );

    expect(easyCoach.kind, CoachWatchKind.perfect);
    expect(
      easyCoach.watch,
      'Buổi tập hoàn hảo, không có gì phải chỉnh. Cứ đà này nhé!',
    );
    expect(easyCoach.next, 'Buổi sau thử thêm 2-3 rep mỗi set xem sao.');
    expect(
      moderateCoach.next,
      'Giữ nguyên mức này, buổi sau sẽ mượt hơn nữa.',
    );
    expect(hardCoach.next, 'Buổi sau cứ giữ nhịp này, cơ thể sẽ quen dần.');
  });

  test('quote composes win and the path-specific tail', () {
    final faultCoach = SessionCoachBuilder.build(
      candidates: [
        _candidate(rate: 0.10),
      ],
      trophy: _trophy(tier: TrophyTier.streakMilestone, value: '7'),
      difficulty: SessionDifficulty.moderate,
    );

    final perfectCoach = SessionCoachBuilder.build(
      candidates: const [],
      trophy: _trophy(tier: TrophyTier.cleanSession),
      difficulty: SessionDifficulty.moderate,
    );

    expect(
      faultCoach.quote,
      'Chuỗi 7 ngày, quá đỉnh! Tinh chỉnh chút xíu nữa là chuẩn.',
    );
    expect(
      perfectCoach.quote,
      'Buổi tập sạch form thật sự! Giữ vững nhé!',
    );
  });

  test('single-exercise session returns valid coach without exercise prefix',
      () {
    final coach = SessionCoachBuilder.build(
      candidates: [
        _candidate(
          exerciseId: 'squat',
          exerciseName: 'Squat',
          rate: 0.20,
          watchCopy: 'Squat watch',
        ),
        _candidate(
          exerciseId: 'squat',
          exerciseName: 'Squat',
          rate: 0.30,
          watchCopy: 'Squat tempo watch',
        ),
      ],
      trophy: _trophy(),
      difficulty: SessionDifficulty.moderate,
    );

    expect(coach.kind, CoachWatchKind.fault);
    expect(coach.watchExerciseName, isNull);
    expect(coach.watch, isNotEmpty);
    expect(coach.next, isNotEmpty);
  });
}

FaultCandidate _candidate({
  String exerciseId = 'squat',
  String exerciseName = 'Squat',
  double exerciseFormScore = 70,
  String faultKey = 'depth',
  double rate = 0.20,
  bool isPainLinked = false,
  int criticalityRank = 0,
  int sortIndex = 0,
  String watchCopy = 'Watch copy',
  String nextCopy = 'Next copy',
}) {
  return FaultCandidate(
    exerciseId: exerciseId,
    exerciseName: exerciseName,
    exerciseFormScore: exerciseFormScore,
    faultKey: faultKey,
    rate: rate,
    isPainLinked: isPainLinked,
    criticalityRank: criticalityRank,
    sortIndex: sortIndex,
    watchCopy: watchCopy,
    nextCopy: nextCopy,
  );
}

Trophy _trophy({
  TrophyTier tier = TrophyTier.showedUp,
  String value = '70',
}) {
  return Trophy(
    tier: tier,
    value: value,
    label: 'Trophy label',
    tag: 'TAG',
  );
}
