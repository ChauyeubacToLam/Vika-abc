// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/debouncer.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';
import 'metrics/plank_up_down_metric_base.dart';
import 'metrics/trunk_alignment_metric.dart';
import 'metrics/hip_rotation_metric.dart';
import 'metrics/arm_extension_metric.dart';
import 'metrics/alternating_lead_arm_metric.dart';

class PlankUpDown extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  final int maxRep;
  PlankState plankState = PlankState.forearm_plank;
  PlankState previousPlankState = PlankState.forearm_plank;

  int? _exerciseStartTimeMs;
  bool _isTimeout = false;
  int? _holdStartTimeMs;
  bool _holdCompleteForState = false;
  bool _reachedHighPlankInCycle = false;

  // Telemetry: Lưu dữ liệu từng frame để debug
  final List<Map<String, dynamic>> _telemetryLog = [];

  // Metrics
  final TrunkAlignmentMetric trunkMetric = TrunkAlignmentMetric();
  final HipRotationMetric hipRotationMetric = HipRotationMetric();
  final ArmExtensionMetric armExtensionMetric = ArmExtensionMetric();
  final AlternatingLeadArmMetric leadArmMetric = AlternatingLeadArmMetric();
  late final List<PlankMetricBase> _metrics = [
    trunkMetric,
    hipRotationMetric,
    armExtensionMetric,
    leadArmMetric,
  ];

  // Debouncers cho State Machine
  final Debouncer _pushingDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _highPlankDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _loweringDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _forearmDebouncer = Debouncer(requiredFrames: 2);

  PlankUpDown({required this.maxRep});

  @override
  String get exerciseName => 'Plank Up-Down';

  @override
  String get currentPhaseKey => plankState.name;

  @override
  String get currentPhaseLabel {
    switch (plankState) {
      case PlankState.forearm_plank:
        return 'Forearm Plank';
      case PlankState.pushing_up:
        return 'Đẩy lên...';
      case PlankState.high_plank:
        return 'High Plank';
      case PlankState.lowering:
        return 'Hạ xuống...';
    }
  }

  // Yêu cầu góc ngang (Side)
  @override
  double? get liveHoldSeconds =>
      _isHoldState(plankState) && !_holdCompleteForState
          ? _holdElapsedSeconds(frameTimestampMs)
          : null;

  @override
  double? get liveHoldTargetSeconds => PlankConfig.HOLD_DURATION_SECONDS;

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return "⚠️ Vui lòng quay góc ngang (Side) để đo trục lưng.";
    }
    return null;
  }

  // Điều kiện chuẩn bị
  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final lHip = landmarks[PoseLandmarkType.leftHip];
    final lKnee = landmarks[PoseLandmarkType.leftKnee];
    final lAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final lElbow = landmarks[PoseLandmarkType.leftElbow];
    final lWrist = landmarks[PoseLandmarkType.leftWrist];

    final rShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final rHip = landmarks[PoseLandmarkType.rightHip];
    final rKnee = landmarks[PoseLandmarkType.rightKnee];
    final rAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final rElbow = landmarks[PoseLandmarkType.rightElbow];
    final rWrist = landmarks[PoseLandmarkType.rightWrist];

    bool leftValid = lShoulder != null &&
        lHip != null &&
        lKnee != null &&
        lAnkle != null &&
        lElbow != null &&
        lWrist != null &&
        [lShoulder, lHip, lKnee, lAnkle, lElbow, lWrist]
            .every(ExerciseBase.isLandmarkConfident);
    bool rightValid = rShoulder != null &&
        rHip != null &&
        rKnee != null &&
        rAnkle != null &&
        rElbow != null &&
        rWrist != null &&
        [rShoulder, rHip, rKnee, rAnkle, rElbow, rWrist]
            .every(ExerciseBase.isLandmarkConfident);

    if (!leftValid && !rightValid) return false;

    bool useLeft =
        leftValid && (!rightValid || (lHip.likelihood >= rHip.likelihood));

    final shoulder = (useLeft ? lShoulder : rShoulder)!;
    final hip = (useLeft ? lHip : rHip)!;
    final ankle = (useLeft ? lAnkle : rAnkle)!;

    final bodyAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: ankle);

    final leftElbowAngle = leftValid
        ? calculateAngleNormalized(
            firstPoint: lShoulder, midPoint: lElbow, lastPoint: lWrist)
        : (rightValid
            ? calculateAngleNormalized(
                firstPoint: rShoulder, midPoint: rElbow, lastPoint: rWrist)
            : 90.0);

    final rightElbowAngle = rightValid
        ? calculateAngleNormalized(
            firstPoint: rShoulder, midPoint: rElbow, lastPoint: rWrist)
        : (leftValid
            ? calculateAngleNormalized(
                firstPoint: lShoulder, midPoint: lElbow, lastPoint: lWrist)
            : 90.0);

    // Cả 2 góc cùi chỏ phải đang ở tư thế gập cẳng tay (forearm plank)
    return bodyAngle >= PlankConfig.BODY_ALIGNMENT_START_MIN &&
        leftElbowAngle <= PlankConfig.ELBOW_FOREARM_MAX &&
        rightElbowAngle <= PlankConfig.ELBOW_FOREARM_MAX;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final now = frameTimestampMs;
    _exerciseStartTimeMs ??= now;

    // Logic Timeout 90s
    if (now - _exerciseStartTimeMs! > PlankConfig.MAX_DURATION_MS) {
      _isTimeout = true;
      requestStop(); // Gọi hàm dừng bài tập
      return;
    }

    final lShoulder = smoothedLandmarks[PoseLandmarkType.leftShoulder];
    final lHip = smoothedLandmarks[PoseLandmarkType.leftHip];
    final lKnee = smoothedLandmarks[PoseLandmarkType.leftKnee];
    final lAnkle = smoothedLandmarks[PoseLandmarkType.leftAnkle];
    final lElbow = smoothedLandmarks[PoseLandmarkType.leftElbow];
    final lWrist = smoothedLandmarks[PoseLandmarkType.leftWrist];

    final rShoulder = smoothedLandmarks[PoseLandmarkType.rightShoulder];
    final rHip = smoothedLandmarks[PoseLandmarkType.rightHip];
    final rKnee = smoothedLandmarks[PoseLandmarkType.rightKnee];
    final rAnkle = smoothedLandmarks[PoseLandmarkType.rightAnkle];
    final rElbow = smoothedLandmarks[PoseLandmarkType.rightElbow];
    final rWrist = smoothedLandmarks[PoseLandmarkType.rightWrist];

    bool leftValid = lShoulder != null &&
        lHip != null &&
        lKnee != null &&
        lAnkle != null &&
        lElbow != null &&
        lWrist != null &&
        [lShoulder, lHip, lKnee, lAnkle, lElbow, lWrist]
            .every(ExerciseBase.isLandmarkConfident);
    bool rightValid = rShoulder != null &&
        rHip != null &&
        rKnee != null &&
        rAnkle != null &&
        rElbow != null &&
        rWrist != null &&
        [rShoulder, rHip, rKnee, rAnkle, rElbow, rWrist]
            .every(ExerciseBase.isLandmarkConfident);

    if (!leftValid && !rightValid) return; // early return to prevent null crash

    // Choose primary side based on likelihood of hip
    bool useLeft =
        leftValid && (!rightValid || (lHip.likelihood >= rHip.likelihood));

    final shoulder = (useLeft ? lShoulder : rShoulder)!;
    final hip = (useLeft ? lHip : rHip)!;
    final knee = (useLeft ? lKnee : rKnee)!;
    final ankle = (useLeft ? lAnkle : rAnkle)!;

    scaleFactor = calculateDistance(shoulder, hip);
    final bodyAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    final kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);

    final leftElbowAngle = leftValid
        ? calculateAngleNormalized(
            firstPoint: lShoulder, midPoint: lElbow, lastPoint: lWrist)
        : (rightValid
            ? calculateAngleNormalized(
                firstPoint: rShoulder, midPoint: rElbow, lastPoint: rWrist)
            : 90.0);

    final rightElbowAngle = rightValid
        ? calculateAngleNormalized(
            firstPoint: rShoulder, midPoint: rElbow, lastPoint: rWrist)
        : (leftValid
            ? calculateAngleNormalized(
                firstPoint: lShoulder, midPoint: lElbow, lastPoint: lWrist)
            : 90.0);

    if (isDebugModeActive) {
      // GHI LOG TELEMETRY
      _telemetryLog.add({
        'timestamp': now,
        'time_elapsed': now - _exerciseStartTimeMs!,
        'state': plankState.name,
        'bodyAngle': double.parse(bodyAngle.toStringAsFixed(1)),
        'leftElbowAngle': double.parse(leftElbowAngle.toStringAsFixed(1)),
        'rightElbowAngle': double.parse(rightElbowAngle.toStringAsFixed(1)),
        'kneeAngle': double.parse(kneeAngle.toStringAsFixed(1)),
        'hipY': double.parse(hip.y.toStringAsFixed(1)),
        'visibility': (useLeft
                    ? [lShoulder, lHip, lKnee, lAnkle, lElbow, lWrist]
                    : [rShoulder, rHip, rKnee, rAnkle, rElbow, rWrist])
                .map((l) => l!.likelihood)
                .reduce((a, b) => a + b) /
            6, // Avg confidence
      });
    }

    final ctx = PlankRepContext(
      bodyAngle: bodyAngle,
      kneeAngle: kneeAngle,
      leftElbowAngle: leftElbowAngle,
      rightElbowAngle: rightElbowAngle,
      hipY: hip.y,
      shoulderY: shoulder.y,
      scaleFactor: scaleFactor,
      currentState: plankState,
      frameTimestampMs: now,
      resultIssues: resultIssues,
    );

    // Update UI Debug Data
    debugData['State'] = plankState.name;
    debugData['Body_Angle'] = bodyAngle.toStringAsFixed(1);
    debugData['Knee_Angle'] = kneeAngle.toStringAsFixed(1);
    debugData['Left_Elbow'] = leftElbowAngle.toStringAsFixed(1);
    debugData['Right_Elbow'] = rightElbowAngle.toStringAsFixed(1);
    debugData['Time_Left'] =
        ((PlankConfig.MAX_DURATION_MS - (now - _exerciseStartTimeMs!)) / 1000)
            .toStringAsFixed(1);

    _updateStateMachine(leftElbowAngle, rightElbowAngle, kneeAngle, now);

    // Chạy Metrics
    for (var metric in _metrics) {
      metric.update(ctx);
      debugData.addAll(metric.debugData);
    }
  }

  void _updateStateMachine(double leftElbowAngle, double rightElbowAngle,
      double kneeAngle, int now) {
    if (kneeAngle < PlankConfig.KNEE_EXTENSION_MIN) {
      resultIssues.feedback['Knee'] = 'Thẳng đầu gối ra!';
      _resetHoldTimer();
      _updatePhaseInstruction(now);
      return; // Dừng State Machine, không đếm rep nếu gối bị co
    } else {
      resultIssues.feedback.remove('Knee');
    }

    _updateHoldGate(leftElbowAngle, rightElbowAngle, now);

    switch (plankState) {
      case PlankState.forearm_plank:
        if (_holdCompleteForState && _reachedHighPlankInCycle) {
          _completeRep();
          _reachedHighPlankInCycle = false;
        }
        if (_holdCompleteForState &&
            _pushingDebouncer.update(
                leftElbowAngle > PlankConfig.ELBOW_PUSHING_THRESHOLD ||
                    rightElbowAngle > PlankConfig.ELBOW_PUSHING_THRESHOLD)) {
          _transitionState(PlankState.pushing_up, now);
        } else if (!_holdCompleteForState) {
          _pushingDebouncer.reset();
        }
        break;
      case PlankState.pushing_up:
        if (_highPlankDebouncer.update(
            leftElbowAngle > PlankConfig.ELBOW_HIGH_PLANK_MIN &&
                rightElbowAngle > PlankConfig.ELBOW_HIGH_PLANK_MIN)) {
          _reachedHighPlankInCycle = true;
          _transitionState(PlankState.high_plank, now);
        }
        break;
      case PlankState.high_plank:
        if (_holdCompleteForState &&
            _loweringDebouncer.update(
                leftElbowAngle < PlankConfig.ELBOW_LOWERING_THRESHOLD ||
                    rightElbowAngle < PlankConfig.ELBOW_LOWERING_THRESHOLD)) {
          _transitionState(PlankState.lowering, now);
        } else if (!_holdCompleteForState) {
          _loweringDebouncer.reset();
        }
        break;
      case PlankState.lowering:
        if (_forearmDebouncer.update(
            leftElbowAngle < PlankConfig.ELBOW_FOREARM_MAX &&
                rightElbowAngle < PlankConfig.ELBOW_FOREARM_MAX)) {
          _transitionState(PlankState.forearm_plank, now);
        }
        break;
    }

    _updatePhaseInstruction(now);
  }

  void _updateHoldGate(double leftElbowAngle, double rightElbowAngle, int now) {
    if (!_isHoldState(plankState)) {
      _holdStartTimeMs = null;
      _clearHoldDebugData();
      return;
    }

    if (_holdCompleteForState) return;

    final isHoldingPose =
        _isHoldingPose(plankState, leftElbowAngle, rightElbowAngle);
    if (!isHoldingPose) {
      _holdStartTimeMs = null;
      return;
    }

    _holdStartTimeMs ??= now;
    if (now - _holdStartTimeMs! >= PlankConfig.HOLD_DURATION_MS) {
      _holdCompleteForState = true;
    }
  }

  bool _isHoldState(PlankState state) =>
      state == PlankState.forearm_plank || state == PlankState.high_plank;

  bool _isHoldingPose(
      PlankState state, double leftElbowAngle, double rightElbowAngle) {
    switch (state) {
      case PlankState.forearm_plank:
        return leftElbowAngle <= PlankConfig.ELBOW_FOREARM_MAX &&
            rightElbowAngle <= PlankConfig.ELBOW_FOREARM_MAX;
      case PlankState.high_plank:
        return leftElbowAngle >= PlankConfig.ELBOW_HIGH_PLANK_MIN &&
            rightElbowAngle >= PlankConfig.ELBOW_HIGH_PLANK_MIN;
      case PlankState.pushing_up:
      case PlankState.lowering:
        return false;
    }
  }

  double _holdElapsedSeconds(int now) {
    if (_holdStartTimeMs == null) return 0.0;
    return ((now - _holdStartTimeMs!) / 1000.0)
        .clamp(0.0, PlankConfig.HOLD_DURATION_SECONDS);
  }

  double _holdRemainingSeconds(int now) =>
      (PlankConfig.HOLD_DURATION_SECONDS - _holdElapsedSeconds(now))
          .clamp(0.0, PlankConfig.HOLD_DURATION_SECONDS);

  double _holdProgress(int now) =>
      (_holdElapsedSeconds(now) / PlankConfig.HOLD_DURATION_SECONDS)
          .clamp(0.0, 1.0);

  void _updatePhaseInstruction(int now) {
    debugData['Hold_Complete'] = _holdCompleteForState;

    if (_isHoldState(plankState) && !_holdCompleteForState) {
      final remaining = _holdRemainingSeconds(now);
      resultIssues.addInstruction(
          plankState.name, 'Status', 'Hold! ${remaining.toStringAsFixed(1)}s');
      debugData['holdProgress'] = _holdProgress(now);
      debugData['holdRemaining'] = remaining;
      debugData['Hold_Remaining'] = remaining.toStringAsFixed(1);
      return;
    }

    _clearHoldDebugData();

    switch (plankState) {
      case PlankState.forearm_plank:
        resultIssues.addInstruction(plankState.name, 'Status', 'Sẵn sàng đẩy');
        break;
      case PlankState.pushing_up:
        resultIssues.addInstruction(plankState.name, 'Status', 'Đang đẩy lên');
        break;
      case PlankState.high_plank:
        resultIssues.addInstruction(
            plankState.name, 'Status', 'Hạ xuống có kiểm soát');
        break;
      case PlankState.lowering:
        resultIssues.addInstruction(plankState.name, 'Status', 'Going Down...');
        break;
    }
  }

  void _resetHoldTimer() {
    _holdStartTimeMs = null;
    _holdCompleteForState = false;
    _clearHoldDebugData();
  }

  void _clearHoldDebugData() {
    debugData.remove('holdProgress');
    debugData.remove('holdRemaining');
    debugData.remove('Hold_Remaining');
  }

  void _transitionState(PlankState newState, int now) {
    previousPlankState = plankState;
    plankState = newState;
    _holdStartTimeMs = _isHoldState(newState) ? now : null;
    _holdCompleteForState = !_isHoldState(newState);
    _pushingDebouncer.reset();
    _highPlankDebouncer.reset();
    _loweringDebouncer.reset();
    _forearmDebouncer.reset();
    for (var metric in _metrics) {
      metric.onStateTransition(previousPlankState, newState, now);
    }
  }

  void _completeRep({bool countRep = true}) {
    if (countRep) repCount++;
    bool isRepGood = true;
    final allFaults = <FaultRecord>[];

    for (var metric in _metrics) {
      allFaults.addAll(metric.faults);
    }
    isRepGood = !allFaults.any((f) => f.affectsForm);

    correctForm = isRepGood;

    if (countRep) {
      logger.addRepLog(RepLog(
        correctForm: correctForm,
        repNumber: repCount,
        data: {
          "lead_arm": leadArmMetric.currentLeadArm ?? 'None',
          "fault_types": allFaults.map((e) => e.type).toSet().toList(),
        },
      ));

      logger.pushGoodRepCount();
    } else {
      correctForm = false;
      resultIssues.feedback['Result'] = 'Không tính';
    }

    for (var metric in _metrics) {
      if (countRep) {
        metric.resetAndCountFault();
      } else {
        metric.reset();
      }
    }
  }

  @override
  bool requestStop() => repCount >= maxRep || _isTimeout;

  @override
  void onSetComplete() {
    logger.pushKey("max_rep", _isTimeout ? repCount : maxRep);
    logger.pushKey("timeout_triggered", _isTimeout);
    logger.pushKey("trunk_sagging_fails_count", trunkMetric.faultsCount);
    logger.pushKey("hip_rotation_fails_count", hipRotationMetric.faultsCount);
    logger.pushKey("arm_extension_fails_count", armExtensionMetric.faultsCount);
    logger.pushKey("left_lead_count", leadArmMetric.leftLeadCount);
    logger.pushKey("right_lead_count", leadArmMetric.rightLeadCount);
    if (isDebugModeActive) {
      logger.pushKey("telemetry_data", _telemetryLog);
    }
  }
}
