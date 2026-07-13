import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../utils/pose_math_helpers.dart';
import '../exercise_base.dart';
import '../hold/rep_counted_hold_exercise.dart';
import 'Metrics/elbow_angle_metric.dart';
import 'Metrics/hold_tempo_metric.dart';
import 'Metrics/neck_shoulder_metric.dart';
import 'Metrics/sphinx_metric_base.dart';

class _SphinxPoseFrame {
  const _SphinxPoseFrame({
    required this.bodyAngle,
    required this.elbowAngle,
    required this.spineAngle,
    required this.forearmAngle,
    required this.upperArmAngle,
    required this.neckAngle,
    required this.hipY,
    required this.ankleY,
    required this.earShoulderDistance,
  });

  final double bodyAngle;
  final double elbowAngle;
  final double spineAngle;
  final double forearmAngle;
  final double upperArmAngle;
  final double neckAngle;
  final double hipY;
  final double ankleY;
  final double earShoulderDistance;
}

class SphinxStretch extends RepCountedHoldExercise {
  SphinxStretch({
    required super.maxHolds,
    required super.holdSeconds,
  });

  int get maxSeconds => holdSeconds;

  bool isLeftTracked = true;
  _SphinxPoseFrame? _sampledFrame;
  double _lastHoldTime = 0.0;
  double _lastStabilityScore = 0.0;

  final HoldTempoMetric tempoMetric = HoldTempoMetric();
  final ElbowAngleMetric elbowMetric = ElbowAngleMetric();
  final NeckShoulderMetric neckMetric = NeckShoulderMetric();

  late final List<SphinxMetricBase> _metrics = <SphinxMetricBase>[
    tempoMetric,
    elbowMetric,
    neckMetric,
  ];

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'Sphinx Pose';

  @override
  int get holdingDebounceFrames => 1;

  @override
  int get droppingDebounceFrames => 1;

  @override
  String get currentPhaseLabel {
    switch (phase) {
      case HoldPhase.setup:
        return 'Nằm chuẩn bị';
      case HoldPhase.holding:
        return 'Giữ tư thế nhân sư';
      case HoldPhase.dropping:
        return 'Thoát thế';
      case HoldPhase.resting:
        return 'Nghỉ';
      case HoldPhase.reArming:
        return 'Vào tư thế';
    }
  }

  @override
  List<FaultRecord> get liveFaults {
    if (phase != HoldPhase.holding) return const <FaultRecord>[];

    final faults = <String, FaultRecord>{};
    final currentArmFault = elbowMetric.currentFault;
    if (elbowMetric.isFaultingNow && currentArmFault != null) {
      final mapped = _mapFaultRecord(currentArmFault);
      faults[mapped.type] = mapped;
    }
    if (neckMetric.isShrugFaultingNow) {
      final source = _faultOfType(neckMetric.faults, 'NeckShrug');
      if (source != null) {
        final mapped = _mapFaultRecord(source);
        faults[mapped.type] = mapped;
      }
    }
    if (neckMetric.isHyperFaultingNow) {
      final source = _faultOfType(neckMetric.faults, 'NeckHyper');
      if (source != null) {
        final mapped = _mapFaultRecord(source);
        faults[mapped.type] = mapped;
      }
    }
    return faults.values.toList(growable: false);
  }

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      interruptReArm();
      return const GuidanceSignal.turnSide();
    }
    if (!_selectTrackedSide(landmarks)) {
      interruptActiveHold(interruptedHoldFaultId);
      interruptReArm();
      return const GuidanceSignal.bodyInFrame();
    }
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (!_selectTrackedSide(landmarks)) return false;

    final shoulder = _point(
      landmarks,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    );
    final hip = _point(
      landmarks,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    );
    final ankle = _point(
      landmarks,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    );
    if (shoulder == null || hip == null || ankle == null) return false;

    final bodyAngle = calculateAngleNormalized(
      firstPoint: shoulder,
      midPoint: hip,
      lastPoint: ankle,
    );
    if (bodyAngle >= SphinxConfig.Aa_Start_Body_Angle) return true;

    final elbow = _point(
      landmarks,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
    );
    final wrist = _point(
      landmarks,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
    );
    final knee = _point(
      landmarks,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
    );
    if (elbow == null || wrist == null || knee == null) return false;
    if (!<PoseLandmark>[elbow, wrist, knee]
        .every(ExerciseBase.isLandmarkConfident)) {
      return false;
    }

    final elbowAngle = calculateAngleNormalized(
      firstPoint: shoulder,
      midPoint: elbow,
      lastPoint: wrist,
    );
    final spineAngle = calculateAngleNormalized(
      firstPoint: shoulder,
      midPoint: hip,
      lastPoint: knee,
    );
    return elbowAngle >= SphinxConfig.Ab_Elbow_Hold_Angle[0] &&
        elbowAngle <= SphinxConfig.Al_Exit_Elbow_Angle &&
        spineAngle >= SphinxConfig.Ac_Spine_Ext_Angle[0] &&
        spineAngle <= SphinxConfig.Am_Exit_Spine_Angle;
  }

  @override
  Set<String> get faultSecondsKeys => const <String>{
        'straight_arm_seconds',
        'shrug_neck_seconds',
      };

  @override
  HoldPoseSample? samplePose(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    if (!_selectTrackedSide(landmarks)) return null;

    final shoulder = _point(
      landmarks,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    );
    final hip = _point(
      landmarks,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    );
    final ankle = _point(
      landmarks,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    );
    final elbow = _point(
      landmarks,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
    );
    final wrist = _point(
      landmarks,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
    );
    final knee = _point(
      landmarks,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
    );
    final ear = _point(
      landmarks,
      PoseLandmarkType.leftEar,
      PoseLandmarkType.rightEar,
    );
    if (shoulder == null ||
        hip == null ||
        ankle == null ||
        elbow == null ||
        wrist == null ||
        knee == null ||
        ear == null) {
      return null;
    }

    scaleFactor = calculateDistance(shoulder, hip);
    if (!scaleFactor.isFinite || scaleFactor <= 1e-6) return null;

    final elbowAngle = calculateAngleNormalized(
      firstPoint: shoulder,
      midPoint: elbow,
      lastPoint: wrist,
    );
    final spineAngle = calculateAngleNormalized(
      firstPoint: shoulder,
      midPoint: hip,
      lastPoint: knee,
    );

    _sampledFrame = _SphinxPoseFrame(
      bodyAngle: calculateAngleNormalized(
        firstPoint: shoulder,
        midPoint: hip,
        lastPoint: ankle,
      ),
      elbowAngle: elbowAngle,
      spineAngle: spineAngle,
      forearmAngle:
          calculateAbsoluteHorizontalAngle(point1: elbow, point2: wrist),
      upperArmAngle:
          calculateAbsoluteHorizontalAngle(point1: shoulder, point2: elbow),
      neckAngle: calculateAngleNormalized(
        firstPoint: ear,
        midPoint: shoulder,
        lastPoint: hip,
      ),
      hipY: hip.y,
      ankleY: ankle.y,
      earShoulderDistance: calculateDistance(ear, shoulder),
    );

    return HoldPoseSample(
      insideOuterEntry: elbowAngle >= SphinxConfig.Ab_Elbow_Hold_Angle[0] &&
          elbowAngle <= SphinxConfig.Ab_Elbow_Hold_Angle[1] &&
          spineAngle >= SphinxConfig.Ac_Spine_Ext_Angle[0] &&
          spineAngle <= SphinxConfig.Ac_Spine_Ext_Angle[1],
      outsideOuterExit: elbowAngle > SphinxConfig.Al_Exit_Elbow_Angle ||
          spineAngle > SphinxConfig.Am_Exit_Spine_Angle,
    );
  }

  @override
  Map<String, bool> updateFormMetrics() {
    final sample = _sampledFrame!;
    final context = SphinxContext(
      bodyAngle: sample.bodyAngle,
      elbowAngle: sample.elbowAngle,
      spineAngle: sample.spineAngle,
      forearmAngle: sample.forearmAngle,
      upperArmAngle: sample.upperArmAngle,
      neckAngle: sample.neckAngle,
      hipY: sample.hipY,
      ankleY: sample.ankleY,
      earShoulderDist: sample.earShoulderDistance,
      scaleFactor: scaleFactor,
      state: _legacyStateFor(phase),
      frameTimestampMs: frameTimestampMs,
      resultIssues: resultIssues,
    );

    if (phase == HoldPhase.holding || phase == HoldPhase.dropping) {
      for (final metric in _metrics) {
        metric.update(context);
        debugData.addAll(metric.debugData);
      }
    }

    return <String, bool>{
      'straight_arm_seconds': elbowMetric.isFaultingNow,
      'shrug_neck_seconds': neckMetric.isFaultingNow,
    };
  }

  @override
  Map<String, FaultRecord> snapshotHoldFaults() {
    final faults = <String, FaultRecord>{};
    for (final fault in elbowMetric.faults) {
      final mapped = _mapFaultRecord(fault);
      faults[mapped.type] = mapped;
    }
    for (final fault in neckMetric.faults) {
      final mapped = _mapFaultRecord(fault);
      faults[mapped.type] = mapped;
    }
    return faults;
  }

  @override
  void resetFormMetrics({required bool countFaults}) {
    for (final metric in _metrics) {
      if (countFaults) {
        metric.resetAndCountFault();
      } else {
        metric.reset();
      }
    }
  }

  @override
  void onHoldPhaseChanged(
    HoldPhase previous,
    HoldPhase next,
    int nowMs,
  ) {
    final oldState = _legacyStateFor(previous);
    final newState = _legacyStateFor(next);
    for (final metric in _metrics) {
      metric.onStateTransition(oldState, newState, nowMs);
    }
  }

  @override
  Map<String, dynamic> holdRepLogExtras() {
    _lastHoldTime = timerMetric.totalHoldingTimeMs / 1000.0;
    _lastStabilityScore = tempoMetric.stabilityScore;
    return <String, dynamic>{
      'active_hold_time': _lastHoldTime,
      'stability_score': _lastStabilityScore,
    };
  }

  @override
  void onHoldSetReset() {
    _sampledFrame = null;
    _lastHoldTime = 0.0;
    _lastStabilityScore = 0.0;
  }

  @override
  void onSetComplete() {
    final targetSeconds = (maxHolds * holdSeconds).toDouble();
    logger.pushKey('active_hold_time', _lastHoldTime);
    logger.pushKey('stability_score', _lastStabilityScore);
    logger.pushKey('total_seconds', targetSeconds);
    logger.pushKey('good_seconds', clampedGoodHoldSeconds(targetSeconds));
    logger.pushKey('hip_seconds', 0.0);
    logger.pushKey(
      'straight_arm_seconds',
      faultHoldSecondsFor('straight_arm_seconds'),
    );
    logger.pushKey(
      'shrug_neck_seconds',
      faultHoldSecondsFor('shrug_neck_seconds'),
    );
    logger.pushKey('max_rep', maxHolds);
    logger.pushGoodRepCount();
  }

  SphinxState _legacyStateFor(HoldPhase holdPhase) {
    switch (holdPhase) {
      case HoldPhase.holding:
        return SphinxState.isometricHold;
      case HoldPhase.dropping:
        return SphinxState.descending;
      case HoldPhase.setup:
      case HoldPhase.resting:
      case HoldPhase.reArming:
        return SphinxState.proneSetup;
    }
  }

  FaultRecord _mapFaultRecord(FaultRecord fault) {
    final type = switch (fault.type) {
      'StraightArm' => 'straight_arm',
      'Forearm' => 'forearm',
      'UpperArm' => 'upper_arm',
      'NeckShrug' => 'shrug',
      'NeckHyper' => 'neck',
      _ => fault.type,
    };
    return FaultRecord(
      phase: phase.name,
      type: type,
      message: fault.message,
      affectsForm: fault.affectsForm,
      voiceMessage: fault.voiceMessage,
      priority: fault.priority,
    );
  }

  FaultRecord? _faultOfType(Iterable<FaultRecord> faults, String type) {
    for (final fault in faults) {
      if (fault.type == type) return fault;
    }
    return null;
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
    if (!<PoseLandmark>[shoulder, hip, ankle]
        .every(ExerciseBase.isLandmarkConfident)) {
      return null;
    }
    return shoulder.likelihood + hip.likelihood + ankle.likelihood;
  }

  PoseLandmark? _point(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    PoseLandmarkType left,
    PoseLandmarkType right,
  ) {
    return landmarks[isLeftTracked ? left : right];
  }
}
