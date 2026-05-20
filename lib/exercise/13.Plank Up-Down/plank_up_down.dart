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
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  final int maxRep;
  PlankState plankState = PlankState.forearm_plank;
  PlankState previousPlankState = PlankState.forearm_plank;
  
  int? _exerciseStartTimeMs;
  bool _isTimeout = false;

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

  PlankUpDown({this.maxRep = PlankConfig.MAX_REP});

  @override
  String get exerciseName => 'Plank Up-Down';

  @override
  String get currentPhaseKey => plankState.name;

  @override
  String get currentPhaseLabel {
    switch (plankState) {
      case PlankState.forearm_plank: return 'Forearm Plank';
      case PlankState.pushing_up: return 'Đẩy lên...';
      case PlankState.high_plank: return 'High Plank';
      case PlankState.lowering: return 'Hạ xuống...';
    }
  }

  // Yêu cầu góc ngang (Side)
  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return "⚠️ Vui lòng quay góc ngang (Side) để đo trục lưng.";
    }
    return null;
  }

  // Điều kiện chuẩn bị
  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final lHip = landmarks[PoseLandmarkType.leftHip];
    final lAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final lElbow = landmarks[PoseLandmarkType.leftElbow];
    final lWrist = landmarks[PoseLandmarkType.leftWrist];

    final rShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final rHip = landmarks[PoseLandmarkType.rightHip];
    final rAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final rElbow = landmarks[PoseLandmarkType.rightElbow];
    final rWrist = landmarks[PoseLandmarkType.rightWrist];

    bool leftValid = lShoulder != null && lHip != null && lAnkle != null && lElbow != null && lWrist != null;
    bool rightValid = rShoulder != null && rHip != null && rAnkle != null && rElbow != null && rWrist != null;

    if (!leftValid && !rightValid) return false;

    bool useLeft = leftValid && (!rightValid || (lHip.likelihood >= rHip.likelihood));

    final shoulder = useLeft ? lShoulder! : rShoulder!;
    final hip = useLeft ? lHip! : rHip!;
    final ankle = useLeft ? lAnkle! : rAnkle!;

    final bodyAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: hip, lastPoint: ankle);

    final leftElbowAngle = leftValid
        ? calculateAngleNormalized(firstPoint: lShoulder!, midPoint: lElbow!, lastPoint: lWrist!)
        : (rightValid ? calculateAngleNormalized(firstPoint: rShoulder!, midPoint: rElbow!, lastPoint: rWrist!) : 90.0);

    final rightElbowAngle = rightValid
        ? calculateAngleNormalized(firstPoint: rShoulder!, midPoint: rElbow!, lastPoint: rWrist!)
        : (leftValid ? calculateAngleNormalized(firstPoint: lShoulder!, midPoint: lElbow!, lastPoint: lWrist!) : 90.0);

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
    final lAnkle = smoothedLandmarks[PoseLandmarkType.leftAnkle];
    final lElbow = smoothedLandmarks[PoseLandmarkType.leftElbow];
    final lWrist = smoothedLandmarks[PoseLandmarkType.leftWrist];

    final rShoulder = smoothedLandmarks[PoseLandmarkType.rightShoulder];
    final rHip = smoothedLandmarks[PoseLandmarkType.rightHip];
    final rAnkle = smoothedLandmarks[PoseLandmarkType.rightAnkle];
    final rElbow = smoothedLandmarks[PoseLandmarkType.rightElbow];
    final rWrist = smoothedLandmarks[PoseLandmarkType.rightWrist];

    bool leftValid = lShoulder != null && lHip != null && lAnkle != null && lElbow != null && lWrist != null;
    bool rightValid = rShoulder != null && rHip != null && rAnkle != null && rElbow != null && rWrist != null;

    if (!leftValid && !rightValid) return; // early return to prevent null crash

    // Choose primary side based on likelihood of hip
    bool useLeft = leftValid && (!rightValid || (lHip.likelihood >= rHip.likelihood));

    final shoulder = useLeft ? lShoulder! : rShoulder!;
    final hip = useLeft ? lHip! : rHip!;
    final ankle = useLeft ? lAnkle! : rAnkle!;

    scaleFactor = calculateDistance(shoulder, hip);
    final bodyAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: hip, lastPoint: ankle);

    final leftElbowAngle = leftValid
        ? calculateAngleNormalized(firstPoint: lShoulder!, midPoint: lElbow!, lastPoint: lWrist!)
        : (rightValid ? calculateAngleNormalized(firstPoint: rShoulder!, midPoint: rElbow!, lastPoint: rWrist!) : 90.0);

    final rightElbowAngle = rightValid
        ? calculateAngleNormalized(firstPoint: rShoulder!, midPoint: rElbow!, lastPoint: rWrist!)
        : (leftValid ? calculateAngleNormalized(firstPoint: lShoulder!, midPoint: lElbow!, lastPoint: lWrist!) : 90.0);

    // GHI LOG TELEMETRY
    _telemetryLog.add({
      'timestamp': now,
      'time_elapsed': now - _exerciseStartTimeMs!,
      'state': plankState.name,
      'bodyAngle': double.parse(bodyAngle.toStringAsFixed(1)),
      'leftElbowAngle': double.parse(leftElbowAngle.toStringAsFixed(1)),
      'rightElbowAngle': double.parse(rightElbowAngle.toStringAsFixed(1)),
      'hipY': double.parse(hip.y.toStringAsFixed(1)),
      'visibility': (useLeft ? [lShoulder, lHip, lAnkle, lElbow, lWrist] : [rShoulder, rHip, rAnkle, rElbow, rWrist])
          .map((l) => l!.likelihood)
          .reduce((a, b) => a + b) / 5, // Avg confidence
    });

    final ctx = PlankRepContext(
      bodyAngle: bodyAngle,
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
    debugData['Left_Elbow'] = leftElbowAngle.toStringAsFixed(1);
    debugData['Right_Elbow'] = rightElbowAngle.toStringAsFixed(1);
    debugData['Time_Left'] = ((PlankConfig.MAX_DURATION_MS - (now - _exerciseStartTimeMs!)) / 1000).toStringAsFixed(1);

    _updateStateMachine(leftElbowAngle, rightElbowAngle, now);

    // Chạy Metrics
    for (var metric in _metrics) {
      metric.update(ctx);
      debugData.addAll(metric.debugData);
    }
  }

  void _updateStateMachine(double leftElbowAngle, double rightElbowAngle, int now) {
    switch (plankState) {
      case PlankState.forearm_plank:
        if (_pushingDebouncer.update(leftElbowAngle > PlankConfig.ELBOW_PUSHING_THRESHOLD || rightElbowAngle > PlankConfig.ELBOW_PUSHING_THRESHOLD)) {
          _transitionState(PlankState.pushing_up, now);
        }
        break;
      case PlankState.pushing_up:
        if (_highPlankDebouncer.update(leftElbowAngle > PlankConfig.ELBOW_HIGH_PLANK_MIN && rightElbowAngle > PlankConfig.ELBOW_HIGH_PLANK_MIN)) {
          _transitionState(PlankState.high_plank, now);
        }
        break;
      case PlankState.high_plank:
        if (_loweringDebouncer.update(leftElbowAngle < PlankConfig.ELBOW_LOWERING_THRESHOLD || rightElbowAngle < PlankConfig.ELBOW_LOWERING_THRESHOLD)) {
          _transitionState(PlankState.lowering, now);
        }
        break;
      case PlankState.lowering:
        if (_forearmDebouncer.update(leftElbowAngle < PlankConfig.ELBOW_FOREARM_MAX && rightElbowAngle < PlankConfig.ELBOW_FOREARM_MAX)) {
          _transitionState(PlankState.forearm_plank, now);
          _completeRep();
        }
        break;
    }
  }

  void _transitionState(PlankState newState, int now) {
    previousPlankState = plankState;
    plankState = newState;
    for (var metric in _metrics) {
      metric.onStateTransition(previousPlankState, newState, now);
    }
  }

  void _completeRep() {
    repCount++;
    bool isRepGood = true;
    final allFaults = <FaultRecord>[];
    
    for (var metric in _metrics) {
      if (metric.faults.isNotEmpty) isRepGood = false;
      allFaults.addAll(metric.faults);
    }
    
    correctForm = isRepGood;

    logger.addRepLog(RepLog(
      correctForm: correctForm,
      repNumber: repCount,
      data: {
        "lead_arm": leadArmMetric.currentLeadArm ?? 'None',
        "fault_types": allFaults.map((e) => e.type).toSet().toList(),
      },
    ));
    
    logger.pushGoodRepCount();
    
    for (var metric in _metrics) {
      metric.resetAndCountFault();
    }
  }

  @override
  bool requestStop() => repCount >= maxRep || _isTimeout;

  @override
  void onSetComplete() {
    logger.pushKey("timeout_triggered", _isTimeout);
    logger.pushKey("trunk_sagging_fails", trunkMetric.faultsCount);
    logger.pushKey("hip_rotation_fails", hipRotationMetric.faultsCount);
    logger.pushKey("arm_extension_fails", armExtensionMetric.faultsCount);
    logger.pushKey("left_lead_count", leadArmMetric.leftLeadCount);
    logger.pushKey("right_lead_count", leadArmMetric.rightLeadCount);
    logger.pushKey("telemetry_data", _telemetryLog);
  }
}