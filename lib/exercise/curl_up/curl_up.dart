// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'dart:math' as math;

import 'package:vika/utils/debouncer.dart';
import 'package:vika/utils/frame_buffer.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../utils/pose_math_helpers.dart';
import '../../utils/frame_snapshot.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';
import '../side_tracked_exercise_mixin.dart';
import 'metrics/curl_up_metric_base.dart';
import 'metrics/curl_up_trunk_elevation.dart';
import 'metrics/curl_up_neck_pulling.dart';
import 'metrics/curl_up_knee_extension.dart';
import '../../voice/policy_voice_coach.dart';
import '../../voice/voice_coach.dart';
import '../../voice/voice_content.dart';
import '../../voice/voice_policy.dart';
import '../../voice/voice_sink.dart';

// =========================================================================
// CURL-UP STATE MACHINE OVERVIEW
//
// State machine drives off TRUNK ANGLE (shoulder-hip from horizontal).
// This is knee-invariant — only depends on shoulder.y and hip.y. Knee
// flexion/extension cannot contaminate trunk angle, so the user can't
// fake reps by moving their leg.
//
// Trunk angle direction:
//   - Lying flat:  trunkAngle ≈ baseline (whatever camera tilt is at
//                  activation; baseline cancels the constant offset)
//   - Curling up:  trunkAngle INCREASES
//   - Returning:   trunkAngle DECREASES back toward baseline
//
// Camera tilt: trunkAngle includes camera-tilt offset, but baseline
// cancels it via subtraction. As long as the camera doesn't move during
// a set (phone on floor, doesn't slide), this works. Future ticket: AR
// sagittal calibration to make this fully tilt-invariant by overlay.
//
// Other metrics (trunk_elevation, neck_pulling, knee_extension) still
// use their own joint-frame angles for grading. State machine concerns
// are decoupled from grading.
// =========================================================================

class CurlUpConfig {
  /// Trunk elevation past baseline that triggers ascending state, and
  /// the tolerance for declaring rep complete. Both in degrees.
  /// Real curl-ups produce 10-25° trunk lift, so 4° entry is generous
  /// and 3° rest tolerance lets minor jitter clear the gate.
  static const double ASCEND_DELTA_THRESHOLD = 2.0;
  static const double REST_TOLERANCE = 5.0;

  /// Bent knee elevation gate at activation (fraction of torso length).
  static const double BENT_KNEE_ELEVATION = 0.03;

  /// Strict knee gate at activation: interior angle ≤ 100° required.
  static const double KNEE_MAX_AT_START = 170.0;

  /// Max ear-to-hip vertical separation, normalized by torso length.
  /// Confirms whole body is supine, not just shoulder-hip segment.
  static const double EAR_HIP_VERTICAL_MAX = 0.55;

  /// Required stable frames at baseline to call rep complete.
  static const int RESTING_DEBOUNCE_FRAMES = 2;

  /// Max allowed knee displacement from baseline before knee is flagged
  /// "out of position." Used to gate state machine entry and exit.
  /// Smoothed by 10-frame StickyDebouncer to filter ML Kit landmark noise.
  static const double KNEE_DISPLACEMENT_MAX = 40.0;

  // Angle gate for detecting stable vs changing angle in FrameBuffer.
  static const double ANGLE_STABLE_GATE = 0.8; // degrees
}

enum CurlUpState { resting, ascending, descending }

class CurlUp extends ExerciseBase with SideTrackedExerciseMixin {
  static const List<String> _voiceFaultIds = [
    'knee_extension',
    'neck_pull',
    'trunk_high',
    'trunk_low',
  ];

  static const String restingStatus = 'Cuộn lên';
  static const String ascendingStatus = 'Lên...';
  static const String descendingStatus = 'Hạ từ từ';

  final int maxRep;
  CurlUpState curlUpState = CurlUpState.resting;
  CurlUpState previousCurlUpState = CurlUpState.resting;

  // Voice-coach handoff state.
  List<String> lastRepFaultVoiceMessages = [];
  String? lastRepTopVoiceMessage;
  int? lastRepTopVoicePriority;
  bool lastRepWasClean = true;

  // ── Baselines ──
  // All captured at activation. Trunk and knee baselines additionally
  // refresh during STABLE resting frames (per-signal stability gate)
  // so they track the user's natural rest pose, not the activation
  // snapshot which can be tense / off-pose.
  //
  // Note: holdStillShoulderHipKnee and holdStillEarShoulderHip are
  // initial seeds passed to metrics via RepContext. The metrics maintain
  // their own internal baselines after activation. We don't refresh
  // those fields here — that's the metric's concern.

  double? _holdStillShoulderHipKnee;
  double? _holdStillEarShoulderHip;
  double? _holdStillHipKneeAnkle;

  /// Baseline for state machine — trunk angle from horizontal at rest.
  /// Refreshes during stable resting frames.
  double? _baselineTrunkAngle;

  /// True when current knee displacement from baseline exceeds threshold.
  /// Smoothed via StickyDebouncer. Gates state machine transitions.
  bool _kneeIsDisplaced = false;
  double? _repPeakTrunkAngle;
  double? _repMinEarShoulderHipAngle;
  double? _repMaxHipKneeAnkleAngle;

  CurlUp({required this.maxRep}) : super(targetReps: maxRep);

  @override
  List<FaultRecord> get liveFaults =>
      [for (final metric in _metrics) ...metric.faults];

  @override
  ExerciseVoiceCoach createVoiceCoach() {
    return PolicyVoiceCoach(
      script: VoiceScript.from(
        VoiceDefaults.repBased,
        slug: 'curl_up',
        faultIds: _voiceFaultIds,
      ),
      targetReps: targetReps,
      coach: VoiceCoach(
        sink: AssetVoiceSink(),
        policy: VoicePolicy(),
      ),
    );
  }

  // ── Voice-coach helpers (parity with Squat) ──

  static List<FaultRecord> orderedVoicedFaults(Iterable<FaultRecord> faults) {
    final voicedFaults = faults
        .where((fault) =>
            fault.voiceMessage != null && fault.voiceMessage!.isNotEmpty)
        .toList()
      ..sort((a, b) {
        final priorityCompare = a.priority.compareTo(b.priority);
        if (priorityCompare != 0) return priorityCompare;
        final typeCompare = a.type.compareTo(b.type);
        if (typeCompare != 0) return typeCompare;
        return a.message.compareTo(b.message);
      });
    return voicedFaults;
  }

  static FaultRecord? topVoicedFault(Iterable<FaultRecord> faults) {
    final voicedFaults = orderedVoicedFaults(faults);
    return voicedFaults.isEmpty ? null : voicedFaults.first;
  }

  static List<String> orderedUniqueVoiceMessages(Iterable<FaultRecord> faults) {
    final messages = <String>[];
    final seen = <String>{};
    for (final fault in orderedVoicedFaults(faults)) {
      final voice = fault.voiceMessage!;
      if (seen.add(voice)) messages.add(voice);
    }
    return messages;
  }

  // ── Metrics ──

  final TrunkElevationMetric trunkElevationMetric = TrunkElevationMetric();
  final NeckPullingMetric neckPullingMetric = NeckPullingMetric();
  final KneeExtensionMetric kneeExtensionMetric = KneeExtensionMetric();

  late final List<CurlUpMetricBase> _metrics = [
    trunkElevationMetric,
    neckPullingMetric,
    kneeExtensionMetric,
  ];

  // Debug metrics

  @override
  Map<String, SideLandmarkPair> get requiredSideLandmarks => const {
        'ear': (
          right: PoseLandmarkType.rightEar,
          left: PoseLandmarkType.leftEar
        ),
        'shoulder': (
          right: PoseLandmarkType.rightShoulder,
          left: PoseLandmarkType.leftShoulder,
        ),
        'hip': (
          right: PoseLandmarkType.rightHip,
          left: PoseLandmarkType.leftHip
        ),
        'knee': (
          right: PoseLandmarkType.rightKnee,
          left: PoseLandmarkType.leftKnee
        ),
      };

  @override
  Map<String, SideLandmarkPair> get optionalSideLandmarks => const {
        'ankle': (
          right: PoseLandmarkType.rightAnkle,
          left: PoseLandmarkType.leftAnkle,
        ),
      };

  // ── Debouncers ──

  final Debouncer _restingDebouncer =
      Debouncer(requiredFrames: CurlUpConfig.RESTING_DEBOUNCE_FRAMES);

  final StickyDebouncer directionDetection =
      StickyDebouncer(requiredFrames: CurlUpConfig.RESTING_DEBOUNCE_FRAMES);

  /// Smooths the knee displacement signal. Starts unblocked
  /// (currentState: false). Flips to true after 10 consecutive frames
  /// of displacement > KNEE_DISPLACEMENT_MAX. Flips back after 10
  /// consecutive frames of recovery. Hysteresis filters ML Kit noise.
  final StickyDebouncer kneeDisplacementDebouncer =
      StickyDebouncer(requiredFrames: 10, currentState: false);

  // --- UI Bridge ---

  @override
  String get exerciseName => 'McGill Curl-up';

  @override
  bool get shouldReplayPreviousSetVoiceFaults => false;

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get currentPhaseKey => curlUpState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (curlUpState) {
      case CurlUpState.resting:
        return 'Nằm';
      case CurlUpState.ascending:
        return 'Cuộn lên';
      case CurlUpState.descending:
        return 'Hạ xuống';
    }
  }

  // --- Start Position ---

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = getSideTrackedLandmarks(landmarks);
    if (lm == null) return false;

    final shoulder = lm['shoulder']!;
    final hip = lm['hip']!;
    final knee = lm['knee']!;
    final ear = lm['ear']!;

    // Compute knee angle once — used for the strict gate AND captured
    // as baseline if ankle is visible.
    final ankle = lm['ankle'];
    double? hka;
    if (ankle != null && ExerciseBase.isLandmarkConfident(ankle)) {
      hka = calculateAngleNormalized(
        firstPoint: hip,
        midPoint: knee,
        lastPoint: ankle,
      );
      if (hka > CurlUpConfig.KNEE_MAX_AT_START) return false;
    }

    // Trunk segment must be roughly horizontal.
    final double trunkAngle =
        _calculateTrunkHorizontalAngle(hip: hip, shoulder: shoulder);
    if (trunkAngle > 12.0) return false;

    // Camera-side knee must be bent away from the torso line. Depending on
    // landscape side and camera placement, the bent knee can appear above or
    // below the hip in screen coordinates.
    final double torsoLen = calculateDistance(hip, shoulder);
    if (torsoLen < 2.5) return false;
    final double kneeElevation = (hip.y - knee.y).abs() / torsoLen;
    if (kneeElevation < CurlUpConfig.BENT_KNEE_ELEVATION) return false;

    // Whole-body lying-flat check (head must be at hip level).
    final double earHipDelta = (ear.y - hip.y).abs() / torsoLen;
    if (earHipDelta > CurlUpConfig.EAR_HIP_VERTICAL_MAX) return false;

    // Capture baselines.
    _holdStillShoulderHipKnee = calculateAngleNormalized(
      firstPoint: shoulder,
      midPoint: hip,
      lastPoint: knee,
    );
    _holdStillEarShoulderHip = calculateAngleNormalized(
      firstPoint: ear,
      midPoint: shoulder,
      lastPoint: hip,
    );
    _holdStillHipKneeAnkle = hka; // null if ankle wasn't visible
    _baselineTrunkAngle = trunkAngle;

    return true;
  }

  // --- Stop Condition & Set-Level Logging ---

  @override
  void onSetComplete() {
    logger.pushKey("trunk_elev_fails_count", trunkElevationMetric.faultsCount);
    logger.pushKey("neck_pull_fails_count", neckPullingMetric.faultsCount);
    logger.pushKey("knee_ext_fails_count", kneeExtensionMetric.faultsCount);

    logger.pushMax("peak_trunk_elevation", "max_peak_trunk_elevation");
    logger.pushMax("peak_neck_deviation", "max_peak_neck_deviation");
    logger.pushMax("max_knee_angle", "max_max_knee_angle");

    logger.pushGoodRepCount();
    logger.pushKey("max_rep", maxRep);
  }

  @override
  bool requestStop() => repCount >= maxRep;

  // --- Safety Checks ---

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return const GuidanceSignal.turnSide();
    }

    final required = getSideTrackedLandmarks(landmarks);
    if (required == null) return const GuidanceSignal.bodyInFrame();

    final allConfident =
        required.values.every((lm) => ExerciseBase.isLandmarkConfident(lm));
    if (!allConfident) return const GuidanceSignal.lighting();

    return null;
  }

  // --- Main Loop (called every frame when activated) ---

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    // 1. Extract landmarks
    final lm = getSideTrackedLandmarks(smoothedLandmarks);
    if (lm == null) return;

    final ear = lm['ear']!;
    final shoulder = lm['shoulder']!;
    final hip = lm['hip']!;
    final knee = lm['knee']!;
    final ankle = lm['ankle']; // Optional

    final debugEnabled = isDebugModeActive;
    debugData["shoulderY"] = shoulder.y;
    final ankleVisible =
        ankle != null && ExerciseBase.isLandmarkConfident(ankle);

    // 2. Calculate geometry
    final trunkAngle =
        _calculateTrunkHorizontalAngle(hip: hip, shoulder: shoulder);
    final shoulderHipKneeAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: knee);
    final earShoulderHipAngle = calculateAngleNormalized(
        firstPoint: ear, midPoint: shoulder, lastPoint: hip);
    final hipKneeAnkleAngle = ankleVisible
        ? calculateAngleNormalized(
            firstPoint: hip, midPoint: knee, lastPoint: ankle)
        : null;
    final now = frameTimestampMs;

    // 3. Build metric context
    final ctx = RepContext(
      trunkAngle: trunkAngle,
      shoulderHipKneeAngle: shoulderHipKneeAngle,
      earShoulderHipAngle: earShoulderHipAngle,
      hipKneeAnkleAngle: hipKneeAnkleAngle,
      scaleFactor: scaleFactor,
      curlUpState: curlUpState,
      frameTimestamp: now,
      shoulderY: shoulder.y,
      hipY: hip.y,
      kneeY: knee.y,
      holdStillShoulderHipKnee: _holdStillShoulderHipKnee,
      holdStillEarShoulderHip: _holdStillEarShoulderHip,
      resultIssues: resultIssues,
    );

    // 4. Buffer frame. Includes trunkAngle (state machine signal),
    //    SHK / ESH (metric signals), and HKA (knee displacement signal).
    frameBuffer.addFrame(FrameSnapshot(log: {
      "trunkAngle": trunkAngle,
      "shoulderHipKneeAngle": shoulderHipKneeAngle,
      "earShoulderHipAngle": earShoulderHipAngle,
      if (hipKneeAnkleAngle != null) "hipKneeAnkleAngle": hipKneeAnkleAngle,
    }, timeStamp: now));

    // 5. Refresh baselines during STABLE resting frames.
    //    Each baseline is gated on its OWN signal's stability:
    //    - trunk baseline gates on trunkAngle stable (so a knee-only
    //      cheat doesn't drift trunk baseline)
    //    - knee baseline gates on hipKneeAnkleAngle stable (so a slow
    //      flex-and-hold cheat doesn't drift knee baseline either)
    //    The activation snapshot is one frame and can be off if the
    //    user is tense at hold-still and relaxes during the set.
    //    Per-signal stable refresh tracks natural rest without letting
    //    movement drift the baseline.
    if (curlUpState == CurlUpState.resting) {
      final trunkChange =
          frameBuffer.getChange("trunkAngle", CurlUpConfig.ANGLE_STABLE_GATE);
      if (trunkChange == ChangeState.stable) {
        _baselineTrunkAngle = trunkAngle;
      }
      if (hipKneeAnkleAngle != null) {
        final kneeChange = frameBuffer.getChange(
            "hipKneeAnkleAngle", CurlUpConfig.ANGLE_STABLE_GATE);
        if (kneeChange == ChangeState.stable) {
          _holdStillHipKneeAnkle = hipKneeAnkleAngle;
        }
      }
    }

    // 6. Knee displacement check. Static deviation from baseline,
    //    smoothed by 10-frame StickyDebouncer to filter landmark noise.
    final baselineKnee = _holdStillHipKneeAnkle;
    if (baselineKnee != null && hipKneeAnkleAngle != null) {
      final displacement = (hipKneeAnkleAngle - baselineKnee).abs();
      final isDisplacedFrame =
          displacement > CurlUpConfig.KNEE_DISPLACEMENT_MAX;
      _kneeIsDisplaced = kneeDisplacementDebouncer.update(isDisplacedFrame);
      debugData['kneeDispl'] = displacement;
    } else {
      _kneeIsDisplaced = kneeDisplacementDebouncer.update(false);
      debugData['kneeDispl'] = 'n/a';
    }
    debugData['kneeBlocked'] = _kneeIsDisplaced;
    debugData['trunkAngle'] = trunkAngle;
    debugData['trunkBaseline'] = _baselineTrunkAngle ?? 'n/a';

    final stateBeforeUpdate = curlUpState;
    if (stateBeforeUpdate != CurlUpState.resting) {
      _updateRepPeaks(ctx);
    }

    // 7. State machine.
    _updateStateBuffer(trunkAngle, now);

    // 8. Rep completion fires once per cycle: descending → resting.
    if (curlUpState == CurlUpState.resting &&
        previousCurlUpState != CurlUpState.resting) {
      _completeRep(ctx);
      return;
    }

    // 9. Run metrics. Resting frames refine baselines; active frames evaluate.
    if (curlUpState == CurlUpState.resting) {
      for (var i = 0; i < _metrics.length; i++) {
        _metrics[i].onRestingFrame(ctx);
      }
    } else {
      for (var i = 0; i < _metrics.length; i++) {
        _metrics[i].update(ctx);
      }
    }

    if (debugEnabled) {
      for (final metric in _metrics) {
        debugData.addAll(metric.debugData);
      }
    }

    // 10. Phase-specific UI status
    _updatePhaseInstructions();
  }

  // --- Rep Completion ---

  void _completeRep(RepContext ctx) {
    repCount += 1;

    trunkElevationMetric.checkRepCompletion(ctx);

    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      allFaults.addAll(metric.faults);
    }

    correctForm = !allFaults.any((f) => f.affectsForm);
    resultIssues.feedback['Result'] = correctForm ? 'Tốt lắm!' : 'Sửa tư thế';

    final faultMap = <String, Map<String, String>>{};
    for (final fault in allFaults) {
      faultMap.putIfAbsent(fault.phase, () => {});
      faultMap[fault.phase]![fault.type] = fault.message;
    }

    final topVoiced = CurlUp.topVoicedFault(allFaults);
    lastRepFaultVoiceMessages = CurlUp.orderedUniqueVoiceMessages(allFaults);
    lastRepTopVoiceMessage = topVoiced?.voiceMessage;
    lastRepTopVoicePriority = topVoiced?.priority;
    lastRepWasClean = correctForm;

    setFeedback.add({correctForm: faultMap});

    if (isDebugModeActive) {
      for (final metric in _metrics) {
        debugData.addAll(metric.debugData);
      }
    }

    // Peak elevation now from trunkAngle (max during rep) — knee-invariant.
    // Neck deviation still on ear-shoulder-hip (separate signal, no knee).
    final baseTrunk = _baselineTrunkAngle;
    final baseESH = _holdStillEarShoulderHip;

    final peakTrunkElev = (baseTrunk != null && _repPeakTrunkAngle != null)
        ? (_repPeakTrunkAngle! - baseTrunk).clamp(0.0, 90.0)
        : 0.0;
    final peakNeckDev = (baseESH != null && _repMinEarShoulderHipAngle != null)
        ? (baseESH - _repMinEarShoulderHipAngle!).clamp(0.0, 90.0)
        : 0.0;

    final faultAffectsForm = <String, bool>{};
    final faultPriorities = <String, int>{};
    for (final fault in allFaults) {
      faultAffectsForm[fault.type] =
          (faultAffectsForm[fault.type] ?? false) || fault.affectsForm;
      final previousPriority = faultPriorities[fault.type];
      if (previousPriority == null || fault.priority < previousPriority) {
        faultPriorities[fault.type] = fault.priority;
      }
    }

    logger.addRepLog(RepLog(
      correctForm: correctForm,
      repNumber: repCount,
      data: {
        "peak_trunk_elevation": peakTrunkElev,
        "peak_neck_deviation": peakNeckDev,
        "max_knee_angle": _repMaxHipKneeAnkleAngle ?? 0.0,
        "fault_types": allFaults.map((f) => f.type).toSet().toList(),
        "fault_affects_form": faultAffectsForm,
        "fault_priorities": faultPriorities,
      },
    ));

    correctForm = true;
    previousCurlUpState = CurlUpState.resting;
    for (final metric in _metrics) {
      metric.resetAndCountFault();
    }
    frameBuffer.clear();
    _resetRepPeaks();
  }

  void _updateRepPeaks(RepContext ctx) {
    if (_repPeakTrunkAngle == null || ctx.trunkAngle > _repPeakTrunkAngle!) {
      _repPeakTrunkAngle = ctx.trunkAngle;
    }
    if (_repMinEarShoulderHipAngle == null ||
        ctx.earShoulderHipAngle < _repMinEarShoulderHipAngle!) {
      _repMinEarShoulderHipAngle = ctx.earShoulderHipAngle;
    }
    final kneeAngle = ctx.hipKneeAnkleAngle;
    if (kneeAngle != null &&
        (_repMaxHipKneeAnkleAngle == null ||
            kneeAngle > _repMaxHipKneeAnkleAngle!)) {
      _repMaxHipKneeAnkleAngle = kneeAngle;
    }
  }

  void _resetRepPeaks() {
    _repPeakTrunkAngle = null;
    _repMinEarShoulderHipAngle = null;
    _repMaxHipKneeAnkleAngle = null;
  }

  // --- Phase Instructions ---

  void _updatePhaseInstructions() {
    switch (curlUpState) {
      case CurlUpState.resting:
        resultIssues.setPhaseStatus('resting', restingStatus);
        break;
      case CurlUpState.ascending:
        resultIssues.setPhaseStatus('ascending', ascendingStatus);
        break;
      case CurlUpState.descending:
        resultIssues.setPhaseStatus('descending', descendingStatus);
        break;
    }
  }

  // --- State Machine (trunk-angle-based, knee-invariant) ---
  //
  // trunkAngle = angle of shoulder→hip segment from horizontal.
  //   Curling UP increases trunkAngle.
  //   Returning DOWN decreases trunkAngle.
  //
  // Knee position is irrelevant — trunkAngle only depends on shoulder.y
  // and hip.y. This is the whole reason we switched off SHK.
  //
  // Both ENTRY and EXIT gates additionally require !_kneeIsDisplaced
  // so knee position must be at baseline (within KNEE_DISPLACEMENT_MAX)
  // for reps to start or complete.

  void _updateStateBuffer(double trunkAngle, int timestampMs) {
    final base = _baselineTrunkAngle;
    if (base == null) return;

    final trunkElev = trunkAngle - base; // positive = curled up

    final angleChange =
        frameBuffer.getChange("trunkAngle", CurlUpConfig.ANGLE_STABLE_GATE);
    debugData["angleChange"] = angleChange.toString().split('.').last;
    final isCurlingUpFrame = angleChange == ChangeState.increasing;
    final isReturningFrame = angleChange == ChangeState.decreasing;

    if (angleChange != ChangeState.stable) {
      final isReturning = directionDetection.update(isReturningFrame);

      // resting → ascending: real trunk lift past entry threshold,
      // not currently returning, knee at baseline.
      if (!isReturning &&
          curlUpState == CurlUpState.resting &&
          trunkElev > CurlUpConfig.ASCEND_DELTA_THRESHOLD &&
          !_kneeIsDisplaced) {
        _transitionState(CurlUpState.ascending, timestampMs);
        frameBuffer.clear();
      }
      // ascending → descending (kinematic apex)
      else if (isReturning && curlUpState == CurlUpState.ascending) {
        _transitionState(CurlUpState.descending, timestampMs);
      }
      // descending → ascending (mid-rep reversal)
      else if (!isReturning && curlUpState == CurlUpState.descending) {
        _transitionState(CurlUpState.ascending, timestampMs);
      }
    }

    // descending → resting: trunk back near baseline AND not curling up
    // again AND knee at baseline. All four conditions must hold for
    // RESTING_DEBOUNCE_FRAMES consecutive frames.
    if (_restingDebouncer.update(trunkElev <= CurlUpConfig.REST_TOLERANCE &&
        curlUpState == CurlUpState.descending &&
        !isCurlingUpFrame &&
        !_kneeIsDisplaced)) {
      _transitionState(CurlUpState.resting, timestampMs);
    }
  }

  void _transitionState(CurlUpState newState, int timestampMs) {
    if (newState == curlUpState) return;

    previousCurlUpState = curlUpState;
    curlUpState = newState;

    if (newState == CurlUpState.ascending &&
        previousCurlUpState == CurlUpState.resting) {
      resultIssues.phaseStatus.clear();
      _resetRepPeaks();
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousCurlUpState, newState, timestampMs);
    }
  }

  double _calculateTrunkHorizontalAngle({
    required PoseLandmark hip,
    required PoseLandmark shoulder,
  }) {
    final dy = (hip.y - shoulder.y).abs();
    final dx = (shoulder.x - hip.x).abs();
    if (dx == 0 && dy == 0) return 0.0;
    final degrees = math.atan2(dy, dx) * (180.0 / math.pi);
    return degrees.clamp(0.0, 90.0).toDouble();
  }
}
