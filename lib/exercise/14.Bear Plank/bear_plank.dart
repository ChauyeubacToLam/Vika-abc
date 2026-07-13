// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../utils/pose_math_helpers.dart';
import '../exercise_base.dart';
import '../hold/rep_counted_hold_exercise.dart';
import 'metrics/bear_plank_metric_base.dart';
import 'metrics/flat_back_metric.dart';
import 'metrics/knee_hover_metric.dart';
import 'metrics/weight_distribution_metric.dart';

class _BearPoseFrame {
  const _BearPoseFrame({
    required this.kneeHeightOffset,
    required this.kneeAngle,
    required this.backYOffset,
    required this.shoulderWristXOffset,
    required this.isHoveringForm,
  });

  final double kneeHeightOffset;
  final double kneeAngle;
  final double backYOffset;
  final double shoulderWristXOffset;
  final bool isHoveringForm;
}

class BearPlank extends RepCountedHoldExercise {
  BearPlank({
    required super.maxHolds,
    required super.holdSeconds,
  });

  int get maxSeconds => holdSeconds;

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  int? _exerciseStartTimeMs;
  _BearPoseFrame? _sampledFrame;

  final List<Map<String, dynamic>> _telemetryLog = <Map<String, dynamic>>[];

  final KneeHoverMetric kneeMetric = KneeHoverMetric();
  final FlatBackMetric backMetric = FlatBackMetric();
  final WeightDistributionMetric weightMetric = WeightDistributionMetric();

  late final List<BearMetricBase> _metrics = <BearMetricBase>[
    kneeMetric,
    backMetric,
    weightMetric,
  ];

  @override
  String get exerciseName => 'Bear Plank';

  @override
  int get holdingDebounceFrames => 3;

  @override
  int get droppingDebounceFrames => 5;

  @override
  String get currentPhaseLabel {
    switch (phase) {
      case HoldPhase.setup:
        return 'Vào vị trí plank gấu';
      case HoldPhase.holding:
        return 'Giữ plank gấu';
      case HoldPhase.dropping:
        return 'Vào lại tư thế';
      case HoldPhase.resting:
        return 'Nghỉ';
      case HoldPhase.reArming:
        return 'Vào tư thế';
    }
  }

  @override
  List<FaultRecord> get liveFaults {
    final sample = _sampledFrame;
    if (sample == null) return const <FaultRecord>[];
    if (phase != HoldPhase.holding && phase != HoldPhase.dropping) {
      return const <FaultRecord>[];
    }

    final faults = <FaultRecord>[];
    final kneeFaultType = sample.kneeHeightOffset < BearConfig.KNEE_HOVER_MIN
        ? 'KneeTouchingFloor'
        : sample.kneeHeightOffset > BearConfig.KNEE_HOVER_MAX
            ? 'ButtTooHigh'
            : null;
    final kneeFault = _faultOfType(kneeMetric.faults, kneeFaultType);
    if (kneeFault != null) faults.add(_mapFaultRecord(kneeFault));

    if (phase == HoldPhase.holding && backMetric.isFaultingNow) {
      final backFaultType = sample.backYOffset > BearConfig.BACK_SAG_THRESHOLD
          ? 'BackSagging'
          : sample.backYOffset < -BearConfig.BACK_ARCH_THRESHOLD
              ? 'BackArching'
              : null;
      final backFault = _faultOfType(backMetric.faults, backFaultType);
      if (backFault != null) faults.add(_mapFaultRecord(backFault));
    }
    if (phase == HoldPhase.holding && weightMetric.isFaultingNow) {
      final weightFault = _faultOfType(weightMetric.faults, 'WeightForward');
      if (weightFault != null) faults.add(_mapFaultRecord(weightFault));
    }
    return faults;
  }

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      interruptReArm();
      return const GuidanceSignal.turnSide();
    }
    if (_getLandmarks(landmarks) == null) {
      interruptActiveHold(interruptedHoldFaultId);
      interruptReArm();
      return const GuidanceSignal.bodyInFrame();
    }
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = _getLandmarks(landmarks);
    if (lm == null) return false;

    final kneeAngle = calculateAngleNormalized(
      firstPoint: lm['hip']!,
      midPoint: lm['knee']!,
      lastPoint: lm['ankle']!,
    );
    return kneeAngle >= BearConfig.KNEE_ANGLE_SETUP_MIN &&
        kneeAngle <= BearConfig.KNEE_ANGLE_SETUP_MAX;
  }

  @override
  Set<String> get faultSecondsKeys => const <String>{
        'knee_seconds',
        'back_seconds',
        'weight_seconds',
      };

  @override
  HoldPoseSample? samplePose(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final now = frameTimestampMs;
    _exerciseStartTimeMs ??= now;

    final lm = _getLandmarks(landmarks);
    if (lm == null) return null;

    final shoulder = lm['shoulder']!;
    final hip = lm['hip']!;
    final knee = lm['knee']!;
    final ankle = lm['ankle']!;
    final wrist = lm['wrist']!;

    scaleFactor = calculateDistance(shoulder, hip);
    if (!scaleFactor.isFinite || scaleFactor <= 1e-6) return null;

    double floorY;
    if ((ankle.x - wrist.x).abs() > 0.001) {
      final t = (knee.x - wrist.x) / (ankle.x - wrist.x);
      floorY = wrist.y + t * (ankle.y - wrist.y);
    } else {
      floorY = wrist.y > ankle.y ? wrist.y : ankle.y;
    }

    final kneeHeightOffset = (floorY - knee.y) / scaleFactor;
    final kneeAngle = calculateAngleNormalized(
      firstPoint: hip,
      midPoint: knee,
      lastPoint: ankle,
    );
    final backYOffset = (shoulder.y - hip.y) / scaleFactor;
    final shoulderWristXOffset = (shoulder.x - wrist.x).abs() / scaleFactor;
    final isHoveringForm = kneeHeightOffset > BearConfig.KNEE_HOVER_MIN &&
        kneeHeightOffset <= BearConfig.KNEE_HOVER_MAX &&
        kneeAngle < BearConfig.KNEE_ANGLE_BUTT_UP;

    if (isDebugModeActive) {
      _telemetryLog.add(<String, dynamic>{
        'timestamp': now,
        'state': phase.name,
        'normKneeHeight': double.parse(kneeHeightOffset.toStringAsFixed(3)),
        'kneeAngle': double.parse(kneeAngle.toStringAsFixed(1)),
        'backYOffset': double.parse(backYOffset.toStringAsFixed(3)),
        'shoulderWristXOffset':
            double.parse(shoulderWristXOffset.toStringAsFixed(3)),
      });
    }

    _sampledFrame = _BearPoseFrame(
      kneeHeightOffset: kneeHeightOffset,
      kneeAngle: kneeAngle,
      backYOffset: backYOffset,
      shoulderWristXOffset: shoulderWristXOffset,
      isHoveringForm: isHoveringForm,
    );

    return HoldPoseSample(
      insideOuterEntry: isHoveringForm,
      outsideOuterExit: !isHoveringForm,
    );
  }

  @override
  Map<String, bool> updateFormMetrics() {
    final sample = _sampledFrame!;
    final context = BearRepContext(
      kneeHeightOffset: sample.kneeHeightOffset,
      kneeAngle: sample.kneeAngle,
      backYOffset: sample.backYOffset,
      shoulderWristXOffset: sample.shoulderWristXOffset,
      scaleFactor: scaleFactor,
      currentState: _legacyStateFor(phase),
      frameTimestampMs: frameTimestampMs,
      resultIssues: resultIssues,
    );

    for (final metric in _metrics) {
      metric.update(context);
      debugData.addAll(metric.debugData);
    }

    debugData['State'] = phase.name;
    debugData['Hover_Time'] =
        '${(timerMetric.totalHoldingTimeMs / 1000).toStringAsFixed(1)}s / ${holdSeconds}s';

    return <String, bool>{
      'knee_seconds': kneeMetric.isFaultingNow,
      'back_seconds': backMetric.isFaultingNow,
      'weight_seconds': weightMetric.isFaultingNow,
    };
  }

  @override
  Map<String, FaultRecord> snapshotHoldFaults() {
    final faults = <String, FaultRecord>{};
    for (final metric in _metrics) {
      for (final fault in metric.faults) {
        final mapped = _mapFaultRecord(fault);
        faults[mapped.type] = mapped;
      }
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
  Map<String, dynamic> holdRepLogExtras() => <String, dynamic>{
        'perfect_hold_time': timerMetric.totalHoldingTimeMs / 1000.0,
      };

  @override
  void onHoldSetReset() {
    _exerciseStartTimeMs = null;
    _sampledFrame = null;
    _telemetryLog.clear();
  }

  @override
  void onSetComplete() {
    final targetSeconds = (maxHolds * holdSeconds).toDouble();
    logger.pushKey('total_seconds', targetSeconds);
    logger.pushKey('good_seconds', clampedGoodHoldSeconds(targetSeconds));
    logger.pushKey('max_rep', maxHolds);
    logger.pushKey(
      'total_hover_time_ms',
      completedHoldingTimeMs + currentPartialHoldingTimeMs,
    );
    logger.pushKey('timeout_triggered', false);
    logger.pushKey('knee_seconds', faultHoldSecondsFor('knee_seconds'));
    logger.pushKey('back_seconds', faultHoldSecondsFor('back_seconds'));
    logger.pushKey('weight_seconds', faultHoldSecondsFor('weight_seconds'));

    if (isDebugModeActive) {
      logger.pushKey('telemetry_data', _telemetryLog);
    }
    logger.pushGoodRepCount();
  }

  BearState _legacyStateFor(HoldPhase holdPhase) {
    switch (holdPhase) {
      case HoldPhase.holding:
        return BearState.hovering;
      case HoldPhase.dropping:
        return BearState.fatiguing;
      case HoldPhase.setup:
      case HoldPhase.resting:
      case HoldPhase.reArming:
        return BearState.setup;
    }
  }

  FaultRecord _mapFaultRecord(FaultRecord fault) {
    final type = switch (fault.type) {
      'KneeTouchingFloor' => 'knee_hover',
      'ButtTooHigh' => 'hip_high',
      'BackSagging' => 'back_sag',
      'BackArching' => 'back_arch',
      'WeightForward' => 'weight',
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

  FaultRecord? _faultOfType(
    Iterable<FaultRecord> faults,
    String? type,
  ) {
    if (type == null) return null;
    for (final fault in faults) {
      if (fault.type == type) return fault;
    }
    return null;
  }

  Map<String, PoseLandmark>? _getLandmarks(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final lShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final lHip = landmarks[PoseLandmarkType.leftHip];
    final lKnee = landmarks[PoseLandmarkType.leftKnee];
    final lAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final lWrist = landmarks[PoseLandmarkType.leftWrist];

    final rShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final rHip = landmarks[PoseLandmarkType.rightHip];
    final rKnee = landmarks[PoseLandmarkType.rightKnee];
    final rAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final rWrist = landmarks[PoseLandmarkType.rightWrist];

    if (lShoulder != null &&
        lHip != null &&
        lKnee != null &&
        lAnkle != null &&
        lWrist != null &&
        <PoseLandmark>[lShoulder, lHip, lKnee, lAnkle, lWrist]
            .every(ExerciseBase.isLandmarkConfident)) {
      if (rHip == null || lHip.likelihood >= rHip.likelihood) {
        return <String, PoseLandmark>{
          'shoulder': lShoulder,
          'hip': lHip,
          'knee': lKnee,
          'ankle': lAnkle,
          'wrist': lWrist,
        };
      }
    }
    if (rShoulder != null &&
        rHip != null &&
        rKnee != null &&
        rAnkle != null &&
        rWrist != null &&
        <PoseLandmark>[rShoulder, rHip, rKnee, rAnkle, rWrist]
            .every(ExerciseBase.isLandmarkConfident)) {
      return <String, PoseLandmark>{
        'shoulder': rShoulder,
        'hip': rHip,
        'knee': rKnee,
        'ankle': rAnkle,
        'wrist': rWrist,
      };
    }
    if (lShoulder != null &&
        lHip != null &&
        lKnee != null &&
        lAnkle != null &&
        lWrist != null &&
        <PoseLandmark>[lShoulder, lHip, lKnee, lAnkle, lWrist]
            .every(ExerciseBase.isLandmarkConfident)) {
      return <String, PoseLandmark>{
        'shoulder': lShoulder,
        'hip': lHip,
        'knee': lKnee,
        'ankle': lAnkle,
        'wrist': lWrist,
      };
    }
    return null;
  }
}
