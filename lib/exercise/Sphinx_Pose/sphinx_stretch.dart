import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/debug/tracked_metric.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';
import 'Metrics/sphinx_metric_base.dart';
import 'Metrics/hip_ground_metric.dart';
import 'Metrics/hold_tempo_metric.dart';
import 'Metrics/elbow_angle_metric.dart';
import 'Metrics/neck_shoulder_metric.dart';

class SphinxStretch extends ExerciseBase {
  SphinxStretch({
    this.maxSeconds = SphinxConfig.Ae_Min_Hold_Time,
  });

  final int maxSeconds;

  SphinxState state = SphinxState.proneSetup;
  SphinxState prevState = SphinxState.proneSetup;
  bool isLeftTracked = true;

  // Cache thông số rep cuối
  double _lastHoldTime = 0.0;
  double _lastStabilityScore = 0.0;
  final HoldSecondsAccumulator _holdSeconds = HoldSecondsAccumulator(const [
    'hip_seconds',
    'straight_arm_seconds',
    'shrug_neck_seconds',
  ]);

  final HipGroundMetric hipMetric = HipGroundMetric();
  final HoldTempoMetric tempoMetric = HoldTempoMetric();
  final ElbowAngleMetric elbowMetric = ElbowAngleMetric();
  final NeckShoulderMetric neckMetric = NeckShoulderMetric();

  late final List<SphinxMetricBase> _metrics = [
    hipMetric,
    tempoMetric,
    elbowMetric,
    neckMetric,
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
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'Sphinx Pose';

  @override
  bool requestStop() => repCount >= SphinxConfig.Af_Max_Reps;

  @override
  void onExerciseActivated() {
    super.onExerciseActivated();
    _holdSeconds.reset();
  }

  @override
  double? get liveHoldSeconds => state == SphinxState.isometricHold
      ? tempoMetric.getLiveHoldTime(frameTimestampMs)
      : null;

  @override
  double? get liveHoldTargetSeconds => maxSeconds.toDouble();

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return "Vui lòng đặt camera quay ngang hông (Side View).";
    }

    if (!_selectTrackedSide(landmarks)) {
      return "Cơ thể chưa nằm trọn trong khung hình hoặc ánh sáng yếu.";
    }

    final req = isLeftTracked
        ? [
            PoseLandmarkType.leftShoulder,
            PoseLandmarkType.leftHip,
            PoseLandmarkType.leftAnkle,
          ]
        : [
            PoseLandmarkType.rightShoulder,
            PoseLandmarkType.rightHip,
            PoseLandmarkType.rightAnkle,
          ];

    for (final type in req) {
      if (landmarks[type] == null ||
          !ExerciseBase.isLandmarkConfident(landmarks[type]!)) {
        return "Cơ thể chưa nằm trọn trong khung hình hoặc ánh sáng yếu.";
      }
    }
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (!_selectTrackedSide(landmarks)) return false;

    final shoulder = isLeftTracked
        ? landmarks[PoseLandmarkType.leftShoulder]
        : landmarks[PoseLandmarkType.rightShoulder];
    final hip = isLeftTracked
        ? landmarks[PoseLandmarkType.leftHip]
        : landmarks[PoseLandmarkType.rightHip];
    final ankle = isLeftTracked
        ? landmarks[PoseLandmarkType.leftAnkle]
        : landmarks[PoseLandmarkType.rightAnkle];
    final elbow = isLeftTracked
        ? landmarks[PoseLandmarkType.leftElbow]
        : landmarks[PoseLandmarkType.rightElbow];
    final wrist = isLeftTracked
        ? landmarks[PoseLandmarkType.leftWrist]
        : landmarks[PoseLandmarkType.rightWrist];
    final knee = isLeftTracked
        ? landmarks[PoseLandmarkType.leftKnee]
        : landmarks[PoseLandmarkType.rightKnee];

    if (shoulder == null || hip == null || ankle == null) return false;

    final bodyAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    if (bodyAngle >= SphinxConfig.Aa_Start_Body_Angle) return true;

    if (elbow == null || wrist == null || knee == null) return false;
    if (![elbow, wrist, knee].every(ExerciseBase.isLandmarkConfident)) {
      return false;
    }

    final elbowAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
    final spineAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: knee);

    return elbowAngle >= SphinxConfig.Ab_Elbow_Hold_Angle[0] &&
        elbowAngle <= SphinxConfig.Al_Exit_Elbow_Angle &&
        spineAngle >= SphinxConfig.Ac_Spine_Ext_Angle[0] &&
        spineAngle <= SphinxConfig.Am_Exit_Spine_Angle;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    if (!_selectTrackedSide(smoothedLandmarks)) {
      _holdSeconds.resetTick();
      return;
    }

    final shoulder = isLeftTracked
        ? smoothedLandmarks[PoseLandmarkType.leftShoulder]
        : smoothedLandmarks[PoseLandmarkType.rightShoulder];
    final hip = isLeftTracked
        ? smoothedLandmarks[PoseLandmarkType.leftHip]
        : smoothedLandmarks[PoseLandmarkType.rightHip];
    final ankle = isLeftTracked
        ? smoothedLandmarks[PoseLandmarkType.leftAnkle]
        : smoothedLandmarks[PoseLandmarkType.rightAnkle];
    final elbow = isLeftTracked
        ? smoothedLandmarks[PoseLandmarkType.leftElbow]
        : smoothedLandmarks[PoseLandmarkType.rightElbow];
    final wrist = isLeftTracked
        ? smoothedLandmarks[PoseLandmarkType.leftWrist]
        : smoothedLandmarks[PoseLandmarkType.rightWrist];
    final knee = isLeftTracked
        ? smoothedLandmarks[PoseLandmarkType.leftKnee]
        : smoothedLandmarks[PoseLandmarkType.rightKnee];
    final ear = isLeftTracked
        ? smoothedLandmarks[PoseLandmarkType.leftEar]
        : smoothedLandmarks[PoseLandmarkType.rightEar];

    if (shoulder == null ||
        hip == null ||
        ankle == null ||
        elbow == null ||
        wrist == null ||
        knee == null ||
        ear == null) {
      _holdSeconds.resetTick();
      return;
    }

    final scaleFactor = calculateDistance(shoulder, hip);

    final ctx = SphinxContext(
      bodyAngle: calculateAngleNormalized(
          firstPoint: shoulder, midPoint: hip, lastPoint: ankle),
      elbowAngle: calculateAngleNormalized(
          firstPoint: shoulder, midPoint: elbow, lastPoint: wrist),
      spineAngle: calculateAngleNormalized(
          firstPoint: shoulder, midPoint: hip, lastPoint: knee),
      forearmAngle:
          calculateAbsoluteHorizontalAngle(point1: elbow, point2: wrist),
      upperArmAngle:
          calculateAbsoluteHorizontalAngle(point1: shoulder, point2: elbow),
      neckAngle: calculateAngleNormalized(
          firstPoint: ear, midPoint: shoulder, lastPoint: hip),
      hipY: hip.y,
      ankleY: ankle.y,
      earShoulderDist: calculateDistance(ear, shoulder),
      scaleFactor: scaleFactor,
      state: state,
      frameTimestampMs: frameTimestampMs,
      resultIssues: resultIssues,
    );

    _updateStateBuffer(ctx);

    if (state != SphinxState.proneSetup) {
      for (final m in _metrics) {
        m.update(ctx);
        debugData.addAll(m.debugData);
      }
    }

    if (state == SphinxState.isometricHold) {
      _holdSeconds.accumulate(
        elapsedMs: elapsedMs,
        faultingByKey: {
          'hip_seconds': hipMetric.isFaultingNow,
          'straight_arm_seconds': elbowMetric.isFaultingNow,
          'shrug_neck_seconds': neckMetric.isFaultingNow,
        },
      );
    } else {
      _holdSeconds.resetTick();
    }
  }

  void _updateStateBuffer(SphinxContext ctx) {
    SphinxState newState = state;

    switch (state) {
      case SphinxState.proneSetup:
        if (ctx.elbowAngle < SphinxConfig.Al_Exit_Elbow_Angle &&
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
        if (ctx.elbowAngle > SphinxConfig.Al_Exit_Elbow_Angle ||
            ctx.spineAngle > SphinxConfig.Am_Exit_Spine_Angle) {
          newState = SphinxState.descending;
        }
        break;

      case SphinxState.descending:
        newState = SphinxState.proneSetup;
        break;
    }

    // Logic xử lý chuyển trạng thái cũ
    if (newState != state) {
      final oldState = state;
      for (final m in _metrics) {
        m.onStateTransition(state, newState, ctx.frameTimestampMs);
      }
      prevState = state;
      state = newState;

      if (oldState == SphinxState.ascending &&
          newState == SphinxState.isometricHold) {
        _holdSeconds.resetTick();
        hipMetric.reset();
        elbowMetric.reset();
        neckMetric.reset();
      } else if (oldState == SphinxState.isometricHold) {
        _holdSeconds.resetTick();
      }
    }

    // --- LOGIC MỚI: ĐẾM REP THEO GIÂY TRONG LÚC HOLD ---
    if (state == SphinxState.isometricHold) {
      // Lấy thời gian hold thực tế đang diễn ra
      double liveHold = tempoMetric.getLiveHoldTime(ctx.frameTimestampMs);

      // Bài giữ: đủ thời gian thì hoàn thành, lỗi form được ghi vào báo cáo.
      if (liveHold >= maxSeconds) {
        // Chốt 1 rep ngay lập tức
        _completeRep(ctx);

        // Ép State Machine về trạng thái Nằm chuẩn bị (Prone Setup)
        prevState = SphinxState.descending;
        state = SphinxState.proneSetup;

        // Báo cho các metrics dọn dẹp state
        for (final m in _metrics) {
          m.onStateTransition(SphinxState.isometricHold, SphinxState.proneSetup,
              ctx.frameTimestampMs);
        }
        _holdSeconds.resetTick();
      }
    }
  }

  void _completeRep(SphinxContext ctx) {
    repCount += 1;
    tempoMetric.flushCurrentSegment(ctx.frameTimestampMs);

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
    _holdSeconds.resetTick();
  }

  bool _selectTrackedSide(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final left = _sideConfidence(
      landmarks,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftAnkle,
    );
    final right = _sideConfidence(
      landmarks,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.rightAnkle,
    );

    if (left == null && right == null) return false;
    isLeftTracked = right == null || (left ?? 0.0) >= right;
    return true;
  }

  double? _sideConfidence(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    PoseLandmarkType shoulderType,
    PoseLandmarkType hipType,
    PoseLandmarkType ankleType,
  ) {
    final shoulder = landmarks[shoulderType];
    final hip = landmarks[hipType];
    final ankle = landmarks[ankleType];
    if (shoulder == null || hip == null || ankle == null) return null;
    if (![shoulder, hip, ankle].every(ExerciseBase.isLandmarkConfident)) {
      return null;
    }
    return shoulder.likelihood + hip.likelihood + ankle.likelihood;
  }

  @override
  String get currentPhaseKey => state.name;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case SphinxState.proneSetup:
        return 'Nằm chuẩn bị';
      case SphinxState.ascending:
        return 'Nâng người';
      case SphinxState.isometricHold:
        return 'Giữ tĩnh';
      case SphinxState.descending:
        return 'Thoát thế';
    }
  }

  @override
  void onSetComplete() {
    if (state == SphinxState.isometricHold) {
      tempoMetric.flushCurrentSegment(frameTimestampMs);
    }
    logger.pushKey("active_hold_time", _lastHoldTime);
    logger.pushKey("stability_score", _lastStabilityScore);
    logger.pushKey("total_seconds", maxSeconds.toDouble());
    logger.pushKey(
        "good_seconds", _holdSeconds.goodSeconds.clamp(0.0, maxSeconds));
    logger.pushKey("hip_seconds", _holdSeconds.faultSecondsFor('hip_seconds'));
    logger.pushKey("straight_arm_seconds",
        _holdSeconds.faultSecondsFor('straight_arm_seconds'));
    logger.pushKey("shrug_neck_seconds",
        _holdSeconds.faultSecondsFor('shrug_neck_seconds'));
    logger.pushKey("max_rep", SphinxConfig.Af_Max_Reps);
    logger.pushGoodRepCount();
  }
}
