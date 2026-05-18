// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../exercise_base.dart';
import 'metrics/plank_shoulder_tap_metric_base.dart';
import 'metrics/hip_rotation_metric.dart';
import 'metrics/trunk_alignment_metric.dart';
import 'metrics/clear_tap_metric.dart';
import 'metrics/tap_tempo_metric.dart';

class PlankShoulderTap extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'Plank Shoulder Tap';

  @override
  String get currentPhaseKey => tapState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (tapState) {
      case PlankTapState.base: return 'Chuẩn bị';
      case PlankTapState.lifting: return 'Đang nâng tay';
      case PlankTapState.tap: return 'Chạm vai';
      case PlankTapState.returning: return 'Hạ tay';
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    return null;
  }

  PlankTapState tapState = PlankTapState.base;
  PlankTapState previousState = PlankTapState.base;

  int? _exerciseStartTimeMs;
  bool _isTimeout = false;

  final HipRotationMetric rotationMetric = HipRotationMetric();
  final TrunkAlignmentMetric trunkMetric = TrunkAlignmentMetric();
  final ClearTapMetric tapMetric = ClearTapMetric();
  final TapTempoMetric tempoMetric = TapTempoMetric();

  late final List<PlankTapMetricBase> _metrics = [
    rotationMetric, trunkMetric, tapMetric, tempoMetric
  ];

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = _getLandmarks(landmarks);
    if (lm == null) return false;

    double trunkAngle = calculateAngleNormalized(firstPoint: lm['shoulder']!, midPoint: lm['hip']!, lastPoint: lm['ankle']!);

    debugData['Setup_Diagnostic'] = {
      'trunkAngle': trunkAngle.toStringAsFixed(1),
      'isTrunkStraight': trunkAngle >= PlankTapConfig.TRUNK_STRAIGHT_RANGE[0] && trunkAngle <= PlankTapConfig.TRUNK_STRAIGHT_RANGE[1],
    };

    if (trunkAngle < PlankTapConfig.TRUNK_STRAIGHT_RANGE[0] || trunkAngle > PlankTapConfig.TRUNK_STRAIGHT_RANGE[1]) return false;

    return true;
  }

  @override
  bool requestStop() {
    if (_exerciseStartTimeMs != null && (frameTimestampMs - _exerciseStartTimeMs!) > PlankTapConfig.MAX_DURATION_MS) {
      _isTimeout = true;
      return true;
    }
    return repCount >= PlankTapConfig.MAX_REP;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    _exerciseStartTimeMs ??= frameTimestampMs;
    final now = frameTimestampMs;

    final lm = _getLandmarks(landmarks);
    if (lm == null) return;

    // Sửa lỗi Null crash: Đảm bảo tồn tại đủ các điểm khớp cổ tay và vai trước khi tính toán
    if (!landmarks.containsKey(PoseLandmarkType.leftWrist) ||
        !landmarks.containsKey(PoseLandmarkType.rightShoulder) ||
        !landmarks.containsKey(PoseLandmarkType.rightWrist) ||
        !landmarks.containsKey(PoseLandmarkType.leftShoulder)) {
      return; 
    }

    scaleFactor = calculateDistance(lm['shoulder']!, lm['hip']!);
    if (scaleFactor == 0) scaleFactor = 1;

    double trunkAngle = calculateAngleNormalized(firstPoint: lm['shoulder']!, midPoint: lm['hip']!, lastPoint: lm['ankle']!);
    
    double distLtoR = calculateDistance(landmarks[PoseLandmarkType.leftWrist]!, landmarks[PoseLandmarkType.rightShoulder]!) / scaleFactor;
    double distRtoL = calculateDistance(landmarks[PoseLandmarkType.rightWrist]!, landmarks[PoseLandmarkType.leftShoulder]!) / scaleFactor;
    
    double activeWristShoulderDistNorm = min(distLtoR, distRtoL);

    debugData['Diagnostic_Table'] = {
      'State': tapState.name,
      'Time_s': ((now - _exerciseStartTimeMs!) / 1000).toStringAsFixed(1),
      'TrunkAngle': trunkAngle.toStringAsFixed(1),
      'Hip_Y': lm['hip']!.y.toStringAsFixed(1),
      'ActiveDistNorm': activeWristShoulderDistNorm.toStringAsFixed(2),
    };

    final ctx = RepContext(
      state: tapState, frameTimestamp: now, scaleFactor: scaleFactor,
      trunkAngle: trunkAngle, hipY: lm['hip']!.y, 
      activeWristShoulderDistNorm: activeWristShoulderDistNorm,
      resultIssues: resultIssues,
    );

    _updateStateMachine(ctx);

    for (final metric in _metrics) {
      metric.update(ctx);
      debugData.addAll(metric.debugData);
    }
  }

  void _updateStateMachine(RepContext ctx) {
    double dist = ctx.activeWristShoulderDistNorm;

    if (tapState == PlankTapState.base && dist < PlankTapConfig.LIFT_START_THRESHOLD) {
      _transitionState(PlankTapState.lifting, ctx.frameTimestamp);
    } 
    else if (tapState == PlankTapState.lifting && dist <= PlankTapConfig.TAP_DISTANCE_THRESHOLD) {
      _transitionState(PlankTapState.tap, ctx.frameTimestamp);
    }
    // Sửa lỗi Rep bị tính dù bỏ qua state TAP: Chỉ sang lowering khi đang ở tap
    else if (tapState == PlankTapState.tap && dist > PlankTapConfig.TAP_DISTANCE_THRESHOLD + 0.1) {
      _transitionState(PlankTapState.returning, ctx.frameTimestamp);
    }
    // Cập nhật lại logic hoàn thành rep
    else if ((tapState == PlankTapState.returning || tapState == PlankTapState.lifting) && dist >= PlankTapConfig.LIFT_START_THRESHOLD) {
      if (tapState == PlankTapState.lifting) {
        // Nâng tay nhưng hạ ngay mà chưa chạm tới vai (Lỗi Missed Tap)
        _transitionState(PlankTapState.returning, ctx.frameTimestamp);
      }
      _completeRep(ctx);
    }
  }

  void _transitionState(PlankTapState newState, int timestampMs) {
    if (newState == tapState) return;
    previousState = tapState;
    tapState = newState;
    for (final metric in _metrics) metric.onStateTransition(previousState, newState, timestampMs);
  }

  void _completeRep(RepContext ctx) {
    repCount++;
    for (final metric in _metrics) metric.evaluateRepEnd(ctx);

    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) allFaults.addAll(metric.faults);
    correctForm = !allFaults.any((f) => f.affectsForm);

    _transitionState(PlankTapState.base, ctx.frameTimestamp);
    for (final metric in _metrics) metric.resetAndCountFault();
  }

  Map<String, PoseLandmark>? _getLandmarks(Map<PoseLandmarkType, PoseLandmark> lm) {
    // Sửa lỗi Null crash: Validate trước các điểm
    if (!lm.containsKey(PoseLandmarkType.leftShoulder) ||
        !lm.containsKey(PoseLandmarkType.leftHip) ||
        !lm.containsKey(PoseLandmarkType.leftAnkle)) {
      return null;
    }
    return {
      'shoulder': lm[PoseLandmarkType.leftShoulder]!,
      'hip': lm[PoseLandmarkType.leftHip]!,
      'ankle': lm[PoseLandmarkType.leftAnkle]!,
    };
  }

  @override
  void onSetComplete() {
    logger.pushKey("timeout", _isTimeout);
    logger.pushKey("rotation_fails", rotationMetric.faultsCount);
    logger.pushKey("alignment_fails", trunkMetric.faultsCount);
    logger.pushKey("tap_fails", tapMetric.faultsCount);
    logger.pushKey("tempo_fails", tempoMetric.faultsCount); // Sửa lỗi thiếu log tempo_fails
    logger.pushGoodRepCount();
  }
}