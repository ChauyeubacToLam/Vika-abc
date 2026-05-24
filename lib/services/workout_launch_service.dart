import 'package:flutter/foundation.dart';

import '../models/exercise_definition.dart';
import '../models/exercise_lookup.dart';
import '../screens/exercise/exercise_launch_args.dart';
import 'recommendation/models/plan.dart';
import 'recommendation/recommendation_service.dart';
import 'session_persistence.dart';

class WorkoutLaunchTarget {
  const WorkoutLaunchTarget({
    required this.snapshot,
    required this.week,
    required this.session,
    required this.scheduledDate,
    required this.isTodayScheduled,
    required this.sequence,
    required this.completedSessionsThisWeek,
  });

  final PlanSnapshot snapshot;
  final WeekPlan week;
  final SessionPlan session;
  final DateTime scheduledDate;
  final bool isTodayScheduled;
  final List<ExerciseSequenceItem> sequence;
  final int completedSessionsThisWeek;

  bool get hasLaunchableSlots => sequence.isNotEmpty;
  bool get isOffDayPullForward => !isTodayScheduled;
  bool get hasCompletedWeek =>
      completedSessionsThisWeek >= week.sessions.length &&
      week.sessions.isNotEmpty;

  ExerciseLaunchArgs? get firstLaunchArgs {
    if (sequence.isEmpty) return null;
    final first = sequence.first;
    return ExerciseLaunchArgs(
      definition: first.definition,
      catalogExerciseId: first.catalogExerciseId,
      prescription: first.prescription,
      recommendationId: first.recommendationId,
      weekNumber: first.weekNumber,
      sessionIndex: first.sessionIndex,
      slotName: first.slotName,
      sequence: sequence,
      sequenceIndex: 0,
    );
  }
}

class WorkoutLaunchHomeState {
  const WorkoutLaunchHomeState({
    required this.hasActivePlan,
    required this.isRecoveryDay,
    required this.hasCompletedWeek,
    required this.completedSessionsThisWeek,
    required this.sessionsThisWeek,
    this.target,
  });

  final bool hasActivePlan;
  final bool isRecoveryDay;
  final bool hasCompletedWeek;
  final int completedSessionsThisWeek;
  final int sessionsThisWeek;
  final WorkoutLaunchTarget? target;
}

class WorkoutLaunchService {
  WorkoutLaunchService({
    RecommendationService? recommendations,
    SessionPersistence? sessions,
  })  : _recommendations = recommendations ?? RecommendationService(),
        _sessions = sessions ?? SessionPersistence();

  final RecommendationService _recommendations;
  final SessionPersistence _sessions;

  Future<WorkoutLaunchTarget?> resolveTodayOrNextInCurrentWeek() async {
    final snapshot =
        await _recommendations.fetchLatestActivePlanSnapshotForCurrentUser();
    if (snapshot == null) return null;
    return resolveFromSnapshot(snapshot);
  }

  Future<WorkoutLaunchHomeState> resolveHomeState() async {
    final snapshot =
        await _recommendations.fetchLatestActivePlanSnapshotForCurrentUser();
    if (snapshot == null) {
      return const WorkoutLaunchHomeState(
        hasActivePlan: false,
        isRecoveryDay: false,
        hasCompletedWeek: false,
        completedSessionsThisWeek: 0,
        sessionsThisWeek: 0,
      );
    }

    final week = snapshot.currentWeek;
    if (week == null || week.sessions.isEmpty) {
      return const WorkoutLaunchHomeState(
        hasActivePlan: true,
        isRecoveryDay: false,
        hasCompletedWeek: false,
        completedSessionsThisWeek: 0,
        sessionsThisWeek: 0,
      );
    }

    final completed = await _sessions.countCompletedWorkoutDaysForWeek(
      recommendationId: snapshot.plan.recommendationId,
      weekNumber: week.weekNumber,
    );
    final todayIndex = _localDay(DateTime.now())
        .difference(
          _weekStart(snapshot, week),
        )
        .inDays;
    final isTodayScheduled = _sessionDayIndexes(
      week.sessions.length,
      snapshot.scheduleDayIndexes,
    ).contains(todayIndex);
    final target = await resolveFromSnapshot(snapshot);

    return WorkoutLaunchHomeState(
      hasActivePlan: true,
      isRecoveryDay: !isTodayScheduled,
      hasCompletedWeek: _hasCompletedWeek(completed, week),
      completedSessionsThisWeek: _clampCompletedCount(completed, week),
      sessionsThisWeek: week.sessions.length,
      target: target,
    );
  }

  Future<WorkoutLaunchTarget?> resolveFromSnapshot(
    PlanSnapshot snapshot, {
    WeekPlan? week,
  }) async {
    if (snapshot.plan.weeks.isEmpty) return null;
    final startWeekNumber = week?.weekNumber ?? snapshot.currentWeekNumber;
    final candidateWeeks = snapshot.plan.weeks
        .where((candidate) => candidate.weekNumber >= startWeekNumber)
        .toList(growable: false)
      ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));

    for (final candidateWeek in candidateWeeks) {
      if (candidateWeek.sessions.isEmpty) continue;
      final target = await _resolveNextInWeek(
        snapshot: snapshot,
        week: candidateWeek,
      );
      if (target != null) return target;
    }
    return null;
  }

  Future<WorkoutLaunchTarget?> _resolveNextInWeek({
    required PlanSnapshot snapshot,
    required WeekPlan week,
  }) async {
    final today = _localDay(DateTime.now());
    final weekStart = _weekStart(snapshot, week);
    final sessionDays =
        _sessionDayIndexes(week.sessions.length, snapshot.scheduleDayIndexes);
    final todayIndex = today.difference(weekStart).inDays;
    final completed = await _sessions.countCompletedWorkoutDaysForWeek(
      recommendationId: snapshot.plan.recommendationId,
      weekNumber: week.weekNumber,
    );
    final completedSessionIndexes =
        await _sessions.completedWorkoutSessionIndexesForWeek(
      recommendationId: snapshot.plan.recommendationId,
      weekNumber: week.weekNumber,
    );
    final completedCursors = _completedCursorsForWeek(
      week,
      completedSessionIndexes,
      fallbackCompletedCount: completed,
    );

    final sessionCursor = _selectNextSessionCursor(
      todayIndex: todayIndex,
      sessionDays: sessionDays,
      completedCursors: completedCursors,
    );
    if (sessionCursor == null || sessionCursor >= week.sessions.length) {
      return null;
    }

    final session = week.sessions[sessionCursor];
    final scheduledDate =
        weekStart.add(Duration(days: sessionDays[sessionCursor]));
    final sequence =
        await _sequenceFor(snapshot.plan.recommendationId, week, session);
    return WorkoutLaunchTarget(
      snapshot: snapshot,
      week: week,
      session: session,
      scheduledDate: scheduledDate,
      isTodayScheduled: sessionDays[sessionCursor] == todayIndex,
      sequence: sequence,
      completedSessionsThisWeek: _clampCompletedCount(completed, week),
    );
  }

  int? _selectNextSessionCursor({
    required int todayIndex,
    required List<int> sessionDays,
    required Set<int> completedCursors,
  }) {
    if (sessionDays.isEmpty) return null;
    bool isIncomplete(int cursor) => !completedCursors.contains(cursor);

    for (var i = 0; i < sessionDays.length; i++) {
      if (sessionDays[i] >= todayIndex && isIncomplete(i)) return i;
    }

    return null;
  }

  Set<int> _completedCursorsForWeek(
    WeekPlan week,
    Set<int> completedSessionIndexes, {
    required int fallbackCompletedCount,
  }) {
    if (completedSessionIndexes.isNotEmpty) {
      final cursors = <int>{};
      for (var cursor = 0; cursor < week.sessions.length; cursor++) {
        if (completedSessionIndexes
            .contains(week.sessions[cursor].sessionIndex)) {
          cursors.add(cursor);
        }
      }
      return cursors;
    }

    return {
      for (var cursor = 0;
          cursor < fallbackCompletedCount && cursor < week.sessions.length;
          cursor++)
        cursor,
    };
  }

  int _clampCompletedCount(int completed, WeekPlan week) {
    return completed.clamp(0, week.sessions.length).toInt();
  }

  bool _hasCompletedWeek(int completed, WeekPlan week) {
    return week.sessions.isNotEmpty && completed >= week.sessions.length;
  }

  Future<List<ExerciseSequenceItem>> _sequenceFor(
    String recommendationId,
    WeekPlan week,
    SessionPlan session,
  ) async {
    final unresolvedCatalogIds = <String>{};
    for (final slot in session.slots) {
      if (lookupExerciseDefinition(slot.exerciseId) == null) {
        unresolvedCatalogIds.add(slot.exerciseId);
      }
    }
    final catalogInfoById = unresolvedCatalogIds.isEmpty
        ? const <String, ExerciseLaunchCatalogInfo>{}
        : await _recommendations.fetchLaunchCatalogInfoForExerciseIds(
            unresolvedCatalogIds,
          );

    final items = <ExerciseSequenceItem>[];
    final unsupportedCatalogIds = <String>[];
    for (final slot in session.slots) {
      final definition = _lookupLaunchDefinition(
        slot.exerciseId,
        catalogInfoById[slot.exerciseId],
      );
      if (definition == null) {
        unsupportedCatalogIds.add(slot.exerciseId);
        continue;
      }
      items.add(
        ExerciseSequenceItem(
          definition: definition,
          catalogExerciseId: slot.exerciseId,
          prescription: slot.volume,
          recommendationId: recommendationId,
          weekNumber: week.weekNumber,
          sessionIndex: session.sessionIndex,
          slotName: slot.slotName,
        ),
      );
    }
    if (items.isEmpty && unsupportedCatalogIds.isNotEmpty) {
      debugPrint(
        '[WorkoutLaunchService] no launchable slots for '
        'recommendation=$recommendationId week=${week.weekNumber} '
        'session=${session.sessionIndex}; unsupported=$unsupportedCatalogIds',
      );
    }
    return items;
  }

  ExerciseDefinition? _lookupLaunchDefinition(
    String catalogExerciseId,
    ExerciseLaunchCatalogInfo? catalogInfo,
  ) {
    final direct = lookupExerciseDefinition(catalogExerciseId);
    if (direct != null) return direct;
    if (catalogInfo == null || !catalogInfo.isFormChecked) return null;

    for (final key in catalogInfo.lookupKeys) {
      final definition = lookupExerciseDefinition(key);
      if (definition != null) return definition;
    }
    return null;
  }

  DateTime _weekStart(PlanSnapshot snapshot, WeekPlan week) {
    final anchor = _mondayOfWeek(_localDay(
      snapshot.startedAt ?? snapshot.generatedAt ?? DateTime.now(),
    ));
    return anchor.add(Duration(days: (week.weekNumber - 1) * 7));
  }

  DateTime _localDay(DateTime date) =>
      DateTime(date.toLocal().year, date.toLocal().month, date.toLocal().day);

  DateTime _mondayOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - DateTime.monday));
  }

  List<int> _sessionDayIndexes(
    int sessionCount,
    List<int> scheduleDayIndexes,
  ) {
    final scheduleDays = scheduleDayIndexes
        .where((day) => day >= 0 && day <= 6)
        .toSet()
        .toList()
      ..sort();
    if (scheduleDays.length >= sessionCount) {
      return scheduleDays.take(sessionCount).toList(growable: false);
    }

    return switch (sessionCount) {
      <= 0 => const <int>[],
      1 => const [0],
      2 => const [0, 3],
      3 => const [0, 2, 4],
      4 => const [0, 1, 3, 5],
      5 => const [0, 1, 2, 3, 4],
      _ => const [0, 1, 2, 3, 4, 5],
    };
  }
}

String workoutVolumeLabel(VolumePrescription volume) {
  final target = volume.reps != null
      ? '${volume.reps} rep'
      : volume.seconds != null
          ? '${volume.seconds} giây'
          : '';
  if (target.isEmpty) return '${volume.sets} hiệp';
  return '${volume.sets} x $target';
}
