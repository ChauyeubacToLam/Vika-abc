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
    
    // 1. Chống lỗi quỳ gối / co gối (Kiểm tra cả 2 chân nếu có hiển thị)
    double leftKneeAngle = 180.0;
    double rightKneeAngle = 180.0;
    
    if (landmarks.containsKey(PoseLandmarkType.leftHip) && landmarks.containsKey(PoseLandmarkType.leftKnee) && landmarks.containsKey(PoseLandmarkType.leftAnkle)) {
      leftKneeAngle = calculateAngleNormalized(firstPoint: landmarks[PoseLandmarkType.leftHip]!, midPoint: landmarks[PoseLandmarkType.leftKnee]!, lastPoint: landmarks[PoseLandmarkType.leftAnkle]!);
    }
    if (landmarks.containsKey(PoseLandmarkType.rightHip) && landmarks.containsKey(PoseLandmarkType.rightKnee) && landmarks.containsKey(PoseLandmarkType.rightAnkle)) {
      rightKneeAngle = calculateAngleNormalized(firstPoint: landmarks[PoseLandmarkType.rightHip]!, midPoint: landmarks[PoseLandmarkType.rightKnee]!, lastPoint: landmarks[PoseLandmarkType.rightAnkle]!);
    }

    // 2. Chống lỗi Wall Push-up (Đứng đẩy tường) - Cơ thể phải nằm ngang
    double dx = (lm['shoulder']!.x - lm['ankle']!.x).abs();
    double dy = (lm['shoulder']!.y - lm['ankle']!.y).abs();
    bool isHorizontal = dx > dy * 1.2;

    debugData['Setup_Diagnostic'] = {
      'trunkAngle': trunkAngle.toStringAsFixed(1),
      'leftKneeAngle': leftKneeAngle.toStringAsFixed(1),
      'rightKneeAngle': rightKneeAngle.toStringAsFixed(1),
      'isHorizontal': isHorizontal,
      'isTrunkStraight': trunkAngle >= PlankTapConfig.TRUNK_STRAIGHT_RANGE[0] && trunkAngle <= PlankTapConfig.TRUNK_STRAIGHT_RANGE[1],
    };

    if (trunkAngle < PlankTapConfig.TRUNK_STRAIGHT_RANGE[0] || trunkAngle > PlankTapConfig.TRUNK_STRAIGHT_RANGE[1]) return false;
    if (leftKneeAngle < 150.0 || rightKneeAngle < 150.0) return false; // Chặn gập/quỳ gối
    if (!isHorizontal) return false; // Chặn đứng đẩy tường

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
    
    // 3. XỬ LÝ LỖI CHE CAMERA: Ép reset State về Base nếu mất các khớp nối trọng yếu
    if (lm == null ||
        !landmarks.containsKey(PoseLandmarkType.leftWrist) ||
        !landmarks.containsKey(PoseLandmarkType.rightShoulder) ||
        !landmarks.containsKey(PoseLandmarkType.rightWrist) ||
        !landmarks.containsKey(PoseLandmarkType.leftShoulder)) {
      
      if (tapState != PlankTapState.base) {
        _transitionState(PlankTapState.base, now);
        for (final metric in _metrics) metric.reset();
      }
      return; 
    }

    scaleFactor = calculateDistance(lm['shoulder']!, lm['hip']!);
    if (scaleFactor == 0) scaleFactor = 1;

    double trunkAngle = calculateAngleNormalized(firstPoint: lm['shoulder']!, midPoint: lm['hip']!, lastPoint: lm['ankle']!);
    
    // Quãng đường cổ tay -> vai ĐỐI DIỆN
    double distLtoR = calculateDistance(landmarks[PoseLandmarkType.leftWrist]!, landmarks[PoseLandmarkType.rightShoulder]!) / scaleFactor;
    double distRtoL = calculateDistance(landmarks[PoseLandmarkType.rightWrist]!, landmarks[PoseLandmarkType.leftShoulder]!) / scaleFactor;
    
    double activeWristShoulderDistNorm = min(distLtoR, distRtoL);

    // Tính trung bình hông hai bên để Anti-Rotation quét nhạy hơn
    double hipY = lm['hip']!.y;
    if (landmarks.containsKey(PoseLandmarkType.rightHip)) {
      hipY = (landmarks[PoseLandmarkType.leftHip]!.y + landmarks[PoseLandmarkType.rightHip]!.y) / 2;
    }

    debugData['Diagnostic_Table'] = {
      'State': tapState.name,
      'Time_s': ((now - _exerciseStartTimeMs!) / 1000).toStringAsFixed(1),
      'TrunkAngle': trunkAngle.toStringAsFixed(1),
      'Hip_Y': hipY.toStringAsFixed(1),
      'ActiveDistNorm': activeWristShoulderDistNorm.toStringAsFixed(2),
    };

    final ctx = RepContext(
      state: tapState, frameTimestamp: now, scaleFactor: scaleFactor,
      trunkAngle: trunkAngle, hipY: hipY, 
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
    else if (tapState == PlankTapState.lifting) {
      if (dist <= PlankTapConfig.TAP_DISTANCE_THRESHOLD) {
        _transitionState(PlankTapState.tap, ctx.frameTimestamp);
      } 
      // 4. XỬ LÝ CHẠM CÙNG TAY HOẶC HẠ TAY SỚM:
      // Tay đã nhấc, nhưng không thể chạm tới vai chéo mà vội hạ xuống lại mặt đất -> HỦY REP
      else if (dist >= PlankTapConfig.LIFT_START_THRESHOLD) {
        _transitionState(PlankTapState.base, ctx.frameTimestamp);
        for (final metric in _metrics) metric.reset();
      }
    }
    else if (tapState == PlankTapState.tap && dist > PlankTapConfig.TAP_DISTANCE_THRESHOLD + 0.1) {
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
    logger.pushKey("tempo_fails", tempoMetric.faultsCount);
    logger.pushGoodRepCount();
  }
}