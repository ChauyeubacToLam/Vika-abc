/// The adapter (design decision D1): implements the existing
/// `ExerciseVoiceCoach` interface exactly, so the camera/exercise pipeline
/// is untouched. Holds prior-frame state and diffs it — that diffing is
/// the entire reason the per-frame contract doesn't need to change.
///
/// Build spec: `docs/reference/voice-coach/implementation-guide.md` §7.
///
/// Stage 1 only: this class is intentionally unwired. Nothing calls it —
/// `ExerciseBase.createVoiceCoach()` still returns the legacy generic coach
/// (see stage 2 of the guide's §9 migration order). It compiles and is
/// unit-testable in isolation, but no exercise instantiates it yet.
///
/// Two real-contract gaps this file works around rather than papering over
/// by inventing new `ExerciseBase` surface (that would violate the "zero
/// changes to the pipeline" guardrail):
/// - There is no "target rep count" anywhere in `ExerciseBase` or
///   `ExerciseVoiceCoach.processFrame`'s fixed signature, so `isFinalReps`
///   can't be derived from the pipeline alone. [targetReps] is an optional
///   constructor parameter the stage-2/3 wiring is expected to supply from
///   whatever the calling screen already knows (the session's prescribed
///   rep count) — left null, hustle simply never fires.
/// - `ExerciseBase` surfaces no structured "safety event" beyond the
///   generic `resultIssues.feedback['System']` string used for every kind
///   of system message (searching/paused/instructions). Wiring a real
///   `CueType.safety` cue needs a dedicated signal that doesn't exist yet;
///   left as `// TODO(wiring)` below rather than guessed at.
library;

import '../exercise/exercise_base.dart';
import '../utils/exercise_logger.dart';
import 'voice_coach.dart';
import 'voice_content.dart';

class PolicyVoiceCoach implements ExerciseVoiceCoach {
  PolicyVoiceCoach({
    required this.script,
    required VoiceCoach coach,
    this.targetReps,
    this.countsByRepNumber = true,
  }) : _coach = coach;

  /// This exercise's footprint: which pools + which fault ids + (if any)
  /// phase cues.
  final VoiceScript script;

  /// Prescribed rep count for this set, if known — see the gap noted in
  /// the library doc comment above. Null means hustle never fires.
  final int? targetReps;

  /// Rep-counted exercises should speak the actual completed rep number.
  ///
  /// Hold/timer exercises still use [VoiceScript.countPool] because their
  /// count keys are time thresholds, not rep indexes. That path is known to
  /// need a separate timer-specific pass; this flag keeps that scope out of
  /// the rep-count fix.
  final bool countsByRepNumber;

  final VoiceCoach _coach;

  int _lastRepCount = 0;
  bool _hasBegunSet = false;
  ExerciseState? _lastExerciseState;

  /// fault id -> the rep it first appeared in this streak. Cleared for a
  /// fault as soon as it stops appearing, so a later recurrence starts a
  /// fresh persistence count. This is the adapter-owned diff state D1
  /// depends on.
  final Map<String, int> _faultFirstSeenRep = {};

  String? _lastPhaseCue;

  @override
  void processFrame({
    required ExerciseBase exercise,
    required int repCount,
    required bool hasPose,
    required Map<String, String> feedback,
  }) {
    final state = exercise.exerciseState;
    final justActivated = state == ExerciseState.activated &&
        _lastExerciseState != ExerciseState.activated;
    if (justActivated || !_hasBegunSet) {
      // New set / activation → wipe hunger + all diff state (§7 step 1).
      _coach.beginSet();
      _faultFirstSeenRep.clear();
      _lastPhaseCue = null;
      _hasBegunSet = true;
    }
    _lastExerciseState = state;

    // TODO(wiring): ExerciseBase exposes no structured safety-event signal
    // (only the generic resultIssues.feedback['System'] string shared by
    // searching/paused/instruction copy). Wire CueType.safety once a real
    // per-exercise hook exists.

    if (state != ExerciseState.activated || exercise.isPaused || !hasPose) {
      _lastRepCount = repCount;
      return;
    }

    final repIncreased = repCount > _lastRepCount;
    if (repIncreased) {
      _handleRepLanded(exercise: exercise, repCount: repCount);
    }

    _maybeSpeakPhaseCue(exercise: exercise, repCount: repCount);

    _lastRepCount = repCount;
  }

  void _handleRepLanded({
    required ExerciseBase exercise,
    required int repCount,
  }) {
    final repLog = _latestRepLog(exercise, repCount);
    final faultIds = _faultIdsFor(repLog);
    final hasCriticalFault = !(repLog?.correctForm ?? true);
    final usesSoftClassifier = script.hasSoftCues;
    final correctionIds = hasCriticalFault ? faultIds : const <String>[];
    // Soft-enabled scripts use the 3-way classifier: critical -> correct,
    // minor fault -> soft, zero faults -> praise. Scripts without soft pools
    // keep the old 2-way behavior exactly: no correctable fault -> praise.
    final clean = usesSoftClassifier ? faultIds.isEmpty : correctionIds.isEmpty;
    final isFinalReps = _isFinalReps(repCount);
    // Binary score from the only per-rep quality signal the logger carries.
    // Glute Bridge disables the probability multiplier locally, but the
    // resolver still uses this to avoid the bigger praise line on measured
    // bad-form reps that have no mapped correction audio.
    final formScore = (repLog?.correctForm ?? true) ? 1.0 : 0.0;

    final baseCtx = CueContext(
      repNumber: repCount,
      isFinalReps: isFinalReps,
      clean: clean,
      formScore: formScore,
    );

    final countContent = countsByRepNumber
        ? VoiceContent.key(repCount.toString())
        : VoiceContent.pool(script.countPool);
    _coach.say(CueType.count, countContent, baseCtx);

    if (correctionIds.isNotEmpty) {
      for (final id in correctionIds) {
        final firstSeenRep = _faultFirstSeenRep.putIfAbsent(
          id,
          () => repCount,
        );
        final persistence = repCount - firstSeenRep;
        _coach.say(
          CueType.criticalFault,
          VoiceContent.key(script.faultKey(id)),
          baseCtx.copyWith(contentKey: id, faultPersistence: persistence),
        );
      }
      // Anything not present this rep is done persisting.
      _faultFirstSeenRep.removeWhere((id, _) => !correctionIds.contains(id));
    } else if (usesSoftClassifier && faultIds.isNotEmpty) {
      _faultFirstSeenRep.clear();
      for (final id in faultIds) {
        final softPool = script.softPoolFor(id);
        if (softPool.isEmpty) continue;
        _coach.say(
          CueType.softFault,
          VoiceContent.pool(softPool),
          baseCtx.copyWith(contentKey: id),
        );
      }
    } else {
      _faultFirstSeenRep.clear();
      _coach.say(
        CueType.praise,
        VoiceContent.pool(script.praisePool),
        baseCtx,
      );
    }

    if (isFinalReps) {
      _coach.say(
        CueType.hustle,
        VoiceContent.pool(script.hustlePool),
        baseCtx,
      );
    }
  }

  void _maybeSpeakPhaseCue({
    required ExerciseBase exercise,
    required int repCount,
  }) {
    if (script.phaseCues.isEmpty) return;
    final cueKey = script.phaseCues[exercise.currentPhaseKey];
    if (cueKey == null || cueKey == _lastPhaseCue) return;
    _lastPhaseCue = cueKey;
    _coach.say(
      CueType.phase,
      VoiceContent.key(cueKey),
      CueContext(repNumber: repCount, sinkBusy: _coach.isBusy),
    );
  }

  bool _isFinalReps(int repCount) {
    final target = targetReps;
    if (target == null || target <= 0) return false;
    return repCount > target - 2; // Final two reps — the hustle window.
  }

  List<String> _faultIdsFor(RepLog? repLog) {
    if (repLog == null) return const [];
    final raw = repLog.data['fault_types'];
    if (raw is! Iterable) return const [];
    final ids = <String>[];
    for (final item in raw) {
      final id = item.toString().trim();
      if (id.isEmpty) continue;
      if (script.faultIds.isEmpty || script.faultIds.contains(id)) {
        ids.add(id);
      }
    }
    return ids;
  }

  RepLog? _latestRepLog(ExerciseBase exercise, int repCount) {
    for (final log in exercise.logger.repLogs.reversed) {
      if (log.repNumber == repCount) return log;
    }
    return null;
  }

  @override
  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 4),
  }) {
    return _coach.waitUntilIdle();
  }

  @override
  void dispose() => _coach.dispose();
}
