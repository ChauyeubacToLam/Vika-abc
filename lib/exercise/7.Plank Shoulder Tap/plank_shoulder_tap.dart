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

enum TappingSide { none, leftHandToRight, rightHandToLeft }

class PlankShoulderTap extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
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
      case PlankTapState.base:
        return 'Chu';
      case PlankTapState.lifting:
        return ' ang n ng tay';
      case PlankTapState.tap:
        return 'Ch m vai';
      case PlankTapState.returning:
        return 'H  tay';
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    return null;
  }

  PlankTapState tapState = PlankTapState.base;
  PlankTapState previousState = PlankTapState.base;
  TappingSide lastTappedSide = TappingSide.none;
  TappingSide currentTappingSide = TappingSide.none;
  int? _exerciseStartTimeMs;
  bool _isTimeout = false;

  final HipRotationMetric rotationMetric = HipRotationMetric();
  final TrunkAlignmentMetric trunkMetric = TrunkAlignmentMetric();
  final ClearTapMetric tapMetric = ClearTapMetric();
  final TapTempoMetric tempoMetric = TapTempoMetric();

  late final List<PlankTapMetricBase> _metrics = [
    rotationMetric,
    trunkMetric,
    tapMetric,
    tempoMetric
  ];

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = _getLandmarks(landmarks);
    if (lm == null) return false;

    double trunkAngle = calculateAngleNormalized(
        firstPoint: lm['shoulder']!,
        midPoint: lm['hip']!,
        lastPoint: lm['ankle']!);

    // 1. Ch ng l i qu i / co g i (Ki m tra c  2 ch n th
    double leftKneeAngle = 180.0;
    double rightKneeAngle = 180.0;

    if (landmarks.containsKey(PoseLandmarkType.leftHip) &&
        landmarks.containsKey(PoseLandmarkType.leftKnee) &&
        landmarks.containsKey(PoseLandmarkType.leftAnkle)) {
      leftKneeAngle = calculateAngleNormalized(
          firstPoint: landmarks[PoseLandmarkType.leftHip]!,
          midPoint: landmarks[PoseLandmarkType.leftKnee]!,
          lastPoint: landmarks[PoseLandmarkType.leftAnkle]!);
    }
    if (landmarks.containsKey(PoseLandmarkType.rightHip) &&
        landmarks.containsKey(PoseLandmarkType.rightKnee) &&
        landmarks.containsKey(PoseLandmarkType.rightAnkle)) {
      rightKneeAngle = calculateAngleNormalized(
          firstPoint: landmarks[PoseLandmarkType.rightHip]!,
          midPoint: landmarks[PoseLandmarkType.rightKnee]!,
          lastPoint: landmarks[PoseLandmarkType.rightAnkle]!);
    }

    // 2. Ch ng l i Wall Push-up ( ng) - C m ngang
    double dx = (lm['shoulder']!.x - lm['ankle']!.x).abs();
    double dy = (lm['shoulder']!.y - lm['ankle']!.y).abs();
    bool isHorizontal = dx > dy * 1.2;

    debugData['Setup_Diagnostic'] = {
      'trunkAngle': trunkAngle.toStringAsFixed(1),
      'leftKneeAngle': leftKneeAngle.toStringAsFixed(1),
      'rightKneeAngle': rightKneeAngle.toStringAsFixed(1),
      'isHorizontal': isHorizontal,
      'isTrunkStraight': trunkAngle >= PlankTapConfig.TRUNK_STRAIGHT_RANGE[0] &&
          trunkAngle <= PlankTapConfig.TRUNK_STRAIGHT_RANGE[1],
    };

    if (trunkAngle < PlankTapConfig.TRUNK_STRAIGHT_RANGE[0] ||
        trunkAngle > PlankTapConfig.TRUNK_STRAIGHT_RANGE[1]) return false;
    if (leftKneeAngle < 150.0 || rightKneeAngle < 150.0)
      return false; // Ch p/qu
    if (!isHorizontal) return false; // Ch
    return true;
  }

  @override
  bool requestStop() {
    if (_exerciseStartTimeMs != null &&
        (frameTimestampMs - _exerciseStartTimeMs!) >
            PlankTapConfig.MAX_DURATION_MS) {
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

    // Nếu mất hẳn thân người thì bỏ qua frame, KHÔNG reset state đang tập
    if (lm == null) return;

    scaleFactor = calculateDistance(lm['shoulder']!, lm['hip']!);
    if (scaleFactor == 0) scaleFactor = 1;
    double trunkAngle = calculateAngleNormalized(
        firstPoint: lm['shoulder']!,
        midPoint: lm['hip']!,
        lastPoint: lm['ankle']!);

    // TÍNH KHOẢNG CÁCH LUÂN PHIÊN ĐỘC LẬP (Sử dụng vai chính để tránh mất điểm mốc ở góc nghiêng)
    double distLtoR = double.infinity;
    double distRtoL = double.infinity;

    PoseLandmark targetShoulder = lm['shoulder']!;

    if (landmarks.containsKey(PoseLandmarkType.leftWrist)) {
      distLtoR = calculateDistance(
              landmarks[PoseLandmarkType.leftWrist]!, targetShoulder) /
          scaleFactor;
    }
    if (landmarks.containsKey(PoseLandmarkType.rightWrist)) {
      distRtoL = calculateDistance(
              landmarks[PoseLandmarkType.rightWrist]!, targetShoulder) /
          scaleFactor;
    }

    // Nếu cả 2 tay đều bị mất tín hiệu thì bỏ qua frame
    if (distLtoR == double.infinity && distRtoL == double.infinity) return;

    double activeWristShoulderDistNorm = double.infinity;

    if (tapState == PlankTapState.base) {
      // Trong trạng thái chuẩn bị, ta xem tay nào đang được nhấc lên (tiến gần vai đối diện)
      if (distLtoR < PlankTapConfig.LIFT_START_THRESHOLD) {
        currentTappingSide = TappingSide.leftHandToRight;
        activeWristShoulderDistNorm = distLtoR;
      } else if (distRtoL < PlankTapConfig.LIFT_START_THRESHOLD) {
        currentTappingSide = TappingSide.rightHandToLeft;
        activeWristShoulderDistNorm = distRtoL;
      } else {
        // Cả 2 tay đang ở dưới đất, lấy khoảng cách nhỏ hơn làm chuẩn tạm thời
        activeWristShoulderDistNorm = min(distLtoR, distRtoL);
        currentTappingSide = TappingSide.none;
      }
    } else {
      // Đang trong chu trình tập, chỉ theo dõi tay đang thực hiện
      activeWristShoulderDistNorm =
          currentTappingSide == TappingSide.leftHandToRight
              ? distLtoR
              : distRtoL;
      // Nếu tay đang thực hiện bị mất tín hiệu tạm thời, bỏ qua frame
      if (activeWristShoulderDistNorm == double.infinity) return;
    }

    double hipY = lm['hip']!.y;
    if (landmarks.containsKey(PoseLandmarkType.rightHip) &&
        landmarks.containsKey(PoseLandmarkType.leftHip)) {
      hipY = (landmarks[PoseLandmarkType.leftHip]!.y +
              landmarks[PoseLandmarkType.rightHip]!.y) /
          2;
    }

    debugData['Diagnostic_Table'] = {
      'State': tapState.name,
      'Time_s': ((now - _exerciseStartTimeMs!) / 1000).toStringAsFixed(1),
      'TrunkAngle': trunkAngle.toStringAsFixed(1),
      'Hip_Y': hipY.toStringAsFixed(1),
      'ActiveDistNorm': activeWristShoulderDistNorm.toStringAsFixed(2),
      'Side': currentTappingSide.name,
    };

    final ctx = RepContext(
      state: tapState,
      frameTimestamp: now,
      scaleFactor: scaleFactor,
      trunkAngle: trunkAngle,
      hipY: hipY,
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

    if (tapState == PlankTapState.base &&
        dist < PlankTapConfig.LIFT_START_THRESHOLD) {
      if (lastTappedSide == TappingSide.none ||
          currentTappingSide != lastTappedSide) {
        _transitionState(PlankTapState.lifting, ctx.frameTimestamp);
      } else {
        ctx.resultIssues
            .addInstruction('Base', 'WrongSide', 'Hãy đổi tay cho rep này!');
      }
    } else if (tapState == PlankTapState.lifting) {
      if (dist <= PlankTapConfig.TAP_DISTANCE_THRESHOLD) {
        _transitionState(PlankTapState.tap, ctx.frameTimestamp);
      }
      // Tay nhấc nhưng vội hạ xuống lại mặt đất -> HỦY REP
      else if (dist >= PlankTapConfig.LIFT_START_THRESHOLD) {
        _transitionState(PlankTapState.base, ctx.frameTimestamp);
        currentTappingSide = TappingSide.none;
        for (final metric in _metrics) metric.reset();
      }
    } else if (tapState == PlankTapState.tap &&
        dist > PlankTapConfig.TAP_DISTANCE_THRESHOLD + 0.1) {
      _transitionState(PlankTapState.returning, ctx.frameTimestamp);
    } else if (tapState == PlankTapState.returning &&
        dist >= PlankTapConfig.LIFT_START_THRESHOLD) {
      _completeRep(ctx);
    }
  }

  void _transitionState(PlankTapState newState, int timestampMs) {
    if (newState == tapState) return;
    previousState = tapState;
    tapState = newState;
    for (final metric in _metrics)
      metric.onStateTransition(previousState, newState, timestampMs);
  }

  void _completeRep(RepContext ctx) {
    repCount++;
    for (final metric in _metrics) metric.evaluateRepEnd(ctx);

    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) allFaults.addAll(metric.faults);

    correctForm = !allFaults.any((f) => f.affectsForm);

    // Lưu lại tay vừa chạm để bắt buộc đổi tay ở rep sau
    lastTappedSide = currentTappingSide;

    _transitionState(PlankTapState.base, ctx.frameTimestamp);
    for (final metric in _metrics) metric.resetAndCountFault();
  }

  Map<String, PoseLandmark>? _getLandmarks(
      Map<PoseLandmarkType, PoseLandmark> lm) {
    bool hasLeft = lm.containsKey(PoseLandmarkType.leftShoulder) &&
        lm.containsKey(PoseLandmarkType.leftHip) &&
        lm.containsKey(PoseLandmarkType.leftAnkle);

    bool hasRight = lm.containsKey(PoseLandmarkType.rightShoulder) &&
        lm.containsKey(PoseLandmarkType.rightHip) &&
        lm.containsKey(PoseLandmarkType.rightAnkle);

    if (!hasLeft && !hasRight) return null;

    // Ưu tiên bên trái, nếu mất bên trái thì dùng tạm bên phải làm mốc đo cơ thể
    if (hasLeft) {
      return {
        'shoulder': lm[PoseLandmarkType.leftShoulder]!,
        'hip': lm[PoseLandmarkType.leftHip]!,
        'ankle': lm[PoseLandmarkType.leftAnkle]!,
      };
    } else {
      return {
        'shoulder': lm[PoseLandmarkType.rightShoulder]!,
        'hip': lm[PoseLandmarkType.rightHip]!,
        'ankle': lm[PoseLandmarkType.rightAnkle]!,
      };
    }
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
