// 4-week plan output of the RecommendationEngine. Round-trips to
// the recommendations_log.plan_structure JSONB column via
// toPlanStructureJson / Plan.fromSupabase.
//
// recommendationId / userId / templateKey are stored as SEPARATE
// columns on recommendations_log and are NOT serialized into
// plan_structure. Pass them in explicitly when reconstructing.

class Plan {
  const Plan({
    required this.recommendationId,
    required this.userId,
    required this.templateKey,
    required this.weeks,
  });

  final String recommendationId;
  final String userId;
  final String templateKey;
  final List<WeekPlan> weeks;

  /// Builds the plan_structure JSONB payload. Does NOT include
  /// recommendationId/userId/templateKey since those are dedicated
  /// columns on recommendations_log.
  Map<String, dynamic> toPlanStructureJson() {
    return {
      'weeks': weeks.map((w) => w.toJson()).toList(),
    };
  }

  /// Reconstructs a Plan from a recommendations_log row. Caller
  /// passes the standalone columns + the JSONB blob; we wire them up.
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
      weeks: rawWeeks
          .map((w) => WeekPlan.fromJson(w as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WeekPlan {
  const WeekPlan({
    required this.weekNumber,
    required this.phaseName,
    required this.volume,
    required this.sessions,
  });

  /// 1-indexed (1 through 4 for v1).
  final int weekNumber;

  /// Pulled from Template.phaseNames[weekNumber - 1] at generation time.
  /// Snapshotted onto the plan so future renames of Template.phaseNames
  /// don't retroactively change historical plans.
  final String phaseName;

  final VolumePrescription volume;
  final List<SessionPlan> sessions;

  Map<String, dynamic> toJson() => {
        'week_number': weekNumber,
        'phase_name': phaseName,
        'volume': volume.toJson(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };

  factory WeekPlan.fromJson(Map<String, dynamic> json) {
    return WeekPlan(
      weekNumber: json['week_number'] as int,
      phaseName: json['phase_name'] as String,
      volume:
          VolumePrescription.fromJson(json['volume'] as Map<String, dynamic>),
      sessions: ((json['sessions'] as List?) ?? const [])
          .map((s) => SessionPlan.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SessionPlan {
  const SessionPlan({
    required this.sessionIndex,
    required this.slots,
  });

  /// 0-indexed position within the week (0, 1, 2 for 3-session weeks).
  final int sessionIndex;

  final List<SlotAssignment> slots;

  Map<String, dynamic> toJson() => {
        'session_index': sessionIndex,
        'slots': slots.map((s) => s.toJson()).toList(),
      };

  factory SessionPlan.fromJson(Map<String, dynamic> json) {
    return SessionPlan(
      sessionIndex: json['session_index'] as int,
      slots: ((json['slots'] as List?) ?? const [])
          .map((s) => SlotAssignment.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SlotAssignment {
  const SlotAssignment({
    required this.slotName,
    required this.exerciseId,
    required this.score,
    required this.topKCandidates,
  });

  /// Matches Slot.name from the template. Persisted to
  /// exercise_sessions.slot_name when the user executes this slot.
  final String slotName;

  /// Final exercise picked for this slot. Look up the full
  /// ExerciseCatalogEntry via ExerciseRepository.findById when
  /// the UI needs more than the id.
  final String exerciseId;

  /// Score of the picked exercise (the winner from sampling).
  final double score;

  /// Top-K alternates considered before stochastic sampling. Kept
  /// on the plan for v1.5 reward-aware scoring (we can re-weight
  /// based on which candidates were CONSIDERED, not just which won).
  final List<({String exerciseId, double score})> topKCandidates;

  Map<String, dynamic> toJson() => {
        'slot_name': slotName,
        'exercise_id': exerciseId,
        'score': score,
        'top_k_candidates': topKCandidates
            .map((c) => {'exercise_id': c.exerciseId, 'score': c.score})
            .toList(),
      };

  factory SlotAssignment.fromJson(Map<String, dynamic> json) {
    final rawTopK = (json['top_k_candidates'] as List?) ?? const [];
    return SlotAssignment(
      slotName: json['slot_name'] as String,
      exerciseId: json['exercise_id'] as String,
      score: (json['score'] as num).toDouble(),
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

/// Volume prescription for a single week.
///
/// Exactly one of `reps` / `seconds` is populated, depending on the
/// exercise type (rep-based vs. hold-based / yoga). `sets` and
/// `restSeconds` always present. `tempoEccentric` optional (only
/// activates at certain weeks per progression_rules.dart).
///
/// Lives in plan.dart (NOT progression_rules.dart, despite the
/// spec's section 4.6 placement) because it's a passive data
/// structure that WeekPlan owns. progression_rules.dart imports it.
class VolumePrescription {
  const VolumePrescription({
    required this.sets,
    required this.restSeconds,
    this.reps,
    this.seconds,
    this.tempoEccentric,
  });

  final int sets;
  final int restSeconds;

  /// Populated for rep-based exercises. Null for yoga/holds.
  /// (Diverges from spec where reps was non-nullable; spec
  /// assumed rep-based only. Yoga needs nullable here.)
  final int? reps;

  /// Populated for hold-based / yoga. Null for rep-based.
  final int? seconds;

  /// Eccentric tempo in seconds. Null until progression rules
  /// activate it (week 3 for intermediate, week 2 for advanced).
  final int? tempoEccentric;

  Map<String, dynamic> toJson() => {
        'sets': sets,
        'reps': reps,
        'seconds': seconds,
        'rest_seconds': restSeconds,
        'tempo_eccentric': tempoEccentric,
      };

  factory VolumePrescription.fromJson(Map<String, dynamic> json) {
    return VolumePrescription(
      sets: json['sets'] as int,
      restSeconds: json['rest_seconds'] as int,
      reps: json['reps'] as int?,
      seconds: json['seconds'] as int?,
      tempoEccentric: json['tempo_eccentric'] as int?,
    );
  }
}
