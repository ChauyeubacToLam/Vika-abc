import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';
import 'metrics/seated_forward_metric_base.dart';
import 'metrics/knee_extension_metric.dart';
import 'metrics/spinal_alignment_metric.dart';
import 'metrics/hold_tempo_metric.dart';
import 'metrics/ankle_dorsiflexion_metric.dart';

class SeatedForwardFold extends ExerciseBase {
  SeatedForwardFold({
    this.maxSeconds = SeatedForwardConfig.At_Min_Hold_Time,
    this.maxHolds = SeatedForwardConfig.At_Num_Holds,
  }) : tempoMetric = HoldTempoMetric(minHoldSeconds: maxSeconds);

  final int maxSeconds;
  final int maxHolds;

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  SeatedForwardState state = SeatedForwardState.setup;
  SeatedForwardState prevState = SeatedForwardState.setup;
  bool isLeftTracked = true;

  double _minHipAngleThisRep = 999.0;
  double _lastMaxDepth = 0.0;
  double? _userMaxRom;

  double _lastHipAngle = -1.0;
  int _lastTimestampMs = -1;
  double _currentVelocity = 0.0;
  int? _stableStartTimeMs;
  final HoldSecondsAccumulator _holdSeconds = HoldSecondsAccumulator(const [
    'knee_bent_seconds',
    'spine_round_seconds',
  ]);

  final KneeExtensionMetric kneeMetric = KneeExtensionMetric();
  final SpinalAlignmentMetric spineMetric = SpinalAlignmentMetric();
  final HoldTempoMetric tempoMetric;
  final AnkleDorsiflexionMetric ankleMetric = AnkleDorsiflexionMetric();

  late final List<SeatedForwardMetricBase> _metrics = [
    kneeMetric,
    spineMetric,
    tempoMetric,
    ankleMetric,
  ];

  @override
  String get exerciseName => 'Seated Forward Fold';

  @override
  bool requestStop() => repCount >= maxHolds;

  @override
  void onExerciseActivated() {
    super.onExerciseActivated();
    _holdSeconds.reset();
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (!_updateTrackedSide()) {
      return 'Vui lòng đặt camera quay ngang hông (Side View).';
    }

    for (final type in _requiredLandmarks) {
      final landmark = landmarks[type];
      if (landmark == null || !ExerciseBase.isLandmarkConfident(landmark)) {
        return 'Các điểm khớp bị khuất. Hãy ngồi trọn trong khung hình.';
      }
    }
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (!_updateTrackedSide()) return false;
    final body = _body(landmarks);
    if (body == null) return false;

    final ah = calculateAngleNormalized(
      firstPoint: body.shoulder,
      midPoint: body.hip,
      lastPoint: body.knee,
    );
    final ak = calculateAngleNormalized(
      firstPoint: body.hip,
      midPoint: body.knee,
      lastPoint: body.heel,
    );

    debugData['SeatedForwardSetup'] = {
      'cameraFacing': cameraFacing.name,
      'trackedSide': isLeftTracked ? 'left' : 'right',
      'hipAngle': ah.toStringAsFixed(1),
      'kneeAngle': ak.toStringAsFixed(1),
    };

    return ak >= SeatedForwardConfig.Ak_Start_Knee_Angle &&
        ah >= SeatedForwardConfig.Ah_Start_Hip_Angle[0] &&
        ah <= SeatedForwardConfig.Ah_Start_Hip_Angle[1];
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    if (!_updateTrackedSide()) {
      _holdSeconds.resetTick();
      return;
    }
    final body = _body(smoothedLandmarks);
    if (body == null) {
      _holdSeconds.resetTick();
      return;
    }

    final ah = calculateAngleNormalized(
      firstPoint: body.shoulder,
      midPoint: body.hip,
      lastPoint: body.knee,
    );
    if (_lastHipAngle >= 0 && _lastTimestampMs > 0) {
      final dt = (frameTimestampMs - _lastTimestampMs) / 1000.0;
      if (dt > 0) _currentVelocity = (ah - _lastHipAngle) / dt;
    }
    _lastHipAngle = ah;
    _lastTimestampMs = frameTimestampMs;

    final scale = calculateDistance(body.shoulder, body.hip);
    if (scale <= 1e-6) {
      _holdSeconds.resetTick();
      return;
    }

    final ctx = SeatedForwardContext(
      kneeAngle: calculateAngleNormalized(
        firstPoint: body.hip,
        midPoint: body.knee,
        lastPoint: body.heel,
      ),
      hipAngle: ah,
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
      scaleFactor: scale,
      state: state,
      frameTimestampMs: frameTimestampMs,
      resultIssues: resultIssues,
    );

    _updateStateBuffer(ctx);

    debugData['SeatedForwardDebug'] = {
      'state': state.name,
      'trackedSide': isLeftTracked ? 'left' : 'right',
      'hipAngle': ctx.hipAngle.toStringAsFixed(1),
      'hipVelocity': ctx.hipVelocity.toStringAsFixed(1),
      'targetDepth': _targetDepth().toStringAsFixed(1),
      'liveHold': liveHoldSeconds?.toStringAsFixed(1),
      'repCount': repCount,
    };

    if (state != SeatedForwardState.setup) {
      for (final m in _metrics) {
        m.update(ctx);
        debugData.addAll(m.debugData);
      }
    }

    if (state == SeatedForwardState.isometricHold) {
      _holdSeconds.accumulate(
        elapsedMs: elapsedMs,
        faultingByKey: {
          'knee_bent_seconds': kneeMetric.isFaultingNow,
          'spine_round_seconds': spineMetric.isFaultingNow,
        },
      );
    } else {
      _holdSeconds.resetTick();
    }
  }

  void _updateStateBuffer(SeatedForwardContext ctx) {
    var newState = state;

    switch (state) {
      case SeatedForwardState.setup:
        final movedFromStart =
            ctx.hipAngle < SeatedForwardConfig.Ah_Start_Hip_Angle[0] - 5.0;
        if (ctx.hipAngle < SeatedForwardConfig.Ah_Start_Hip_Angle[0] &&
            (ctx.hipVelocity < -10.0 || movedFromStart)) {
          newState = SeatedForwardState.descending;
        }
        break;

      case SeatedForwardState.descending:
        if (ctx.hipAngle < _minHipAngleThisRep) {
          _minHipAngleThisRep = ctx.hipAngle;
        }

        final targetDepth = _targetDepth();
        if (ctx.hipAngle < targetDepth &&
            ctx.hipVelocity.abs() < SeatedForwardConfig.Av_Stable_Velocity) {
          _stableStartTimeMs ??= ctx.frameTimestampMs;
          if (ctx.frameTimestampMs - _stableStartTimeMs! >= 2000) {
            newState = SeatedForwardState.isometricHold;
            _stableStartTimeMs = null;
          }
        } else {
          _stableStartTimeMs = null;
        }
        break;

      case SeatedForwardState.isometricHold:
        if (ctx.hipAngle < _minHipAngleThisRep) {
          _minHipAngleThisRep = ctx.hipAngle;
        }
        if (ctx.hipAngle >
            _minHipAngleThisRep + SeatedForwardConfig.Ascending_Threshold) {
          newState = SeatedForwardState.ascending;
        }
        break;

      case SeatedForwardState.ascending:
        if (ctx.hipAngle > SeatedForwardConfig.Ah_Start_Hip_Angle[0] - 10) {
          newState = SeatedForwardState.setup;
        }
        break;
    }

    if (newState != state) {
      for (final m in _metrics) {
        m.onStateTransition(state, newState, ctx.frameTimestampMs);
      }
      prevState = state;
      state = newState;

      if (state == SeatedForwardState.setup &&
          prevState == SeatedForwardState.ascending) {
        _completeRep(ctx);
      }
    }
  }

  double _targetDepth() {
    return _userMaxRom != null
        ? _userMaxRom! * 1.15
        : SeatedForwardConfig.Ah_Hold_Safety_Floor;
  }

  void _completeRep(SeatedForwardContext ctx) {
    repCount += 1;
    _lastMaxDepth = _minHipAngleThisRep;
    if (_userMaxRom == null || _lastMaxDepth < _userMaxRom!) {
      _userMaxRom = _lastMaxDepth;
    }

    final allFaults = <FaultRecord>[
      ...kneeMetric.faults,
      ...spineMetric.faults,
      ...tempoMetric.faults,
      ...ankleMetric.faults,
    ];

    correctForm = !allFaults.any((f) =>
        f.priority == SeatedForwardFaultVoicePriority.kneeBent ||
        f.priority == SeatedForwardFaultVoicePriority.spineRound);

    logger.addRepLog(RepLog(
      repNumber: repCount,
      correctForm: correctForm,
      data: {
        'max_depth_angle': _lastMaxDepth,
        'hold_time': tempoMetric.activeHoldSeconds,
        'fault_types': allFaults.map((f) => f.type).toSet().toList(),
      },
    ));

    _minHipAngleThisRep = 999.0;
    _stableStartTimeMs = null;
    for (final m in _metrics) {
      m.resetAndCountFault();
    }
  }

  @override
  String get currentPhaseKey => state.name;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case SeatedForwardState.setup:
        return 'Chuẩn bị';
      case SeatedForwardState.descending:
        return 'Gập người';
      case SeatedForwardState.isometricHold:
        return 'Giữ tĩnh';
      case SeatedForwardState.ascending:
        return 'Nhả cơ';
    }
  }

  @override
  double? get liveHoldSeconds => state == SeatedForwardState.isometricHold
      ? tempoMetric.getLiveHoldTime(frameTimestampMs)
      : null;

  @override
  double? get liveHoldTargetSeconds => maxSeconds.toDouble();

  @override
  void onSetComplete() {
    final targetSeconds = (maxHolds * maxSeconds).toDouble();
    logger.pushKey('total_seconds', targetSeconds);
    logger.pushKey(
      'good_seconds',
      _holdSeconds.goodSeconds.clamp(0.0, targetSeconds),
    );
    logger.pushKey(
        'knee_bent_seconds', _holdSeconds.faultSecondsFor('knee_bent_seconds'));
    logger.pushKey('spine_round_seconds',
        _holdSeconds.faultSecondsFor('spine_round_seconds'));
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

  List<PoseLandmarkType> get _requiredLandmarks => [
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
      Map<PoseLandmarkType, PoseLandmark> landmarks) {
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
  final PoseLandmark ear;
  final PoseLandmark shoulder;
  final PoseLandmark hip;
  final PoseLandmark knee;
  final PoseLandmark heel;
  final PoseLandmark toe;

  const _SeatedForwardLandmarks({
    required this.ear,
    required this.shoulder,
    required this.hip,
    required this.knee,
    required this.heel,
    required this.toe,
  });
}
