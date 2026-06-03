// ProgramPlanMapper — maps the engine-side PlanSnapshot to the UI-side
// ProgramPlan that the redesigned (completion-anchored) Plan screen renders.
//
// PURE by design: no Supabase, no async. The caller fetches the snapshot and
// the catalog name/AI lookup, then calls this. That keeps the mapper unit-
// testable and mirrors how WorkoutLaunchService resolves catalog info
// separately from its pure logic.
//
// STATUS is not stored anywhere — it is DERIVED from the same completion rule
// as PlanSnapshot.currentPosition (the first incomplete (week, session)).
// Reusing that one rule keeps Plan / Home / retest consistent by construction.
//
// COPY is static v1 (block/session/retest coach notes, focus). Dynamic coach
// text comes later from the three-pillar aggregator.

import '../../data/program_mock.dart';
import 'models/plan.dart';
import 'recommendation_service.dart'; // PlanSnapshot + ExerciseLaunchCatalogInfo
import '../workout_launch_service.dart'; // workoutVolumeLabel

class ProgramPlanMapper {
  const ProgramPlanMapper._();

  /// Build the UI ProgramPlan from the engine snapshot.
  ///
  /// [catalogById] resolves exercise_id -> display name + isFormChecked.
  /// Caller fetches it via RecommendationService.fetchLaunchCatalogInfo
  /// ForExerciseIds over every exercise_id in the plan.
  ///
  /// [ledgerResults] is keyed by `(weekNumber, sessionIndex)` and contains
  /// completed workout summaries + per-exercise rows fetched by the caller.
  static ProgramPlan fromSnapshot(
    PlanSnapshot snapshot, {
    required Map<String, ExerciseLaunchCatalogInfo> catalogById,
    PlanLedgerSessionResults ledgerResults = const {},
    String programTitle = '',
  }) {
    final plan = snapshot.plan;
    final completion = snapshot.completionMap;
    // The single first-incomplete (week, sessionIndex), or null = plan done.
    final current = snapshot.currentPosition;

    final blocks = plan.weeks
        .map((week) => _mapBlock(
              week,
              completion,
              current,
              catalogById,
              ledgerResults,
            ))
        .toList(growable: false);

    return ProgramPlan(
      programTitle: programTitle,
      blocks: blocks,
      retest: _mapRetest(plan.endOfPlanRetest, current, catalogById),
    );
  }

  // ── Status (the one completion rule, reused) ──────────────────────────────

  /// A session is done if its index is in the week's completion set; it is the
  /// single `current` iff it equals currentPosition; everything else upcoming.
  static ProgramStatus _sessionStatus(
    int weekNumber,
    int sessionIndex,
    Map<int, Set<int>> completion,
    (int, int)? current,
  ) {
    final done = completion[weekNumber]?.contains(sessionIndex) ?? false;
    if (done) return ProgramStatus.done;
    if (current != null &&
        current.$1 == weekNumber &&
        current.$2 == sessionIndex) {
      return ProgramStatus.current;
    }
    return ProgramStatus.upcoming;
  }

  /// A block is done when all its sessions are done; current when it holds the
  /// current session; upcoming otherwise. Falls out of the session rule, so it
  /// can never disagree with it.
  static ProgramStatus _blockStatus(
    List<ProgramStatus> sessionStatuses,
  ) {
    if (sessionStatuses.isEmpty) return ProgramStatus.upcoming;
    final allDone = sessionStatuses.every((s) => s == ProgramStatus.done);
    if (allDone) return ProgramStatus.done;
    final hasCurrent = sessionStatuses.any((s) => s == ProgramStatus.current);
    return hasCurrent ? ProgramStatus.current : ProgramStatus.upcoming;
  }

  // ── Block / session / exercise mapping ────────────────────────────────────

  static ProgramBlock _mapBlock(
    WeekPlan week,
    Map<int, Set<int>> completion,
    (int, int)? current,
    Map<String, ExerciseLaunchCatalogInfo> catalogById,
    PlanLedgerSessionResults ledgerResults,
  ) {
    final sessions = week.sessions.map((session) {
      final status = _sessionStatus(
        week.weekNumber,
        session.sessionIndex,
        completion,
        current,
      );
      final ledgerResult = status == ProgramStatus.done
          ? ledgerResults[(week.weekNumber, session.sessionIndex)]
          : null;
      final exerciseDifficulties = ledgerResult?.exercises.values
          .map((result) => _difficultyFromDb(result.difficulty));
      return PlanSession(
        index: session.sessionIndex,
        label: 'Buổi ${(session.sessionIndex + 1).toString().padLeft(2, '0')}',
        status: status,
        coachNote: _sessionCoachNote(status, week.isDeloadWeek),
        formScore: ledgerResult?.sessionFormScore,
        difficulty: _modalDifficulty(exerciseDifficulties ?? const []),
        exercises: session.slots
            .map((slot) => _mapExercise(
                  slot,
                  catalogById,
                  result: ledgerResult?.exercises[slot.exerciseId],
                ))
            .toList(growable: false),
      );
    }).toList(growable: false);

    return ProgramBlock(
      blockNumber: week.weekNumber,
      phaseNumber: week.phaseNumber,
      phaseName: week.phaseName,
      isDeload: week.isDeloadWeek,
      status: _blockStatus(sessions.map((s) => s.status).toList()),
      // STUB (copy pass): body-focus label. Empty renders no focus chip.
      focusLabel: week.isDeloadWeek ? 'Phục hồi' : '',
      coachNote: _blockCoachNote(week.isDeloadWeek),
      sessions: sessions,
    );
  }

  static SessionExercise _mapExercise(
    SlotAssignment slot,
    Map<String, ExerciseLaunchCatalogInfo> catalogById, {
    PlanLedgerExerciseResult? result,
  }) {
    final info = catalogById[slot.exerciseId];
    return SessionExercise(
      name: info?.vietnameseName ?? slot.exerciseId,
      volumeLabel: workoutVolumeLabel(slot.volume),
      exerciseId: slot.exerciseId,
      hasAi: info?.isFormChecked ?? false,
      formScore: result?.formScore,
      difficulty: _difficultyFromDb(result?.difficulty),
    );
  }

  static SessionDifficulty? _difficultyFromDb(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'light' => SessionDifficulty.light,
      'medium' => SessionDifficulty.moderate,
      'heavy' => SessionDifficulty.hard,
      _ => null,
    };
  }

  static SessionDifficulty? _modalDifficulty(
    Iterable<SessionDifficulty?> values,
  ) {
    final counts = <SessionDifficulty, int>{};
    for (final value in values) {
      if (value == null) continue;
      counts[value] = (counts[value] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;

    SessionDifficulty? best;
    var bestCount = -1;
    for (final entry in counts.entries) {
      final currentRank = _difficultyRank(entry.key);
      final bestRank = best == null ? -1 : _difficultyRank(best);
      if (entry.value > bestCount ||
          (entry.value == bestCount && currentRank > bestRank)) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    return best;
  }

  static int _difficultyRank(SessionDifficulty difficulty) {
    return switch (difficulty) {
      SessionDifficulty.light => 0,
      SessionDifficulty.moderate => 1,
      SessionDifficulty.hard => 2,
    };
  }

  // ── Retest beat ───────────────────────────────────────────────────────────

  static ProgramRetest? _mapRetest(
    PlanRetest? retest,
    (int, int)? current,
    Map<String, ExerciseLaunchCatalogInfo> catalogById,
  ) {
    if (retest == null) return null; // phase_1_only plans have no retest
    // Unlocked exactly when every block is done (currentPosition == null).
    final status =
        current == null ? ProgramStatus.current : ProgramStatus.upcoming;
    return ProgramRetest(
      title: retest.vietnameseTitle,
      description: retest.vietnameseDescription,
      coachNote: _retestCoachNote,
      status: status,
      // NOTE: empty for plans reconstructed from stored end_retest JSON
      // (which only carries trigger_week + scoring_version). The retest
      // SCREEN drives its own squat + wall push-up assessment regardless.
      exercises: retest.exercises
          .map((e) => SessionExercise(
                name: e.vietnameseName,
                volumeLabel: '${e.durationSeconds} giây',
                exerciseId: e.exerciseId,
                hasAi: catalogById[e.exerciseId]?.isFormChecked ?? false,
              ))
          .toList(growable: false),
    );
  }

  // ── Static v1 copy ──────────────────────────────────────────────────────

  static String _blockCoachNote(bool isDeload) => isDeload
      ? 'Tuần này nhẹ hơn có chủ đích. Giữ form sạch, thở đều và để cơ thể hồi lại nhé.'
      : 'Bài tập giữ quen thuộc, mục tiêu tăng vừa đủ để bạn thấy tiến bộ mà không bị quá sức.';

  static String _sessionCoachNote(ProgramStatus status, bool isDeload) {
    switch (status) {
      case ProgramStatus.current:
        return 'Buổi tiếp theo của bạn đây. Vào nhẹ nhàng, giữ nhịp thở đều nhé.';
      case ProgramStatus.upcoming:
        return 'Sẽ mở khi bạn hoàn thành các buổi trước. Cứ từ từ.';
      case ProgramStatus.done:
        // STUB (summary pass): swap for the persisted WorkoutSummary coach note.
        return isDeload
            ? 'Buổi phục hồi đã xong. Cơ thể có khoảng nghỉ tốt.'
            : 'Buổi này hoàn tất. Giữ đều như vậy là bạn đang đi đúng hướng.';
    }
  }

  static const String _retestCoachNote =
      'Hoàn thành lộ trình rồi. Một bài kiểm tra ngắn để Vika cập nhật chặng tiếp theo cho bạn.';
}
