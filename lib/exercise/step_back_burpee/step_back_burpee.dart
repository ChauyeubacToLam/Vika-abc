// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names

import 'package:vika/debug/tracked_metric.dart';
import 'package:vika/utils/debouncer.dart';
import '../../utils/exercise_logger.dart';
import '../../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../exercise_base.dart';
import 'metrics/step_back_burpee_metric_base.dart';
import 'metrics/squat_hinge_metric.dart';
import 'metrics/plank_form_metric.dart';

class BurpeeConfig {
  static const int MAX_REP = 15;
  static const double STANDING_BODY_ANGLE = 155.0; // Góc đứng thẳng

  // Ngưỡng khoảng cách ngang (X) để xác định Plank (đơn vị tương đối)
  static const double PLANK_MIN_DIST_X = 0.55; // normalized by torso length
}

class StepBackBurpee extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  final int maxRep;
  StepBackBurpee({required this.maxRep});

  BurpeeState burpeeState = BurpeeState.standing;
  BurpeeState previousBurpeeState = BurpeeState.standing;

  final Debouncer _plankDebouncer = Debouncer(requiredFrames: 3);
  final Debouncer _standingDebouncer = Debouncer(requiredFrames: 3);

  // Metrics & Report
  final SquatHingeMetric squatHingeMetric = SquatHingeMetric();
  final PlankFormMetric plankFormMetric = PlankFormMetric();

  late final List<StepBackBurpeeMetricBase> _metrics = [
    squatHingeMetric,
    plankFormMetric,
  ];
  late final List<TrackedMetric> _trackedMetrics =
      _metrics.map(TrackedMetric.new).toList();

  @override
  List<TrackedMetric> get trackedDebugMetrics =>
      List<TrackedMetric>.unmodifiable(
        [
          ...super.trackedDebugMetrics,
          ..._trackedMetrics,
        ],
      );

  @override
  String get exerciseName => 'Step-Back Burpee';

  @override
  String get currentPhaseKey => burpeeState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (burpeeState) {
      case BurpeeState.standing:
        return 'Đứng thẳng';
      case BurpeeState.squattingDown:
        return 'Hạ người';
      case BurpeeState.steppingBack:
        return 'Bước lùi';
      case BurpeeState.highPlank:
        return 'Nằm xuống'; // Thay vì Plank
      case BurpeeState.steppingForward:
        return 'Bước lên';
      case BurpeeState.standingUp:
        return 'Đứng lên';
    }
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final shoulder = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    final hip = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);
    final ankle = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle);
    final wrist = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightWrist,
        leftType: PoseLandmarkType.leftWrist);
    final knee = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightKnee,
        leftType: PoseLandmarkType.leftKnee);

    if (shoulder == null ||
        hip == null ||
        ankle == null ||
        wrist == null ||
        knee == null) return false;

    // Yêu cầu nhìn rõ toàn thân, tránh việc bị ngoại suy khi mới thấy nửa người
    if (shoulder.likelihood < 0.5 ||
        hip.likelihood < 0.5 ||
        ankle.likelihood < 0.5 ||
        wrist.likelihood < 0.5 ||
        knee.likelihood < 0.5) return false;

    double bodyAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: ankle);

    if (bodyAngle < BurpeeConfig.STANDING_BODY_ANGLE) return false;
    return true;
  }

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey("spine_fails_count", squatHingeMetric.faultsCount);
    logger.pushKey("plank_form_fails_count", plankFormMetric.faultsCount);
    logger.pushGoodRepCount();
    logger.pushKey('max_rep', maxRep);
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return "⚠️ Vui lòng quay ngang người. Góc ngang là BẮT BUỘC để AI bảo vệ cột sống của bạn!";
    }
    return null;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
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
    PoseLandmark? knee = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightKnee,
        leftType: PoseLandmarkType.leftKnee);
    PoseLandmark? ankle = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle);

    if (shoulder == null ||
        elbow == null ||
        wrist == null ||
        hip == null ||
        knee == null ||
        ankle == null) return;

    // 1. Tính toán Hình học
    double kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);
    double bodyAlignmentAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    double hipAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: knee);
    double elbowAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
    double shoulderToArmAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: shoulder, lastPoint: wrist);

    double localScaleFactor = scaleFactor;
    if (localScaleFactor <= 0) {
      localScaleFactor = calculateDistance(shoulder, hip);
    }
    if (localScaleFactor <= 0) localScaleFactor = 1;

    double wristAnkleDistX = (wrist.x - ankle.x).abs() /
        localScaleFactor; // Chuẩn hóa theo tỷ lệ cơ thể
    double shoulderWristDistY = (wrist.y - shoulder.y) /
        localScaleFactor; // Duong khi co tay nam duoi vai
    double wristY = wrist.y;
    double kneeY = knee.y;
    int now = frameTimestampMs;

    final ctx = RepContext(
      kneeAngle: kneeAngle,
      bodyAlignmentAngle: bodyAlignmentAngle,
      hipAngle: hipAngle,
      elbowAngle: elbowAngle,
      wristAnkleDistX: wristAnkleDistX,
      wristY: wristY,
      burpeeState: burpeeState,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    debugData['State'] = currentPhaseKey;
    debugData['Knee'] = kneeAngle.toStringAsFixed(0);
    debugData['Body'] = bodyAlignmentAngle.toStringAsFixed(0);
    debugData['DistX'] = wristAnkleDistX.toStringAsFixed(2);
    debugData['ShToArm'] = shoulderToArmAngle.toStringAsFixed(0);
    debugData['ShWrDistY'] = shoulderWristDistY.toStringAsFixed(2);

    // 2. State Machine Update
    _updateState(kneeAngle, bodyAlignmentAngle, wristAnkleDistX, wristY, kneeY,
        shoulderToArmAngle, shoulderWristDistY, now);

    // 3. Update Metrics
    for (final metric in _metrics) {
      metric.update(ctx);
      debugData.addAll(metric.debugData);
    }

    // 4. Hoàn thành 1 Rep (từ StandingUp -> Standing)
    if (burpeeState == BurpeeState.standing &&
        previousBurpeeState == BurpeeState.standingUp) {
      repCount += 1;

      final allFaults = <FaultRecord>[];
      for (final metric in _metrics) allFaults.addAll(metric.faults);

      correctForm = !allFaults.any((f) => f.affectsForm);
      resultIssues.feedback['Result'] = correctForm ? 'Tốt!' : 'Sửa form nhé!';

      final faultMap = <String, Map<String, String>>{};
      for (final fault in allFaults) {
        if (!faultMap.containsKey(fault.phase)) faultMap[fault.phase] = {};
        faultMap[fault.phase]![fault.type] = fault.message;
      }
      setFeedback.add({correctForm: faultMap});

      logger.addRepLog(RepLog(
        correctForm: correctForm,
        repNumber: repCount,
        data: {
          'fault_types': allFaults.map((f) => f.type).toSet().toList(),
        },
      ));

      for (final metric in _metrics) metric.resetAndCountFault();

      correctForm = true;
      previousBurpeeState = BurpeeState.standing;
    }
  }

  void _updateState(
      double kneeAngle,
      double bodyAngle,
      double distX,
      double wristY,
      double kneeY,
      double shoulderToArmAngle,
      double shoulderWristDistY,
      int timestampMs) {
    // Logic nhận diện trạng thái qua khoảng cách ngang (DistX) và tư thế
    bool isCrouching = kneeAngle < 120 && bodyAngle < 120; // Đang co người

    // Yêu cầu nằm hoàn toàn xuống sàn: vai phải hạ thấp gần bằng cổ tay (khoảng cách Y nhỏ)
    bool isHighPlank = _plankDebouncer.update(
      distX > BurpeeConfig.PLANK_MIN_DIST_X &&
          bodyAngle > 135 &&
          shoulderWristDistY > 0.25 &&
          shoulderWristDistY < 1.60 &&
          shoulderToArmAngle > 25 &&
          shoulderToArmAngle < 155,
    );

    bool isStandingStraight =
        _standingDebouncer.update(bodyAngle > BurpeeConfig.STANDING_BODY_ANGLE);

    if (burpeeState == BurpeeState.standing && !isStandingStraight) {
      _transitionState(BurpeeState.squattingDown, timestampMs);
    } else if (burpeeState == BurpeeState.squattingDown &&
        isCrouching &&
        distX > 0.2) {
      _transitionState(BurpeeState.steppingBack, timestampMs);
    } else if ((burpeeState == BurpeeState.steppingBack ||
            burpeeState == BurpeeState.squattingDown) &&
        isHighPlank) {
      _transitionState(BurpeeState.highPlank,
          timestampMs); // Sử dụng highPlank state làm trạng thái nằm
    } else if (burpeeState == BurpeeState.highPlank &&
        !isHighPlank &&
        distX < BurpeeConfig.PLANK_MIN_DIST_X * 1.1) {
      _transitionState(BurpeeState.steppingForward, timestampMs);
    } else if (burpeeState == BurpeeState.steppingForward && bodyAngle > 100) {
      _transitionState(BurpeeState.standingUp, timestampMs);
    } else if (burpeeState == BurpeeState.standingUp && isStandingStraight) {
      _transitionState(BurpeeState.standing, timestampMs);
    } else if (isStandingStraight && burpeeState != BurpeeState.standing) {
      // Reset state if user stands up without completing the full sequence
      _transitionState(BurpeeState.standing, timestampMs);
    }
  }

  void _transitionState(BurpeeState newState, int timestampMs) {
    previousBurpeeState = burpeeState;
    burpeeState = newState;

    for (final metric in _metrics) {
      metric.onStateTransition(previousBurpeeState, newState, timestampMs);
    }
  }
}
