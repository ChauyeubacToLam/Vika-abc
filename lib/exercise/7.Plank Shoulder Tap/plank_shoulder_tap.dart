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
    return null; // No specific safety check for this exercise yet.
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

    scaleFactor = calculateDistance(lm['shoulder']!, lm['hip']!);
    if (scaleFactor == 0) scaleFactor = 1;

    double trunkAngle = calculateAngleNormalized(firstPoint: lm['shoulder']!, midPoint: lm['hip']!, lastPoint: lm['ankle']!);
    
    // Tìm khoảng cách nhỏ nhất giữa Cổ tay L - Vai R và Cổ tay R - Vai L để biết tay nào đang nhấc
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
    // Chuyển sang lowering (returning) khi khoảng cách bắt đầu xa ra
    else if ((tapState == PlankTapState.tap || tapState == PlankTapState.lifting) && dist > PlankTapConfig.TAP_DISTANCE_THRESHOLD + 0.1) {
      _transitionState(PlankTapState.returning, ctx.frameTimestamp);
    }
    else if (tapState == PlankTapState.returning && dist >= PlankTapConfig.LIFT_START_THRESHOLD) {
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
    return {
      'shoulder': lm[PoseLandmarkType.leftShoulder]!,
      'hip': lm[PoseLandmarkType.leftHip]!,
      'ankle': lm[PoseLandmarkType.leftAnkle]!,
      // Mặc định lấy side chuẩn, cổ tay tính chéo ở trên
    };
  }

  @override
  void onSetComplete() {
    logger.pushKey("timeout", _isTimeout);
    logger.pushKey("rotation_fails", rotationMetric.faultsCount);
    logger.pushKey("alignment_fails", trunkMetric.faultsCount);
    logger.pushKey("tap_fails", tapMetric.faultsCount);
    logger.pushGoodRepCount();
  }
}