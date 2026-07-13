import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../utils/pose_math_helpers.dart';
import '../exercise_base.dart';
import '../fault_record.dart';
import '../hold/rep_counted_hold_exercise.dart';

class SidePlankConfig {
  static const double MIN_BODY_ANGLE = 155.0;
  static const double MAX_SHOULDER_ELBOW_OFFSET_RATIO = 0.55;
  static const double MIN_BASELINE_WIDTH_RATIO = 0.05;
  static const double MIN_ROTATION_RATIO = 0.60;
  static const double MAX_ROTATION_RATIO = 1.55;
  static const int MAX_FRAME_DELTA_MS = 250;
}

class _SidePlankPoseFrame {
  const _SidePlankPoseFrame({
    required this.bodyAngle,
    required this.shoulderOffsetRatio,
    required this.bodyStraight,
    required this.shoulderAligned,
    required this.rotationStable,
  });

  final double bodyAngle;
  final double shoulderOffsetRatio;
  final bool bodyStraight;
  final bool shoulderAligned;
  final bool rotationStable;

  bool get formClean => bodyStraight && shoulderAligned && rotationStable;
}

/// Static side plank hold.
///
/// The historical class/id is retained so saved sessions and report routing
/// remain compatible, but hip-dip rep counting is intentionally removed.
class SidePlankDip extends RepCountedHoldExercise {
  SidePlankDip({
    required super.maxHolds,
    required super.holdSeconds,
  });

  int get maxSeconds => holdSeconds;

  double? _baselineShoulderWidth;
  double? _baselineHipWidth;
  _SidePlankPoseFrame? _sampledFrame;

  bool _shoulderFaultSeen = false;
  bool _rotationFaultSeen = false;
  bool _bodyLineFaultSeen = false;
  int _shoulderFaultHolds = 0;
  int _rotationFaultHolds = 0;
  int _bodyLineFaultHolds = 0;

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.portrait,
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'Side Plank with Hip Dip';

  @override
  int get holdingDebounceFrames => 1;

  @override
  int get droppingDebounceFrames => 1;

  @override
  String get currentPhaseLabel {
    switch (phase) {
      case HoldPhase.setup:
        return 'Vào tư thế plank nghiêng';
      case HoldPhase.holding:
        return 'Giữ plank nghiêng';
      case HoldPhase.dropping:
        return 'Chỉnh lại tư thế';
      case HoldPhase.resting:
        return 'Nghỉ';
      case HoldPhase.reArming:
        return 'Vào tư thế';
    }
  }

  @override
  List<FaultRecord> get liveFaults {
    final sample = _sampledFrame;
    if (sample == null ||
        (phase != HoldPhase.holding && phase != HoldPhase.dropping)) {
      return const <FaultRecord>[];
    }
    return <FaultRecord>[
      if (!sample.shoulderAligned)
        FaultRecord(
          phase: phase.name,
          type: 'shoulder',
          message: 'Khuỷu tay trụ lệch khỏi vai',
          affectsForm: true,
          priority: 0,
        ),
      if (!sample.rotationStable)
        FaultRecord(
          phase: phase.name,
          type: 'rotation',
          message: 'Thân người bị xoay',
          affectsForm: true,
          priority: 1,
        ),
      if (!sample.bodyStraight)
        FaultRecord(
          phase: phase.name,
          type: 'amplitude',
          message: 'Thân người mất đường thẳng',
          affectsForm: true,
          priority: 2,
        ),
    ];
  }

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      interruptReArm();
      return const GuidanceSignal.turnSide();
    }
    if (_trackedBody(landmarks) == null) {
      interruptActiveHold(interruptedHoldFaultId);
      interruptReArm();
      return const GuidanceSignal.bodyInFrame();
    }
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final body = _trackedBody(landmarks);
    if (body == null) return false;

    final geometry = _geometry(body);
    if (!geometry.bodyStraight || !geometry.shoulderAligned) return false;

    _baselineShoulderWidth = (body.leftShoulder.x - body.rightShoulder.x).abs();
    _baselineHipWidth = (body.leftHip.x - body.rightHip.x).abs();
    return true;
  }

  @override
  Set<String> get faultSecondsKeys => const <String>{
        'shoulder_seconds',
        'rotation_seconds',
        'body_line_seconds',
      };

  @override
  HoldPoseSample? samplePose(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final body = _trackedBody(landmarks);
    if (body == null) return null;

    final geometry = _geometry(body);
    scaleFactor = geometry.scale;
    final rotationStable = _rotationIsStable(body, geometry.scale);
    _sampledFrame = _SidePlankPoseFrame(
      bodyAngle: geometry.bodyAngle,
      shoulderOffsetRatio: geometry.shoulderOffsetRatio,
      bodyStraight: geometry.bodyStraight,
      shoulderAligned: geometry.shoulderAligned,
      rotationStable: rotationStable,
    );

    final formClean =
        geometry.bodyStraight && geometry.shoulderAligned && rotationStable;
    return HoldPoseSample(
      insideOuterEntry: formClean,
      outsideOuterExit: !formClean,
    );
  }

  @override
  Map<String, bool> updateFormMetrics() {
    final sample = _sampledFrame!;
    final shoulderFaulting = !sample.shoulderAligned;
    final rotationFaulting = !sample.rotationStable;
    final bodyLineFaulting = !sample.bodyStraight;

    if (phase == HoldPhase.holding || phase == HoldPhase.dropping) {
      _shoulderFaultSeen |= shoulderFaulting;
      _rotationFaultSeen |= rotationFaulting;
      _bodyLineFaultSeen |= bodyLineFaulting;
    }

    if (bodyLineFaulting) {
      resultIssues.feedback['Amplitude'] =
          'Nâng hông để vai, hông và cổ chân thành một đường thẳng.';
    }
    if (shoulderFaulting) {
      resultIssues.feedback['Shoulder'] = 'Đặt khuỷu tay trụ ngay dưới vai.';
    }
    if (rotationFaulting) {
      resultIssues.feedback['Rotation'] =
          'Giữ ngực và hông không đổ về trước hoặc sau.';
    }

    debugData['sidePlankBodyAngle'] = sample.bodyAngle;
    debugData['sidePlankShoulderOffset'] = sample.shoulderOffsetRatio;
    debugData['sidePlankHoldSeconds'] = timerMetric.totalHoldingTimeMs / 1000.0;

    return <String, bool>{
      'shoulder_seconds': shoulderFaulting,
      'rotation_seconds': rotationFaulting,
      'body_line_seconds': bodyLineFaulting,
    };
  }

  @override
  Map<String, FaultRecord> snapshotHoldFaults() => <String, FaultRecord>{
        if (_shoulderFaultSeen)
          'shoulder': FaultRecord(
            phase: HoldPhase.holding.name,
            type: 'shoulder',
            message: 'Khuỷu tay trụ lệch khỏi vai',
            affectsForm: true,
            priority: 0,
          ),
        if (_rotationFaultSeen)
          'rotation': FaultRecord(
            phase: HoldPhase.holding.name,
            type: 'rotation',
            message: 'Thân người bị xoay',
            affectsForm: true,
            priority: 1,
          ),
        if (_bodyLineFaultSeen)
          'amplitude': FaultRecord(
            phase: HoldPhase.holding.name,
            type: 'amplitude',
            message: 'Thân người mất đường thẳng',
            affectsForm: true,
            priority: 2,
          ),
      };

  @override
  void resetFormMetrics({required bool countFaults}) {
    if (countFaults) {
      if (_shoulderFaultSeen) _shoulderFaultHolds += 1;
      if (_rotationFaultSeen) _rotationFaultHolds += 1;
      if (_bodyLineFaultSeen) _bodyLineFaultHolds += 1;
    }
    _shoulderFaultSeen = false;
    _rotationFaultSeen = false;
    _bodyLineFaultSeen = false;
  }

  @override
  void onHoldPhaseChanged(
    HoldPhase previous,
    HoldPhase next,
    int nowMs,
  ) {}

  @override
  void onHoldSetReset() {
    _sampledFrame = null;
    _shoulderFaultSeen = false;
    _rotationFaultSeen = false;
    _bodyLineFaultSeen = false;
    _shoulderFaultHolds = 0;
    _rotationFaultHolds = 0;
    _bodyLineFaultHolds = 0;
  }

  @override
  void onSetComplete() {
    final targetSeconds = (maxHolds * holdSeconds).toDouble();
    logger.pushKey('shoulder_align_fails_count', _shoulderFaultHolds);
    logger.pushKey('rotation_fails_count', _rotationFaultHolds);
    logger.pushKey('dip_depth_fails_count', _bodyLineFaultHolds);
    logger.pushKey('total_seconds', targetSeconds);
    logger.pushKey('good_seconds', clampedGoodHoldSeconds(targetSeconds));
    logger.pushKey(
      'shoulder_seconds',
      faultHoldSecondsFor('shoulder_seconds'),
    );
    logger.pushKey(
      'rotation_seconds',
      faultHoldSecondsFor('rotation_seconds'),
    );
    logger.pushKey(
      'body_line_seconds',
      faultHoldSecondsFor('body_line_seconds'),
    );
    logger.pushKey('max_rep', maxHolds);
    logger.pushGoodRepCount();
  }

  _SidePlankBody? _trackedBody(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    final required = <PoseLandmark?>[
      leftElbow,
      rightElbow,
      leftShoulder,
      rightShoulder,
      leftHip,
      rightHip,
      leftAnkle,
      rightAnkle,
    ];
    if (required.any((landmark) =>
        landmark == null || !ExerciseBase.isLandmarkConfident(landmark))) {
      return null;
    }

    final isLeftSupport = leftElbow!.y >= rightElbow!.y;
    return _SidePlankBody(
      supportShoulder: isLeftSupport ? leftShoulder! : rightShoulder!,
      supportElbow: isLeftSupport ? leftElbow : rightElbow,
      supportHip: isLeftSupport ? leftHip! : rightHip!,
      supportAnkle: isLeftSupport ? leftAnkle! : rightAnkle!,
      leftShoulder: leftShoulder!,
      rightShoulder: rightShoulder!,
      leftHip: leftHip!,
      rightHip: rightHip!,
    );
  }

  ({
    double scale,
    double bodyAngle,
    double shoulderOffsetRatio,
    bool bodyStraight,
    bool shoulderAligned,
  }) _geometry(_SidePlankBody body) {
    final scale = calculateDistance(body.supportShoulder, body.supportHip);
    if (!scale.isFinite || scale <= 1e-6) {
      return (
        scale: 1.0,
        bodyAngle: 0.0,
        shoulderOffsetRatio: double.infinity,
        bodyStraight: false,
        shoulderAligned: false,
      );
    }

    final bodyAngle = calculateAngleNormalized(
      firstPoint: body.supportShoulder,
      midPoint: body.supportHip,
      lastPoint: body.supportAnkle,
    );
    final shoulderOffset =
        (body.supportShoulder.x - body.supportElbow.x).abs() / scale;
    return (
      scale: scale,
      bodyAngle: bodyAngle,
      shoulderOffsetRatio: shoulderOffset,
      bodyStraight: bodyAngle >= SidePlankConfig.MIN_BODY_ANGLE,
      shoulderAligned:
          shoulderOffset <= SidePlankConfig.MAX_SHOULDER_ELBOW_OFFSET_RATIO,
    );
  }

  bool _rotationIsStable(_SidePlankBody body, double scale) {
    final baselineShoulder = _baselineShoulderWidth;
    final baselineHip = _baselineHipWidth;
    if (baselineShoulder == null || baselineHip == null) return true;

    bool stable(double current, double baseline) {
      if (baseline / scale < SidePlankConfig.MIN_BASELINE_WIDTH_RATIO) {
        return true;
      }
      final ratio = current / baseline;
      return ratio >= SidePlankConfig.MIN_ROTATION_RATIO &&
          ratio <= SidePlankConfig.MAX_ROTATION_RATIO;
    }

    return stable(
          (body.leftShoulder.x - body.rightShoulder.x).abs(),
          baselineShoulder,
        ) &&
        stable(
          (body.leftHip.x - body.rightHip.x).abs(),
          baselineHip,
        );
  }
}

class _SidePlankBody {
  const _SidePlankBody({
    required this.supportShoulder,
    required this.supportElbow,
    required this.supportHip,
    required this.supportAnkle,
    required this.leftShoulder,
    required this.rightShoulder,
    required this.leftHip,
    required this.rightHip,
  });

  final PoseLandmark supportShoulder;
  final PoseLandmark supportElbow;
  final PoseLandmark supportHip;
  final PoseLandmark supportAnkle;
  final PoseLandmark leftShoulder;
  final PoseLandmark rightShoulder;
  final PoseLandmark leftHip;
  final PoseLandmark rightHip;
}
