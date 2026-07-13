import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../utils/frame_snapshot.dart';
import '../exercise_base.dart';
import '../fault_record.dart' as hold_fault;
import '../hold/rep_counted_hold_exercise.dart';
import 'metrics/butterfly_metric_base.dart';
import 'metrics/foot_placement_metric.dart';
import 'metrics/knee_separation_metric.dart';
import 'metrics/posture_metric.dart';

class ButterflyConfig {
  static const int TARGET_HOLD_SECONDS = 20;
  static const double MAX_ANKLE_SEPARATION_NORM = 0.20;
  static const double HOLD_STABILITY_THRESHOLD = 0.04;
  static const double STRETCH_THRESHOLD = 0.015;
  static const double RELEASE_THRESHOLD = -0.04;
  static const double MIN_KNEE_SEPARATION_NORM = 0.70;
  static const int MAX_BUFFER_FRAMES = 45;
}

class _ButterflyPoseFrame {
  const _ButterflyPoseFrame({
    required this.kneeSeparation,
    required this.leftKneeY,
    required this.rightKneeY,
    required this.ankleSeparation,
    required this.shoulderToHipRatio,
    required this.shoulderTilt,
    required this.ankleSeparationNorm,
    required this.footToHipDistanceNorm,
    required this.torsoVerticalNorm,
    required this.yChangeNorm,
  });

  final double kneeSeparation;
  final double leftKneeY;
  final double rightKneeY;
  final double ankleSeparation;
  final double shoulderToHipRatio;
  final double shoulderTilt;
  final double ankleSeparationNorm;
  final double footToHipDistanceNorm;
  final double torsoVerticalNorm;
  final double yChangeNorm;
}

class ButterflyStretch extends RepCountedHoldExercise {
  ButterflyStretch({
    required super.maxHolds,
    required super.holdSeconds,
  });

  int get maxSeconds => holdSeconds;

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.portrait,
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  _ButterflyPoseFrame? _sampledFrame;
  double _maxKneeSeparation = 0.0;

  final KneeSeparationMetric kneeMetric = KneeSeparationMetric();
  final PostureMetric postureMetric = PostureMetric();
  final FootPlacementMetric footPlacementMetric = FootPlacementMetric();

  late final List<ButterflyMetricBase> _metrics = <ButterflyMetricBase>[
    kneeMetric,
    postureMetric,
    footPlacementMetric,
  ];

  @override
  String get exerciseName => 'Butterfly Stretch';

  @override
  String get setupOrientationIntroVoiceKey => 'common.thang_intro';

  @override
  int get holdingDebounceFrames => 10;

  @override
  int get droppingDebounceFrames => 5;

  @override
  String get currentPhaseLabel {
    switch (phase) {
      case HoldPhase.setup:
        return 'Chuẩn bị';
      case HoldPhase.holding:
        return 'Giữ tư thế bướm';
      case HoldPhase.dropping:
        return 'Thả lỏng';
      case HoldPhase.resting:
        return 'Nghỉ';
      case HoldPhase.reArming:
        return 'Vào tư thế';
    }
  }

  @override
  List<hold_fault.FaultRecord> get liveFaults {
    if (phase != HoldPhase.holding) {
      return const <hold_fault.FaultRecord>[];
    }
    final faults = <String, hold_fault.FaultRecord>{};
    if (kneeMetric.isFaultingNow) {
      _addMappedFaults(faults, kneeMetric.faults);
    }
    if (postureMetric.isFaultingNow) {
      final currentPostureFault = _faultOfType(
        postureMetric.faults,
        postureMetric.currentFaultType,
      );
      if (currentPostureFault != null) {
        _addMappedFaults(faults, <FaultRecord>[currentPostureFault]);
      }
    }
    if (footPlacementMetric.isFaultingNow) {
      _addMappedFaults(faults, footPlacementMetric.faults);
    }
    return faults.values.toList(growable: false);
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.front) return false;

    final points = _landmarks(landmarks);
    if (points == null) return false;

    final shoulderDistance =
        (points.leftShoulder.x - points.rightShoulder.x).abs();
    if (shoulderDistance < 10) return false;

    final ankleDistance = (points.leftAnkle.x - points.rightAnkle.x).abs();
    if ((ankleDistance / shoulderDistance) > 0.6) return false;

    final kneeDistance = (points.leftKnee.x - points.rightKnee.x).abs();
    if (kneeDistance < shoulderDistance * 0.8) return false;

    final averageShoulderY =
        (points.leftShoulder.y + points.rightShoulder.y) / 2;
    final averageHipY = (points.leftHip.y + points.rightHip.y) / 2;
    final torsoHeight = (averageShoulderY - averageHipY).abs();
    final normalizer = _bodyNormalizer(torsoHeight, shoulderDistance);
    final footToHipDistanceNorm = _pointDistance(
          (points.leftHip.x + points.rightHip.x) / 2,
          averageHipY,
          (points.leftHeel.x + points.rightHeel.x) / 2,
          (points.leftHeel.y + points.rightHeel.y) / 2,
        ) /
        normalizer;
    final torsoVerticalNorm = torsoHeight / shoulderDistance;

    return footToHipDistanceNorm <=
            FootPlacementConfig.MAX_FOOT_TO_HIP_DISTANCE_NORM &&
        torsoVerticalNorm >= PostureConfig.COLLAPSE_THRESHOLD;
  }

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.front) {
      interruptReArm();
      return const GuidanceSignal.faceCamera();
    }
    if (_landmarks(landmarks) == null) {
      interruptActiveHold(interruptedHoldFaultId);
      interruptReArm();
      return const GuidanceSignal.bodyInFrame();
    }
    return null;
  }

  @override
  Set<String> get faultSecondsKeys => const <String>{
        'knee_seconds',
        'posture_seconds',
        'foot_placement_seconds',
      };

  @override
  HoldPoseSample? samplePose(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final points = _landmarks(landmarks);
    if (points == null) return null;

    final kneeSeparation = (points.leftKnee.x - points.rightKnee.x).abs();
    final ankleSeparation = (points.leftAnkle.x - points.rightAnkle.x).abs();
    final averageKneeY = (points.leftKnee.y + points.rightKnee.y) / 2;
    final averageShoulderY =
        (points.leftShoulder.y + points.rightShoulder.y) / 2;
    final averageHipY = (points.leftHip.y + points.rightHip.y) / 2;
    final torsoHeight = (averageShoulderY - averageHipY).abs();
    final shoulderWidth =
        (points.leftShoulder.x - points.rightShoulder.x).abs();
    final safeShoulderWidth = shoulderWidth == 0 ? 1.0 : shoulderWidth;
    final normalizer = _bodyNormalizer(torsoHeight, shoulderWidth);
    scaleFactor = normalizer;

    final kneeSeparationNorm = kneeSeparation / safeShoulderWidth;
    final ankleSeparationNorm = ankleSeparation / safeShoulderWidth;
    final footToHipDistanceNorm = _pointDistance(
          (points.leftHip.x + points.rightHip.x) / 2,
          averageHipY,
          (points.leftHeel.x + points.rightHeel.x) / 2,
          (points.leftHeel.y + points.rightHeel.y) / 2,
        ) /
        normalizer;
    final torsoVerticalNorm = torsoHeight / safeShoulderWidth;

    frameBuffer.addFrame(FrameSnapshot(
      log: <String, double>{
        'avgKneeY': averageKneeY,
        'kneeSep': kneeSeparation,
      },
      timeStamp: frameTimestampMs,
    ));
    if (frameBuffer.frameBuffer.length > ButterflyConfig.MAX_BUFFER_FRAMES) {
      frameBuffer.frameBuffer.removeAt(0);
    }

    var yChange = 0.0;
    final buffer = frameBuffer.frameBuffer;
    if (buffer.length >= 2) {
      final lookback = buffer.length > 10 ? 10 : buffer.length - 1;
      final currentY = buffer.last.log['avgKneeY'] ?? 0.0;
      final pastY = buffer[buffer.length - 1 - lookback].log['avgKneeY'] ?? 0.0;
      yChange = currentY - pastY;
    }
    final yChangeNorm = yChange / (torsoHeight == 0 ? 1 : torsoHeight);

    _sampledFrame = _ButterflyPoseFrame(
      kneeSeparation: kneeSeparation,
      leftKneeY: points.leftKnee.y,
      rightKneeY: points.rightKnee.y,
      ankleSeparation: ankleSeparation,
      shoulderToHipRatio: torsoHeight,
      shoulderTilt: (points.leftShoulder.y - points.rightShoulder.y).abs(),
      ankleSeparationNorm: ankleSeparationNorm,
      footToHipDistanceNorm: footToHipDistanceNorm,
      torsoVerticalNorm: torsoVerticalNorm,
      yChangeNorm: yChangeNorm,
    );

    debugData['kneeSeparationNorm'] = kneeSeparationNorm;
    return HoldPoseSample(
      insideOuterEntry:
          yChangeNorm.abs() < ButterflyConfig.HOLD_STABILITY_THRESHOLD,
      outsideOuterExit: yChangeNorm < ButterflyConfig.RELEASE_THRESHOLD,
    );
  }

  @override
  Map<String, bool> updateFormMetrics() {
    final sample = _sampledFrame!;
    final context = StretchContext(
      kneeSeparation: sample.kneeSeparation,
      leftKneeY: sample.leftKneeY,
      rightKneeY: sample.rightKneeY,
      ankleSeparation: sample.ankleSeparation,
      shoulderToHipRatio: sample.shoulderToHipRatio,
      shoulderTilt: sample.shoulderTilt,
      ankleSeparationNorm: sample.ankleSeparationNorm,
      footToHipDistanceNorm: sample.footToHipDistanceNorm,
      torsoVerticalNorm: sample.torsoVerticalNorm,
      currentState: _legacyStateFor(phase),
      frameTimestamp: frameTimestampMs,
      resultIssues: resultIssues,
      currentHoldSeconds: timerMetric.totalHoldingTimeMs / 1000.0,
    );

    if (phase == HoldPhase.holding || phase == HoldPhase.dropping) {
      for (final metric in _metrics) {
        metric.update(context);
        debugData.addAll(metric.debugData);
      }
      if (kneeMetric.maxSeparation > _maxKneeSeparation) {
        _maxKneeSeparation = kneeMetric.maxSeparation;
      }
    }

    resultIssues.feedback['Thời gian'] =
        '${(timerMetric.totalHoldingTimeMs / 1000).toStringAsFixed(1)}s / ${holdSeconds}s';
    debugData['total_hold'] =
        (timerMetric.totalHoldingTimeMs / 1000).toStringAsFixed(1);

    return <String, bool>{
      'knee_seconds': kneeMetric.isFaultingNow,
      'posture_seconds': postureMetric.isFaultingNow,
      'foot_placement_seconds': footPlacementMetric.isFaultingNow,
    };
  }

  @override
  Map<String, hold_fault.FaultRecord> snapshotHoldFaults() {
    final faults = <String, hold_fault.FaultRecord>{};
    _addMappedFaults(faults, kneeMetric.faults);
    _addMappedFaults(faults, postureMetric.faults);
    _addMappedFaults(faults, footPlacementMetric.faults);
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
  void onHoldSetReset() {
    _sampledFrame = null;
    _maxKneeSeparation = 0.0;
    frameBuffer.clear();
  }

  @override
  void onSetComplete() {
    final targetSeconds = (maxHolds * holdSeconds).toDouble();
    logger.pushKey('max_rep', maxHolds);
    logger.pushKey('total_seconds', targetSeconds);
    logger.pushKey('good_seconds', clampedGoodHoldSeconds(targetSeconds));
    logger.pushKey('total_hold_time', completedHoldingTimeMs / 1000.0);
    logger.pushKey('max_knee_separation', _maxKneeSeparation);
    logger.pushKey('knee_seconds', faultHoldSecondsFor('knee_seconds'));
    logger.pushKey('posture_seconds', faultHoldSecondsFor('posture_seconds'));
    logger.pushKey(
      'foot_placement_seconds',
      faultHoldSecondsFor('foot_placement_seconds'),
    );
    logger.pushGoodRepCount();
  }

  ButterflyState _legacyStateFor(HoldPhase holdPhase) {
    switch (holdPhase) {
      case HoldPhase.holding:
        return ButterflyState.isometric_hold;
      case HoldPhase.dropping:
        return ButterflyState.release;
      case HoldPhase.setup:
      case HoldPhase.resting:
      case HoldPhase.reArming:
        return ButterflyState.setup;
    }
  }

  void _addMappedFaults(
    Map<String, hold_fault.FaultRecord> target,
    Iterable<FaultRecord> source,
  ) {
    for (final fault in source) {
      final mapped = _mapFaultRecord(fault);
      target[mapped.type] = mapped;
    }
  }

  hold_fault.FaultRecord _mapFaultRecord(FaultRecord fault) {
    final type = switch (fault.type) {
      'Knee' => 'knee',
      'PostureCollapse' => 'posture',
      'Posture' => 'shoulder',
      'FootPlacement' => 'foot',
      _ => fault.type,
    };
    final priority = switch (type) {
      'knee' => 0,
      'posture' => 1,
      'foot' => 2,
      _ => 99,
    };
    return hold_fault.FaultRecord(
      phase: phase.name,
      type: type,
      message: fault.message,
      affectsForm: fault.affectsForm,
      priority: priority,
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

  _ButterflyLandmarks? _landmarks(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final points = _ButterflyLandmarks.maybeFrom(landmarks);
    if (points == null || !points.all.every(ExerciseBase.isLandmarkConfident)) {
      return null;
    }
    return points;
  }

  double _bodyNormalizer(double torsoHeight, double shoulderWidth) {
    final normalizer =
        torsoHeight > shoulderWidth ? torsoHeight : shoulderWidth;
    return normalizer < 1 ? 1 : normalizer;
  }

  double _pointDistance(double ax, double ay, double bx, double by) {
    final dx = ax - bx;
    final dy = ay - by;
    return math.sqrt(dx * dx + dy * dy);
  }
}

class _ButterflyLandmarks {
  const _ButterflyLandmarks({
    required this.leftKnee,
    required this.rightKnee,
    required this.leftAnkle,
    required this.rightAnkle,
    required this.leftShoulder,
    required this.rightShoulder,
    required this.leftHip,
    required this.rightHip,
    required this.leftHeel,
    required this.rightHeel,
  });

  static _ButterflyLandmarks? maybeFrom(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftHeel = landmarks[PoseLandmarkType.leftHeel];
    final rightHeel = landmarks[PoseLandmarkType.rightHeel];
    if (leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null ||
        leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null ||
        leftHeel == null ||
        rightHeel == null) {
      return null;
    }
    return _ButterflyLandmarks(
      leftKnee: leftKnee,
      rightKnee: rightKnee,
      leftAnkle: leftAnkle,
      rightAnkle: rightAnkle,
      leftShoulder: leftShoulder,
      rightShoulder: rightShoulder,
      leftHip: leftHip,
      rightHip: rightHip,
      leftHeel: leftHeel,
      rightHeel: rightHeel,
    );
  }

  final PoseLandmark leftKnee;
  final PoseLandmark rightKnee;
  final PoseLandmark leftAnkle;
  final PoseLandmark rightAnkle;
  final PoseLandmark leftShoulder;
  final PoseLandmark rightShoulder;
  final PoseLandmark leftHip;
  final PoseLandmark rightHip;
  final PoseLandmark leftHeel;
  final PoseLandmark rightHeel;

  List<PoseLandmark> get all => <PoseLandmark>[
        leftKnee,
        rightKnee,
        leftAnkle,
        rightAnkle,
        leftShoulder,
        rightShoulder,
        leftHip,
        rightHip,
        leftHeel,
        rightHeel,
      ];
}
