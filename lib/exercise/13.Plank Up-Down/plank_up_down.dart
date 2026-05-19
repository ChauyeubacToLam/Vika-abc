// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/debouncer.dart';
import '../exercise_base.dart';
import 'metrics/plank_up_down_metric_base.dart';
import 'metrics/trunk_alignment_metric.dart';
import 'metrics/hip_rotation_metric.dart';
import 'metrics/arm_extension_metric.dart';

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
  late final List<PlankMetricBase> _metrics = [trunkMetric, hipRotationMetric, armExtensionMetric];

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
    final lm = _getLandmarks(landmarks);
    if (lm == null) return false;

    final bodyAngle = calculateAngleNormalized(firstPoint: lm['shoulder']!, midPoint: lm['hip']!, lastPoint: lm['ankle']!);
    final elbowAngle = calculateAngleNormalized(firstPoint: lm['shoulder']!, midPoint: lm['elbow']!, lastPoint: lm['wrist']!);

    // Cơ thể phải thẳng và tay đang gập ở Forearm
    return bodyAngle >= PlankConfig.BODY_ALIGNMENT_START_MIN && elbowAngle <= PlankConfig.ELBOW_FOREARM_MAX;
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

    final lm = _getLandmarks(smoothedLandmarks);
    if (lm == null) return;

    final shoulder = lm['shoulder']!;
    final hip = lm['hip']!;
    final ankle = lm['ankle']!;
    final elbow = lm['elbow']!;
    final wrist = lm['wrist']!;

    scaleFactor = calculateDistance(shoulder, hip);
    final bodyAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    final elbowAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);

    // GHI LOG TELEMETRY
    _telemetryLog.add({
      'timestamp': now,
      'time_elapsed': now - _exerciseStartTimeMs!,
      'state': plankState.name,
      'bodyAngle': double.parse(bodyAngle.toStringAsFixed(1)),
      'elbowAngle': double.parse(elbowAngle.toStringAsFixed(1)),
      'hipY': double.parse(hip.y.toStringAsFixed(1)),
      'visibility': lm.values.map((l) => l.likelihood).reduce((a, b) => a + b) / lm.length, // Avg confidence
    });

    final ctx = PlankRepContext(
      bodyAngle: bodyAngle,
      elbowAngle: elbowAngle,
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
    debugData['Elbow_Angle'] = elbowAngle.toStringAsFixed(1);
    debugData['Time_Left'] = ((PlankConfig.MAX_DURATION_MS - (now - _exerciseStartTimeMs!)) / 1000).toStringAsFixed(1);

    _updateStateMachine(elbowAngle, now);

    // Chạy Metrics
    for (var metric in _metrics) {
      metric.update(ctx);
      debugData.addAll(metric.debugData);
    }
  }

  void _updateStateMachine(double elbowAngle, int now) {
    switch (plankState) {
      case PlankState.forearm_plank:
        if (_pushingDebouncer.update(elbowAngle > PlankConfig.ELBOW_PUSHING_THRESHOLD)) {
          _transitionState(PlankState.pushing_up, now);
        }
        break;
      case PlankState.pushing_up:
        if (_highPlankDebouncer.update(elbowAngle > PlankConfig.ELBOW_HIGH_PLANK_MIN)) {
          _transitionState(PlankState.high_plank, now);
        }
        break;
      case PlankState.high_plank:
        if (_loweringDebouncer.update(elbowAngle < PlankConfig.ELBOW_LOWERING_THRESHOLD)) {
          _transitionState(PlankState.lowering, now);
        }
        break;
      case PlankState.lowering:
        if (_forearmDebouncer.update(elbowAngle < PlankConfig.ELBOW_FOREARM_MAX)) {
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
    
    for (var metric in _metrics) {
      if (metric.faults.isNotEmpty) isRepGood = false;
      metric.resetAndCountFault();
    }
    
    correctForm = isRepGood;
    logger.pushGoodRepCount();
  }

  @override
  bool requestStop() => repCount >= maxRep || _isTimeout;

  @override
  void onSetComplete() {
    logger.pushKey("timeout_triggered", _isTimeout);
    logger.pushKey("trunk_sagging_fails", trunkMetric.faultsCount);
    logger.pushKey("hip_rotation_fails", hipRotationMetric.faultsCount);
    logger.pushKey("arm_extension_fails", armExtensionMetric.faultsCount);
    
    // Đẩy toàn bộ Telemetry Log ra để dev debug, hoặc lưu vào file nội bộ
    // Ví dụ: khi repCount = 0 (tức là tập fail), dev có thể đọc cái bảng này để biết do góc nào bị sai.
    logger.pushKey("telemetry_data", _telemetryLog);
  }

  Map<String, PoseLandmark>? _getLandmarks(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    // Ưu tiên bên trái (hoặc tự động nhận diện bên rõ nhất tùy framework của bạn)
    final shoulder = landmarks[PoseLandmarkType.leftShoulder] ?? landmarks[PoseLandmarkType.rightShoulder];
    final hip = landmarks[PoseLandmarkType.leftHip] ?? landmarks[PoseLandmarkType.rightHip];
    final knee = landmarks[PoseLandmarkType.leftKnee] ?? landmarks[PoseLandmarkType.rightKnee];
    final ankle = landmarks[PoseLandmarkType.leftAnkle] ?? landmarks[PoseLandmarkType.rightAnkle];
    final elbow = landmarks[PoseLandmarkType.leftElbow] ?? landmarks[PoseLandmarkType.rightElbow];
    final wrist = landmarks[PoseLandmarkType.leftWrist] ?? landmarks[PoseLandmarkType.rightWrist];

    if (shoulder == null || hip == null || knee == null || ankle == null || elbow == null || wrist == null) return null;
    return {'shoulder': shoulder, 'hip': hip, 'knee': knee, 'ankle': ankle, 'elbow': elbow, 'wrist': wrist};
  }
}