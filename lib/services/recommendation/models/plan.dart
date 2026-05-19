// 7-week plan output of the RecommendationEngine. Round-trips to
// the recommendations_log.plan_structure JSONB column via
// toPlanStructureJson / Plan.fromSupabase.
//
// recommendationId / userId / templateKey are stored as SEPARATE
// columns on recommendations_log and are NOT serialized into
// plan_structure. Pass them in explicitly when reconstructing.
//
// v4.3 STRUCTURE: 2 phases x 3 weeks + 1 deload week = 7 weeks.
// Templates can override numPhases/weeksPerPhase/includeDeloadAtEnd
// for variants (e.g., custom plans).
//
// VolumePrescription is single-target (reps OR seconds), NOT a range.
// User-facing presentation is a single number. Internal autoregulation
// (via the per-set difficulty system) handles fluctuation.

/// Plan scope constants. Used in plan_structure JSONB and on Plan model.
const String kPlanScopePhase1Only = 'phase_1_only';
const String kPlanScopeFull = 'full';

class Plan {
  const Plan({
    required this.recommendationId,
    required this.userId,
    required this.templateKey,
    required this.planScope,
    required this.weeks,
    this.schemaVersion = '4.4',
    this.weeklyCheckInWeeks = const [],
    this.endOfPlanRetest,
  });

  final String recommendationId;
  final String userId;
  final String templateKey;

  /// plan_structure schema marker. Older rows omit this; deserialization
  /// falls back to 'legacy'.
  final String schemaVersion;

  /// kPlanScopePhase1Only | kPlanScopeFull. Read by the engine when
  /// deciding how many weeks to generate.
  final String planScope;

  /// v1 default: 7 entries (W1-W6 progression + W7 deload).
  /// Length is template.numPhases * template.weeksPerPhase + (deload ? 1 : 0).
  final List<WeekPlan> weeks;

  /// Week numbers where the soft weekly wellness check-in should appear.
  /// v4.4 default is weeks 2..last week, including deload.
  final List<int> weeklyCheckInWeeks;

  /// Forced retest after the deload week and before next plan generation.
  final PlanRetest? endOfPlanRetest;

  /// Builds the plan_structure JSONB payload. Does NOT include
  /// recommendationId/userId/templateKey since those are dedicated
  /// columns on recommendations_log.
  Map<String, dynamic> toPlanStructureJson() {
    return {
      'schema_version': schemaVersion,
      'plan_scope': planScope,
      'weekly_check_in_weeks': weeklyCheckInWeeks,
      if (endOfPlanRetest != null) 'end_retest': endOfPlanRetest!.toJson(),
      'weeks': weeks.map((w) => w.toJson()).toList(),
    };
  }

  /// Reconstructs a Plan from a recommendations_log row.
  factory Plan.fromSupabase({
    required String recommendationId,
    required String userId,
    required String templateKey,
    required Map<String, dynamic> planStructure,
  }) {
    final rawWeeks = (planStructure['weeks'] as List?) ?? const [];
    return Plan(
      recommendationId: recommendationId,
      userId: userId,
      templateKey: templateKey,
      schemaVersion: (planStructure['schema_version'] as String?) ?? 'legacy',
      planScope: (planStructure['plan_scope'] as String?) ?? kPlanScopeFull,
      weeklyCheckInWeeks:
          ((planStructure['weekly_check_in_weeks'] as List?) ?? const [])
              .map((w) => (w as num).toInt())
              .toList(),
      endOfPlanRetest: planStructure['end_retest'] == null
          ? null
          : PlanRetest.fromJson(
              planStructure['end_retest'] as Map<String, dynamic>,
            ),
      weeks: rawWeeks
          .map((w) => WeekPlan.fromJson(w as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PlanRetest {
  const PlanRetest({
    required this.afterWeekNumber,
    required this.vietnameseTitle,
    required this.vietnameseDescription,
    required this.exercises,
    this.scoringVersion = 'v1',
    this.isRequired = true,
  });

  final int afterWeekNumber;
  final String vietnameseTitle;
  final String vietnameseDescription;
  final bool isRequired;
  final String scoringVersion;
  final List<RetestExercise> exercises;

  Map<String, dynamic> toJson() => {
        'trigger_week': afterWeekNumber + 1,
        'scoring_version': scoringVersion,
      };

  factory PlanRetest.fromJson(Map<String, dynamic> json) {
    final triggerWeek = (json['trigger_week'] as num?)?.toInt();
    return PlanRetest(
      afterWeekNumber: (json['after_week_number'] as num?)?.toInt() ??
          (triggerWeek ?? 1) - 1,
      vietnameseTitle:
          (json['vietnamese_title'] as String?) ?? 'Kiểm tra lại thể lực',
      vietnameseDescription: (json['vietnamese_description'] as String?) ??
          'Hoàn thành bài kiểm tra ngắn để Vika cập nhật lộ trình tiếp theo.',
      isRequired: (json['is_required'] as bool?) ?? true,
      scoringVersion: (json['scoring_version'] as String?) ?? 'v1',
      exercises: ((json['exercises'] as List?) ?? const [])
          .map((e) => RetestExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RetestExercise {
  const RetestExercise({
    required this.exerciseId,
    required this.vietnameseName,
    required this.durationSeconds,
  });

  final String exerciseId;
  final String vietnameseName;
  final int durationSeconds;

  Map<String, dynamic> toJson() => {
        'exercise_id': exerciseId,
        'vietnamese_name': vietnameseName,
        'duration_seconds': durationSeconds,
      };

  factory RetestExercise.fromJson(Map<String, dynamic> json) {
    return RetestExercise(
      exerciseId: json['exercise_id'] as String,
      vietnameseName: json['vietnamese_name'] as String,
      durationSeconds: (json['duration_seconds'] as num).toInt(),
    );
  }
}

class WeekPlan {
  const WeekPlan({
    required this.weekNumber,
    required this.phaseNumber,
    required this.phaseName,
    required this.isDeloadWeek,
    required this.sessions,
  });

  /// 1-indexed absolute week. Range 1..7 for v1 default.
  final int weekNumber;

  /// Which phase this week belongs to. v1: 1, 2, or 3 (deload).
  ///   Phase 1 (Nền tảng):   weeks 1-3
  ///   Phase 2 (Phát triển): weeks 4-6
  ///   Phase 3 (Phục hồi):   week 7 (deload)
  final int phaseNumber;

  /// Pulled from Template.phaseNames[phaseNumber - 1] (or deloadName
  /// if isDeloadWeek) at generation time. Snapshotted onto the plan
  /// so future template renames don't change historical plans.
  final String phaseName;

  /// True for the deload week. UI shows different copy
  /// (e.g., "Tuần phục hồi"). Algorithm skips capacity updates on
  /// sessions from deload weeks.
  final bool isDeloadWeek;

  final List<SessionPlan> sessions;

  Map<String, dynamic> toJson() => {
        'week_number': weekNumber,
        'phase_number': phaseNumber,
        'phase_name': phaseName,
        'is_deload_week': isDeloadWeek,
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };

  factory WeekPlan.fromJson(Map<String, dynamic> json) {
    final weekVolume = json['volume'] == null
        ? null
        : VolumePrescription.fromJson(
            json['volume'] as Map<String, dynamic>,
          );
    return WeekPlan(
      weekNumber: (json['week_number'] as num).toInt(),
      phaseNumber: (json['phase_number'] as num?)?.toInt() ??
          (json['week_number'] as num).toInt(),
      phaseName: (json['phase_name'] as String?) ?? 'Lộ trình',
      isDeloadWeek: (json['is_deload_week'] as bool?) ?? false,
      sessions: ((json['sessions'] as List?) ?? const [])
          .map(
            (s) => SessionPlan.fromJson(
              s as Map<String, dynamic>,
              fallbackVolume: weekVolume,
            ),
          )
          .toList(),
    );
  }
}

class SessionPlan {
  const SessionPlan({
    required this.sessionIndex,
    required this.slots,
    this.sessionType = kSessionTypeWorkout,
  });

  /// 0-indexed position within the week.
  final int sessionIndex;

  final List<SlotAssignment> slots;

  /// kSessionTypeWorkout today; retained for future retest-in-week rows.
  final String sessionType;

  Map<String, dynamic> toJson() => {
        'session_index': sessionIndex,
        'session_type': sessionType,
        'slots': slots.map((s) => s.toJson()).toList(),
      };

  factory SessionPlan.fromJson(
    Map<String, dynamic> json, {
    VolumePrescription? fallbackVolume,
  }) {
    return SessionPlan(
      sessionIndex: (json['session_index'] as num).toInt(),
      sessionType: (json['session_type'] as String?) ?? kSessionTypeWorkout,
      slots: ((json['slots'] as List?) ?? const [])
          .map(
            (s) => SlotAssignment.fromJson(
              s as Map<String, dynamic>,
              fallbackVolume: fallbackVolume,
            ),
          )
          .toList(),
    );
  }
}

const String kSessionTypeWorkout = 'workout';

class SlotAssignment {
  const SlotAssignment({
    required this.slotName,
    required this.exerciseId,
    required this.volume,
    required this.score,
    required this.topKCandidates,
  });

  /// Matches Slot.name from the template.
  final String slotName;

  /// Final exercise picked for this slot.
  ///
  /// IMPORTANT (v4.3): this id is FIXED for the entire plan once
  /// generated. Variant unlock takes effect at the NEXT plan
  /// generation, not mid-plan.
  final String exerciseId;

  /// Volume prescription for this slot in this specific week.
  /// In v4.3, this varies week-to-week (reps grow toward cap, sets
  /// ramp in P1W3, deload week cuts sets).
  final VolumePrescription volume;

  /// Score of the picked exercise (the winner from sampling).
  /// Range: [0.0, 1.0]. See scoring.dart for component math.
  final double score;

  /// Top-K alternates considered before stochastic sampling. Kept on
  /// the plan for v1.5 reward-aware scoring. Capped at _logN = 5 in
  /// stochastic_sampler.dart.
  final List<({String exerciseId, double score})> topKCandidates;

  Map<String, dynamic> toJson() => {
        'slot_name': slotName,
        'exercise_id': exerciseId,
        'volume': volume.toJson(),
        'score': score,
        'top_k_candidates': topKCandidates
            .map((c) => {'exercise_id': c.exerciseId, 'score': c.score})
            .toList(),
      };

  factory SlotAssignment.fromJson(
    Map<String, dynamic> json, {
    VolumePrescription? fallbackVolume,
  }) {
    final rawTopK = (json['top_k_candidates'] as List?) ?? const [];
    return SlotAssignment(
      slotName: json['slot_name'] as String,
      exerciseId: json['exercise_id'] as String,
      volume: json['volume'] == null
          ? (fallbackVolume ?? VolumePrescription.legacyFallback())
          : VolumePrescription.fromJson(
              json['volume'] as Map<String, dynamic>,
            ),
      score: (json['score'] as num?)?.toDouble() ?? 0,
      topKCandidates: rawTopK.map((c) {
        final m = c as Map<String, dynamic>;
        return (
          exerciseId: m['exercise_id'] as String,
          score: (m['score'] as num).toDouble(),
        );
      }).toList(),
    );
  }
}

/// Volume prescription for a single (slot, week) cell.
///
/// Exactly one of `reps` / `seconds` is populated, depending on the
/// exercise type (rep-based vs. hold-based / yoga). `sets` and
/// `restSeconds` always present.
///
/// v4.3: NO range. Single integer target. Internal autoregulation via
/// the per-set difficulty system handles within-session adaptation.
///
/// v4.3: NO tempo eccentric. The field was dropped entirely. Density
/// progression (rest reduction within session via per-set difficulty)
/// replaces it as the autoregulation lever.
class VolumePrescription {
  const VolumePrescription({
    required this.sets,
    required this.restSeconds,
    this.reps,
    this.seconds,
    this.isDeloadWeek = false,
  });

  final int sets;
  final int restSeconds;

  /// Populated for rep-based exercises. Null for yoga/holds.
  final int? reps;

  /// Populated for hold-based / yoga. Null for rep-based.
  final int? seconds;

  /// True if this prescription is part of a deload week.
  /// UI shows different copy ("Tuần phục hồi - giảm cường độ").
  /// Algorithm uses this to skip session-to-session carry-over update.
  final bool isDeloadWeek;

  Map<String, dynamic> toJson() => {
        'sets': sets,
        'rest_seconds': restSeconds,
        'reps': reps,
        'seconds': seconds,
        'is_deload_week': isDeloadWeek,
      };

  factory VolumePrescription.fromJson(Map<String, dynamic> json) {
    return VolumePrescription(
      sets: (json['sets'] as num).toInt(),
      restSeconds: (json['rest_seconds'] as num?)?.toInt() ?? 60,
      reps: (json['reps'] as num?)?.toInt(),
      seconds: (json['seconds'] as num?)?.toInt(),
      isDeloadWeek: (json['is_deload_week'] as bool?) ?? false,
    );
  }

  factory VolumePrescription.legacyFallback() {
    return const VolumePrescription(
      sets: 3,
      reps: 8,
      restSeconds: 60,
    );
  }
}
