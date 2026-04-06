// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'package:vinafit_mobile/utils/debouncer.dart';

import '../../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../exercise_base.dart';
import 'metrics/push_up_metric_base.dart';
import 'metrics/trunk_alignment_metric.dart';
import 'metrics/depth_metric.dart';
import 'metrics/tempo_metric.dart';

// --- Config ---

class PushUpConfig {
  static const int MAX_REP = 15;

  // State machine transitions driven by elbow angle (β = shoulder→elbow→wrist)
  static const double PLANK_ANGLE_THRESHOLD = 155.0;
  static const double DESCEND_ANGLE_THRESHOLD = 145.0;
  static const List<double> BOTTOM_ANGLE_RANGE = [80.0, 100.0];

  // Trunk horizontal targets per facing direction (clock angle from vertical)
  static const double HORIZONTAL_CLOCK_LEFT = 270.0;
  static const double HORIZONTAL_CLOCK_RIGHT = 90.0;
}

enum PushUpState { plank, descending, bottom, ascending }

// --- Push Up ---

class PushUp extends ExerciseBase {
  final int maxRep;
  PushUp({this.maxRep = PushUpConfig.MAX_REP});

  PushUpState pushUpState = PushUpState.plank;
  PushUpState previousPushUpState = PushUpState.plank;

  final Debouncer _entryDebouncer = Debouncer(requiredFrames: 2);

  final TrunkAlignmentMetric trunkAlignmentMetric = TrunkAlignmentMetric();
  final DepthMetric depthMetric = DepthMetric();
  final TempoMetric tempoMetric = TempoMetric();

  late final List<PushUpMetricBase> _metrics = [
    trunkAlignmentMetric,
    depthMetric,
    tempoMetric,
  ];

  // --- UI Bridge ---

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

  // --- Start Position ---

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

    // Trunk must be roughly horizontal (within 25°)
    double trunkClockAngle =
        calculateVerticalAngle(pivot: hip, point: shoulder);
    double horizontalTarget = cameraFacing == CameraFacing.right
        ? PushUpConfig.HORIZONTAL_CLOCK_RIGHT
        : PushUpConfig.HORIZONTAL_CLOCK_LEFT;
    double diff = trunkClockAngle - horizontalTarget;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    if (diff.abs() > 25.0) return false;

    // Arms must be extended (elbow angle > 140°)
    double elbowAngle = calculateAngle(
      firstPoint: shoulder,
      midPoint: elbow,
      lastPoint: wrist,
    );
    if (elbowAngle < 140.0) return false;

    return true;
  }

  // --- Stop Condition ---

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {}

  // --- Safety Checks ---

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return "⚠️ Xin hãy quay nghiêng để theo dõi tư thế Push Up";
    }

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

  // --- Main Loop (called every frame when activated) ---

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    // 1. Get landmarks
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

    // 2. Calculate geometry
    double elbowAngle = 360 -
        calculateAngle(firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);

    double trunkClockAngle =
        calculateVerticalAngle(pivot: hip, point: shoulder);

    double horizontalTarget = cameraFacing == CameraFacing.right
        ? PushUpConfig.HORIZONTAL_CLOCK_RIGHT
        : PushUpConfig.HORIZONTAL_CLOCK_LEFT;
    double trunkDeviation =
        clockAngleDeviation(trunkClockAngle, horizontalTarget);

    int now = frameTimestampMs;

    // 3. Build RepContext
    final ctx = RepContext(
      elbowAngle: elbowAngle,
      trunkDeviation: trunkDeviation,
      trunkClockAngle: trunkClockAngle,
      scaleFactor: scaleFactor,
      pushUpState: pushUpState,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    // 4. Debug data
    debugData['pushUpState'] = pushUpState.toString().split('.').last;
    debugData['elbowAngle'] = elbowAngle.toStringAsFixed(1);
    debugData['trunkClock'] = trunkClockAngle.toStringAsFixed(1);
    debugData['trunkDev'] =
        '${trunkDeviation >= 0 ? "+" : ""}${trunkDeviation.toStringAsFixed(1)}°';
    debugData['correctForm'] = correctForm.toString();

    // 5. Rep completion (return to plank)
    if (pushUpState == PushUpState.plank &&
        previousPushUpState != PushUpState.plank) {
      repCount += 1;

      depthMetric.checkRepCompletion(previousPushUpState, ctx);
      _transitionState(PushUpState.plank, now);
      tempoMetric.evaluateRep(ctx);

      final allFaults = <FaultRecord>[];
      for (final metric in _metrics) {
        allFaults.addAll(metric.faults);
      }

      correctForm = !allFaults.any((f) => f.affectsForm);
      resultIssues.feedback['Result'] = correctForm ? 'Tốt!' : 'Chỉnh tư thế';

      final faultMap = <String, Map<String, String>>{};
      for (final fault in allFaults) {
        if (!faultMap.containsKey(fault.phase)) {
          faultMap[fault.phase] = {};
        }
        faultMap[fault.phase]![fault.type] = fault.message;
      }
      setFeedback.add({correctForm: faultMap});

      if (tempoMetric.descentDuration != null) {
        resultIssues.feedback['Tempo'] =
            '↓${tempoMetric.descentDuration!.toStringAsFixed(1)}s';
        if (tempoMetric.ascentDuration != null) {
          resultIssues.feedback['Tempo'] =
              '↓${tempoMetric.descentDuration!.toStringAsFixed(1)}s ↑${tempoMetric.ascentDuration!.toStringAsFixed(1)}s';
        }
      }

      for (final metric in _metrics) {
        debugData.addAll(metric.debugData);
      }

      correctForm = true;
      for (final metric in _metrics) {
        metric.reset();
      }
      return;
    }

    // 6. Update state machine
    _updatePushUpState(elbowAngle, now);

    // 7. Run all metrics
    if (pushUpState != PushUpState.plank) {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
    }

    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }

    if (pushUpState == PushUpState.descending) {
      resultIssues.addInstruction('descending', 'Status', 'Đang xuống...');
    } else if (pushUpState == PushUpState.bottom) {
      resultIssues.addInstruction('bottom', 'Status', 'Đẩy lên!');
    } else if (pushUpState == PushUpState.ascending) {
      resultIssues.addInstruction('ascending', 'Status', "Đang đẩy lên!");
    }
  }

  // --- State Machine ---

  void _updatePushUpState(double elbowAngle, int timestampMs) {
    bool isEnteringRep = elbowAngle < PushUpConfig.DESCEND_ANGLE_THRESHOLD;
    bool confirmedEntry = _entryDebouncer.update(isEnteringRep);

    if (confirmedEntry && pushUpState == PushUpState.plank) {
      _transitionState(PushUpState.descending, timestampMs);
    } else if (elbowAngle <= PushUpConfig.BOTTOM_ANGLE_RANGE[1] &&
        pushUpState == PushUpState.descending) {
      _transitionState(PushUpState.bottom, timestampMs);
    } else if (elbowAngle > (PushUpConfig.BOTTOM_ANGLE_RANGE[1] + 5) &&
        pushUpState == PushUpState.bottom) {
      _transitionState(PushUpState.ascending, timestampMs);
    } else if (elbowAngle > PushUpConfig.PLANK_ANGLE_THRESHOLD &&
        (pushUpState == PushUpState.ascending ||
            pushUpState == PushUpState.descending)) {
      _transitionState(PushUpState.plank, timestampMs);
    }
  }

  void _transitionState(PushUpState newState, int timestampMs) {
    previousPushUpState = pushUpState;
    pushUpState = newState;

    if (newState == PushUpState.descending &&
        previousPushUpState == PushUpState.plank) {
      resultIssues.instructions.clear();
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousPushUpState, newState, timestampMs);
    }
  }
}
