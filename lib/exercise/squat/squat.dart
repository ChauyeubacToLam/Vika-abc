// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'package:vinafit_mobile/utils/debouncer.dart';

import '../../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../exercise_base.dart';
import 'metrics/squat_metric_base.dart';
import 'metrics/squat_depth_metric.dart';
import 'metrics/trunk_lean_metric.dart';
import 'metrics/heel_rise_metric.dart';
import 'metrics/tempo_metric.dart';
import 'metrics/hip_shoulder_sync.dart';
import '../../services/viettel_tts_service.dart';

/* =========================================================================
   CONFIGURATION & THRESHOLDS
   ========================================================================= */
class SquatConfig {
  static const int MAX_REP = 15; // Placeholder max rep count for demo purposes
  static const int SQUAT_STAND_ANGLE_THRESHOLD = 160;
  static const int SQUAT_DESCEND_ANGLE_THRESHOLD = 152;
  static const List<int> SQUAT_BOTTOM_ANGLE_THRESHOLD = [80, 100];
}

enum SquatState {
  standing,
  descending,
  bottom,
  ascending,
}

/* =========================================================================
   SQUAT LOGIC
   ========================================================================= */

class Squat extends ExerciseBase {
  SquatState squatState = SquatState.standing;
  SquatState previousSquatState = SquatState.standing;

  final ViettelTTSService _ttsService = ViettelTTSService();
  bool _spokenUp = false;

  // Debounce entry into rep — prevents false starts from noisy frames
  final Debouncer _entryDebouncer = Debouncer(requiredFrames: 2);

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

  /* -----------------------------------------------------------------------
     UI BRIDGE
  ----------------------------------------------------------------------- */
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

  /* -----------------------------------------------------------------------
      INITIALIZATION 
  ----------------------------------------------------------------------- */
  @override
  void onExerciseActivated() {
    super.onExerciseActivated();
    _ttsService.speak("Sẵn sàng, xuống");
  }

  @override
  bool isInStartPosition(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing facing,
    double? scaleFactor,
  ) {
    // Check: user is standing upright
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

    // 1. Trunk must be roughly vertical (clock angle near 0°/360°)
    double trunkClockAngle =
        calculateVerticalAngle(pivot: hip, point: shoulder);
    // Near vertical: clock angle close to 0° (or 360°)
    double deviationFromVertical = trunkClockAngle;
    if (deviationFromVertical > 180)
      deviationFromVertical = 360 - deviationFromVertical;
    if (deviationFromVertical > 25.0) return false;

    // 2. Legs must be straight (knee angle > 155° = standing)
    double kneeAngle = calculateAngleNormalized(
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

  /* -----------------------------------------------------------------------
     STOP CONDITION
  ----------------------------------------------------------------------- */
  @override
  bool requestStop() {
    return repCount >= SquatConfig.MAX_REP;
  }

  /* -----------------------------------------------------------------------
     SAFETY CHECKS
  ----------------------------------------------------------------------- */

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks,
      CameraFacing cameraFacing) {
    // Only accept side view for squat — front view makes it hard to track depth and trunk lean, which are critical for safety feedback.
    if (cameraFacing == CameraFacing.front) {
      return "⚠️ Please turn to the side for better tracking for Squat";
    }

    // check visibility and confidence of critical landmarks: hip, shoulder, knee, ankle
    PoseLandmark? hip = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);
    PoseLandmark? shoulder = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    PoseLandmark? knee = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightKnee,
        leftType: PoseLandmarkType.leftKnee);
    PoseLandmark? ankle = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle);
    PoseLandmark? foot = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightFootIndex,
        leftType: PoseLandmarkType.leftFootIndex);
    PoseLandmark? heel = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightHeel,
        leftType: PoseLandmarkType.leftHeel);

    if (hip == null ||
        shoulder == null ||
        knee == null ||
        ankle == null ||
        foot == null ||
        heel == null) return "⚠️ Body not fully visible.";

    if (hip.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        shoulder.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        knee.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        ankle.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        foot.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        heel.likelihood < ExerciseBase.MIN_CONFIDENCE) {
      return "⚠️ Adjust lighting/position.";
    }
    return null;
  }

  /* -----------------------------------------------------------------------
     MAIN PHYSICS LOOP — Called every frame when activated.
  ----------------------------------------------------------------------- */
  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks,
      CameraFacing cameraFacing, double? scaleFactor) {
    // ---------- 1. Get Landmarks ----------

    PoseLandmark? knee = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightKnee,
        leftType: PoseLandmarkType.leftKnee);
    PoseLandmark? hip = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);
    PoseLandmark? ankle = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle);
    PoseLandmark? shoulder = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    PoseLandmark? foot = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightFootIndex,
        leftType: PoseLandmarkType.leftFootIndex);
    PoseLandmark? heel = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightHeel,
        leftType: PoseLandmarkType.leftHeel);

    if (knee == null ||
        hip == null ||
        ankle == null ||
        shoulder == null ||
        foot == null ||
        heel == null) return;

    // ---------- 2. Calculate Geometry ----------

    double kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);
    double backAngle = calculateVerticalAngle(pivot: hip, point: shoulder);
    double trunkLean = convertClockAngleToTrunkLean(backAngle, cameraFacing);
    double heelDistanceToFloor = foot.y - heel.y;
    int now = DateTime.now().millisecondsSinceEpoch;

    // ---------- 3. Build RepContext ----------

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

    // ---------- 4. Populate Debug Data ----------

    // debugData['squatState'] = squatState.toString().split('.').last;
    // debugData['kneeAngle'] = kneeAngle.toStringAsFixed(1);
    // debugData['backClockAngle'] = backAngle.toStringAsFixed(1);
    // debugData['trunkLean'] =
    //     '${trunkLean >= 0 ? "+" : ""}${trunkLean.toStringAsFixed(1)}°';
    // debugData['trunkLeanDir'] = trunkLean >= 0 ? 'Forward' : 'Backward';
    // debugData['heelDist'] = heelDistanceToFloor.toStringAsFixed(2);
    // debugData['correctForm'] = correctForm.toString();

    // ---------- 5. Rep Completion (Standing Up) ----------

    if (squatState == SquatState.standing &&
        previousSquatState != SquatState.standing) {
      repCount += 1;

      // Let depth check if rep was deep enough
      depthMetric.checkRepCompletion(previousSquatState, ctx);

      // Fire final state transition so tempo can calculate ascent
      _transitionState(SquatState.standing, now);

      // Let tempo evaluate the full rep
      tempoMetric.evaluateRep(ctx);

      // Collect faults from all metrics
      final allFaults = <FaultRecord>[];
      for (final metric in _metrics) {
        allFaults.addAll(metric.faults);
      }

      // Determine correctForm: true if no faults with affectsForm=true
      correctForm = !allFaults.any((f) => f.affectsForm);

      // UI feedback
      resultIssues.feedback['Result'] = correctForm ? 'Good Rep!' : 'Fix Form';

      // --- Voice feedback (queue-based) ---
      // 1. Count rep number
      _ttsService.speak(repCount.toString());

      // 2. Specific error feedback or praise
      bool hasDepthFault = allFaults.any((f) => f.type == 'Depth');
      bool hasTrunkFault = allFaults.any((f) => f.type == 'Back');

      if (hasDepthFault) {
        _ttsService.speak("Thấp hơn nữa");
      }
      if (hasTrunkFault) {
        _ttsService.speak("Ưỡn ngực lên");
      }
      if (correctForm) {
        _ttsService.speak("Tốt lắm");
      }

      // 3. End or continue
      if (repCount >= SquatConfig.MAX_REP) {
        _ttsService.speak("Hoàn thành bài tập");
      } else {
        _ttsService.speak("Xuống");
      }

      // Build fault map for set history
      final faultMap = <String, Map<String, String>>{};
      for (final fault in allFaults) {
        if (!faultMap.containsKey(fault.phase)) {
          faultMap[fault.phase] = {};
        }
        faultMap[fault.phase]![fault.type] = fault.message;
      }
      setFeedback.add({correctForm: faultMap});

      // Merge metric debug data BEFORE reset
      for (final metric in _metrics) {
        debugData.addAll(metric.debugData);
      }

      // Add tempo summary to post-rep feedback
      if (tempoMetric.descentDuration != null) {
        resultIssues.feedback['Tempo'] =
            '↓${tempoMetric.descentDuration!.toStringAsFixed(1)}s';
        if (tempoMetric.ascentDuration != null) {
          resultIssues.feedback['Tempo'] =
              '↓${tempoMetric.descentDuration!.toStringAsFixed(1)}s ↑${tempoMetric.ascentDuration!.toStringAsFixed(1)}s';
        }
      }

      // Reset metrics for next rep (instructions survive — shown during standing)
      correctForm = true;
      for (final metric in _metrics) {
        metric.reset();
      }
      return;
    }

    // ---------- 6. Update State Machine ----------

    _updateSquatState(kneeAngle, now);

    // ---------- 7. Run All Metrics ----------

    if (squatState != SquatState.standing) {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
    }

    // Merge metric debug data
    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }

    // Status instruction based on current squat phase
    if (squatState == SquatState.descending) {
      resultIssues.addInstruction('descending', 'Status', 'Going Down...');
    } else if (squatState == SquatState.bottom) {
      final remaining = tempoMetric.bottomHoldRemaining;
      final progress = tempoMetric.bottomHoldProgress;
      if (remaining != null && remaining > 0.05) {
        resultIssues.addInstruction(
            'bottom', 'Status', 'Hold! ${remaining.toStringAsFixed(1)}s');
      } else {
        resultIssues.addInstruction('bottom', 'Status', 'Push Up Now!');
        if (!_spokenUp) {
          _ttsService.speak("Lên");
          _spokenUp = true;
        }
      }
      if (progress != null) {
        debugData['bottomHoldProgress'] = progress;
      }
    } else if (squatState == SquatState.ascending) {
      resultIssues.addInstruction('ascending', 'Status', 'Push Up!');
    }
  }

  /* -----------------------------------------------------------------------
     STATE MACHINE (with transition notifications)
  ----------------------------------------------------------------------- */

  void _updateSquatState(double kneeAngle, int timestampMs) {
    // Debounce entry: require 2 consecutive frames below threshold
    bool isEnteringRep = kneeAngle <= SquatConfig.SQUAT_DESCEND_ANGLE_THRESHOLD;
    bool confirmedEntry = _entryDebouncer.update(isEnteringRep);

    if (confirmedEntry && squatState == SquatState.standing) {
      _transitionState(SquatState.descending, timestampMs);
    } else if (kneeAngle <= SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[1] &&
        squatState == SquatState.descending) {
      _transitionState(SquatState.bottom, timestampMs);
    } else if (kneeAngle > (SquatConfig.SQUAT_BOTTOM_ANGLE_THRESHOLD[1] + 5) &&
        squatState == SquatState.bottom) {
      _transitionState(SquatState.ascending, timestampMs);
    } else if (kneeAngle > SquatConfig.SQUAT_STAND_ANGLE_THRESHOLD &&
        (squatState == SquatState.ascending ||
            squatState == SquatState.descending)) {
      _transitionState(SquatState.standing, timestampMs);
    }
  }

  void _transitionState(SquatState newState, int timestampMs) {
    previousSquatState = squatState;
    squatState = newState;

    // Clear coaching instructions when user starts a new rep.
    // Instructions were shown during standing — no longer needed.
    if (newState == SquatState.descending) {
      _ttsService.clearQueue(); // Stop any pending voice to avoid overlap
      resultIssues.instructions.clear();
      _spokenUp = false;
    } else if (newState == SquatState.bottom) {
      _ttsService.speak("Giữ");
    } else if (newState == SquatState.ascending) {
      // Audio handled at the end of bottom hold
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousSquatState, newState, timestampMs);
    }
  }
}
