// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/debouncer.dart';
import '../exercise_base.dart';
import 'metrics/bear_plank_metric_base.dart';
import 'metrics/knee_hover_metric.dart';
import 'metrics/flat_back_metric.dart';
import 'metrics/weight_distribution_metric.dart';

class BearPlank extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  BearState bearState = BearState.setup;
  BearState previousBearState = BearState.setup;
  
  int? _exerciseStartTimeMs;
  int _totalHoverTimeMs = 0; // Tổng thời gian giữ form chuẩn
  int? _lastFrameTimeMs;
  bool _isTimeout = false;

  // Telemetry Log
  final List<Map<String, dynamic>> _telemetryLog = [];

  // Metrics
  final KneeHoverMetric kneeMetric = KneeHoverMetric();
  final FlatBackMetric backMetric = FlatBackMetric();
  final WeightDistributionMetric weightMetric = WeightDistributionMetric();
  late final List<BearMetricBase> _metrics = [kneeMetric, backMetric, weightMetric];

  // Debouncers
  final Debouncer _hoverDebouncer = Debouncer(requiredFrames: 3);
  final Debouncer _fatigueDebouncer = Debouncer(requiredFrames: 5);

  @override
  String get exerciseName => 'Bear Plank';

  @override
  String get currentPhaseKey => bearState.name;

  @override
  String get currentPhaseLabel {
    switch (bearState) {
      case BearState.setup: return 'Setup (Vào vị trí)';
      case BearState.hovering: return 'Giữ tĩnh (Hold!)';
      case BearState.fatiguing: return 'Mất form/Hạ gối';
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return "⚠️ Yêu cầu quay ngang (Side) để đo độ phẳng của lưng và độ cao đầu gối.";
    }
    return null;
  }

  // Điều kiện Setup chuẩn: Tay thẳng, đùi vuông góc, gối chạm hoặc sát đất
  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = _getLandmarks(landmarks);
    if (lm == null) return false;

    final kneeAngle = calculateAngleNormalized(firstPoint: lm['hip']!, midPoint: lm['knee']!, lastPoint: lm['ankle']!);
    // Đầu gối vuông góc 70-110 độ. Nếu lưng thẳng nữa thì mới cho bắt đầu.
    return kneeAngle >= BearConfig.KNEE_ANGLE_SETUP_MIN && kneeAngle <= BearConfig.KNEE_ANGLE_SETUP_MAX;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final now = frameTimestampMs;
    _exerciseStartTimeMs ??= now;
    final int dt = _lastFrameTimeMs != null ? (now - _lastFrameTimeMs!) : 0;
    _lastFrameTimeMs = now;

    if (now - _exerciseStartTimeMs! > BearConfig.MAX_SESSION_MS || _totalHoverTimeMs >= BearConfig.TARGET_HOVER_MS) {
      _isTimeout = (now - _exerciseStartTimeMs! > BearConfig.MAX_SESSION_MS);
      requestStop();
      return;
    }

    final lm = _getLandmarks(smoothedLandmarks);
    if (lm == null) return;

    scaleFactor = calculateDistance(lm['shoulder']!, lm['hip']!);
    if (scaleFactor == 0) scaleFactor = 1;

    // Tính toán hình học
    final kneeHeightOffset = lm['ankle']!.y - lm['knee']!.y; // Y hướng xuống
    final kneeAngle = calculateAngleNormalized(firstPoint: lm['hip']!, midPoint: lm['knee']!, lastPoint: lm['ankle']!);
    final backYDifference = (lm['shoulder']!.y - lm['hip']!.y).abs();
    final wristXDifference = (lm['shoulder']!.x - lm['wrist']!.x).abs();

    // Chuẩn hóa
    final normKneeHeight = kneeHeightOffset / scaleFactor;
    final normBackY = backYDifference / scaleFactor;
    final normWristX = wristXDifference / scaleFactor;

    // GHI LOG TELEMETRY
    _telemetryLog.add({
      'timestamp': now,
      'state': bearState.name,
      'normKneeHeight': double.parse(normKneeHeight.toStringAsFixed(3)),
      'kneeAngle': double.parse(kneeAngle.toStringAsFixed(1)),
      'normBackY': double.parse(normBackY.toStringAsFixed(3)),
      'normWristX': double.parse(normWristX.toStringAsFixed(3)),
    });

    final ctx = BearRepContext(
      kneeHeightOffset: normKneeHeight,
      kneeAngle: kneeAngle,
      backYDifference: normBackY,
      wristXDifference: normWristX,
      scaleFactor: scaleFactor,
      currentState: bearState,
      frameTimestampMs: now,
      resultIssues: resultIssues,
    );

    // Cập nhật State Machine
    _updateStateMachine(ctx, now, dt);

    // Cập nhật Metrics
    for (var metric in _metrics) {
      metric.update(ctx);
      debugData.addAll(metric.debugData);
    }
    
    // UI Data
    debugData['State'] = bearState.name;
    debugData['Hover_Time'] = '${(_totalHoverTimeMs / 1000).toStringAsFixed(1)}s / ${BearConfig.TARGET_HOVER_MS/1000}s';
  }

  void _updateStateMachine(BearRepContext ctx, int now, int dt) {
    bool isHoveringForm = ctx.kneeHeightOffset > BearConfig.KNEE_HOVER_MIN && 
                          ctx.kneeHeightOffset <= BearConfig.KNEE_HOVER_MAX &&
                          ctx.kneeAngle < BearConfig.KNEE_ANGLE_BUTT_UP;
                          
    bool isFatiguedForm = ctx.kneeHeightOffset <= 0 || ctx.kneeAngle >= BearConfig.KNEE_ANGLE_BUTT_UP;

    switch (bearState) {
      case BearState.setup:
        if (_hoverDebouncer.update(isHoveringForm)) {
          _transitionState(BearState.hovering, now);
        }
        break;
      case BearState.hovering:
        _totalHoverTimeMs += dt; // Cộng dồn thời gian giữ đúng form
        
        if (_fatigueDebouncer.update(isFatiguedForm)) {
          _transitionState(BearState.fatiguing, now);
        }
        break;
      case BearState.fatiguing:
        if (_hoverDebouncer.update(isHoveringForm)) {
          _transitionState(BearState.hovering, now);
        }
        break;
    }
  }

  void _transitionState(BearState newState, int now) {
    previousBearState = bearState;
    bearState = newState;
    for (var metric in _metrics) {
      metric.onStateTransition(previousBearState, newState, now);
    }
  }

  @override
  bool requestStop() => _totalHoverTimeMs >= BearConfig.TARGET_HOVER_MS || _isTimeout;

  @override
  void onSetComplete() {
    // Đẩy dữ liệu tổng kết
    logger.pushKey("total_hover_time_ms", _totalHoverTimeMs);
    logger.pushKey("timeout_triggered", _isTimeout);
    logger.pushKey("knee_fails", kneeMetric.faultsCount);
    logger.pushKey("back_fails", backMetric.faultsCount);
    logger.pushKey("weight_fails", weightMetric.faultsCount);
    logger.pushKey("telemetry_data", _telemetryLog); // Chìa khóa debug
    
    // Set kết quả (Form tốt nếu giữ trên 80% thời gian mục tiêu)
    correctForm = _totalHoverTimeMs >= (BearConfig.TARGET_HOVER_MS * 0.8);
    logger.pushGoodRepCount();
  }

  Map<String, PoseLandmark>? _getLandmarks(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final shoulder = landmarks[PoseLandmarkType.leftShoulder] ?? landmarks[PoseLandmarkType.rightShoulder];
    final hip = landmarks[PoseLandmarkType.leftHip] ?? landmarks[PoseLandmarkType.rightHip];
    final knee = landmarks[PoseLandmarkType.leftKnee] ?? landmarks[PoseLandmarkType.rightKnee];
    final ankle = landmarks[PoseLandmarkType.leftAnkle] ?? landmarks[PoseLandmarkType.rightAnkle];
    final wrist = landmarks[PoseLandmarkType.leftWrist] ?? landmarks[PoseLandmarkType.rightWrist];

    if (shoulder == null || hip == null || knee == null || ankle == null || wrist == null) return null;
    return {'shoulder': shoulder, 'hip': hip, 'knee': knee, 'ankle': ankle, 'wrist': wrist};
  }
}
