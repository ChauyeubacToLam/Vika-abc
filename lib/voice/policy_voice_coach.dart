/// The adapter (design decision D1): implements the existing
/// `ExerciseVoiceCoach` interface exactly, so the camera/exercise pipeline
/// is untouched. Holds prior-frame state and diffs it — that diffing is
/// the entire reason the per-frame contract doesn't need to change.
///
/// Build spec: `docs/reference/voice-coach/implementation-guide.md` §7.
///
/// Live since the glute-bridge pilot (07-09/07-10): `GluteBridge.
/// createVoiceCoach()` instantiates this adapter directly; other exercises
/// still return the legacy generic coach until fleet rollout.
///
/// - [targetReps] is optional because some exercises are holds/timers. When
///   present it drives the final-two count anchor and lets hustle use a
///   target-proven final-push line; generic hustle still requires an exercise
///   to opt in via [VoiceScript.effortPhaseKeys].
/// - Setup/tracking-safety speaks off the typed `ExerciseBase.guidanceSignal`
///   (`GuidanceSignal`, 07-10) via the `_SetupSafetyVoiceController` latch
///   channel below — the old "no structured safety event exists" gap is
///   closed.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../exercise/exercise_base.dart';
import '../exercise/fault_record.dart';
import '../utils/debouncer.dart';
import '../utils/exercise_logger.dart';
import 'earcon_player.dart';
import 'voice_coach.dart';
import 'voice_content.dart';

class PolicyVoiceCoach implements ExerciseVoiceCoach {
  // TUNE-ON-CALIBRATION: placeholder gap collection window for Stage A logs.
  static const int kBaselineGapCount = 2;

  // TUNE-ON-CALIBRATION: placeholder stretch ratio until device runs land.
  static const double kStretchRatio = 1.5;

  // TUNE-ON-CALIBRATION: placeholder lower bound to ignore tiny transitions.
  static const int kMinArmGapMs = 800;

  /// Feel-tune (NOT canonical): elapsed-hold offsets, in ms, at which the
  /// voiced activation countdown fires "ba / hai / một". Each is a threshold
  /// into the 3s hold; the last is deliberately < HOLD_STILL_REQUIRED_DURATION
  /// (3000ms) so "một" fires on a frame BEFORE the state machine flips to
  /// activated — the moment activation lands, `holdStillElapsedMs` returns null
  /// — letting the spoken "một" land at/near activation. ~0.8s spacing reads as
  /// a "ba-hai-một-go" cadence over the hold.
  static const List<int> kActivationCountOffsetsMs = <int>[800, 1600, 2400];

  /// Generous ceiling on the wait for intro audio to finish before the grace
  /// window re-anchors (item 2). The player's own `waitUntilIdle` default is 4s
  /// and resolves silently on timeout — the two-line intro can run past that,
  /// so a naive 4s wait would re-anchor grace mid-intro and let graced safety
  /// lines fire over the intro tail. Sized well past any real intro.
  static const Duration _introIdleTimeout = Duration(seconds: 30);

  // Feel-tune guards for short holds. Final-10 needs a 5s gap after halfway;
  // spoken 5..1 starts only when it also has a 5s gap after halfway.
  static const double kMinHalfwayHoldSeconds = 10.0;
  static const double kMinFinalTenHoldSeconds = 30.0;
  static const double kMinSpokenCountdownHoldSeconds = 20.0;

  PolicyVoiceCoach({
    required this.script,
    required VoiceCoach coach,
    EarconSink? earcon,
    this.targetReps,
    this.countsByRepNumber = true,
  })  : _coach = coach,
        _earcon = earcon ?? EarconPlayer();

  /// This exercise's footprint: which pools + which fault ids + (if any)
  /// phase cues.
  final VoiceScript script;

  /// Prescribed rep count for this set, if known — see the gap noted in
  /// the library doc comment above.
  final int? targetReps;

  /// Rep-counted exercises should speak the actual completed rep number.
  ///
  /// Hold/timer exercises still use [VoiceScript.countPool] because their
  /// count keys are time thresholds, not rep indexes. That path is known to
  /// need a separate timer-specific pass; this flag keeps that scope out of
  /// the rep-count fix.
  final bool countsByRepNumber;

  final VoiceCoach _coach;
  final EarconSink _earcon;
  final _SetupSafetyVoiceController _setupSafetyController =
      _SetupSafetyVoiceController();

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
  final Set<String> _liveCriticalFaultTypesThisRep = <String>{};
  final Map<String, int> _liveCriticalFaultPriorityThisRep = {};
  final Set<String> _reminderEligibleFaultTypes = <String>{};
  final Map<String, int> _reminderPriorityByFault = {};
  final Map<String, int> _reminderStreakByFault = {};

  // Track only a reminder that actually spoke. Rep-number arithmetic makes
  // one silent rep expire the ban without another state transition.
  String? _lastReminderFaultId;
  int? _lastReminderRep;

  String? _lastPhaseKey;
  bool _awaitingRepStart = false;
  int? _lastRepLandedAtMs;
  final List<int> _validGapMs = <int>[];
  int? _baselineGapMs;
  bool _finalPushConsumed = false;
  bool _gapVoidLogged = false;

  String? _lastPhaseCue;
  int _trackedRepNumber = 1;

  // --- Deterministic per-set setup cues (intro / countdown / ready / done).
  // All reset per set in the set-start block so a genuine new set re-fires them.
  bool _introFired = false;
  bool _introSpoke = false;
  bool _introAudioEnded = false;
  int? _introAudioEndMs;
  bool _readySpoken = false;
  bool _setCompleteSpoken = false;
  final Set<int> _countdownSpoken = <int>{};
  bool _holdCountingActive = false;
  bool _resumeReactivationPending = false;

  int? _lastEndToneRep;
  String? _lastHoldPhaseKey;
  int? _trackedHoldRepNumber;
  double? _previousHoldSeconds;
  final Set<String> _holdMilestonesFired = <String>{};
  final Set<int> _holdCountdownSpoken = <int>{};
  bool _cleanSinceLastHoldMilestone = true;
  bool _lastHoldMilestoneWasPraise = false;
  bool _rehHoldHustleArmed = false;
  bool _holdPoolsValidated = false;
  final Set<String> _reportedHoldContractIssues = <String>{};

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
    final justCompleted = state == ExerciseState.completed &&
        _lastExerciseState != ExerciseState.completed;
    final startedResumeReactivation = state == ExerciseState.notActivated &&
        exercise.isReactivatingAfterPause &&
        _lastExerciseState == ExerciseState.activated;
    if (startedResumeReactivation) {
      _resumeReactivationPending = true;
      _readySpoken = false;
      _countdownSpoken.clear();
      _holdCountingActive = false;
    }
    final justReactivatedAfterPause =
        justActivated && _resumeReactivationPending;
    // A genuine set restart: the machine dropped back to notActivated from a
    // later state (completed set → the next set). Re-arm the per-set one-shots
    // so the intro/countdown/ready/set-complete all fire again next set. Inert
    // for the single-set pilot (the machine never leaves completed there).
    final restartedSet = state == ExerciseState.notActivated &&
        !exercise.isReactivatingAfterPause &&
        _lastExerciseState != null &&
        _lastExerciseState != ExerciseState.notActivated;
    if (restartedSet) {
      _hasBegunSet = false;
      debugPrint('[VoiceSetup] set restart — per-set one-shots re-armed');
    }

    final isSetStart = !_hasBegunSet;
    if ((justActivated && !justReactivatedAfterPause) || !_hasBegunSet) {
      // New set / activation → wipe hunger + all diff state (§7 step 1).
      _coach.beginSet();
      exercise.beginGuidanceSignalGrace(nowMs: exercise.frameTimestampMs);
      _setupSafetyController.beginSet();
      _faultFirstSeenRep.clear();
      _reminderEligibleFaultTypes.clear();
      _reminderPriorityByFault.clear();
      _reminderStreakByFault.clear();
      _lastReminderFaultId = null;
      _lastReminderRep = null;
      _startTrackingRep(repCount + 1);
      _lastPhaseCue = null;
      _lastPhaseKey = null;
      _awaitingRepStart = false;
      _lastRepLandedAtMs = null;
      _validGapMs.clear();
      _baselineGapMs = null;
      _finalPushConsumed = false;
      _gapVoidLogged = false;
      if (isSetStart) _resetSetupCueState();
      _hasBegunSet = true;
    } else if (justReactivatedAfterPause) {
      exercise.beginGuidanceSignalGrace(nowMs: exercise.frameTimestampMs);
      _startTrackingRep(repCount + 1);
      _lastPhaseCue = null;
      _lastPhaseKey = null;
      _awaitingRepStart = false;
      _lastRepLandedAtMs = null;
      _gapVoidLogged = false;
      _resumeReactivationPending = false;
    }
    _lastExerciseState = state;

    // Per-set intro: <slug>.setup_position + <slug>.active_intro, back-to-back,
    // ONCE at set start, unconditional (no pose/in-frame gating — the intro is
    // what tells the user to get in frame). Latched by _introFired.
    if (isSetStart) _fireSetupIntro();

    // Voice-grace window = the intro's actual duration (voice-only; the UI
    // renders signage live and never consults grace). While the intro audio
    // plays, keep the shared window pinned to NOW every frame so it can't
    // expire mid-intro and let a graced safety line fire over the intro tail.
    // At intro-audio-end the window CLOSES — no settle tail; the latch's ~1s
    // enter debounce (accrued during the intro) is the only residual delay.
    // The end edge also stamps _introAudioEndMs frame-synchronously: the
    // stuck-user re-tell's delay floor, stamped in BOTH branches below because
    // the re-tell needs a floor even when the intro produced no audio.
    if (_introFired &&
        !_introAudioEnded &&
        exercise.currentPhaseKey != REP_COUNTED_HOLD_PHASE_RESTING &&
        !exercise.isReArmingHold) {
      exercise.beginGuidanceSignalGrace(nowMs: exercise.frameTimestampMs);
    } else if (_introAudioEnded && _introAudioEndMs == null) {
      _introAudioEndMs = exercise.frameTimestampMs;
      if (_introSpoke && !justActivated) {
        exercise.endGuidanceSignalGrace(nowMs: exercise.frameTimestampMs);
        debugPrint(
          '[VoiceSetup] intro audio ended — voice grace CLOSED, '
          're-tell floor stamped',
        );
      } else {
        debugPrint(
          '[VoiceSetup] intro end stamped (${_introSpoke ? 'activation-edge '
              're-anchor kept' : 'no intro audio — set-start fallback window '
              'stays'})',
        );
      }
      // !_introSpoke → no spoken first-telling happened, so the fixed
      // kGuidanceSignalGraceMs window from the set-start anchor above still
      // earns its keep (the ruled fallback) — leave it running.
      // justActivated → the activation-edge re-anchor (retained ruling) was
      // taken this same frame in the set-start block above; closing here
      // would clobber it, so the close yields. The countdown-termination
      // path can't hit this: it only runs while notActivated.
    }

    _setupSafetyController.processFrame(
      exercise: exercise,
      repCount: repCount,
      script: script,
      coach: _coach,
      introAudioEndMs: _introAudioEndMs,
    );

    // Voiced activation countdown, synced to the 3s hold (item 4). Runs before
    // the early return because it fires during notActivated.
    _handleActivationCountdown(exercise);

    // common.ready on the activation edge; the end tone on the completion
    // edge. Both deterministic, once per set (hard rule 2).
    if (justActivated && !_readySpoken) {
      _readySpoken = true;
      _coach.say(
        CueType.setup,
        VoiceContent.key('common.ready'),
        const CueContext(repNumber: 0, contentKey: 'ready'),
      );
    }

    // Some exercise state machines land their final rep and flip the base to
    // completed in the same frame. Drain that rep before the completion early
    // return so count=registration still includes the final rep/hold.
    if (justCompleted && repCount > _lastRepCount) {
      _drainLiveFaults(exercise: exercise, repNumber: _trackedRepNumber);
      _handleRepLanded(exercise: exercise, repCount: repCount);
      _startTrackingRep(repCount + 1);
      _lastRepCount = repCount;
    }
    if (justCompleted && !_setCompleteSpoken) {
      _setCompleteSpoken = true;
      if (!exercise.usesRepCountedHolds || _lastEndToneRep != repCount) {
        unawaited(_earcon.endTone());
        _lastEndToneRep = repCount;
      }
      if (exercise.isFinalSet) {
        _coach.say(
          CueType.setup,
          VoiceContent.key('common.exercise_complete'),
          const CueContext(repNumber: 0, contentKey: 'exercise_complete'),
        );
      }
    }

    if (exercise.usesRepCountedHolds) {
      _handleRepCountedHold(
        exercise: exercise,
        repCount: repCount,
        canSpeak:
            state == ExerciseState.activated && !exercise.isPaused && hasPose,
      );
    }

    if (state != ExerciseState.activated || exercise.isPaused || !hasPose) {
      _voidCurrentGapIfNeeded(
        exercise: exercise,
        repCount: repCount,
        reason: exercise.isPaused
            ? 'pause'
            : !hasPose
                ? 'pose_loss'
                : null,
      );
      _lastRepCount = repCount;
      return;
    }

    final repIncreased = repCount > _lastRepCount;
    if (repIncreased) {
      if (exercise.usesRepCountedHolds) {
        unawaited(_earcon.endTone());
        _lastEndToneRep = repCount;
      }
      _drainLiveFaults(exercise: exercise, repNumber: _trackedRepNumber);
      _handleRepLanded(exercise: exercise, repCount: repCount);
      _startTrackingRep(repCount + 1);
    } else {
      final inProgressRep = repCount + 1;
      if (_trackedRepNumber != inProgressRep) {
        _startTrackingRep(inProgressRep);
      }
    }

    // The rep-start reminder must claim the outcome slot at the commit edge
    // BEFORE the in-progress live-fault drain. The reminder is feedforward
    // ("lần này nhớ..."): the spec has it fire first, then same-fault-
    // already-voiced suppresses the re-correction for that fault this rep
    // ("remind, don't re-nag"). Draining first — the old order — let a
    // CONTINUOUS critical (neck_head, present from the start of nearly every
    // rep) grab the slot before the reminder ran, so the reminder lost to
    // `second-outcome-slot-is-critical-only` every rep and was near-silent on
    // device (Nam, 07-11). First-occurrence criticals are unaffected: a fault
    // with no prior-rep sighting has no eligible reminder, so it can never be
    // preempted here.
    _onRepAttemptBoundary(exercise: exercise, repCount: repCount);

    if (!repIncreased) {
      _drainLiveFaults(exercise: exercise, repNumber: repCount + 1);
    }
    _maybeSpeakPhaseCue(exercise: exercise, repCount: repCount);

    _lastRepCount = repCount;
  }

  void _resetSetupCueState() {
    _introFired = false;
    _introSpoke = false;
    _introAudioEnded = false;
    _introAudioEndMs = null;
    _readySpoken = false;
    _setCompleteSpoken = false;
    _countdownSpoken.clear();
    _holdCountingActive = false;
    _lastEndToneRep = null;
    _lastHoldPhaseKey = null;
    _trackedHoldRepNumber = null;
    _previousHoldSeconds = null;
    _holdMilestonesFired.clear();
    _holdCountdownSpoken.clear();
    _cleanSinceLastHoldMilestone = true;
    _lastHoldMilestoneWasPraise = false;
    _rehHoldHustleArmed = false;
  }

  /// Speaks the per-set intro pair back-to-back via CueType.setup, then arms the
  /// intro-audio-end detector. The waitUntilIdle waiter is registered AFTER the
  /// say() calls have synchronously enqueued the lines, so it can't resolve
  /// against an already-idle sink and re-anchor grace at intro START; it uses a
  /// generous timeout so the player's silent 4s cap can't fire mid-intro.
  void _fireSetupIntro() {
    if (_introFired) return;
    _introFired = true;
    final spoke1 = _coach.say(
      CueType.setup,
      VoiceContent.key(script.setupPositionKey),
      const CueContext(repNumber: 0, contentKey: 'setup_position'),
    );
    final spoke2 = _coach.say(
      CueType.setup,
      VoiceContent.key(script.activeIntroKey),
      const CueContext(repNumber: 0, contentKey: 'active_intro'),
    );
    _introSpoke = spoke1 || spoke2;
    if (!_introSpoke) {
      // No intro audio was queued (cue suppressed / no mapping). There is
      // nothing to wait for, so mark it ended NOW — synchronously, not via the
      // async waiter — so grace collapses to the set-start anchor (the
      // fallback) this same frame instead of pinning open forever.
      debugPrint('[VoiceSetup] intro produced NO audio — fallback grace');
      _introAudioEnded = true;
      return;
    }
    debugPrint('[VoiceSetup] intro fired — voice grace pinned until audio end');
    // Register the waiter AFTER the say() calls have synchronously enqueued the
    // lines, so it can't resolve against an already-idle sink and re-anchor
    // grace at intro START. The generous timeout keeps the player's silent 4s
    // default from resolving mid-intro.
    unawaited(
      _coach.waitUntilIdle(timeout: _introIdleTimeout).then((_) {
        _introAudioEnded = true;
      }),
    );
  }

  /// Voiced "ba / hai / một" synced to the 3s activation hold (item 4).
  /// Deterministic (CueType.setup), never routed through rep-count thinning.
  /// Counts are perishable: a broken hold drops any pending count line and
  /// re-arms from "ba"; activation keeps the queue so "một" finishes as the
  /// "go" cue.
  void _handleActivationCountdown(ExerciseBase exercise) {
    final holdMs = exercise.holdStillElapsedMs;
    final inActivationContext =
        exercise.exerciseState == ExerciseState.notActivated ||
            exercise.isReArmingHold;
    final holding = holdMs != null && inActivationContext;

    if (holding) {
      _holdCountingActive = true;
      for (var i = 0; i < kActivationCountOffsetsMs.length; i++) {
        if (_countdownSpoken.contains(i)) continue;
        if (holdMs >= kActivationCountOffsetsMs[i]) {
          // A count firing while the intro is still playing TERMINATES it
          // (ruled): a user already holding the start position has no use for
          // setup instructions, and a count queued behind the intro would lag
          // the hold and read broken. Stop the sink (current + queued lines
          // dropped — the intro is one-shot and consumed, it never resumes),
          // mark intro-audio-end NOW so the voice grace closes with it and the
          // re-tell floor is stamped this same frame, then speak the count.
          if (exercise.exerciseState == ExerciseState.notActivated &&
              _introFired &&
              !_introAudioEnded) {
            _coach.stop();
            _introAudioEnded = true;
            _introAudioEndMs = exercise.frameTimestampMs;
            exercise.endGuidanceSignalGrace(nowMs: exercise.frameTimestampMs);
            debugPrint(
              '[VoiceSetup] countdown TERMINATED intro (user already in '
              'position) — grace closed',
            );
          }
          _countdownSpoken.add(i);
          final spokenNumber = kActivationCountOffsetsMs.length - i;
          _coach.say(
            CueType.setup,
            VoiceContent.key('$spokenNumber'),
            CueContext(repNumber: 0, contentKey: 'count_$spokenNumber'),
          );
        }
      }
      return;
    }

    if (!_holdCountingActive) return;
    // The hold ended. A break (still notActivated) drops the perishable pending
    // counts so no stale count plays; activation (now activated) keeps the
    // queue so a mid-play "một" survives. Either way the tracker re-arms.
    if (inActivationContext) {
      _coach.clearPending();
      debugPrint(
        '[VoiceSetup] hold BROKE — pending counts dropped, countdown '
        're-armed from ba',
      );
    }
    _holdCountingActive = false;
    _countdownSpoken.clear();
  }

  void _handleRepCountedHold({
    required ExerciseBase exercise,
    required int repCount,
    required bool canSpeak,
  }) {
    _validateRepCountedHoldContract(exercise);
    final phase = exercise.currentPhaseKey;
    final previousPhase = _lastHoldPhaseKey;
    final enteredDropping = previousPhase != REP_COUNTED_HOLD_PHASE_DROPPING &&
        phase == REP_COUNTED_HOLD_PHASE_DROPPING;
    final enteredHolding = previousPhase != REP_COUNTED_HOLD_PHASE_HOLDING &&
        phase == REP_COUNTED_HOLD_PHASE_HOLDING;
    final enteredResting = previousPhase != REP_COUNTED_HOLD_PHASE_RESTING &&
        phase == REP_COUNTED_HOLD_PHASE_RESTING;
    final enteredReArming = previousPhase == REP_COUNTED_HOLD_PHASE_RESTING &&
        phase == REP_COUNTED_HOLD_PHASE_RE_ARMING;
    final target = exercise.liveHoldTargetSeconds;
    final live = exercise.liveHoldSeconds;

    if (enteredResting) {
      _countdownSpoken.clear();
      _holdCountingActive = false;
    }
    if (enteredReArming) {
      unawaited(_earcon.restEndTone());
    }

    if (enteredDropping) {
      _cleanSinceLastHoldMilestone = false;
      if (target != null && live != null && live >= target * (2 / 3)) {
        _rehHoldHustleArmed = true;
      }
    }

    if (enteredHolding &&
        previousPhase == REP_COUNTED_HOLD_PHASE_DROPPING &&
        _rehHoldHustleArmed &&
        canSpeak) {
      _coach.say(
        CueType.hustle,
        VoiceContent.pool(script.hustlePool),
        CueContext(
          repNumber: repCount + 1,
          sinkBusy: _coach.isBusy,
        ),
      );
      _rehHoldHustleArmed = false;
    }
    _lastHoldPhaseKey = phase;

    if (!canSpeak ||
        phase != REP_COUNTED_HOLD_PHASE_HOLDING ||
        target == null ||
        live == null) {
      return;
    }

    final inProgressHold = repCount + 1;
    if (_trackedHoldRepNumber != inProgressHold) {
      _trackedHoldRepNumber = inProgressHold;
      _previousHoldSeconds = 0.0;
      _holdMilestonesFired.clear();
      _holdCountdownSpoken.clear();
      _cleanSinceLastHoldMilestone = true;
      _rehHoldHustleArmed = false;
    }

    if (exercise.liveFaults.isNotEmpty) {
      _cleanSinceLastHoldMilestone = false;
    }

    final previous = _previousHoldSeconds ?? live;
    if (target >= kMinHalfwayHoldSeconds) {
      _maybeFireHoldMilestone(
        id: 'halfway',
        key: 'common.time.halfway',
        threshold: target / 2,
        previous: previous,
        current: live,
        target: target,
        repNumber: inProgressHold,
      );
    }
    if (target >= kMinFinalTenHoldSeconds) {
      _maybeFireHoldMilestone(
        id: 'final_10',
        key: 'common.time.10s_left',
        threshold: target - 10,
        previous: previous,
        current: live,
        target: target,
        repNumber: inProgressHold,
      );
    }

    if (target >= kMinSpokenCountdownHoldSeconds) {
      for (var number = 5; number >= 1; number--) {
        if (_holdCountdownSpoken.contains(number)) continue;
        final threshold = target - number;
        if (!_crossed(previous, live, threshold)) continue;
        _holdCountdownSpoken.add(number);
        final expiresAtEarnedSecond = threshold + 1;
        _coach.say(
          CueType.count,
          VoiceContent.key('$number'),
          CueContext(
            repNumber: inProgressHold,
            contentKey: 'hold_countdown_$number',
          ),
          isStillRelevant: () {
            final now = exercise.liveHoldSeconds;
            return exercise.currentPhaseKey == REP_COUNTED_HOLD_PHASE_HOLDING &&
                exercise.repCount + 1 == inProgressHold &&
                now != null &&
                now < expiresAtEarnedSecond;
          },
        );
      }
    }
    _previousHoldSeconds = live;
  }

  void _validateRepCountedHoldContract(ExerciseBase exercise) {
    if (!_holdPoolsValidated) {
      _holdPoolsValidated = true;
      final emptyPools = <String>[
        if (script.praisePool.isEmpty) 'praisePool',
        if (script.hustlePool.isEmpty) 'hustlePool',
      ];
      if (emptyPools.isNotEmpty) {
        _reportHoldContractIssue(
          'empty-pools',
          '${exercise.exerciseName} is a rep-counted hold but '
              '${emptyPools.join(' + ')} is empty; deterministic milestone '
              'outcomes would go silent.',
        );
      }
    }

    final phase = exercise.currentPhaseKey;
    if (!REP_COUNTED_HOLD_PHASE_KEYS.contains(phase)) {
      _reportHoldContractIssue(
        'phase:$phase',
        '${exercise.exerciseName} reports unsupported rep-counted-hold phase '
            '"$phase". Expected one of $REP_COUNTED_HOLD_PHASE_KEYS.',
      );
    }
  }

  void _reportHoldContractIssue(String key, String message) {
    if (!_reportedHoldContractIssues.add(key)) return;
    debugPrint('[VoiceGuard] $message');
    assert(false, message);
  }

  void _maybeFireHoldMilestone({
    required String id,
    required String key,
    required double threshold,
    required double previous,
    required double current,
    required double target,
    required int repNumber,
  }) {
    if (_holdMilestonesFired.contains(id) ||
        !_crossed(previous, current, threshold)) {
      return;
    }
    _holdMilestonesFired.add(id);
    _coach.say(
      CueType.count,
      VoiceContent.key(key),
      CueContext(repNumber: repNumber, contentKey: id),
    );

    final isFinalStretch = threshold >= target * (2 / 3);
    var wantHustle = !_cleanSinceLastHoldMilestone || isFinalStretch;
    if (!wantHustle && _lastHoldMilestoneWasPraise) {
      wantHustle = true;
    }
    if (wantHustle) {
      _coach.say(
        CueType.hustle,
        VoiceContent.pool(script.hustlePool),
        CueContext(repNumber: repNumber, force: true),
      );
    } else {
      _coach.say(
        CueType.praise,
        VoiceContent.pool(script.praisePool),
        CueContext(
          repNumber: repNumber,
          clean: true,
          formScore: 1.0,
          force: true,
        ),
      );
    }
    _lastHoldMilestoneWasPraise = !wantHustle;
    _cleanSinceLastHoldMilestone = true;
  }

  bool _crossed(double previous, double current, double threshold) =>
      previous < threshold && current >= threshold;

  void _handleRepLanded({
    required ExerciseBase exercise,
    required int repCount,
  }) {
    _lastRepLandedAtMs = exercise.frameTimestampMs;
    _awaitingRepStart = true;
    _gapVoidLogged = false;

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
    final sinkBusyBeforeCount = _coach.isBusy;
    final countSpoke = _coach.say(CueType.count, countContent, baseCtx);
    // Device-log observability: rep counts and the activation countdown share
    // the numeral keys ('1'..'3'), so a bare player "queued: 3" can't be
    // attributed. This line + the [VoiceCoach] say-type log make count
    // thinning auditable on device (an "it counts every rep" report is
    // unfalsifiable from the player log alone).
    debugPrint(
      '[VoiceCount] rep=$repCount spoke=$countSpoke '
      'anchor=${repCount <= 1 || isFinalReps} target=$targetReps',
    );

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

    _maybePairFinalPush(
      baseCtx: baseCtx,
      countSpoke: countSpoke,
      repCount: repCount,
      sinkBusyBeforeCount: sinkBusyBeforeCount,
    );
    _refreshReminderEligibilityAfterRep();
  }

  void _maybePairFinalPush({
    required CueContext baseCtx,
    required bool countSpoke,
    required int repCount,
    required bool sinkBusyBeforeCount,
  }) {
    final target = targetReps;
    final oneRemaining = target != null && repCount == target - 1;
    if (!oneRemaining || !countSpoke || script.hustleFinalPool.isEmpty) {
      return;
    }

    final fired = _coach.say(
      CueType.hustle,
      VoiceContent.pool(script.hustleFinalPool),
      baseCtx.copyWith(sinkBusy: sinkBusyBeforeCount),
    );
    if (fired) _finalPushConsumed = true;
  }

  void _startTrackingRep(int repNumber) {
    _trackedRepNumber = repNumber;
    _spokenFaultTypesThisRep.clear();
    _seenFaultTypesThisRep.clear();
    _liveCriticalFaultTypesThisRep.clear();
    _liveCriticalFaultPriorityThisRep.clear();
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
      _rememberLiveCriticalFault(fault);
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

  void _rememberLiveCriticalFault(FaultRecord fault) {
    if (!fault.affectsForm) return;
    final id = fault.type.trim();
    _liveCriticalFaultTypesThisRep.add(id);
    final previousPriority = _liveCriticalFaultPriorityThisRep[id];
    if (previousPriority == null || fault.priority < previousPriority) {
      _liveCriticalFaultPriorityThisRep[id] = fault.priority;
    }
  }

  void _refreshReminderEligibilityAfterRep() {
    _reminderEligibleFaultTypes
      ..clear()
      ..addAll(_liveCriticalFaultTypesThisRep);
    _reminderPriorityByFault
      ..clear()
      ..addAll(_liveCriticalFaultPriorityThisRep);
    _reminderStreakByFault
        .removeWhere((id, _) => !_liveCriticalFaultTypesThisRep.contains(id));
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
    return repCount > target - 2; // Final two reps — count anchor only.
  }

  void _voidCurrentGapIfNeeded({
    required ExerciseBase exercise,
    required int repCount,
    required String? reason,
  }) {
    final landedAtMs = _lastRepLandedAtMs;
    if (_awaitingRepStart &&
        landedAtMs != null &&
        reason != null &&
        !_gapVoidLogged) {
      final gapMs = exercise.frameTimestampMs - landedAtMs;
      debugPrint(
        '[VoiceHustle] void rep=${repCount + 1} reason=$reason gapMs=$gapMs',
      );
      _gapVoidLogged = true;
    }
    _lastRepLandedAtMs = null;
  }

  void _onRepAttemptBoundary({
    required ExerciseBase exercise,
    required int repCount,
  }) {
    final repStartPhaseKeys = script.repStartPhaseKeys;
    final effortPhaseKeys = script.effortPhaseKeys;
    if (repStartPhaseKeys.isEmpty && effortPhaseKeys.isEmpty) return;

    final currentPhaseKey = exercise.currentPhaseKey;
    final enteredRepStart = !repStartPhaseKeys.contains(_lastPhaseKey) &&
        repStartPhaseKeys.contains(currentPhaseKey);
    final enteredEffort = !effortPhaseKeys.contains(_lastPhaseKey) &&
        effortPhaseKeys.contains(currentPhaseKey);
    _lastPhaseKey = currentPhaseKey;
    if ((!enteredRepStart && !enteredEffort) || !_awaitingRepStart) return;

    final startedRep = repCount + 1;
    final target = targetReps;
    final afterTarget = target != null && startedRep > target;

    if (enteredRepStart && !afterTarget) {
      _maybeSpeakReminder(startedRep: startedRep);
    }
    if (!enteredEffort) {
      if (effortPhaseKeys.isEmpty || afterTarget) {
        _awaitingRepStart = false;
      }
      return;
    }

    _awaitingRepStart = false;
    if (afterTarget) return;

    final landedAtMs = _lastRepLandedAtMs;
    if (landedAtMs == null) return;

    final gapMs = exercise.frameTimestampMs - landedAtMs;

    // Fast-path artifact guard (Stage-B watch item, confirmed on device 07-11):
    // the glute descending→ascending fast path emits ~0ms "gaps" that are not
    // real inter-rep hesitation. They can never arm (arming needs
    // gapMs > kMinArmGapMs) and, left in the sample, they deflate the baseline
    // median so genuine gaps look stretched. Exclude them from the baseline
    // entirely — an unreal gap neither arms nor calibrates.
    if (gapMs < kMinArmGapMs) {
      _debugLogGap(
        startedRep: startedRep,
        gapMs: gapMs,
        baselineMs: _baselineGapMs,
        armed: false,
      );
      return;
    }

    _validGapMs.add(gapMs);

    if (_baselineGapMs == null) {
      if (_validGapMs.length >= kBaselineGapCount) {
        _baselineGapMs = _medianMs(_validGapMs.take(kBaselineGapCount));
      }
      _debugLogGap(
        startedRep: startedRep,
        gapMs: gapMs,
        baselineMs: _baselineGapMs,
        armed: false,
      );
      return;
    }

    final baselineMs = _baselineGapMs!;
    final armed = gapMs > baselineMs * kStretchRatio && gapMs > kMinArmGapMs;
    _debugLogGap(
      startedRep: startedRep,
      gapMs: gapMs,
      baselineMs: baselineMs,
      armed: armed,
    );
    if (!armed) return;

    final isFinalRep = target != null && startedRep == target;
    if (isFinalRep && _finalPushConsumed) return;

    final pool = isFinalRep && script.hustleFinalPool.isNotEmpty
        ? script.hustleFinalPool
        : script.hustlePool;
    _coach.say(
      CueType.hustle,
      VoiceContent.pool(pool),
      CueContext(repNumber: startedRep, sinkBusy: _coach.isBusy),
    );
  }

  bool _maybeSpeakReminder({required int startedRep}) {
    final id = _highestPriorityReminderFaultId(startedRep: startedRep);
    if (id == null) return false;
    final pool = script.reminderPoolFor(id);
    if (pool.isEmpty) return false;

    final streak = _reminderStreakByFault[id] ?? 0;
    final spoke = _coach.say(
      CueType.reminder,
      VoiceContent.pool(pool),
      CueContext(
        repNumber: startedRep,
        isFinalReps: _isFinalReps(startedRep),
        clean: false,
        formScore: 0.0,
        contentKey: id,
        faultPersistence: streak,
      ),
    );
    if (spoke) {
      _reminderStreakByFault[id] = streak + 1;
      _lastReminderFaultId = id;
      _lastReminderRep = startedRep;
    }
    return spoke;
  }

  String? _highestPriorityReminderFaultId({required int startedRep}) {
    final lastReminderRep = _lastReminderRep;
    final eligible = _reminderEligibleFaultTypes
        .where((id) => script.reminderPoolFor(id).isNotEmpty)
        .where(
          (id) => !(id == _lastReminderFaultId &&
              lastReminderRep != null &&
              startedRep == lastReminderRep + 1),
        )
        .toList();
    if (eligible.isEmpty) return null;
    eligible.sort((a, b) {
      final priorityCompare = (_reminderPriorityByFault[a] ?? 99)
          .compareTo(_reminderPriorityByFault[b] ?? 99);
      if (priorityCompare != 0) return priorityCompare;
      return a.compareTo(b);
    });
    return eligible.first;
  }

  int _medianMs(Iterable<int> values) {
    final sorted = values.toList()..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  void _debugLogGap({
    required int startedRep,
    required int gapMs,
    required int? baselineMs,
    required bool armed,
  }) {
    debugPrint(
      '[VoiceHustle] gap rep=$startedRep gapMs=$gapMs '
      'baselineMs=${baselineMs ?? 'collecting'} armed=$armed',
    );
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
    return _coach.waitUntilIdle(timeout: timeout);
  }

  @override
  void dispose() {
    _coach.dispose();
    _earcon.dispose();
  }
}

enum _SafetyVoiceClass {
  orientation,
  bodyInFrame,
  paused,
  resume,
  setupPosition,
  phoneLandscape,
  phonePortrait,
}

class _SetupSafetyVoiceController {
  static const int _debounceFrames = 30;
  static const int _recueMs = 10000;

  /// Feel-tune (NOT canonical): delay from intro-audio-end before the stuck-user
  /// setup_position re-tell fires (item 3). Separate constant from [_recueMs]
  /// (the mid-set re-cue) even though both are ~10s today — the review-targets
  /// list treats them as independent knobs (this one is measured from
  /// intro-audio-end and watched against real floor-settling times, that one
  /// from latch start).
  static const int _setupRetellDelayMs = 10000;

  final Map<_SafetyVoiceClass, _SteadyGuidanceLatch> _steadyLatches = {
    _SafetyVoiceClass.orientation: _SteadyGuidanceLatch(
      enterFrames: _debounceFrames,
      exitFrames: _debounceFrames,
      recueMs: _recueMs,
    ),
    _SafetyVoiceClass.bodyInFrame: _SteadyGuidanceLatch(
      enterFrames: _debounceFrames,
      exitFrames: _debounceFrames,
      recueMs: _recueMs,
    ),
    // Stuck-user re-tell: entry fire SUPPRESSED (the intro already told them);
    // the ONE fire is the delayed re-tell, gated on intro-audio-end via
    // delayFloorMs so it never speaks over the intro.
    _SafetyVoiceClass.setupPosition: _SteadyGuidanceLatch(
      enterFrames: _debounceFrames,
      exitFrames: _debounceFrames,
      recueMs: _setupRetellDelayMs,
      fireOnEntry: false,
    ),
    // Phone-orientation rotate prompts (ruled 07-11, device-driven — Nam hit
    // the silent rotate signage on device). Standard entry-fire latches;
    // ungraced (phone setup happens BEFORE getting into position), so with
    // wrong orientation at set start the rotate line queues right behind the
    // intro (FIFO) — flagged as a feel-check, not gated.
    _SafetyVoiceClass.phoneLandscape: _SteadyGuidanceLatch(
      enterFrames: _debounceFrames,
      exitFrames: _debounceFrames,
      recueMs: _recueMs,
    ),
    _SafetyVoiceClass.phonePortrait: _SteadyGuidanceLatch(
      enterFrames: _debounceFrames,
      exitFrames: _debounceFrames,
      recueMs: _recueMs,
    ),
  };

  _SafetyVoiceRequest? _pending;
  bool _pausedWasPresent = false;
  bool _resumeWasPresent = false;

  void beginSet() {
    _pending = null;
    _pausedWasPresent = false;
    _resumeWasPresent = false;
    for (final latch in _steadyLatches.values) {
      latch.reset();
    }
  }

  void processFrame({
    required ExerciseBase exercise,
    required int repCount,
    required VoiceScript script,
    required VoiceCoach coach,
    int? introAudioEndMs,
  }) {
    final nowMs = exercise.frameTimestampMs;
    final signal = exercise.guidanceSignal;
    final activeClass = _classForSignal(signal);
    final activeGrace =
        signal != null && exercise.isGuidanceGraceActive(signal.kind);

    _handleEdgeRequests(
      activeClass: activeClass,
      nowMs: nowMs,
      script: script,
    );

    for (final entry in _steadyLatches.entries) {
      final voiceClass = entry.key;
      final present = activeClass == voiceClass;
      final request = entry.value.update(
        present: present,
        nowMs: nowMs,
        voiceClass: voiceClass,
        key: _keyForClass(voiceClass, script),
        graceActive: present && activeGrace,
        // Only the fireOnEntry:false (stuck-setup) latch consults this: its
        // delayed fire is floored at intro-audio-end, so a null floor (intro
        // still playing / never played) blocks the re-tell entirely.
        delayFloorMs: introAudioEndMs,
      );
      if (request != null) {
        _pending = request;
      }
    }

    _pump(
      nowMs: nowMs,
      repCount: repCount,
      activeClass: activeClass,
      coach: coach,
    );
  }

  void _handleEdgeRequests({
    required _SafetyVoiceClass? activeClass,
    required int nowMs,
    required VoiceScript script,
  }) {
    final pausedPresent = activeClass == _SafetyVoiceClass.paused;
    if (pausedPresent && !_pausedWasPresent) {
      _pending = const _SafetyVoiceRequest(
        voiceClass: _SafetyVoiceClass.paused,
        key: 'common.paused',
        edge: true,
        trigger: 'paused-edge',
      );
    }
    _pausedWasPresent = pausedPresent;

    final resumePresent = activeClass == _SafetyVoiceClass.resume;
    if (resumePresent && !_resumeWasPresent) {
      _pending = const _SafetyVoiceRequest(
        voiceClass: _SafetyVoiceClass.resume,
        key: 'common.resume',
        edge: true,
        trigger: 'resume-edge',
      );
    }
    _resumeWasPresent = resumePresent;
  }

  void _pump({
    required int nowMs,
    required int repCount,
    required _SafetyVoiceClass? activeClass,
    required VoiceCoach coach,
  }) {
    final request = _pending;
    if (request == null) return;
    if (coach.isBusy) return;

    final isPaused = request.voiceClass == _SafetyVoiceClass.paused;

    if (!request.edge && activeClass != request.voiceClass) {
      debugPrint(
        '[VoiceGuard] DROP ${request.key} (${request.trigger}) — condition '
        'cleared before speak (latest-wins re-validation)',
      );
      _pending = null;
      return;
    }
    if (request.edge && isPaused && activeClass != _SafetyVoiceClass.paused) {
      debugPrint(
        '[VoiceGuard] DROP ${request.key} (paused-edge) — pause already over',
      );
      _pending = null;
      return;
    }

    debugPrint('[VoiceGuard] fire ${request.key} (${request.trigger})');
    coach.say(
      CueType.safety,
      VoiceContent.key(request.key),
      CueContext(
        repNumber: repCount,
        contentKey: request.key,
        sinkBusy: coach.isBusy,
      ),
    );
    _pending = null;
  }

  _SafetyVoiceClass? _classForSignal(GuidanceSignal? signal) {
    return switch (signal?.kind) {
      GuidanceClass.turnSide ||
      GuidanceClass.faceCamera =>
        _SafetyVoiceClass.orientation,
      GuidanceClass.bodyInFrame ||
      GuidanceClass.lighting =>
        _SafetyVoiceClass.bodyInFrame,
      GuidanceClass.paused => _SafetyVoiceClass.paused,
      GuidanceClass.resume => _SafetyVoiceClass.resume,
      GuidanceClass.setupPosition => _SafetyVoiceClass.setupPosition,
      // Phone-orientation prompts voiced since 07-11 (Nam's device ruling).
      GuidanceClass.phoneLandscape => _SafetyVoiceClass.phoneLandscape,
      GuidanceClass.phonePortrait => _SafetyVoiceClass.phonePortrait,
      // holdStill stays lineless: the voiced activation countdown (item 4) owns
      // that state's audio — a "giữ yên" line would talk over its own count.
      // searching stays silent by ruling: the setup intro covers "get in
      // frame", and searching is reassurance, not a correction.
      GuidanceClass.searching || GuidanceClass.holdStill || null => null,
    };
  }

  String _keyForClass(_SafetyVoiceClass voiceClass, VoiceScript script) {
    return switch (voiceClass) {
      _SafetyVoiceClass.orientation => 'common.side_orientation',
      _SafetyVoiceClass.bodyInFrame => 'common.body_in_frame',
      _SafetyVoiceClass.paused => 'common.paused',
      _SafetyVoiceClass.resume => 'common.resume',
      // Replays the intro's own first line (v1 — a fuller "help" variant is a
      // later recording; the mechanism doesn't wait for it).
      _SafetyVoiceClass.setupPosition => script.setupPositionKey,
      _SafetyVoiceClass.phoneLandscape => 'common.rotate_landscape',
      _SafetyVoiceClass.phonePortrait => 'common.rotate_portrait',
    };
  }
}

class _SteadyGuidanceLatch {
  _SteadyGuidanceLatch({
    required int enterFrames,
    required int exitFrames,
    required this.recueMs,
    this.fireOnEntry = true,
  })  : _enter = Debouncer(requiredFrames: enterFrames),
        _exit = Debouncer(requiredFrames: exitFrames);

  final Debouncer _enter;
  final Debouncer _exit;
  final int recueMs;

  /// When true (orientation / body_in_frame): fire on debounced entry, then ONE
  /// mid-set re-cue after [recueMs] of continuous latching. When false
  /// (stuck-setup): entry fire suppressed; the ONE fire IS the delayed re-tell.
  final bool fireOnEntry;

  bool _latched = false;
  bool _recued = false;
  int? _latchedSinceMs;

  _SafetyVoiceRequest? update({
    required bool present,
    required int nowMs,
    required _SafetyVoiceClass voiceClass,
    required String key,
    required bool graceActive,
    int? delayFloorMs,
  }) {
    if (graceActive) {
      _enter.update(present);
      if (!present) {
        _exit.update(true);
      } else {
        _exit.reset();
      }
      return null;
    }

    if (!_latched) {
      if (_enter.update(present)) {
        _latched = true;
        _recued = false;
        _latchedSinceMs = nowMs;
        _exit.reset();
        return fireOnEntry
            ? _SafetyVoiceRequest(voiceClass: voiceClass, key: key)
            : null; // suppressed entry fire — the delayed re-tell is the fire.
      }
      return null;
    }

    if (!present) {
      if (_exit.update(true)) {
        reset();
      }
      return null;
    }

    _exit.reset();
    final latchedSince = _latchedSinceMs;
    if (_recued || latchedSince == null) return null;
    // The single delayed fire references the LATER of (latch start, delay
    // floor). For the mid-set re-cue there is no floor → latch start. For the
    // stuck-setup re-tell the floor is intro-audio-end, so the re-tell is never
    // earlier than recueMs past the intro finishing, and a null floor (intro
    // still playing) blocks it outright — it never speaks over the intro.
    final int referenceMs;
    if (fireOnEntry) {
      referenceMs = latchedSince;
    } else {
      if (delayFloorMs == null) return null;
      referenceMs = latchedSince > delayFloorMs ? latchedSince : delayFloorMs;
    }
    if (nowMs - referenceMs >= recueMs) {
      _recued = true;
      return _SafetyVoiceRequest(
        voiceClass: voiceClass,
        key: key,
        trigger: fireOnEntry ? 'recue' : 'retell',
      );
    }
    return null;
  }

  void reset() {
    _latched = false;
    _recued = false;
    _latchedSinceMs = null;
    _enter.reset();
    _exit.reset();
  }
}

class _SafetyVoiceRequest {
  const _SafetyVoiceRequest({
    required this.voiceClass,
    required this.key,
    this.edge = false,
    this.trigger = 'entry',
  });

  final _SafetyVoiceClass voiceClass;
  final String key;
  final bool edge;

  /// Device-log label only: what caused this request (entry / recue / retell /
  /// paused-edge / resume-edge). Never read by logic.
  final String trigger;
}
