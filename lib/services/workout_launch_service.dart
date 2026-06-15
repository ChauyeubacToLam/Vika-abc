import 'package:flutter/foundation.dart';

import '../models/exercise_definition.dart';
import '../models/exercise_lookup.dart';
import '../screens/exercise/exercise_launch_args.dart';
import 'recommendation/models/plan.dart';
import 'recommendation/recommendation_service.dart';

class WorkoutLaunchTarget {
  const WorkoutLaunchTarget({
    required this.snapshot,
    required this.week,
    required this.session,
    required this.sequence,
    required this.completedSessionsThisWeek,
  });

  final PlanSnapshot snapshot;
  final WeekPlan week;
  final SessionPlan session;
  final List<ExerciseSequenceItem> sequence;
  final int completedSessionsThisWeek;

  bool get hasLaunchableSlots => sequence.isNotEmpty;
  bool get hasCompletedWeek =>
      completedSessionsThisWeek >= week.sessions.length &&
      week.sessions.isNotEmpty;

  ExerciseLaunchArgs? firstLaunchArgs({String? workoutSessionId}) {
    if (sequence.isEmpty) return null;
    final first = sequence.first;
    return ExerciseLaunchArgs(
      definition: first.definition,
      catalogExerciseId: first.catalogExerciseId,
      catalogInfo: first.catalogInfo,
      prescription: first.prescription,
      recommendationId: first.recommendationId,
      weekNumber: first.weekNumber,
      sessionIndex: first.sessionIndex,
      slotName: first.slotName,
      sequence: sequence,
      sequenceIndex: 0,
      workoutSessionId: workoutSessionId,
    );
  }
}

class WorkoutLaunchHomeState {
  const WorkoutLaunchHomeState({
    required this.hasActivePlan,
    required this.hasCompletedWeek,
    required this.completedSessionsThisWeek,
    required this.sessionsThisWeek,
    this.target,
  });

  final bool hasActivePlan;
  final bool hasCompletedWeek;
  final int completedSessionsThisWeek;
  final int sessionsThisWeek;
  final WorkoutLaunchTarget? target;
}

class WorkoutLaunchService {
  WorkoutLaunchService({RecommendationService? recommendations})
      : _recommendations = recommendations ?? RecommendationService();

  final RecommendationService _recommendations;

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
        hasCompletedWeek: false,
        completedSessionsThisWeek: 0,
        sessionsThisWeek: 0,
      );
    }

    final week = snapshot.currentWeek;
    if (week == null || week.sessions.isEmpty) {
      return const WorkoutLaunchHomeState(
        hasActivePlan: true,
        hasCompletedWeek: false,
        completedSessionsThisWeek: 0,
        sessionsThisWeek: 0,
      );
    }

    final completed = snapshot.completionMap[week.weekNumber]?.length ?? 0;

    final target = await resolveFromSnapshot(snapshot);

    return WorkoutLaunchHomeState(
      hasActivePlan: true,
      hasCompletedWeek: _hasCompletedWeek(completed, week),
      completedSessionsThisWeek: _clampCompletedCount(completed, week),
      sessionsThisWeek: week.sessions.length,
      target: target,
    );
  }

  Future<WorkoutLaunchTarget?> resolveFromSnapshot(
      PlanSnapshot snapshot) async {
    final pos = snapshot.currentPosition;

    final startWeek = snapshot.currentWeek;
    if (snapshot.plan.weeks.isEmpty || pos == null || startWeek == null) {
      return null;
    }
    final startSessionIndex = pos.$2;

    final target = await _buildTarget(
      snapshot: snapshot,
      week: startWeek,
      session: startWeek.sessions[startSessionIndex],
    );

    return target;
  }

  Future<WorkoutLaunchTarget> _buildTarget({
    required PlanSnapshot snapshot,
    required WeekPlan week,
    required SessionPlan session,
  }) async {
    final sequence =
        await _sequenceFor(snapshot.plan.recommendationId, week, session);
    final completed = snapshot.completionMap[week.weekNumber]?.length ?? 0;
    return WorkoutLaunchTarget(
      snapshot: snapshot,
      week: week,
      session: session,
      sequence: sequence,
      completedSessionsThisWeek: _clampCompletedCount(completed, week),
    );
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
    final catalogIds = <String>{
      for (final slot in session.slots) slot.exerciseId,
    };
    final catalogInfoById = catalogIds.isEmpty
        ? const <String, ExerciseLaunchCatalogInfo>{}
        : await _recommendations.fetchLaunchCatalogInfoForExerciseIds(
            catalogIds,
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
          catalogInfo: catalogInfoById[slot.exerciseId],
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
