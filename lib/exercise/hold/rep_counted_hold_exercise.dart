import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/utils/debouncer.dart';

import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';
import '../fault_record.dart';
import 'timer_metric.dart';

class HoldPoseSample {
  const HoldPoseSample({
    required this.insideOuterEntry,
    required this.outsideOuterExit,
  });

  final bool insideOuterEntry;
  final bool outsideOuterExit;
}

/// Shared reps-of-holds state machine.
///
/// Subclasses implement [samplePose] and [updateFormMetrics]. Do not override
/// [checkingPose]: its pre-transition sample and post-transition metric order is
/// part of the hold-timing contract.
abstract class RepCountedHoldExercise extends ExerciseBase {
  RepCountedHoldExercise({
    required this.maxHolds,
    required this.holdSeconds,
  }) : super(targetReps: maxHolds, targetSeconds: holdSeconds);

  static const double defaultRestDurationSeconds = 5.0;

  final int maxHolds;
  final int holdSeconds;

  HoldPhase phase = HoldPhase.setup;
  HoldPhase previousPhase = HoldPhase.setup;
  final TimerMetric timerMetric = TimerMetric();

  int? _restStartMs;
  int? _reArmHoldStartMs;
  int _completedHoldingTimeMs = 0;
  String? _outerBreakFaultId;

  late final HoldSecondsAccumulator _holdSeconds =
      HoldSecondsAccumulator(faultSecondsKeys.toList(growable: false));
  late final Debouncer _holdingDebouncer =
      Debouncer(requiredFrames: holdingDebounceFrames);
  late final Debouncer _droppingDebouncer =
      Debouncer(requiredFrames: droppingDebounceFrames);

  int get holdingDebounceFrames => 4;
  int get droppingDebounceFrames => 2;
  double get restDurationSeconds => defaultRestDurationSeconds;
  String get interruptedHoldFaultId => 'wall_guard';

  Set<String> get faultSecondsKeys;

  HoldPoseSample? samplePose(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  );

  Map<String, bool> updateFormMetrics();

  Map<String, FaultRecord> snapshotHoldFaults();

  void resetFormMetrics({required bool countFaults});

  void onHoldPhaseChanged(
    HoldPhase previous,
    HoldPhase next,
    int nowMs,
  );

  Map<String, dynamic> holdRepLogExtras() => const <String, dynamic>{};

  void onHoldSetReset() {}

  String? get outerBreakFaultId => _outerBreakFaultId;
  int get completedHoldingTimeMs => _completedHoldingTimeMs;

  int get currentPartialHoldingTimeMs =>
      phase == HoldPhase.holding || phase == HoldPhase.dropping
          ? timerMetric.totalHoldingTimeMs
          : 0;

  double clampedGoodHoldSeconds(double targetSeconds) =>
      _holdSeconds.goodSeconds.clamp(0.0, targetSeconds);

  double faultHoldSecondsFor(String key) => _holdSeconds.faultSecondsFor(key);

  @override
  bool get usesRepCountedHolds => true;

  @override
  String get currentPhaseKey => phase.name;

  @override
  bool get isReArmingHold => phase == HoldPhase.reArming;

  @override
  int? get holdStillElapsedMs {
    if (!isReArmingHold) return super.holdStillElapsedMs;
    final startedAt = _reArmHoldStartMs;
    return startedAt == null ? null : frameTimestampMs - startedAt;
  }

  @override
  double? get activationProgress {
    if (!isReArmingHold) return super.activationProgress;
    final elapsedMs = holdStillElapsedMs;
    if (elapsedMs == null) return null;
    return (elapsedMs /
            ExerciseBase.HOLD_STILL_REQUIRED_DURATION.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  @override
  double? get liveHoldSeconds =>
      phase == HoldPhase.holding || phase == HoldPhase.dropping
          ? timerMetric.totalHoldingTimeMs / 1000.0
          : null;

  @override
  double? get liveHoldTargetSeconds => holdSeconds.toDouble();

  @override
  double? get liveRestSeconds {
    final startedAt = _restStartMs;
    if (phase != HoldPhase.resting || startedAt == null) return null;
    final elapsedSeconds = (frameTimestampMs - startedAt) / 1000.0;
    return (restDurationSeconds - elapsedSeconds)
        .clamp(0.0, restDurationSeconds);
  }

  @override
  double? get liveRestTargetSeconds => restDurationSeconds;

  @override
  bool requestStop() => repCount >= maxHolds;

  @override
  Map<String, String> processNoPoseFrame() {
    final feedback = super.processNoPoseFrame();
    interruptActiveHold(interruptedHoldFaultId);
    interruptReArm();
    advanceRestOnClock(frameTimestampMs);
    return feedback;
  }

  @override
  void onExerciseActivated() {
    super.onExerciseActivated();
    _resetSetState();
  }

  @override
  void onPauseReactivationStarted() {
    if (phase != HoldPhase.holding && phase != HoldPhase.dropping) return;

    // A base pause/re-hold is a real interruption, unlike a brief outer-ring
    // drop. Discard only the current partial hold; completed progress survives.
    transitionHoldPhase(HoldPhase.setup, frameTimestampMs);
    _outerBreakFaultId = null;
    correctForm = true;
    resultIssues.phaseStatus.clear();
    resetFormMetrics(countFaults: false);
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final now = frameTimestampMs;
    final sample = samplePose(landmarks);
    if (sample == null) {
      interruptActiveHold(interruptedHoldFaultId);
      interruptReArm();
      return;
    }

    final wasHolding = phase == HoldPhase.holding;
    _updateStateMachine(sample, now);
    publishReArmGuidance();

    // Metrics, including the earned-time clock, deliberately observe the
    // post-transition phase of this same frame.
    final faultingByKey = updateFormMetrics();
    timerMetric.updateAt(phase: phase, timestampMs: now);

    if (phase == HoldPhase.holding) {
      _holdSeconds.accumulate(
        elapsedMs: elapsedMs,
        faultingByKey: faultingByKey,
      );
    } else if (wasHolding) {
      _holdSeconds.resetTick();
    }

    resultIssues.setPhaseStatus(phase.name, currentPhaseLabel);
  }

  void advanceRestOnClock(int nowMs) {
    final restStartedAt = _restStartMs;
    if (phase != HoldPhase.resting || restStartedAt == null) return;
    final restSeconds = (nowMs - restStartedAt) / 1000.0;
    if (restSeconds >= restDurationSeconds) {
      transitionHoldPhase(HoldPhase.reArming, nowMs);
    }
  }

  void publishReArmGuidance() {
    if (phase != HoldPhase.reArming) return;
    if (_reArmHoldStartMs == null) {
      publishGuidanceSignal(
        const GuidanceSignal.setupPosition(
          title: 'Vào vị trí',
          body: 'Vào tư thế và giữ yên để bắt đầu.',
        ),
      );
    } else {
      clearGuidanceSignal();
    }
  }

  void transitionHoldPhase(HoldPhase next, int nowMs) {
    if (next == phase) return;
    previousPhase = phase;
    phase = next;
    _holdingDebouncer.reset();
    _droppingDebouncer.reset();
    onHoldPhaseChanged(previousPhase, next, nowMs);
    timerMetric.onStateTransition(previousPhase, next, nowMs);

    switch (next) {
      case HoldPhase.holding:
        // A drop pauses the current hold. Setup/rest begin a fresh hold.
        if (previousPhase != HoldPhase.dropping) {
          timerMetric.resetForNextHold();
        }
        _restStartMs = null;
        _reArmHoldStartMs = null;
        _outerBreakFaultId = null;
        _holdSeconds.resetTick();
        break;
      case HoldPhase.dropping:
        timerMetric.pause();
        _holdSeconds.resetTick();
        break;
      case HoldPhase.resting:
        timerMetric.pause();
        _holdSeconds.resetTick();
        _restStartMs = nowMs;
        _reArmHoldStartMs = null;
        _onHoldComplete();
        break;
      case HoldPhase.reArming:
        timerMetric.pause();
        _holdSeconds.resetTick();
        _restStartMs = null;
        _reArmHoldStartMs = null;
        break;
      case HoldPhase.setup:
        timerMetric.resetForNextHold();
        _restStartMs = null;
        _reArmHoldStartMs = null;
        _holdSeconds.resetTick();
        break;
    }
  }

  void interruptActiveHold(String faultId) {
    if (phase != HoldPhase.holding) return;
    _outerBreakFaultId = faultId;
    transitionHoldPhase(HoldPhase.dropping, frameTimestampMs);
  }

  void interruptReArm() {
    if (phase != HoldPhase.reArming) return;
    _reArmHoldStartMs = null;
    _holdingDebouncer.reset();
  }

  void _updateStateMachine(HoldPoseSample sample, int nowMs) {
    final confirmedOuterPose =
        _holdingDebouncer.update(sample.insideOuterEntry);

    if (phase == HoldPhase.setup || phase == HoldPhase.dropping) {
      if (confirmedOuterPose) {
        transitionHoldPhase(HoldPhase.holding, nowMs);
      }
    } else if (phase == HoldPhase.holding) {
      if (_droppingDebouncer.update(sample.outsideOuterExit)) {
        _outerBreakFaultId = interruptedHoldFaultId;
        transitionHoldPhase(HoldPhase.dropping, nowMs);
      } else if (timerMetric.totalHoldingTimeMs >= holdSeconds * 1000) {
        transitionHoldPhase(HoldPhase.resting, nowMs);
      }
    } else if (phase == HoldPhase.resting) {
      advanceRestOnClock(nowMs);
    } else if (phase == HoldPhase.reArming) {
      if (!confirmedOuterPose) {
        _reArmHoldStartMs = null;
      } else {
        _reArmHoldStartMs ??= nowMs;
        if (nowMs - _reArmHoldStartMs! >=
            ExerciseBase.HOLD_STILL_REQUIRED_DURATION.inMilliseconds) {
          transitionHoldPhase(HoldPhase.holding, nowMs);
        }
      }
    }
  }

  void _resetSetState() {
    phase = HoldPhase.setup;
    previousPhase = HoldPhase.setup;
    _restStartMs = null;
    _reArmHoldStartMs = null;
    _completedHoldingTimeMs = 0;
    _outerBreakFaultId = null;
    _holdSeconds.reset();
    repCount = 0;
    correctForm = true;
    logger.clear();
    timerMetric.reset();
    _holdingDebouncer.reset();
    _droppingDebouncer.reset();
    resetFormMetrics(countFaults: false);
    onHoldSetReset();
  }

  void _onHoldComplete() {
    repCount += 1;
    final targetTimeMs = holdSeconds * 1000;
    final measuredHoldTimeMs =
        timerMetric.totalHoldingTimeMs.clamp(0, targetTimeMs);
    _completedHoldingTimeMs += measuredHoldTimeMs;

    final faultsById = snapshotHoldFaults();
    correctForm = !faultsById.values.any((fault) => fault.affectsForm);

    final faultMap = <String, Map<String, String>>{
      if (faultsById.isNotEmpty)
        'HOLDING': <String, String>{
          for (final entry in faultsById.entries)
            entry.key: entry.value.message,
        },
    };
    setFeedback.add({correctForm: faultMap});
    logger.addRepLog(
      RepLog(
        correctForm: correctForm,
        repNumber: repCount,
        data: {
          'hold_time': measuredHoldTimeMs / 1000.0,
          'fault_types': faultsById.keys.toList(),
          'fault_affects_form': <String, bool>{
            for (final entry in faultsById.entries)
              entry.key: entry.value.affectsForm,
          },
          ...holdRepLogExtras(),
        },
      ),
    );

    resetFormMetrics(countFaults: true);
    correctForm = true;
  }
}
