// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names

import 'package:vika/debug/tracked_metric.dart';
import 'package:vika/utils/debouncer.dart';
import '../../utils/exercise_logger.dart';
import '../../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../exercise_base.dart';
import 'metrics/side_plank_dip_metric_base.dart';
import 'metrics/shoulder_alignment_metric.dart';
import 'metrics/anti_rotation_metric.dart';
import 'metrics/hip_amplitude_metric.dart';

class SidePlankConfig {
  static const int MAX_REP = 12;
  static const double STRAIGHT_BODY_ANGLE = 175.0;
  static const double BOTTOM_BODY_ANGLE = 160.0;
  static const double MOVEMENT_THRESHOLD = 3.0; // Y-axis delta (pixels/cm)
  static const double MOVEMENT_THRESHOLD_NORM = 0.025;
  static const double BOTTOM_STILLNESS_NORM = 0.02;
  static const int REP_COOLDOWN_MS = 500; // 0.5s
  static const int REP_TIMEOUT_MS = 4000; // 4s
}

class SidePlankDip extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.portrait, // Ưu tiên quay dọc/ngang chính diện
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  final int maxRep;
  SidePlankDip({this.maxRep = SidePlankConfig.MAX_REP});

  SidePlankState plankState = SidePlankState.setupPlank;
  SidePlankState previousPlankState = SidePlankState.setupPlank;

  double? _previousHipY;
  int? _lastRepTime;
  int? _stateEnterTime;

  final Debouncer _bottomDebouncer = Debouncer(requiredFrames: 3);

  // Metrics & Report
  final ShoulderAlignmentMetric shoulderAlignmentMetric =
      ShoulderAlignmentMetric();
  final AntiRotationMetric antiRotationMetric = AntiRotationMetric();
  final HipAmplitudeMetric hipAmplitudeMetric = HipAmplitudeMetric();

  late final List<SidePlankDipMetricBase> _metrics = [
    shoulderAlignmentMetric,
    antiRotationMetric,
    hipAmplitudeMetric,
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
  String get exerciseName => 'Side Plank with Hip Dip';

  @override
  String get currentPhaseKey => plankState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (plankState) {
      case SidePlankState.setupPlank:
        return 'Tư thế Plank';
      case SidePlankState.basePlank:
        return 'Chuẩn bị';
      case SidePlankState.descending:
        return 'Hạ hông';
      case SidePlankState.bottom:
        return 'Giữ đáy';
      case SidePlankState.ascending:
        return 'Nâng hông';
      case SidePlankState.top:
        return 'Đỉnh điểm';
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return 'Quay ngang người với camera để đo side plank chính xác.';
    }

    final required = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];
    for (final type in required) {
      final landmark = landmarks[type];
      if (landmark == null || !ExerciseBase.isLandmarkConfident(landmark)) {
        return 'Giữ vai, khuỷu tay, hông và cổ chân rõ trong khung hình.';
      }
    }
    // Note: Gate y khoa rách chóp xoay cần làm ở UI trước khi mở cam.
    return null; // Không ép góc quay cứng, nhưng yêu cầu chính diện.
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null) return false;
    if (![leftShoulder, rightShoulder, leftHip, rightHip]
        .every(ExerciseBase.isLandmarkConfident)) return false;

    // Tư thế chuẩn bị giống hệt bài plank (thân người nằm ngang)
    double trunkClockAngle =
        calculateVerticalAngle(pivot: leftHip, point: leftShoulder);
    double horizontalDiff = (trunkClockAngle % 180) - 90;
    if (horizontalDiff.abs() > 30.0) return false;

    antiRotationMetric.captureBaseline(landmarks); // Chụp baseline 2D
    return true;
  }

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey(
        "shoulder_align_fails_count", shoulderAlignmentMetric.faultsCount);
    logger.pushKey("rotation_fails_count", antiRotationMetric.faultsCount);
    logger.pushKey("dip_depth_fails_count", hipAmplitudeMetric.faultsCount);
    logger.pushGoodRepCount();
    logger.pushKey('max_rep', maxRep);
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final leftElbow = smoothedLandmarks[PoseLandmarkType.leftElbow];
    final rightElbow = smoothedLandmarks[PoseLandmarkType.rightElbow];
    if (leftElbow == null || rightElbow == null) return;

    bool isLeftSupport = leftElbow.y > rightElbow.y;

    final supportShoulder = smoothedLandmarks[isLeftSupport
        ? PoseLandmarkType.leftShoulder
        : PoseLandmarkType.rightShoulder];
    final supportHip = smoothedLandmarks[
        isLeftSupport ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip];
    final supportAnkle = smoothedLandmarks[isLeftSupport
        ? PoseLandmarkType.leftAnkle
        : PoseLandmarkType.rightAnkle];
    final supportElbow = isLeftSupport ? leftElbow : rightElbow;

    final lShoulder = smoothedLandmarks[PoseLandmarkType.leftShoulder];
    final rShoulder = smoothedLandmarks[PoseLandmarkType.rightShoulder];
    final lHip = smoothedLandmarks[PoseLandmarkType.leftHip];
    final rHip = smoothedLandmarks[PoseLandmarkType.rightHip];

    if (supportShoulder == null ||
        supportHip == null ||
        supportAnkle == null ||
        lShoulder == null ||
        rShoulder == null ||
        lHip == null ||
        rHip == null) return;
    if (![
      supportShoulder,
      supportHip,
      supportAnkle,
      supportElbow,
      lShoulder,
      rShoulder,
      lHip,
      rHip,
    ].every(ExerciseBase.isLandmarkConfident)) return;

    scaleFactor = calculateDistance(supportShoulder, supportHip);
    if (!scaleFactor.isFinite || scaleFactor <= 1e-6) return;

    // 1. Tính toán Hình học
    double bodyAngle = calculateAngle(
        firstPoint: supportShoulder,
        midPoint: supportHip,
        lastPoint: supportAnkle);
    double shoulderElbowOffsetX =
        (supportShoulder.x - supportElbow.x).abs() / scaleFactor;

    double shoulderWidthX = (lShoulder.x - rShoulder.x).abs();
    double shoulderWidthY = (lShoulder.y - rShoulder.y).abs();
    double hipWidthX = (lHip.x - rHip.x).abs();
    double lowerHipY = supportHip.y;
    int now = frameTimestampMs;

    final ctx = RepContext(
      bodyAngle: bodyAngle,
      shoulderElbowOffsetX: shoulderElbowOffsetX,
      shoulderWidthX: shoulderWidthX,
      hipWidthX: hipWidthX,
      lowerHipY: lowerHipY,
      shoulderWidthY: shoulderWidthY,
      plankState: plankState,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    debugData['State'] = currentPhaseKey;
    debugData['BodyAng'] = bodyAngle.toStringAsFixed(0);
    debugData['Offset'] = shoulderElbowOffsetX.toStringAsFixed(1);

    // 2. State Machine Update
    _updateState(
        lowerHipY, bodyAngle, shoulderWidthY, shoulderWidthX, scaleFactor, now);
    _previousHipY = lowerHipY;

    // 3. Update Metrics
    for (final metric in _metrics) {
      metric.update(ctx);
      debugData.addAll(metric.debugData);
    }

    // 4. Hoàn thành 1 Rep
    if (plankState == SidePlankState.top &&
        previousPlankState == SidePlankState.ascending) {
      repCount += 1;
      _lastRepTime = now;

      final allFaults = <FaultRecord>[];
      for (final metric in _metrics) allFaults.addAll(metric.faults);

      correctForm = !allFaults.any((f) => f.affectsForm);
      resultIssues.feedback['Result'] =
          correctForm ? 'Hoàn hảo!' : 'Sửa form nhé';

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

      _transitionState(SidePlankState.basePlank, now);
    }
  }

  void _updateState(double currentHipY, double bodyAngle, double shoulderWidthY,
      double shoulderWidthX, double scale, int timestampMs) {
    if (_previousHipY == null) return;

    _stateEnterTime ??= timestampMs;

    // Timeout logic: reset to basePlank or setupPlank if stuck for 4 seconds
    if (plankState != SidePlankState.setupPlank &&
        plankState != SidePlankState.basePlank) {
      if (timestampMs - _stateEnterTime! > SidePlankConfig.REP_TIMEOUT_MS) {
        _transitionState(SidePlankState.basePlank, timestampMs);
      }
    }

    double deltaY =
        currentHipY - _previousHipY!; // Y tăng -> đi xuống, Y giảm -> đi lên
    final deltaYNorm = deltaY / scale;
    bool isTwisting =
        shoulderWidthX > shoulderWidthY; // Xoay người (ngực úp xuống sàn)

    if (plankState == SidePlankState.setupPlank) {
      // Rotate into side plank
      if (!isTwisting && bodyAngle > SidePlankConfig.BOTTOM_BODY_ANGLE) {
        _transitionState(SidePlankState.basePlank, timestampMs);
      }
    } else if (plankState == SidePlankState.basePlank) {
      bool cooldownOk = _lastRepTime == null ||
          (timestampMs - _lastRepTime! > SidePlankConfig.REP_COOLDOWN_MS);
      if (cooldownOk &&
          deltaYNorm > SidePlankConfig.MOVEMENT_THRESHOLD_NORM &&
          !isTwisting) {
        _transitionState(SidePlankState.descending, timestampMs);
      } else if (isTwisting) {
        _transitionState(SidePlankState.setupPlank, timestampMs);
      }
    } else if (plankState == SidePlankState.descending) {
      if (bodyAngle < SidePlankConfig.BOTTOM_BODY_ANGLE &&
          _bottomDebouncer.update(
              deltaYNorm.abs() < SidePlankConfig.BOTTOM_STILLNESS_NORM)) {
        _transitionState(SidePlankState.bottom, timestampMs);
      } else if (isTwisting) {
        _transitionState(SidePlankState.setupPlank, timestampMs);
      }
    } else if (plankState == SidePlankState.bottom) {
      if (deltaYNorm < -SidePlankConfig.MOVEMENT_THRESHOLD_NORM &&
          !isTwisting) {
        _transitionState(SidePlankState.ascending, timestampMs);
      } else if (isTwisting) {
        _transitionState(SidePlankState.setupPlank, timestampMs);
      }
    } else if (plankState == SidePlankState.ascending) {
      if (bodyAngle > SidePlankConfig.STRAIGHT_BODY_ANGLE && !isTwisting) {
        _transitionState(SidePlankState.top, timestampMs);
      } else if (isTwisting) {
        _transitionState(SidePlankState.setupPlank, timestampMs);
      }
    }
  }

  void _transitionState(SidePlankState newState, int timestampMs) {
    previousPlankState = plankState;
    plankState = newState;
    _stateEnterTime = timestampMs;
    for (final metric in _metrics) {
      metric.onStateTransition(previousPlankState, newState, timestampMs);
    }
  }
}
