// ignore_for_file: curly_braces_in_flow_control_structures
import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';
import 'metrics/plank_shoulder_tap_metric_base.dart';
import 'metrics/hip_rotation_metric.dart';
import 'metrics/trunk_alignment_metric.dart';
import 'metrics/clear_tap_metric.dart';
import 'metrics/tap_tempo_metric.dart';

enum TappingSide { none, leftHandToRight, rightHandToLeft }

class PlankShoulderTap extends ExerciseBase {
  PlankShoulderTap({this.maxRep = PlankTapConfig.MAX_REP});

  final int maxRep;

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
        return 'Chuẩn bị';
      case PlankTapState.lifting:
        return 'Đang nâng tay';
      case PlankTapState.tap:
        return 'Chạm vai';
      case PlankTapState.returning:
        return 'Hạ tay';
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final guidance = _cameraAngleGuidance();
    if (guidance != null) return guidance;
    if (_getLandmarks(smoothedLandmarks) == null) {
      return 'Giữ vai, hông, cổ chân và cổ tay phía camera rõ trong khung hình.';
    }
    return null;
  }

  PlankTapState tapState = PlankTapState.base;
  PlankTapState previousState = PlankTapState.base;
  TappingSide lastTappedSide = TappingSide.none;
  TappingSide currentTappingSide = TappingSide.none;
  int? _exerciseStartTimeMs;
  bool _isTimeout = false;
  int _rejectedTapAttempts = 0;
  double? _baselineWristY;

  final HipRotationMetric rotationMetric = HipRotationMetric();
  final TrunkAlignmentMetric trunkMetric = TrunkAlignmentMetric();
  final ClearTapMetric tapMetric = ClearTapMetric();
  final TapTempoMetric tempoMetric = TapTempoMetric();

  late final List<PlankTapMetricBase> _metrics = [
    rotationMetric,
    trunkMetric,
    tapMetric,
    tempoMetric,
  ];

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final angleGuidance = _cameraAngleGuidance();
    if (angleGuidance != null) {
      resultIssues.feedback['System'] = angleGuidance;
      return false;
    }

    final lm = _getLandmarks(landmarks);
    if (lm == null) return false;

    final trunkAngle = calculateAngleNormalized(
      firstPoint: lm['shoulder']!,
      midPoint: lm['hip']!,
      lastPoint: lm['ankle']!,
    );

    double leftKneeAngle = 180.0;
    double rightKneeAngle = 180.0;
    if (_hasAll(landmarks, const [
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.leftAnkle,
    ])) {
      leftKneeAngle = calculateAngleNormalized(
        firstPoint: landmarks[PoseLandmarkType.leftHip]!,
        midPoint: landmarks[PoseLandmarkType.leftKnee]!,
        lastPoint: landmarks[PoseLandmarkType.leftAnkle]!,
      );
    }
    if (_hasAll(landmarks, const [
      PoseLandmarkType.rightHip,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.rightAnkle,
    ])) {
      rightKneeAngle = calculateAngleNormalized(
        firstPoint: landmarks[PoseLandmarkType.rightHip]!,
        midPoint: landmarks[PoseLandmarkType.rightKnee]!,
        lastPoint: landmarks[PoseLandmarkType.rightAnkle]!,
      );
    }

    final dx = (lm['shoulder']!.x - lm['ankle']!.x).abs();
    final dy = (lm['shoulder']!.y - lm['ankle']!.y).abs();
    final isHorizontal = dx > dy * 1.2;
    final trunkStraight =
        trunkAngle >= PlankTapConfig.TRUNK_STRAIGHT_RANGE[0] &&
            trunkAngle <= PlankTapConfig.TRUNK_STRAIGHT_RANGE[1];

    debugData['PlankTapSetup'] = {
      'cameraFacing': cameraFacing.name,
      'frontFacingRatio': frontFacingRatio.toStringAsFixed(2),
      'trackedSide': _preferredIsRight ? 'right' : 'left',
      'trunkAngle': trunkAngle.toStringAsFixed(1),
      'leftKneeAngle': leftKneeAngle.toStringAsFixed(1),
      'rightKneeAngle': rightKneeAngle.toStringAsFixed(1),
      'isHorizontal': isHorizontal,
      'trunkStraight': trunkStraight,
    };

    if (!trunkStraight) return false;
    if (leftKneeAngle < 150.0 || rightKneeAngle < 150.0) return false;
    if (!isHorizontal) return false;
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
    return repCount >= maxRep;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    _exerciseStartTimeMs ??= frameTimestampMs;
    final now = frameTimestampMs;
    final angleGuidance = _cameraAngleGuidance();
    if (angleGuidance != null) {
      resultIssues.feedback['System'] = angleGuidance;
      return;
    }

    final lm = _getLandmarks(landmarks);
    if (lm == null) return;

    scaleFactor = calculateDistance(lm['shoulder']!, lm['hip']!);
    if (scaleFactor <= 1e-6) return;

    final trunkAngle = calculateAngleNormalized(
      firstPoint: lm['shoulder']!,
      midPoint: lm['hip']!,
      lastPoint: lm['ankle']!,
    );
    final wrist = lm['wrist']!;
    final wristShoulderDist =
        calculateDistance(wrist, lm['shoulder']!) / scaleFactor;

    if (tapState == PlankTapState.base &&
        (_baselineWristY == null ||
            (_wristLiftNorm(wrist.y) <= PlankTapConfig.WRIST_RETURN_THRESHOLD &&
                wristShoulderDist >
                    PlankTapConfig.TAP_DISTANCE_THRESHOLD + 0.12))) {
      _baselineWristY = wrist.y;
    }

    final wristLiftNorm = _wristLiftNorm(wrist.y);
    currentTappingSide = _preferredIsRight
        ? TappingSide.rightHandToLeft
        : TappingSide.leftHandToRight;

    double hipY = lm['hip']!.y;
    double? hipWidthXNorm;
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    if (leftHip != null && rightHip != null) {
      hipY = (leftHip.y + rightHip.y) / 2;
      hipWidthXNorm = (leftHip.x - rightHip.x).abs() / scaleFactor;
    }

    debugData['PlankTapDebug'] = {
      'state': tapState.name,
      'cameraFacing': cameraFacing.name,
      'frontFacingRatio': frontFacingRatio.toStringAsFixed(2),
      'trackedHand': currentTappingSide.name,
      'timeSeconds': ((now - _exerciseStartTimeMs!) / 1000).toStringAsFixed(1),
      'scaleFactor': scaleFactor.toStringAsFixed(2),
      'trunkAngle': trunkAngle.toStringAsFixed(1),
      'hipY': hipY.toStringAsFixed(1),
      'hipWidthXNorm': hipWidthXNorm?.toStringAsFixed(2),
      'wristShoulderDistNorm': wristShoulderDist.toStringAsFixed(2),
      'wristLiftNorm': wristLiftNorm.toStringAsFixed(2),
      'repCount': repCount,
      'rejectedTapAttempts': _rejectedTapAttempts,
    };

    final ctx = RepContext(
      state: tapState,
      frameTimestamp: now,
      scaleFactor: scaleFactor,
      trunkAngle: trunkAngle,
      hipY: hipY,
      activeWristShoulderDistNorm: wristShoulderDist,
      wristLiftNorm: wristLiftNorm,
      hipWidthXNorm: hipWidthXNorm,
      resultIssues: resultIssues,
    );

    _updateStateMachine(ctx);
    for (final metric in _metrics) {
      metric.update(ctx);
      debugData.addAll(metric.debugData);
    }
  }

  void _updateStateMachine(RepContext ctx) {
    final dist = ctx.activeWristShoulderDistNorm;
    final lifted =
        ctx.wristLiftNorm >= PlankTapConfig.WRIST_LIFT_START_THRESHOLD;
    final returned = ctx.wristLiftNorm <= PlankTapConfig.WRIST_RETURN_THRESHOLD;

    if (tapState == PlankTapState.base &&
        lifted &&
        dist < PlankTapConfig.LIFT_START_THRESHOLD) {
      _transitionState(PlankTapState.lifting, ctx.frameTimestamp);
    } else if (tapState == PlankTapState.lifting) {
      if (lifted && dist <= PlankTapConfig.TAP_DISTANCE_THRESHOLD) {
        _transitionState(PlankTapState.tap, ctx.frameTimestamp);
      } else if (returned) {
        _completeRep(ctx, countRep: false);
      }
    } else if (tapState == PlankTapState.tap &&
        (dist > PlankTapConfig.TAP_DISTANCE_THRESHOLD + 0.10 ||
            ctx.wristLiftNorm <
                PlankTapConfig.WRIST_LIFT_START_THRESHOLD * 0.75)) {
      _transitionState(PlankTapState.returning, ctx.frameTimestamp);
    } else if (tapState == PlankTapState.returning && returned) {
      _completeRep(ctx);
    }
  }

  void _transitionState(PlankTapState newState, int timestampMs) {
    if (newState == tapState) return;
    previousState = tapState;
    tapState = newState;
    for (final metric in _metrics) {
      metric.onStateTransition(previousState, newState, timestampMs);
    }
  }

  void _completeRep(RepContext ctx, {bool countRep = true}) {
    for (final metric in _metrics) metric.evaluateRepEnd(ctx);

    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) allFaults.addAll(metric.faults);

    if (countRep) {
      repCount++;
      correctForm = !allFaults.any((f) => f.affectsForm);
      lastTappedSide = currentTappingSide;
      logger.addRepLog(RepLog(
        correctForm: correctForm,
        repNumber: repCount,
        data: {
          "fault_types": allFaults.map((f) => f.type).toSet().toList(),
        },
      ));
    } else {
      _rejectedTapAttempts++;
      correctForm = false;
      resultIssues.feedback['Result'] = 'Không tính';
    }

    _transitionState(PlankTapState.base, ctx.frameTimestamp);
    currentTappingSide = TappingSide.none;
    _baselineWristY = null;
    for (final metric in _metrics) {
      if (countRep) {
        metric.resetAndCountFault();
      } else {
        metric.reset();
      }
    }
  }

  Map<String, PoseLandmark>? _getLandmarks(
      Map<PoseLandmarkType, PoseLandmark> lm) {
    final preferred = _preferredIsRight ? _rightSide(lm) : _leftSide(lm);
    if (preferred != null) return preferred;
    return _preferredIsRight ? _leftSide(lm) : _rightSide(lm);
  }

  bool get _preferredIsRight => cameraFacing == CameraFacing.right;

  Map<String, PoseLandmark>? _leftSide(Map<PoseLandmarkType, PoseLandmark> lm) {
    return _side(lm, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip,
        PoseLandmarkType.leftAnkle, PoseLandmarkType.leftWrist);
  }

  Map<String, PoseLandmark>? _rightSide(
      Map<PoseLandmarkType, PoseLandmark> lm) {
    return _side(lm, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip,
        PoseLandmarkType.rightAnkle, PoseLandmarkType.rightWrist);
  }

  Map<String, PoseLandmark>? _side(
    Map<PoseLandmarkType, PoseLandmark> lm,
    PoseLandmarkType shoulderType,
    PoseLandmarkType hipType,
    PoseLandmarkType ankleType,
    PoseLandmarkType wristType,
  ) {
    final shoulder = lm[shoulderType];
    final hip = lm[hipType];
    final ankle = lm[ankleType];
    final wrist = lm[wristType];
    if (shoulder == null || hip == null || ankle == null || wrist == null) {
      return null;
    }
    if (!ExerciseBase.isLandmarkConfident(shoulder) ||
        !ExerciseBase.isLandmarkConfident(hip) ||
        !ExerciseBase.isLandmarkConfident(ankle) ||
        !ExerciseBase.isLandmarkConfident(wrist)) {
      return null;
    }
    return {
      'shoulder': shoulder,
      'hip': hip,
      'ankle': ankle,
      'wrist': wrist,
    };
  }

  bool _hasAll(
    Map<PoseLandmarkType, PoseLandmark> lm,
    List<PoseLandmarkType> types,
  ) {
    return types.every((type) => lm.containsKey(type));
  }

  double _wristLiftNorm(double wristY) {
    if (_baselineWristY == null || scaleFactor <= 1e-6) return 0.0;
    return max(0.0, (_baselineWristY! - wristY) / scaleFactor);
  }

  String? _cameraAngleGuidance() {
    if (cameraFacing == CameraFacing.left ||
        cameraFacing == CameraFacing.right) {
      return null;
    }
    if (cameraFacing == CameraFacing.front) {
      return 'Đặt camera ngang bên hông, không quay chính diện.';
    }
    if (cameraFacing == CameraFacing.angled) {
      return 'Xoay sang góc ngang bên hông rồi mới tập.';
    }
    return 'Cần đặt camera ngang bên hông để thấy thân người và tay chống sàn.';
  }

  @override
  void onSetComplete() {
    logger.pushKey("timeout", _isTimeout);
    logger.pushKey("rotation_fails_count", rotationMetric.faultsCount);
    logger.pushKey("alignment_fails_count", trunkMetric.faultsCount);
    logger.pushKey("tap_fails_count", tapMetric.faultsCount);
    logger.pushKey("tempo_fails_count", tempoMetric.faultsCount);
    logger.pushKey("rejected_tap_attempts", _rejectedTapAttempts);
    logger.pushGoodRepCount();
    logger.pushKey("max_rep", _isTimeout ? repCount : maxRep);
  }
}
