import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../utils/pose_math_helpers.dart';
import '../exercise_base.dart';
import '../hold/rep_counted_hold_exercise.dart';
import 'metrics/ankle_dorsiflexion_metric.dart';
import 'metrics/hold_tempo_metric.dart';
import 'metrics/knee_extension_metric.dart';
import 'metrics/seated_forward_metric_base.dart';
import 'metrics/spinal_alignment_metric.dart';

class _SeatedForwardPoseFrame {
  const _SeatedForwardPoseFrame({
    required this.kneeAngle,
    required this.hipAngle,
    required this.hipVelocity,
    required this.spineAngle,
    required this.ankleAngle,
  });

  final double kneeAngle;
  final double hipAngle;
  final double hipVelocity;
  final double spineAngle;
  final double ankleAngle;
}

class SeatedForwardFold extends RepCountedHoldExercise {
  SeatedForwardFold({
    required super.maxHolds,
    required super.holdSeconds,
  }) : tempoMetric = HoldTempoMetric(minHoldSeconds: holdSeconds);

  int get maxSeconds => holdSeconds;

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  bool isLeftTracked = true;

  double _minHipAngleThisRep = 999.0;
  double _lastMaxDepth = 0.0;
  double? _setupHipAngle;
  double _lastHipAngle = -1.0;
  int _lastTimestampMs = -1;
  double _currentVelocity = 0.0;
  int? _stableStartTimeMs;
  _SeatedForwardPoseFrame? _sampledFrame;

  final KneeExtensionMetric kneeMetric = KneeExtensionMetric();
  final SpinalAlignmentMetric spineMetric = SpinalAlignmentMetric();
  final HoldTempoMetric tempoMetric;
  final AnkleDorsiflexionMetric ankleMetric = AnkleDorsiflexionMetric();

  late final List<SeatedForwardMetricBase> _metrics = <SeatedForwardMetricBase>[
    kneeMetric,
    spineMetric,
    tempoMetric,
    ankleMetric,
  ];

  @override
  String get exerciseName => 'Seated Forward Fold';

  @override
  int get holdingDebounceFrames => 1;

  @override
  int get droppingDebounceFrames => 1;

  @override
  String get currentPhaseLabel {
    switch (phase) {
      case HoldPhase.setup:
        return 'Chuẩn bị';
      case HoldPhase.holding:
        return 'Giữ tư thế gập';
      case HoldPhase.dropping:
        return 'Nhả cơ';
      case HoldPhase.resting:
        return 'Nghỉ';
      case HoldPhase.reArming:
        return 'Vào tư thế';
    }
  }

  @override
  List<FaultRecord> get liveFaults {
    final faults = <String, FaultRecord>{};
    if (phase == HoldPhase.holding) {
      if (kneeMetric.isFaultingNow) {
        _addMappedFaults(faults, kneeMetric.faults);
      }
      if (spineMetric.isFaultingNow) {
        _addMappedFaults(faults, spineMetric.faults);
      }
      if (ankleMetric.isFaultingNow) {
        _addMappedFaults(faults, ankleMetric.faults);
      }
    } else if (phase == HoldPhase.dropping) {
      _addMappedFaults(
        faults,
        tempoMetric.faults.where((fault) => fault.type == 'TempoShort'),
      );
    }
    return faults.values.toList(growable: false);
  }

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (!_updateTrackedSide()) {
      interruptReArm();
      return const GuidanceSignal.turnSide();
    }

    for (final type in _requiredLandmarks) {
      final landmark = landmarks[type];
      if (landmark == null || !ExerciseBase.isLandmarkConfident(landmark)) {
        interruptActiveHold(interruptedHoldFaultId);
        interruptReArm();
        return const GuidanceSignal.bodyInFrame();
      }
    }
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (!_updateTrackedSide()) return false;
    final body = _body(landmarks);
    if (body == null || !body.all.every(ExerciseBase.isLandmarkConfident)) {
      return false;
    }

    final hipAngle = calculateAngleNormalized(
      firstPoint: body.shoulder,
      midPoint: body.hip,
      lastPoint: body.knee,
    );
    final kneeAngle = calculateAngleNormalized(
      firstPoint: body.hip,
      midPoint: body.knee,
      lastPoint: body.heel,
    );

    debugData['SeatedForwardSetup'] = <String, String>{
      'cameraFacing': cameraFacing.name,
      'trackedSide': isLeftTracked ? 'left' : 'right',
      'hipAngle': hipAngle.toStringAsFixed(1),
      'kneeAngle': kneeAngle.toStringAsFixed(1),
    };

    final isValid = kneeAngle >= SeatedForwardConfig.Ak_Start_Knee_Angle &&
        hipAngle >= SeatedForwardConfig.Ah_Start_Hip_Angle[0] &&
        hipAngle <= SeatedForwardConfig.Ah_Start_Hip_Angle[1];
    if (isValid) _setupHipAngle = hipAngle;
    return isValid;
  }

  @override
  Set<String> get faultSecondsKeys => const <String>{
        'knee_bent_seconds',
        'spine_round_seconds',
      };

  @override
  HoldPoseSample? samplePose(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    if (!_updateTrackedSide()) return null;
    final body = _body(landmarks);
    if (body == null || !body.all.every(ExerciseBase.isLandmarkConfident)) {
      return null;
    }

    final hipAngle = calculateAngleNormalized(
      firstPoint: body.shoulder,
      midPoint: body.hip,
      lastPoint: body.knee,
    );
    if (_lastHipAngle >= 0 && _lastTimestampMs > 0) {
      final deltaSeconds = (frameTimestampMs - _lastTimestampMs) / 1000.0;
      if (deltaSeconds > 0) {
        _currentVelocity = (hipAngle - _lastHipAngle) / deltaSeconds;
      }
    } else {
      _currentVelocity = 0.0;
    }
    _lastHipAngle = hipAngle;
    _lastTimestampMs = frameTimestampMs;

    scaleFactor = calculateDistance(body.shoulder, body.hip);
    if (!scaleFactor.isFinite || scaleFactor <= 1e-6) return null;

    if (hipAngle < _minHipAngleThisRep) {
      _minHipAngleThisRep = hipAngle;
    }

    final atDepth = hipAngle < _targetDepth();
    final stable =
        _currentVelocity.abs() < SeatedForwardConfig.Av_Stable_Velocity;
    if (atDepth && stable) {
      _stableStartTimeMs ??= frameTimestampMs;
    } else {
      _stableStartTimeMs = null;
    }
    final stableAtDepth = _stableStartTimeMs != null &&
        frameTimestampMs - _stableStartTimeMs! >= 1000;
    final releasedEarly = _minHipAngleThisRep < 999.0 &&
        hipAngle >
            _minHipAngleThisRep + SeatedForwardConfig.Ascending_Threshold;

    _sampledFrame = _SeatedForwardPoseFrame(
      kneeAngle: calculateAngleNormalized(
        firstPoint: body.hip,
        midPoint: body.knee,
        lastPoint: body.heel,
      ),
      hipAngle: hipAngle,
      hipVelocity: _currentVelocity,
      spineAngle: calculateAngleNormalized(
        firstPoint: body.ear,
        midPoint: body.shoulder,
        lastPoint: body.hip,
      ),
      ankleAngle: calculateAngleNormalized(
        firstPoint: body.knee,
        midPoint: body.heel,
        lastPoint: body.toe,
      ),
    );

    return HoldPoseSample(
      insideOuterEntry: stableAtDepth,
      outsideOuterExit: releasedEarly,
    );
  }

  @override
  Map<String, bool> updateFormMetrics() {
    final sample = _sampledFrame!;
    final context = SeatedForwardContext(
      kneeAngle: sample.kneeAngle,
      hipAngle: sample.hipAngle,
      hipVelocity: sample.hipVelocity,
      spineAngle: sample.spineAngle,
      ankleAngle: sample.ankleAngle,
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

    debugData['SeatedForwardDebug'] = <String, dynamic>{
      'state': phase.name,
      'trackedSide': isLeftTracked ? 'left' : 'right',
      'hipAngle': sample.hipAngle.toStringAsFixed(1),
      'hipVelocity': sample.hipVelocity.toStringAsFixed(1),
      'targetDepth': _targetDepth().toStringAsFixed(1),
      'liveHold': liveHoldSeconds?.toStringAsFixed(1),
      'repCount': repCount,
    };

    return <String, bool>{
      'knee_bent_seconds': kneeMetric.isFaultingNow,
      'spine_round_seconds': spineMetric.isFaultingNow,
    };
  }

  @override
  Map<String, FaultRecord> snapshotHoldFaults() {
    final faults = <String, FaultRecord>{};
    for (final metric in _metrics) {
      _addMappedFaults(faults, metric.faults);
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

    if (previous == HoldPhase.holding && next == HoldPhase.resting) {
      _lastMaxDepth = _minHipAngleThisRep;
    }
    if (next == HoldPhase.dropping) {
      _stableStartTimeMs = null;
    } else if (next == HoldPhase.setup || next == HoldPhase.reArming) {
      _resetAttemptGeometry();
    }
  }

  @override
  Map<String, dynamic> holdRepLogExtras() => <String, dynamic>{
        'max_depth_angle': _lastMaxDepth,
      };

  @override
  void onHoldSetReset() {
    _sampledFrame = null;
    _lastMaxDepth = 0.0;
    _resetAttemptGeometry();
  }

  @override
  void onSetComplete() {
    final targetSeconds = (maxHolds * holdSeconds).toDouble();
    logger.pushKey('total_seconds', targetSeconds);
    logger.pushKey('good_seconds', clampedGoodHoldSeconds(targetSeconds));
    logger.pushKey(
      'knee_bent_seconds',
      faultHoldSecondsFor('knee_bent_seconds'),
    );
    logger.pushKey(
      'spine_round_seconds',
      faultHoldSecondsFor('spine_round_seconds'),
    );
  }

  void _resetAttemptGeometry() {
    _minHipAngleThisRep = 999.0;
    _lastHipAngle = -1.0;
    _lastTimestampMs = -1;
    _currentVelocity = 0.0;
    _stableStartTimeMs = null;
  }

  double _targetDepth() {
    final setupTarget =
        (_setupHipAngle ?? 90.0) - SeatedForwardConfig.Ah_Min_Fold_From_Setup;
    return setupTarget > SeatedForwardConfig.Ah_Hold_Safety_Floor
        ? setupTarget
        : SeatedForwardConfig.Ah_Hold_Safety_Floor;
  }

  SeatedForwardState _legacyStateFor(HoldPhase holdPhase) {
    switch (holdPhase) {
      case HoldPhase.holding:
        return SeatedForwardState.isometricHold;
      case HoldPhase.dropping:
        return SeatedForwardState.ascending;
      case HoldPhase.setup:
      case HoldPhase.resting:
      case HoldPhase.reArming:
        return SeatedForwardState.setup;
    }
  }

  void _addMappedFaults(
    Map<String, FaultRecord> target,
    Iterable<FaultRecord> source,
  ) {
    for (final fault in source) {
      final mapped = _mapFaultRecord(fault);
      target[mapped.type] = mapped;
    }
  }

  FaultRecord _mapFaultRecord(FaultRecord fault) {
    final type = switch (fault.type) {
      'KneeBent' => 'knee',
      'SpineRound' => 'spine',
      'AnklePlantar' => 'ankle',
      'TempoShort' => 'tempo',
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

  bool _updateTrackedSide() {
    if (cameraFacing == CameraFacing.left) {
      isLeftTracked = true;
      return true;
    }
    if (cameraFacing == CameraFacing.right) {
      isLeftTracked = false;
      return true;
    }
    return false;
  }

  List<PoseLandmarkType> get _requiredLandmarks => <PoseLandmarkType>[
        isLeftTracked ? PoseLandmarkType.leftEar : PoseLandmarkType.rightEar,
        isLeftTracked
            ? PoseLandmarkType.leftShoulder
            : PoseLandmarkType.rightShoulder,
        isLeftTracked ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip,
        isLeftTracked ? PoseLandmarkType.leftKnee : PoseLandmarkType.rightKnee,
        isLeftTracked ? PoseLandmarkType.leftHeel : PoseLandmarkType.rightHeel,
        isLeftTracked
            ? PoseLandmarkType.leftFootIndex
            : PoseLandmarkType.rightFootIndex,
      ];

  _SeatedForwardLandmarks? _body(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final ear = landmarks[
        isLeftTracked ? PoseLandmarkType.leftEar : PoseLandmarkType.rightEar];
    final shoulder = landmarks[isLeftTracked
        ? PoseLandmarkType.leftShoulder
        : PoseLandmarkType.rightShoulder];
    final hip = landmarks[
        isLeftTracked ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip];
    final knee = landmarks[
        isLeftTracked ? PoseLandmarkType.leftKnee : PoseLandmarkType.rightKnee];
    final heel = landmarks[
        isLeftTracked ? PoseLandmarkType.leftHeel : PoseLandmarkType.rightHeel];
    final toe = landmarks[isLeftTracked
        ? PoseLandmarkType.leftFootIndex
        : PoseLandmarkType.rightFootIndex];

    if (ear == null ||
        shoulder == null ||
        hip == null ||
        knee == null ||
        heel == null ||
        toe == null) {
      return null;
    }
    return _SeatedForwardLandmarks(
      ear: ear,
      shoulder: shoulder,
      hip: hip,
      knee: knee,
      heel: heel,
      toe: toe,
    );
  }
}

class _SeatedForwardLandmarks {
  const _SeatedForwardLandmarks({
    required this.ear,
    required this.shoulder,
    required this.hip,
    required this.knee,
    required this.heel,
    required this.toe,
  });

  final PoseLandmark ear;
  final PoseLandmark shoulder;
  final PoseLandmark hip;
  final PoseLandmark knee;
  final PoseLandmark heel;
  final PoseLandmark toe;

  List<PoseLandmark> get all => <PoseLandmark>[
        ear,
        shoulder,
        hip,
        knee,
        heel,
        toe,
      ];
}
