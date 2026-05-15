import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';
import 'metrics/sphinx_metric_base.dart';
import 'metrics/hip_ground_metric.dart';
import 'metrics/hold_tempo_metric.dart';
import 'metrics/elbow_angle_metric.dart';
import 'metrics/neck_shoulder_metric.dart';

class SphinxStretch extends ExerciseBase {
  SphinxState state = SphinxState.proneSetup;
  SphinxState prevState = SphinxState.proneSetup;
  bool isLeftTracked = true;

  // Cache thông số rep cuối
  double _lastHoldTime = 0.0;
  double _lastStabilityScore = 0.0;

  final HipGroundMetric hipMetric = HipGroundMetric();
  final HoldTempoMetric tempoMetric = HoldTempoMetric();
  final ElbowAngleMetric elbowMetric = ElbowAngleMetric();
  final NeckShoulderMetric neckMetric = NeckShoulderMetric();

  late final List<SphinxMetricBase> _metrics = [
    hipMetric, tempoMetric, elbowMetric, neckMetric,
  ];

  @override
  String get exerciseName => 'Sphinx Pose';

  @override
  bool requestStop() {
    if (state == SphinxState.isometricHold) {
      tempoMetric.flushCurrentSegment(frameTimestampMs);
    }
    return tempoMetric.activeHoldSeconds >= SphinxConfig.Ae_Min_Hold_Time;
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return "Vui lòng đặt camera quay ngang hông (Side View).";
    }

    final req = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftAnkle,
    ];

    for (final type in req) {
      if (landmarks[type] == null || !ExerciseBase.isLandmarkConfident(landmarks[type]!)) {
        return "Cơ thể chưa nằm trọn trong khung hình hoặc ánh sáng yếu.";
      }
    }
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final shoulder = isLeftTracked ? landmarks[PoseLandmarkType.leftShoulder] : landmarks[PoseLandmarkType.rightShoulder];
    final hip = isLeftTracked ? landmarks[PoseLandmarkType.leftHip] : landmarks[PoseLandmarkType.rightHip];
    final ankle = isLeftTracked ? landmarks[PoseLandmarkType.leftAnkle] : landmarks[PoseLandmarkType.rightAnkle];

    if (shoulder == null || hip == null || ankle == null) return false;

    final bodyAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    return bodyAngle >= SphinxConfig.Aa_Start_Body_Angle;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final shoulder = isLeftTracked ? smoothedLandmarks[PoseLandmarkType.leftShoulder] : smoothedLandmarks[PoseLandmarkType.rightShoulder];
    final hip      = isLeftTracked ? smoothedLandmarks[PoseLandmarkType.leftHip]      : smoothedLandmarks[PoseLandmarkType.rightHip];
    final ankle    = isLeftTracked ? smoothedLandmarks[PoseLandmarkType.leftAnkle]    : smoothedLandmarks[PoseLandmarkType.rightAnkle];
    final elbow    = isLeftTracked ? smoothedLandmarks[PoseLandmarkType.leftElbow]    : smoothedLandmarks[PoseLandmarkType.rightElbow];
    final wrist    = isLeftTracked ? smoothedLandmarks[PoseLandmarkType.leftWrist]    : smoothedLandmarks[PoseLandmarkType.rightWrist];
    final knee     = isLeftTracked ? smoothedLandmarks[PoseLandmarkType.leftKnee]     : smoothedLandmarks[PoseLandmarkType.rightKnee];
    final ear      = isLeftTracked ? smoothedLandmarks[PoseLandmarkType.leftEar]      : smoothedLandmarks[PoseLandmarkType.rightEar];

    if (shoulder == null || hip == null || ankle == null ||
        elbow == null || wrist == null || knee == null || ear == null) {
      return;
    }

    final scaleFactor = calculateDistance(shoulder, hip);

    final ctx = SphinxContext(
      bodyAngle:      calculateAngleNormalized(firstPoint: shoulder, midPoint: hip,    lastPoint: ankle),
      elbowAngle:     calculateAngleNormalized(firstPoint: shoulder, midPoint: elbow,  lastPoint: wrist),
      spineAngle:     calculateAngleNormalized(firstPoint: shoulder, midPoint: hip,    lastPoint: knee),
      neckAngle:      calculateAngleNormalized(firstPoint: ear,      midPoint: shoulder, lastPoint: hip),
      hipY:           hip.y,
      ankleY:         ankle.y,
      earShoulderDist: calculateDistance(ear, shoulder),
      scaleFactor:    scaleFactor,
      state:          state,
      frameTimestampMs: frameTimestampMs,
      resultIssues:   resultIssues,
    );

    _updateStateBuffer(ctx);

    if (state != SphinxState.proneSetup) {
      for (final m in _metrics) {
        m.update(ctx);
        debugData.addAll(m.debugData);
      }
    }
  }

  void _updateStateBuffer(SphinxContext ctx) {
    SphinxState newState = state;

    switch (state) {
      case SphinxState.proneSetup:
        if (ctx.elbowAngle < 130 &&
            ctx.spineAngle < SphinxConfig.Ac_Spine_Ext_Angle[1] + 10) {
          newState = SphinxState.ascending;
        }
        break;

      case SphinxState.ascending:
        if (ctx.elbowAngle >= SphinxConfig.Ab_Elbow_Hold_Angle[0] &&
            ctx.elbowAngle <= SphinxConfig.Ab_Elbow_Hold_Angle[1] &&
            ctx.spineAngle >= SphinxConfig.Ac_Spine_Ext_Angle[0] &&
            ctx.spineAngle <= SphinxConfig.Ac_Spine_Ext_Angle[1]) {
          newState = SphinxState.isometricHold;
        }
        break;

      case SphinxState.isometricHold:
        if (ctx.elbowAngle > 140 ||
            ctx.spineAngle > SphinxConfig.Aa_Start_Body_Angle - 10) {
          newState = SphinxState.descending;
        }
        break;

      case SphinxState.descending:
        newState = SphinxState.proneSetup;
        break;
    }

    // Logic xử lý chuyển trạng thái cũ
    if (newState != state) {
      for (final m in _metrics) {
        m.onStateTransition(state, newState, ctx.frameTimestampMs);
      }
      prevState = state;
      state = newState;

      if (state == SphinxState.proneSetup && prevState == SphinxState.descending) {
        _completeRep(ctx);
      }
    }

    // --- LOGIC MỚI: ĐẾM REP THEO GIÂY TRONG LÚC HOLD ---
    if (state == SphinxState.isometricHold) {
      // Lấy thời gian hold thực tế đang diễn ra
      double liveHold = tempoMetric.getLiveHoldTime(ctx.frameTimestampMs);
      
      // Kiểm tra xem 3 metrics (Hông, Tay, Cổ) có đang dính lỗi form nào không
      bool isFormOkay = hipMetric.faults.isEmpty && 
                        elbowMetric.faults.isEmpty && 
                        neckMetric.faults.isEmpty;

      // Nếu form chuẩn VÀ giữ đủ X giây
      if (isFormOkay && liveHold >= SphinxConfig.Ae_Min_Hold_Time) {
        
        // Chốt 1 rep ngay lập tức
        _completeRep(ctx);

        // Ép State Machine về trạng thái Nằm chuẩn bị (Prone Setup)
        prevState = SphinxState.descending; 
        state = SphinxState.proneSetup;

        // Báo cho các metrics dọn dẹp state
        for (final m in _metrics) {
          m.onStateTransition(SphinxState.isometricHold, SphinxState.proneSetup, ctx.frameTimestampMs);
        }
      }
    }
  }

  void _completeRep(SphinxContext ctx) {
    repCount += 1;

    final allFaults = <FaultRecord>[
      ...hipMetric.faults,
      ...elbowMetric.faults,
      ...neckMetric.faults,
      ...tempoMetric.faults,
    ];

    correctForm = !allFaults.any((f) => f.affectsForm);

    _lastHoldTime = tempoMetric.activeHoldSeconds;
    _lastStabilityScore = tempoMetric.stabilityScore;

    logger.addRepLog(RepLog(
      repNumber: repCount,
      correctForm: correctForm,
      data: {
        "active_hold_time": _lastHoldTime,
        "stability_score": _lastStabilityScore,
        "fault_types": allFaults.map((f) => f.type).toSet().toList(),
      },
    ));

    for (final m in _metrics) {
      m.resetAndCountFault();
    }
  }

  @override
  String get currentPhaseKey => state.name;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case SphinxState.proneSetup:    return 'Nằm chuẩn bị';
      case SphinxState.ascending:     return 'Nâng người';
      case SphinxState.isometricHold: return 'Giữ tĩnh';
      case SphinxState.descending:    return 'Thoát thế';
    }
  }

  @override
  void onSetComplete() {
    logger.pushKey("hip_fails_count",        hipMetric.faultsCount);
    logger.pushKey("straight_arm_fails_count", elbowMetric.faultsCount);
    logger.pushKey("shrug_neck_fails_count",  neckMetric.faultsCount);
    logger.pushKey("active_hold_time",        _lastHoldTime);
    logger.pushKey("stability_score",         _lastStabilityScore);
  }
}