// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'package:vinafit_mobile/utils/debouncer.dart';
import 'package:vinafit_mobile/utils/frame_buffer.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../utils/pose_math_helpers.dart';
import '../../utils/frame_snapshot.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';
import 'metrics/squat_metric_base.dart';
import 'metrics/squat_depth_metric.dart';
import 'metrics/trunk_lean_metric.dart';
import 'metrics/heel_rise_metric.dart';
import 'metrics/tempo_metric.dart';
import 'metrics/hip_shoulder_sync.dart';

// --- Config ---

class SquatConfig {
  static const int MAX_REP = 15;
  static const int SQUAT_STAND_ANGLE_THRESHOLD = 160;
  static const int SQUAT_DESCEND_ANGLE_THRESHOLD = 152;
  static const List<int> SQUAT_BOTTOM_ANGLE_THRESHOLD = [80, 100];
}

enum SquatState { standing, descending, bottom, ascending }

// --- Squat ---
//
// DATA LOGGING PIPELINE:
// 1. frameBuffer (Per-Frame):
//    - kneeAngle: used for state transitions and finding the peak_knee_angle
//    - trunkLean: used for finding trunk_lean_at_bottom
//    - heelDistance: used for finding peak_heel_distance
// 2. RepLog (Per-Rep):
//    - peak_heel_distance: the max heelDistance reached in the rep
//    - peak_knee_angle: the min kneeAngle reached in the rep (deepest point)
//    - trunk_lean_at_bottom: the trunkLean at the deepest point
//    - ascending_time & descending_time: analyzed by TempoMetric
// 3. Set-Level Summaries (onSetComplete):
//    Aggregates all RepLogs from the set into final values:
//    - max_heel_distance: from the max of all peak_heel_distance
//    - min_knee_angle: from the min of all peak_knee_angle
//    - min_ascending_time: from the min of all ascending_time
//    - min_descending_time: from the min of all descending_time
//    On set complete, push:
//    - heel_fails_count: from the sum of all heel_fails_count
//    - depth_fails_count: from the sum of all depth_fails_count
//    - trunk_lean_fails_count: from the sum of all trunk_lean_fails_count
//    - tempo_fails_count: from the sum of all tempo_fails_count
//    - hip_shoulder_sync_fails_count: from the sum of all hip_shoulder_sync_fails_count

class Squat extends ExerciseBase {
  final int maxRep;
  SquatState squatState = SquatState.standing;
  SquatState previousSquatState = SquatState.standing;

  // Debounce entry into rep — prevents false starts from noisy frames
  final Debouncer _entryDebouncer = Debouncer(requiredFrames: 2);

  Squat({this.maxRep = SquatConfig.MAX_REP});

  // Metrics
  final DepthMetric depthMetric = DepthMetric();
  final TrunkLeanMetric trunkLeanMetric = TrunkLeanMetric();
  final HeelRiseMetric heelRiseMetric = HeelRiseMetric();
  final TempoMetric tempoMetric = TempoMetric();
  final HipShoulderSyncMetric hipShoulderSyncMetric = HipShoulderSyncMetric();

  late final List<SquatMetricBase> _metrics = [
    depthMetric,
    trunkLeanMetric,
    heelRiseMetric,
    tempoMetric,
    hipShoulderSyncMetric,
  ];

  // Debouncers for state transitions
  final Debouncer _bottomDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _standingDebouncer = Debouncer(requiredFrames: 2);
  final StickyDebouncer directionDetection = StickyDebouncer();

  // --- UI Bridge ---

  @override
  String get exerciseName => 'Squat';

  @override
  String get currentPhaseKey => squatState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (squatState) {
      case SquatState.standing:
        return 'Đứng thẳng';
      case SquatState.descending:
        return 'Xuống';
      case SquatState.bottom:
        return 'Giữ';
      case SquatState.ascending:
        return 'Đứng lên';
    }
  }

  // --- Start Position ---
  // User must stand upright with straight legs to begin.

  @override
  void onExerciseActivated() {
    super.onExerciseActivated();
    ttsService.speak("Sẵn sàng, xuống");
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final shoulder = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightShoulder,
      leftType: PoseLandmarkType.leftShoulder,
    );
    final hip = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightHip,
      leftType: PoseLandmarkType.leftHip,
    );
    final knee = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightKnee,
      leftType: PoseLandmarkType.leftKnee,
    );

    if (shoulder == null || hip == null || knee == null) return false;

    // Trunk must be roughly vertical (< 25° deviation)
    double deviation = calculateVerticalAngle(pivot: hip, point: shoulder);
    if (deviation > 180) deviation = 360 - deviation;
    if (deviation > 25.0) return false;

    // Legs must be straight (knee angle > 155°)
    final kneeAngle = calculateAngleNormalized(
      firstPoint: hip,
      midPoint: knee,
      lastPoint: getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle,
      )!,
    );
    if (kneeAngle < 155.0) return false;

    return true;
  }

  // --- Stop Condition & Set-Level Logging ---
  // Aggregates per-rep data into set-level summaries when exercise completes.
  @override
  void onSetComplete() {
    // Fault counts per metric
    logger.pushKey("heel_fails_count", heelRiseMetric.faultsCount);
    logger.pushKey("depth_fails_count", depthMetric.faultsCount);
    logger.pushKey("trunk_lean_fails_count", trunkLeanMetric.faultsCount);
    logger.pushKey("tempo_fails_count", tempoMetric.faultsCount);
    logger.pushKey(
        "hip_shoulder_sync_fails_count", hipShoulderSyncMetric.faultsCount);

    // Aggregated per-rep statsL
    logger.pushMax("peak_heel_distance", "max_heel_distance");
    logger.pushMin("peak_knee_angle", "min_knee_angle");
    logger.pushMin("ascending_time", "min_ascending_time");
    logger.pushMin("descending_time", "min_descending_time");

    // Count good reps
    logger.pushGoodRepCount();
    // Push max rep
    logger.pushKey("max_rep", maxRep);
  }

  @override
  bool requestStop() => repCount >= maxRep;

  // --- Safety Checks ---
  // Requires side-facing camera and all key landmarks visible with high confidence.

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return "⚠️ Please turn to the side for better tracking for Squat";
    }

    final requiredLandmarks = _getRequiredLandmarks(landmarks);
    if (requiredLandmarks == null) return "⚠️ Body not fully visible.";

    final allConfident = requiredLandmarks.values
        .every((lm) => lm.likelihood >= ExerciseBase.MIN_CONFIDENCE);
    if (!allConfident) return "⚠️ Adjust lighting/position.";

    return null;
  }

  /// Returns all 6 required landmarks, or null if any is missing.
  Map<String, PoseLandmark>? _getRequiredLandmarks(
      Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final hip = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);
    final shoulder = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    final knee = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightKnee,
        leftType: PoseLandmarkType.leftKnee);
    final ankle = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle);
    final foot = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightFootIndex,
        leftType: PoseLandmarkType.leftFootIndex);
    final heel = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightHeel,
        leftType: PoseLandmarkType.leftHeel);

    if (hip == null ||
        shoulder == null ||
        knee == null ||
        ankle == null ||
        foot == null ||
        heel == null) return null;

    return {
      'hip': hip,
      'shoulder': shoulder,
      'knee': knee,
      'ankle': ankle,
      'foot': foot,
      'heel': heel,
    };
  }

  // --- Main Loop (called every frame when activated) ---

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    // 1. Extract landmarks
    final lm = _getRequiredLandmarks(smoothedLandmarks);
    if (lm == null) return;

    final hip = lm['hip']!;
    final knee = lm['knee']!;
    final ankle = lm['ankle']!;
    final shoulder = lm['shoulder']!;
    final foot = lm['foot']!;
    final heel = lm['heel']!;

    // 2. Calculate geometry
    final kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);
    final backAngle = calculateVerticalAngle(pivot: hip, point: shoulder);
    final trunkLean = convertClockAngleToTrunkLean(backAngle, cameraFacing);
    final heelDistanceToFloor = foot.y - heel.y;
    final now = frameTimestampMs;

    // 3. Build metric context
    final ctx = RepContext(
      kneeAngle: kneeAngle,
      trunkLean: trunkLean,
      clockAngle: backAngle,
      heelDistance: heelDistanceToFloor,
      scaleFactor: scaleFactor,
      squatState: squatState,
      frameTimestamp: now,
      kneeY: knee.y,
      hipY: hip.y,
      shoulderY: shoulder.y,
      resultIssues: resultIssues,
    );

    // 4. Debug overlay
    debugData['squatState'] = squatState.name;
    debugData['previousSquatState'] = previousSquatState.name;
    debugData['repCount'] = repCount;
    debugData['frameBuffer'] = frameBuffer.frameBuffer.length;

    // 5. Handle rep completion (transition back to standing)
    if (squatState == SquatState.standing &&
        previousSquatState != SquatState.standing) {
      _completeRep(ctx, now);
      return;
    }

    // 6. Buffer frame & update state machine
    frameBuffer.addFrame(FrameSnapshot(log: {
      "kneeAngle": kneeAngle,
      "trunkLean": trunkLean,
      "heelDistance": heelDistanceToFloor,
    }, timeStamp: now));

    _updateStateBuffer(kneeAngle, now);

    // 7. Run all metrics (skip standing phase)
    if (squatState != SquatState.standing) {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
    }

    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }

    // 8. Phase-specific UI instructions
    _updatePhaseInstructions(now);
  }

  // --- Rep Completion ---

  void _completeRep(RepContext ctx, int now) {
    repCount += 1;

    // Evaluate final metrics for this rep
    depthMetric.checkRepCompletion(previousSquatState, ctx);
    _transitionState(SquatState.standing, now);
    tempoMetric.evaluateRep(ctx);

    // Collect faults from all metrics
    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      allFaults.addAll(metric.faults);
    }

    // Determine rep quality
    correctForm = !allFaults.any((f) => f.affectsForm);
    resultIssues.feedback['Result'] = correctForm ? 'Good Rep!' : 'Fix Form';

    speakRepCompletion(
      nextPhaseVoice: "Xuống",
      correctForm: correctForm,
    );

    // Build fault map grouped by phase
    final faultMap = <String, Map<String, String>>{};
    for (final fault in allFaults) {
      faultMap.putIfAbsent(fault.phase, () => {});
      faultMap[fault.phase]![fault.type] = fault.message;
    }
    setFeedback.add({correctForm: faultMap});

    // Update debug data with metric outputs
    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }

    // Tempo feedback for UI
    if (tempoMetric.descentDuration != null) {
      final descent = tempoMetric.descentDuration!.toStringAsFixed(1);
      resultIssues.feedback['Tempo'] = '↓${descent}s';
      if (tempoMetric.ascentDuration != null) {
        final ascent = tempoMetric.ascentDuration!.toStringAsFixed(1);
        resultIssues.feedback['Tempo'] = '↓${descent}s ↑${ascent}s';
      }
    }

    // Log per-rep data for onboarding assessment
    final peakKneeSnapshot = frameBuffer.getPeakMin("kneeAngle");
    logger
        .addRepLog(RepLog(correctForm: correctForm, repNumber: repCount, data: {
      "peak_heel_distance":
          frameBuffer.getPeakMax("heelDistance")?.log["heelDistance"] ?? 0,
      "peak_knee_angle": peakKneeSnapshot?.log["kneeAngle"] ?? 0,
      "trunk_lean_at_bottom": peakKneeSnapshot?.log["trunkLean"] ?? 0,
      "ascending_time": tempoMetric.ascentDuration ?? 0.0,
      "descending_time": tempoMetric.descentDuration ?? 0.0,
    }));

    // Reset for next rep
    correctForm = true;
    for (final metric in _metrics) {
      metric.resetAndCountFault();
    }
  }

  // --- Phase Instructions ---

  void _updatePhaseInstructions(int now) {
    switch (squatState) {
      case SquatState.descending:
        resultIssues.addInstruction('descending', 'Status', 'Going Down...');
        break;
      case SquatState.bottom:
        final remaining = tempoMetric.bottomHoldRemaining(now);
        final progress = tempoMetric.bottomHoldProgress(now);
        if (remaining != null && remaining > 0.05) {
          resultIssues.addInstruction(
              'bottom', 'Status', 'Hold! ${remaining.toStringAsFixed(1)}s');
        } else {
          resultIssues.addInstruction('bottom', 'Status', 'Push Up Now!');
        }
        if (progress != null) debugData['bottomHoldProgress'] = progress;
        break;
      case SquatState.ascending:
        resultIssues.addInstruction('ascending', 'Status', 'Push Up!');
        break;
      case SquatState.standing:
        break;
    }
  }

  // --- State Machine (buffer-based) ---
  // Uses frame buffer angle change direction + debouncers for robust transitions.

  void _updateStateBuffer(double kneeAngle, int timestampMs) {
    final angleChange = frameBuffer.getAngleChange("kneeAngle");

    // Direction-based transitions
    if (angleChange != AngleChangeState.stable) {
      final isIncreasing =
          directionDetection.update(angleChange == AngleChangeState.increasing);

      if (!isIncreasing &&
          squatState == SquatState.standing &&
          kneeAngle < SquatConfig.SQUAT_STAND_ANGLE_THRESHOLD - 5) {
        _transitionState(SquatState.descending, timestampMs);
        frameBuffer.clear();
      } else if (isIncreasing && squatState == SquatState.bottom) {
        _transitionState(SquatState.ascending, timestampMs);
      }
    }

    // Debounced threshold transitions
    if (_bottomDebouncer.update(
        kneeAngle <= SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[1] &&
            squatState == SquatState.descending)) {
      _transitionState(SquatState.bottom, timestampMs);
    } else if (_standingDebouncer.update(
        kneeAngle > SquatConfig.SQUAT_STAND_ANGLE_THRESHOLD &&
            (squatState == SquatState.ascending ||
                squatState == SquatState.descending))) {
      _transitionState(SquatState.standing, timestampMs);
    }
  }

  void _transitionState(SquatState newState, int timestampMs) {
    previousSquatState = squatState;
    squatState = newState;

    if (newState == SquatState.descending) {
      ttsService.clearQueue(); // Stop any pending voice to avoid overlap
      resultIssues.instructions.clear();
    } else if (newState == SquatState.bottom) {
      ttsService.speak("Giữ");
    } else if (newState == SquatState.ascending) {
      ttsService.speak("Lên");
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousSquatState, newState, timestampMs);
    }
  }
}
