// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import '../../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../exercise_base.dart';
import 'metrics/push_up_metric_base.dart';
import 'metrics/trunk_alignment_metric.dart';
import 'metrics/depth_metric.dart';
import 'metrics/tempo_metric.dart';

/* =========================================================================
   CONFIGURATION & THRESHOLDS
   ========================================================================= */
class PushUpConfig {
  static const int MAX_REP = 15;

  /// State machine transitions driven by elbow angle (β)
  /// β = SHOULDER→ELBOW→WRIST
  static const double PLANK_ANGLE_THRESHOLD = 155.0; // above = plank
  static const double DESCEND_ANGLE_THRESHOLD = 145.0; // below = descending
  static const List<double> BOTTOM_ANGLE_RANGE = [80.0, 100.0]; // bottom zone
  // Hysteresis: exit bottom when β > BOTTOM_ANGLE_RANGE[1] + 5°

  /// Trunk horizontal targets per facing direction.
  /// Same approach as Plank — clock angle from vertical.
  /// Left-facing: shoulder is left of hip → clock angle ~270°
  /// Right-facing: shoulder is right of hip → clock angle ~90°
  static const double HORIZONTAL_CLOCK_LEFT = 270.0;
  static const double HORIZONTAL_CLOCK_RIGHT = 90.0;
}

enum PushUpState {
  plank, // Top position — arms extended
  descending, // Lowering body
  bottom, // Maximum flexion
  ascending, // Pushing back up
}

/* =========================================================================
   PUSH-UP LOGIC
   ========================================================================= */

class PushUp extends ExerciseBase {
  PushUpState pushUpState = PushUpState.plank;
  PushUpState previousPushUpState = PushUpState.plank;

  // -- Metrics --
  final TrunkAlignmentMetric trunkAlignmentMetric = TrunkAlignmentMetric();
  final DepthMetric depthMetric = DepthMetric();
  final TempoMetric tempoMetric = TempoMetric();

  late final List<PushUpMetricBase> _metrics = [
    trunkAlignmentMetric,
    depthMetric,
    tempoMetric,
  ];

  /* -----------------------------------------------------------------------
     UI BRIDGE
     ----------------------------------------------------------------------- */
  @override
  String get exerciseName => 'Push Up';

  @override
  String get currentPhaseKey => pushUpState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (pushUpState) {
      case PushUpState.plank:
        return 'Chuẩn bị';
      case PushUpState.descending:
        return 'Xuống';
      case PushUpState.bottom:
        return 'Giữ';
      case PushUpState.ascending:
        return 'Đẩy lên';
    }
  }

  /* -----------------------------------------------------------------------
     Start     
     ----------------------------------------------------------------------- */
  @override
  bool isInStartPosition(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing facing,
    double? scaleFactor,
  ) {
    // Check: user is in plank position (horizontal trunk, arms extended)
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
    final elbow = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightElbow,
      leftType: PoseLandmarkType.leftElbow,
    );
    final wrist = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightWrist,
      leftType: PoseLandmarkType.leftWrist,
    );

    if (shoulder == null || hip == null || elbow == null || wrist == null) {
      return false;
    }

    // 1. Trunk must be roughly horizontal (within 25° of horizontal)
    double trunkClockAngle =
        calculateVerticalAngle(pivot: hip, point: shoulder);
    double horizontalTarget = facing == CameraFacing.right
        ? PushUpConfig.HORIZONTAL_CLOCK_RIGHT
        : PushUpConfig.HORIZONTAL_CLOCK_LEFT;
    double diff = trunkClockAngle - horizontalTarget;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    if (diff.abs() > 25.0) return false;

    // 2. Arms must be extended (elbow angle > 140° = plank top position)
    double elbowAngle = calculateAngle(
      firstPoint: shoulder,
      midPoint: elbow,
      lastPoint: wrist,
    );
    if (elbowAngle < 140.0) return false;

    return true;
  }

  /* -----------------------------------------------------------------------
     STOP CONDITION
     ----------------------------------------------------------------------- */
  @override
  bool requestStop() {
    return repCount >= PushUpConfig.MAX_REP;
  }

  /* -----------------------------------------------------------------------
     SAFETY CHECKS
     ----------------------------------------------------------------------- */
  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks,
      CameraFacing cameraFacing) {
    // Side view only for MVP (front view = future elbow flare metric)
    if (cameraFacing == CameraFacing.front) {
      return "⚠️ Xin hãy quay nghiêng để theo dõi tư thế Push Up";
    }

    // Required landmarks: shoulder, elbow, wrist, hip
    // Note: knee/ankle NOT required — may be out of frame
    PoseLandmark? shoulder = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    PoseLandmark? elbow = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightElbow,
        leftType: PoseLandmarkType.leftElbow);
    PoseLandmark? wrist = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightWrist,
        leftType: PoseLandmarkType.leftWrist);
    PoseLandmark? hip = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);

    if (shoulder == null || elbow == null || wrist == null || hip == null) {
      return "⚠️ Đảm bảo phần trên cơ thể trong khung hình";
    }

    if (shoulder.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        elbow.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        wrist.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        hip.likelihood < ExerciseBase.MIN_CONFIDENCE) {
      return "⚠️ Hình ảnh không rõ. Điều chỉnh ánh sáng hoặc vị trí";
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

    PoseLandmark? shoulder = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    PoseLandmark? elbow = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightElbow,
        leftType: PoseLandmarkType.leftElbow);
    PoseLandmark? wrist = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightWrist,
        leftType: PoseLandmarkType.leftWrist);
    PoseLandmark? hip = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);

    if (shoulder == null || elbow == null || wrist == null || hip == null) {
      return;
    }

    // ---------- 2. Calculate Geometry ----------

    // Elbow angle β: drives state machine (outer clock angle at elbow)
    double elbowAngle = 360 -
        calculateAngle(firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);

    // Trunk: clock angle from vertical (same as Plank approach)
    double trunkClockAngle =
        calculateVerticalAngle(pivot: hip, point: shoulder);

    // Deviation from horizontal (positive = sag, negative = pike)
    double horizontalTarget = cameraFacing == CameraFacing.right
        ? PushUpConfig.HORIZONTAL_CLOCK_RIGHT
        : PushUpConfig.HORIZONTAL_CLOCK_LEFT;
    double trunkDeviation =
        clockAngleDeviation(trunkClockAngle, horizontalTarget);

    int now = DateTime.now().millisecondsSinceEpoch;

    // ---------- 3. Build RepContext ----------

    final ctx = RepContext(
      elbowAngle: elbowAngle,
      trunkDeviation: trunkDeviation,
      trunkClockAngle: trunkClockAngle,
      scaleFactor: scaleFactor,
      pushUpState: pushUpState,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    // ---------- 4. Populate Debug Data ----------

    debugData['pushUpState'] = pushUpState.toString().split('.').last;
    debugData['elbowAngle'] = elbowAngle.toStringAsFixed(1);
    debugData['trunkClock'] = trunkClockAngle.toStringAsFixed(1);
    debugData['trunkDev'] =
        '${trunkDeviation >= 0 ? "+" : ""}${trunkDeviation.toStringAsFixed(1)}°';
    debugData['correctForm'] = correctForm.toString();

    // ---------- 5. Rep Completion (Return to Plank) ----------

    if (pushUpState == PushUpState.plank &&
        previousPushUpState != PushUpState.plank) {
      repCount += 1;

      // Let depth check if rep was deep enough
      depthMetric.checkRepCompletion(previousPushUpState, ctx);

      // Fire final state transition so tempo can calculate ascent
      _transitionState(PushUpState.plank, now);

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
      resultIssues.feedback['Result'] = correctForm ? 'Tốt!' : 'Chỉnh tư thế';

      // Build fault map for set history
      final faultMap = <String, Map<String, String>>{};
      for (final fault in allFaults) {
        if (!faultMap.containsKey(fault.phase)) {
          faultMap[fault.phase] = {};
        }
        faultMap[fault.phase]![fault.type] = fault.message;
      }
      setFeedback.add({correctForm: faultMap});

      // Add tempo summary to post-rep feedback
      if (tempoMetric.descentDuration != null) {
        resultIssues.feedback['Tempo'] =
            '↓${tempoMetric.descentDuration!.toStringAsFixed(1)}s';
        if (tempoMetric.ascentDuration != null) {
          resultIssues.feedback['Tempo'] =
              '↓${tempoMetric.descentDuration!.toStringAsFixed(1)}s ↑${tempoMetric.ascentDuration!.toStringAsFixed(1)}s';
        }
      }

      // Merge metric debug data BEFORE reset
      for (final metric in _metrics) {
        debugData.addAll(metric.debugData);
      }

      // Reset metrics for next rep
      correctForm = true;
      for (final metric in _metrics) {
        metric.reset();
      }
      return;
    }

    // ---------- 6. Update State Machine ----------

    _updatePushUpState(elbowAngle, now);

    // ---------- 7. Run All Metrics ----------
    // Trunk alignment runs continuously (not just during active phases)
    // Depth and tempo run during descent/bottom/ascent

    if (pushUpState != PushUpState.plank) {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
    }

    // Merge metric debug data
    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }

    // Status instruction based on current phase
    if (pushUpState == PushUpState.descending) {
      resultIssues.addInstruction('descending', 'Status', 'Đang xuống...');
    } else if (pushUpState == PushUpState.bottom) {
      resultIssues.addInstruction('bottom', 'Status', 'Đẩy lên!');
    } else if (pushUpState == PushUpState.ascending) {
      resultIssues.addInstruction('ascending', 'Status', "Đang đẩy lên!");
    }
  }

  /* -----------------------------------------------------------------------
     STATE MACHINE (with transition notifications)
     Driven by elbow angle β, same pattern as squat knee angle.
     ----------------------------------------------------------------------- */

  void _updatePushUpState(double elbowAngle, int timestampMs) {
    // plank → descending: elbow starts bending
    if (elbowAngle < PushUpConfig.DESCEND_ANGLE_THRESHOLD &&
        pushUpState == PushUpState.plank) {
      _transitionState(PushUpState.descending, timestampMs);
    }
    // descending → bottom: elbow enters bottom range
    else if (elbowAngle <= PushUpConfig.BOTTOM_ANGLE_RANGE[1] &&
        pushUpState == PushUpState.descending) {
      _transitionState(PushUpState.bottom, timestampMs);
    }
    // bottom → ascending: elbow starts opening past bottom range + hysteresis
    else if (elbowAngle > (PushUpConfig.BOTTOM_ANGLE_RANGE[1] + 5) &&
        pushUpState == PushUpState.bottom) {
      _transitionState(PushUpState.ascending, timestampMs);
    }
    // ascending → plank: elbow fully extended
    else if (elbowAngle > PushUpConfig.PLANK_ANGLE_THRESHOLD &&
        (pushUpState == PushUpState.ascending ||
            pushUpState == PushUpState.descending)) {
      _transitionState(PushUpState.plank, timestampMs);
    }
  }

  void _transitionState(PushUpState newState, int timestampMs) {
    previousPushUpState = pushUpState;
    pushUpState = newState;

    // Clear coaching instructions when user starts a new rep
    if (newState == PushUpState.descending) {
      resultIssues.instructions.clear();
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousPushUpState, newState, timestampMs);
    }
  }

  /* -----------------------------------------------------------------------
     HELPERS
     ----------------------------------------------------------------------- */
}
