// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names

import 'package:vika/utils/debouncer.dart';
import '../../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../exercise_base.dart';
import 'metrics/side_plank_dip_metric_base.dart';
import 'metrics/shoulder_alignment_metric.dart';
import 'metrics/anti_rotation_metric.dart';
import 'metrics/hip_amplitude_metric.dart';
import 'report/side_plank_dip_report_builder.dart';

class SidePlankConfig {
  static const int MAX_REP = 12;
  static const double STRAIGHT_BODY_ANGLE = 175.0;
  static const double BOTTOM_BODY_ANGLE = 160.0;
  static const double MOVEMENT_THRESHOLD = 3.0; // Y-axis delta (pixels/cm)
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

  int? _setStartTime;
  double? _previousHipY;
  int? _lastRepTime;
  int? _stateEnterTime;

  final Debouncer _bottomDebouncer = Debouncer(requiredFrames: 3);

  // Metrics & Report
  final ShoulderAlignmentMetric shoulderAlignmentMetric =
      ShoulderAlignmentMetric();
  final AntiRotationMetric antiRotationMetric = AntiRotationMetric();
  final HipAmplitudeMetric hipAmplitudeMetric = HipAmplitudeMetric();
  final SidePlankDipReportBuilder reportBuilder = SidePlankDipReportBuilder();

  late final List<SidePlankDipMetricBase> _metrics = [
    shoulderAlignmentMetric,
    antiRotationMetric,
    hipAmplitudeMetric,
  ];

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
    final report = reportBuilder.buildReport(
        _setStartTime ?? DateTime.now().millisecondsSinceEpoch,
        DateTime.now().millisecondsSinceEpoch);
    logger.pushKey("Shoulder Safety", report.shoulderSafetyScore);
    logger.pushKey("Anti-Rotation", report.antiRotationScore);
    logger.pushKey("Dip Depth", report.dipDepthScore);
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    _setStartTime ??= frameTimestampMs;

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
    _updateState(lowerHipY, bodyAngle, shoulderWidthY, shoulderWidthX, now);
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

      reportBuilder.recordRep(allFaults);

      correctForm = !allFaults.any((f) => f.affectsForm);
      resultIssues.feedback['Result'] =
          correctForm ? 'Hoàn hảo!' : 'Sửa form nhé';

      final faultMap = <String, Map<String, String>>{};
      for (final fault in allFaults) {
        if (!faultMap.containsKey(fault.phase)) faultMap[fault.phase] = {};
        faultMap[fault.phase]![fault.type] = fault.message;
      }
      setFeedback.add({correctForm: faultMap});

      correctForm = true;
      for (final metric in _metrics) metric.reset();

      _transitionState(SidePlankState.basePlank, now);
    }
  }

  void _updateState(double currentHipY, double bodyAngle, double shoulderWidthY,
      double shoulderWidthX, int timestampMs) {
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
          deltaY > SidePlankConfig.MOVEMENT_THRESHOLD &&
          !isTwisting) {
        _transitionState(SidePlankState.descending, timestampMs);
      } else if (isTwisting) {
        _transitionState(SidePlankState.setupPlank, timestampMs);
      }
    } else if (plankState == SidePlankState.descending) {
      if (bodyAngle < SidePlankConfig.BOTTOM_BODY_ANGLE &&
          _bottomDebouncer.update(deltaY.abs() < 2.0)) {
        _transitionState(SidePlankState.bottom, timestampMs);
      } else if (isTwisting) {
        _transitionState(SidePlankState.setupPlank, timestampMs);
      }
    } else if (plankState == SidePlankState.bottom) {
      if (deltaY < -SidePlankConfig.MOVEMENT_THRESHOLD && !isTwisting) {
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
