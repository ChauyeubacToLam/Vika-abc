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
  static const double STRAIGHT_BODY_ANGLE = 165.0; 
  static const double MOVEMENT_THRESHOLD = 3.0; // Y-axis delta (pixels/cm)
}

class SidePlankDip extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.portrait, // Ưu tiên quay dọc/ngang chính diện
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  final int maxRep;
  SidePlankDip({this.maxRep = SidePlankConfig.MAX_REP});

  SidePlankState plankState = SidePlankState.basePlank;
  SidePlankState previousPlankState = SidePlankState.basePlank;
  
  int? _setStartTime;
  double? _previousHipY;
  
  final Debouncer _bottomDebouncer = Debouncer(requiredFrames: 3);

  // Metrics & Report
  final ShoulderAlignmentMetric shoulderAlignmentMetric = ShoulderAlignmentMetric();
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
      case SidePlankState.basePlank: return 'Chuẩn bị';
      case SidePlankState.descending: return 'Hạ hông';
      case SidePlankState.bottom: return 'Giữ đáy';
      case SidePlankState.ascending: return 'Nâng hông';
      case SidePlankState.top: return 'Đỉnh điểm';
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    // Note: Gate y khoa rách chóp xoay cần làm ở UI trước khi mở cam.
    return null; // Không ép góc quay cứng, nhưng yêu cầu chính diện.
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    // Tự động tìm bên trụ: Khuỷu tay nào gần đất (Y lớn hơn) là bên trụ
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    if (leftElbow == null || rightElbow == null) return false;

    bool isLeftSupport = leftElbow.y > rightElbow.y;
    
    final shoulder = landmarks[isLeftSupport ? PoseLandmarkType.leftShoulder : PoseLandmarkType.rightShoulder];
    final hip = landmarks[isLeftSupport ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip];
    final ankle = landmarks[isLeftSupport ? PoseLandmarkType.leftAnkle : PoseLandmarkType.rightAnkle];
    final elbow = isLeftSupport ? leftElbow : rightElbow;

    if (shoulder == null || hip == null || ankle == null) return false;

    // Cơ thể phải thẳng
    double bodyAngle = calculateAngle(firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    if (bodyAngle < SidePlankConfig.STRAIGHT_BODY_ANGLE) return false;
    
    // Khuỷu tay vuông góc trục vai (X gần nhau)
    double offsetX = (shoulder.x - elbow.x).abs() / (scaleFactor ?? 1.0);
    if (offsetX > 20.0) return false; // Cần canh thẳng trước khi bắt đầu

    antiRotationMetric.captureBaseline(landmarks); // Chụp baseline 2D
    return true;
  }

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {
    final report = reportBuilder.buildReport(_setStartTime ?? DateTime.now().millisecondsSinceEpoch, DateTime.now().millisecondsSinceEpoch);
    print("Shoulder Safety: ${report.shoulderSafetyScore}%");
    print("Anti-Rotation: ${report.antiRotationScore}%");
    print("Dip Depth: ${report.dipDepthScore}%");
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    _setStartTime ??= frameTimestampMs;

    final leftElbow = smoothedLandmarks[PoseLandmarkType.leftElbow];
    final rightElbow = smoothedLandmarks[PoseLandmarkType.rightElbow];
    if (leftElbow == null || rightElbow == null) return;

    bool isLeftSupport = leftElbow.y > rightElbow.y;
    
    final supportShoulder = smoothedLandmarks[isLeftSupport ? PoseLandmarkType.leftShoulder : PoseLandmarkType.rightShoulder];
    final supportHip = smoothedLandmarks[isLeftSupport ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip];
    final supportAnkle = smoothedLandmarks[isLeftSupport ? PoseLandmarkType.leftAnkle : PoseLandmarkType.rightAnkle];
    final supportElbow = isLeftSupport ? leftElbow : rightElbow;
    
    final lShoulder = smoothedLandmarks[PoseLandmarkType.leftShoulder];
    final rShoulder = smoothedLandmarks[PoseLandmarkType.rightShoulder];
    final lHip = smoothedLandmarks[PoseLandmarkType.leftHip];
    final rHip = smoothedLandmarks[PoseLandmarkType.rightHip];

    if (supportShoulder == null || supportHip == null || supportAnkle == null || lShoulder == null || rShoulder == null || lHip == null || rHip == null) return;

    // 1. Tính toán Hình học
    double bodyAngle = calculateAngle(firstPoint: supportShoulder, midPoint: supportHip, lastPoint: supportAnkle);
    double shoulderElbowOffsetX = (supportShoulder.x - supportElbow.x).abs() / (scaleFactor ?? 1.0);
    
    double shoulderWidthX = (lShoulder.x - rShoulder.x).abs();
    double hipWidthX = (lHip.x - rHip.x).abs();
    double lowerHipY = supportHip.y;
    int now = frameTimestampMs;

    final ctx = RepContext(
      bodyAngle: bodyAngle,
      shoulderElbowOffsetX: shoulderElbowOffsetX,
      shoulderWidthX: shoulderWidthX,
      hipWidthX: hipWidthX,
      lowerHipY: lowerHipY,
      plankState: plankState,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    debugData['State'] = currentPhaseKey;
    debugData['BodyAng'] = bodyAngle.toStringAsFixed(0);
    debugData['Offset'] = shoulderElbowOffsetX.toStringAsFixed(1);

    // 2. State Machine Update
    _updateState(lowerHipY, bodyAngle, now);
    _previousHipY = lowerHipY;

    // 3. Update Metrics
    for (final metric in _metrics) {
      metric.update(ctx);
      debugData.addAll(metric.debugData);
    }

    // 4. Hoàn thành 1 Rep
    if (plankState == SidePlankState.top && previousPlankState == SidePlankState.ascending) {
      repCount += 1;
      
      final allFaults = <FaultRecord>[];
      for (final metric in _metrics) allFaults.addAll(metric.faults);

      reportBuilder.recordRep(allFaults);

      correctForm = !allFaults.any((f) => f.affectsForm);
      resultIssues.feedback['Result'] = correctForm ? 'Hoàn hảo!' : 'Sửa form nhé';

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

  void _updateState(double currentHipY, double bodyAngle, int timestampMs) {
    if (_previousHipY == null) return;
    
    double deltaY = currentHipY - _previousHipY!; // Y tăng -> đi xuống, Y giảm -> đi lên
    
    if (plankState == SidePlankState.basePlank && deltaY > SidePlankConfig.MOVEMENT_THRESHOLD) {
      _transitionState(SidePlankState.descending, timestampMs);
    } 
    else if (plankState == SidePlankState.descending && _bottomDebouncer.update(deltaY.abs() < 2.0)) {
      _transitionState(SidePlankState.bottom, timestampMs);
    } 
    else if (plankState == SidePlankState.bottom && deltaY < -SidePlankConfig.MOVEMENT_THRESHOLD) {
      _transitionState(SidePlankState.ascending, timestampMs);
    } 
    else if (plankState == SidePlankState.ascending && bodyAngle > SidePlankConfig.STRAIGHT_BODY_ANGLE) {
      _transitionState(SidePlankState.top, timestampMs);
    }
  }

  void _transitionState(SidePlankState newState, int timestampMs) {
    previousPlankState = plankState;
    plankState = newState;
    for (final metric in _metrics) {
      metric.onStateTransition(previousPlankState, newState, timestampMs);
    }
  }
}