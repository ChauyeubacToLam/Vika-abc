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
import '../exercise/fault_record.dart';
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
  final Set<String> _spokenFaultTypesThisRep = <String>{};
  final Set<String> _seenFaultTypesThisRep = <String>{};

  String? _lastPhaseCue;
  int _trackedRepNumber = 1;

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
      _startTrackingRep(repCount + 1);
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
      _drainLiveFaults(exercise: exercise, repNumber: _trackedRepNumber);
      _handleRepLanded(exercise: exercise, repCount: repCount);
      _startTrackingRep(repCount + 1);
    } else {
      final inProgressRep = repCount + 1;
      if (_trackedRepNumber != inProgressRep) {
        _startTrackingRep(inProgressRep);
      }
      _drainLiveFaults(exercise: exercise, repNumber: inProgressRep);
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
    final usesSoftClassifier = script.hasSoftCues;
    final hasCriticalFault = usesSoftClassifier
        ? faultIds.any((id) => _faultAffectsFormFor(repLog, id))
        : !(repLog?.correctForm ?? true);
    final correctionIds = hasCriticalFault ? faultIds : const <String>[];
    // Soft-enabled scripts use the 3-way classifier: critical -> correct,
    // minor fault -> soft, zero faults -> praise. Scripts without soft pools
    // keep the old 2-way behavior exactly: no correctable fault -> praise.
    final clean = usesSoftClassifier
        ? faultIds.isEmpty && _seenFaultTypesThisRep.isEmpty
        : correctionIds.isEmpty;
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

    if (usesSoftClassifier) {
      _handleSoftEnabledRepLogFaults(
        repLog: repLog,
        faultIds: faultIds,
        baseCtx: baseCtx,
      );
      if (clean) {
        _faultFirstSeenRep.clear();
        _coach.say(
          CueType.praise,
          VoiceContent.pool(script.praisePool),
          baseCtx,
        );
      }
    } else if (correctionIds.isNotEmpty) {
      for (final id in correctionIds) {
        final firstSeenRep = _faultFirstSeenRep.putIfAbsent(
          id,
          () => repCount,
        );
        final persistence = repCount - firstSeenRep;
        final spoke = _coach.say(
          CueType.criticalFault,
          VoiceContent.key(script.faultKey(id)),
          baseCtx.copyWith(contentKey: id, faultPersistence: persistence),
        );
        if (spoke) _spokenFaultTypesThisRep.add(id);
      }
      // Anything not present this rep is done persisting.
      _faultFirstSeenRep.removeWhere((id, _) => !correctionIds.contains(id));
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

  void _startTrackingRep(int repNumber) {
    _trackedRepNumber = repNumber;
    _spokenFaultTypesThisRep.clear();
    _seenFaultTypesThisRep.clear();
  }

  void _drainLiveFaults({
    required ExerciseBase exercise,
    required int repNumber,
  }) {
    final faults = _sortedFaults(exercise.liveFaults);
    if (faults.isEmpty) return;

    final baseCtx = CueContext(
      repNumber: repNumber,
      isFinalReps: _isFinalReps(repNumber),
      clean: false,
      formScore: 0.0,
    );

    for (final fault in faults) {
      final id = fault.type.trim();
      if (!_isKnownFaultId(id)) continue;
      _seenFaultTypesThisRep.add(id);
      if (_spokenFaultTypesThisRep.contains(id)) continue;

      final spoke = _sayFaultRecord(
        fault: fault,
        repNumber: repNumber,
        baseCtx: baseCtx,
        consumeFirstSeenOnAttempt: false,
      );
      if (spoke) {
        _spokenFaultTypesThisRep.add(id);
      }
    }
  }

  void _handleSoftEnabledRepLogFaults({
    required RepLog? repLog,
    required List<String> faultIds,
    required CueContext baseCtx,
  }) {
    final criticalIdsThisRep = <String>{};
    final sortedIds = _sortedFaultIdsForRepLog(repLog, faultIds);

    // TODO(post-rep-instructions): Peak faults currently speak here as
    // next-rep guidance. Move them to the post-rep instruction layer once
    // that parked feature ships, then remove this rep-end outcome firing.
    for (final id in sortedIds) {
      final affectsForm = _faultAffectsFormFor(repLog, id);
      if (affectsForm) {
        criticalIdsThisRep.add(id);
      }

      final wasSeenLive = _seenFaultTypesThisRep.contains(id);
      _seenFaultTypesThisRep.add(id);
      if (_spokenFaultTypesThisRep.contains(id) || wasSeenLive) {
        continue;
      }

      final spoke = _sayFault(
        id: id,
        affectsForm: affectsForm,
        repNumber: baseCtx.repNumber,
        baseCtx: baseCtx,
        consumeFirstSeenOnAttempt: false,
      );
      if (spoke) {
        _spokenFaultTypesThisRep.add(id);
      }
    }

    _faultFirstSeenRep.removeWhere((id, _) => !criticalIdsThisRep.contains(id));
  }

  bool _sayFaultRecord({
    required FaultRecord fault,
    required int repNumber,
    required CueContext baseCtx,
    required bool consumeFirstSeenOnAttempt,
  }) {
    return _sayFault(
      id: fault.type.trim(),
      affectsForm: fault.affectsForm,
      repNumber: repNumber,
      baseCtx: baseCtx,
      consumeFirstSeenOnAttempt: consumeFirstSeenOnAttempt,
    );
  }

  bool _sayFault({
    required String id,
    required bool affectsForm,
    required int repNumber,
    required CueContext baseCtx,
    required bool consumeFirstSeenOnAttempt,
  }) {
    if (affectsForm) {
      final firstSeenRep = _faultFirstSeenRep[id];
      if (consumeFirstSeenOnAttempt && firstSeenRep == null) {
        _faultFirstSeenRep[id] = repNumber;
      }
      final persistence =
          repNumber - (firstSeenRep ?? _faultFirstSeenRep[id] ?? repNumber);
      final spoke = _coach.say(
        CueType.criticalFault,
        VoiceContent.key(script.faultKey(id)),
        baseCtx.copyWith(contentKey: id, faultPersistence: persistence),
      );
      if (!consumeFirstSeenOnAttempt && spoke && firstSeenRep == null) {
        _faultFirstSeenRep[id] = repNumber;
      }
      return spoke;
    }

    final softPool = script.softPoolFor(id);
    if (softPool.isEmpty) return false;
    return _coach.say(
      CueType.softFault,
      VoiceContent.pool(softPool),
      baseCtx.copyWith(contentKey: id),
    );
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

  bool _isKnownFaultId(String id) {
    if (id.isEmpty) return false;
    return script.faultIds.isEmpty || script.faultIds.contains(id);
  }

  List<FaultRecord> _sortedFaults(List<FaultRecord> faults) {
    final sorted = faults.where((fault) {
      return _isKnownFaultId(fault.type.trim());
    }).toList();
    sorted.sort((a, b) {
      if (a.affectsForm != b.affectsForm) {
        return a.affectsForm ? -1 : 1;
      }
      final priorityCompare = a.priority.compareTo(b.priority);
      if (priorityCompare != 0) return priorityCompare;
      return a.type.compareTo(b.type);
    });
    return sorted;
  }

  List<String> _sortedFaultIdsForRepLog(RepLog? repLog, List<String> ids) {
    final sorted = ids.toList();
    sorted.sort((a, b) {
      final aAffects = _faultAffectsFormFor(repLog, a);
      final bAffects = _faultAffectsFormFor(repLog, b);
      if (aAffects != bAffects) return aAffects ? -1 : 1;
      final priorityCompare =
          _faultPriorityFor(repLog, a).compareTo(_faultPriorityFor(repLog, b));
      if (priorityCompare != 0) return priorityCompare;
      return a.compareTo(b);
    });
    return sorted;
  }

  bool _faultAffectsFormFor(RepLog? repLog, String id) {
    final raw = repLog?.data['fault_affects_form'];
    if (raw is Map) {
      final value = raw[id];
      if (value is bool) return value;
    }
    return !(repLog?.correctForm ?? true);
  }

  int _faultPriorityFor(RepLog? repLog, String id) {
    final raw = repLog?.data['fault_priorities'];
    if (raw is Map) {
      final value = raw[id];
      if (value is int) return value;
      if (value is num) return value.toInt();
    }
    return 99;
  }

  List<String> _faultIdsFor(RepLog? repLog) {
    if (repLog == null) return const [];
    final raw = repLog.data['fault_types'];
    if (raw is! Iterable) return const [];
    final ids = <String>[];
    final seen = <String>{};
    for (final item in raw) {
      final id = item.toString().trim();
      if (id.isEmpty) continue;
      if (_isKnownFaultId(id) && seen.add(id)) {
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
