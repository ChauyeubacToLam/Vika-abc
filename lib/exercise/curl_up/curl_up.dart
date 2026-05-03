// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

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

// --- Config ---

class CurlUpConfig {
  static const int MAX_REP = 12;

  // Personal-baseline-relative entry/exit thresholds (degrees).
  // Baseline = shoulder-hip-knee interior angle captured during hold-still
  // activation. As the user curls up, this interior angle DECREASES.
  //
  // ASCEND_DELTA: how far the angle must drop below baseline to register
  //               as actively curling. Below 5° = noise/breath movement.
  // REST_TOLERANCE: how close the angle must return to baseline before we
  //                 call the rep complete and arm the next one.
  static const double ASCEND_DELTA_THRESHOLD = 3.0;
  static const double REST_TOLERANCE = 3.0;

  // Bent knee elevation (fraction of torso length) for McGill setup check.
  // 0.15 = knee raised at least 15 % of shoulder-to-hip distance above hip.
  static const double BENT_KNEE_ELEVATION = 0.15;
}

enum CurlUpState { resting, ascending, descending }

// --- Curl Up ---
//
// DATA LOGGING PIPELINE:
// 1. frameBuffer (Per-Frame):
//    - shoulderHipKneeAngle: drives state transitions, finds peak (min) angle
//    - earShoulderHipAngle: tracks neck deviation peak
//    - hipKneeAnkleAngle: tracks knee straightening peak (when ankle visible)
// 2. RepLog (Per-Rep):
//    - peak_trunk_elevation: max (baseline - SHK) reached during the rep
//    - peak_neck_deviation: max (baseline - ESH) during ascending
//    - max_knee_angle: largest hip-knee-ankle reached (knee extension creep)
//    - fault_types: list of fault types logged this rep
// 3. Set-Level Summaries (onSetComplete):
//    - trunk_elev_fails_count, neck_pull_fails_count, knee_ext_fails_count
//    - max_peak_trunk_elevation, max_peak_neck_deviation
//    - good_rep_count, max_rep

class CurlUp extends ExerciseBase with SideTrackedExerciseMixin {
  // Anticipatory cues (what the user should do next while in this state),
  // mirrored on Squat's standingStatus / descendingStatus / ascendingStatus.
  static const String restingStatus = 'Cuộn lên';
  static const String ascendingStatus = 'Lên...';
  static const String descendingStatus = 'Hạ từ từ';

  final int maxRep;
  CurlUpState curlUpState = CurlUpState.resting;
  CurlUpState previousCurlUpState = CurlUpState.resting;

  // Voice-coach handoff state (mirror of squat).
  List<String> lastRepFaultVoiceMessages = [];
  String? lastRepTopVoiceMessage;
  int? lastRepTopVoicePriority;
  bool lastRepWasClean = true;

  // Hold-still baselines captured during isInStartPosition.
  // These persist for the whole set — resting posture doesn't change mid-set.
  double? _holdStillShoulderHipKnee;
  double? _holdStillEarShoulderHip;

  CurlUp({this.maxRep = CurlUpConfig.MAX_REP});

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

  // ── Debouncers for state transitions ──

  // Confirms the user has truly returned to resting (filters jitter near
  // baseline at the end of a rep).
  final Debouncer _restingDebouncer = Debouncer(requiredFrames: 2);

  // Tracks sustained direction reversal of shoulderHipKneeAngle. Filters
  // single-frame noise reversals during slow ascent.
  final StickyDebouncer directionDetection = StickyDebouncer();

  // --- UI Bridge ---

  @override
  String get exerciseName => 'McGill Curl-up';

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
  // User must lie flat in a side view with the camera-side knee bent
  // (McGill setup: hands under lumbar spine, one knee bent ~90°).

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = getSideTrackedLandmarks(landmarks);
    if (lm == null) return false;

    final shoulder = lm['shoulder']!;
    final hip = lm['hip']!;
    final knee = lm['knee']!;
    final ear = lm['ear']!;

    // Trunk roughly horizontal in the camera frame (lying flat).
    final double trunkAngle =
        calculateHorizontalAngle(point1: shoulder, point2: hip);
    if (trunkAngle > 8.0) return false;

    // Camera-side knee must be bent — knee raised above hip in screen coords.
    // Use Euclidean torso length (not Δy) — when lying flat in side view,
    // shoulder.y ≈ hip.y so the y-axis projection collapses to ~0.
    final double torsoLen = calculateDistance(shoulder, hip);
    if (torsoLen < 2.5) return false;
    final double kneeElevation = (hip.y - knee.y) / torsoLen;
    if (kneeElevation < CurlUpConfig.BENT_KNEE_ELEVATION) return false;

    // Capture hold-still baselines. Used by metrics for personalized
    // thresholds (especially neck — kyphotic users have non-neutral resting
    // baselines).
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

    return true;
  }

  // --- Stop Condition & Set-Level Logging ---
  // Aggregates per-rep data into set-level summaries when the set ends.

  @override
  void onSetComplete() {
    // Fault counts per metric
    logger.pushKey("trunk_elev_fails_count", trunkElevationMetric.faultsCount);
    logger.pushKey("neck_pull_fails_count", neckPullingMetric.faultsCount);
    logger.pushKey("knee_ext_fails_count", kneeExtensionMetric.faultsCount);

    // Aggregated per-rep stats
    logger.pushMax("peak_trunk_elevation", "max_peak_trunk_elevation");
    logger.pushMax("peak_neck_deviation", "max_peak_neck_deviation");
    logger.pushMax("max_knee_angle", "max_max_knee_angle");

    // Count good reps & push max rep
    logger.pushGoodRepCount();
    logger.pushKey("max_rep", maxRep);
  }

  @override
  bool requestStop() => repCount >= maxRep;

  // --- Safety Checks ---
  // Side-facing camera; all required landmarks visible with high confidence.

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return "⚠️ Hãy quay người sang ngang so với camera để theo dõi Curl-up";
    }

    final required = getSideTrackedLandmarks(landmarks);
    if (required == null) return "⚠️ Cơ thể chưa hiện đủ trong khung hình";

    final allConfident = required.values
        .every((lm) => lm.likelihood >= ExerciseBase.MIN_CONFIDENCE);
    if (!allConfident) return "⚠️ Điều chỉnh ánh sáng/vị trí";

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

    debugData["shoulderY"] = shoulder.y.toStringAsFixed(1);
    final ankleVisible =
        ankle != null && ankle.likelihood >= ExerciseBase.MIN_CONFIDENCE;

    scaleFactor = calculateDistance(shoulder, hip);

    // 2. Calculate geometry
    final trunkAngle = calculateHorizontalAngle(point1: shoulder, point2: hip);
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

    // // 4. Debug overlay
    // debugData['curlUpState'] = curlUpState.name;
    // debugData['previousCurlUpState'] = previousCurlUpState.name;
    // debugData['repCount'] = repCount;
    // debugData['frameBuffer'] = frameBuffer.frameBuffer.length;
    // debugData['trackedSide'] = trackedSide?.name ?? 'unknown';
    // debugData['trackedSideSource'] = lastTrackedSideSource;
    // debugData['leftSideScore'] = lastLeftSideScore.toStringAsFixed(2);
    // debugData['rightSideScore'] = lastRightSideScore.toStringAsFixed(2);
    // debugData['trunkAngle'] = trunkAngle.toStringAsFixed(1);
    // debugData['shAngle'] = shoulderHipKneeAngle.toStringAsFixed(1);
    // debugData['neckAngle'] = earShoulderHipAngle.toStringAsFixed(1);
    // debugData['kneeAngle'] = hipKneeAnkleAngle?.toStringAsFixed(1) ?? 'n/a';
    // debugData['baselineSHK'] =
    //     _holdStillShoulderHipKnee?.toStringAsFixed(1) ?? 'n/a';

    // 5. Buffer frame & update state machine
    frameBuffer.addFrame(FrameSnapshot(log: {
      "shoulderHipKneeAngle": shoulderHipKneeAngle,
      "earShoulderHipAngle": earShoulderHipAngle,
      if (hipKneeAnkleAngle != null) "hipKneeAnkleAngle": hipKneeAnkleAngle,
    }, timeStamp: now));

    _updateStateBuffer(shoulderHipKneeAngle, now);

    // 6. Rep completion fires once per cycle: descending → resting.
    //    previousCurlUpState != resting filter ensures we only complete once,
    //    even though resting is a sticky state.
    if (curlUpState == CurlUpState.resting &&
        previousCurlUpState != CurlUpState.resting) {
      _completeRep(ctx);
      return;
    }

    // 7. Run metrics. Resting frames refine baselines; active frames evaluate.
    if (curlUpState == CurlUpState.resting) {
      for (final metric in _metrics) {
        metric.onRestingFrame(ctx);
      }
    } else {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
    }

    for (final metric in _metrics) {
      // debugData.addAll(metric.debugData);
    }

    // 8. Phase-specific UI instructions
    _updatePhaseInstructions();
  }

  // --- Rep Completion ---

  void _completeRep(RepContext ctx) {
    repCount += 1;

    // Per-spec: trunk elevation is evaluated at the apex (= the
    // ascending→descending transition, or here at end-of-rep using the
    // peak captured in the buffer).
    trunkElevationMetric.checkRepCompletion(ctx);

    // Collect faults from all metrics
    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      allFaults.addAll(metric.faults);
    }

    // Determine rep quality
    correctForm = !allFaults.any((f) => f.affectsForm);
    resultIssues.feedback['Result'] = correctForm ? 'Tốt lắm!' : 'Sửa tư thế';

    // Build fault map grouped by phase (consumed by setFeedback / report)
    final faultMap = <String, Map<String, String>>{};
    for (final fault in allFaults) {
      faultMap.putIfAbsent(fault.phase, () => {});
      faultMap[fault.phase]![fault.type] = fault.message;
    }

    // Voice-coach handoff
    final topVoiced = CurlUp.topVoicedFault(allFaults);
    lastRepFaultVoiceMessages = CurlUp.orderedUniqueVoiceMessages(allFaults);
    lastRepTopVoiceMessage = topVoiced?.voiceMessage;
    lastRepTopVoicePriority = topVoiced?.priority;
    lastRepWasClean = correctForm;

    setFeedback.add({correctForm: faultMap});

    for (final metric in _metrics) {
      // debugData.addAll(metric.debugData);
    }

    // Per-rep log: pull peak values out of the frame buffer and convert to
    // baseline-relative deltas (the actual signal the report cares about).
    final peakSHKSnap = frameBuffer.getPeakMin("shoulderHipKneeAngle");
    final peakESHSnap = frameBuffer.getPeakMin("earShoulderHipAngle");
    final peakKneeSnap = frameBuffer.getPeakMax("hipKneeAnkleAngle");

    final baseSHK = _holdStillShoulderHipKnee;
    final baseESH = _holdStillEarShoulderHip;

    final peakTrunkElev = (baseSHK != null && peakSHKSnap != null)
        ? (baseSHK - (peakSHKSnap.log["shoulderHipKneeAngle"] as double))
            .clamp(0.0, 90.0)
        : 0.0;
    final peakNeckDev = (baseESH != null && peakESHSnap != null)
        ? (baseESH - (peakESHSnap.log["earShoulderHipAngle"] as double))
            .clamp(0.0, 90.0)
        : 0.0;

    logger.addRepLog(RepLog(
      correctForm: correctForm,
      repNumber: repCount,
      data: {
        "peak_trunk_elevation": peakTrunkElev,
        "peak_neck_deviation": peakNeckDev,
        "max_knee_angle":
            peakKneeSnap?.log["hipKneeAnkleAngle"] as double? ?? 0.0,
        "fault_types": allFaults.map((f) => f.type).toSet().toList(),
      },
    ));

    // Reset for next rep
    correctForm = true;
    previousCurlUpState = CurlUpState.resting;
    for (final metric in _metrics) {
      metric.resetAndCountFault();
    }
    frameBuffer.clear();
  }

  // --- Phase Instructions ---

  void _updatePhaseInstructions() {
    switch (curlUpState) {
      case CurlUpState.resting:
        // Anticipatory: while user is flat, prompt them to begin curling.
        resultIssues.addInstruction('resting', 'Status', restingStatus);
        break;
      case CurlUpState.ascending:
        resultIssues.addInstruction('ascending', 'Status', ascendingStatus);
        break;
      case CurlUpState.descending:
        resultIssues.addInstruction('descending', 'Status', descendingStatus);
        break;
    }
  }

  // --- State Machine (buffer-based) ---
  // Drives transitions off shoulderHipKneeAngle (SHK):
  //   - SHK DECREASES as user curls up (back rounds, hip closes)
  //   - SHK at minimum = apex
  //   - SHK INCREASES back toward baseline as user lowers
  //
  // resting → ascending : actively curling AND past entry threshold
  // ascending → descending : sustained direction reversal (apex)
  // descending → ascending : user reverses again mid-descent (allowed)
  // descending → resting   : SHK back within tolerance of baseline (debounced)

  void _updateStateBuffer(double shkAngle, int timestampMs) {
    final base = _holdStillShoulderHipKnee;
    if (base == null)
      return; // No baseline yet — should not happen post-activation.

    final angleChange = frameBuffer.getAngleChange("shoulderHipKneeAngle");
    debugData['angleChange'] = angleChange.toString().split('.').last;
    final isCurlingUpFrame = angleChange == AngleChangeState.decreasing;
    final isReturningFrame = angleChange == AngleChangeState.increasing;

    if (angleChange != AngleChangeState.stable) {
      // StickyDebouncer turns frame-to-frame direction into sustained
      // "is the user returning toward flat?" — filters noise reversals.
      final isReturning = directionDetection.update(isReturningFrame);

      debugData['delta Angle'] =
          (base - CurlUpConfig.ASCEND_DELTA_THRESHOLD).toStringAsFixed(1);
      debugData['shkAngle'] = shkAngle.toStringAsFixed(1);
      // resting → ascending
      if (!isReturning &&
          curlUpState == CurlUpState.resting &&
          shkAngle < base - CurlUpConfig.ASCEND_DELTA_THRESHOLD) {
        _transitionState(CurlUpState.ascending, timestampMs);
        frameBuffer.clear();
      }
      // ascending → descending (kinematic apex). No minimum-elevation gate
      // here — the StickyDebouncer already filters jitter, and gating would
      // re-introduce the shallow-rep ghost bug.
      else if (isReturning && curlUpState == CurlUpState.ascending) {
        _transitionState(CurlUpState.descending, timestampMs);
      }
      // descending → ascending: user reversed mid-descent and is curling
      // again. Mirrors squat's bottom/descending → ascending allowance.
      else if (!isReturning && curlUpState == CurlUpState.descending) {
        _transitionState(CurlUpState.ascending, timestampMs);
      }
    }

    // descending → resting: SHK has returned to within REST_TOLERANCE of
    // baseline and we're not actively curling again. Debounced to filter
    // breath/jitter at the floor.
    if (_restingDebouncer.update(
        shkAngle >= base - CurlUpConfig.REST_TOLERANCE &&
            curlUpState == CurlUpState.descending &&
            !isCurlingUpFrame)) {
      _transitionState(CurlUpState.resting, timestampMs);
    }
  }

  void _transitionState(CurlUpState newState, int timestampMs) {
    if (newState == curlUpState) return;

    previousCurlUpState = curlUpState;
    curlUpState = newState;

    // Wipe stale instructions when a new rep cycle begins so old coaching
    // doesn't bleed into the new rep.
    if (newState == CurlUpState.ascending &&
        previousCurlUpState == CurlUpState.resting) {
      resultIssues.instructions.clear();
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousCurlUpState, newState, timestampMs);
    }
  }
}
