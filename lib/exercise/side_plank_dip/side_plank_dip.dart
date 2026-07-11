import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../utils/exercise_logger.dart';
import '../../utils/pose_math_helpers.dart';
import '../exercise_base.dart';
import 'metrics/side_plank_dip_metric_base.dart';

class SidePlankConfig {
  static const double MIN_BODY_ANGLE = 155.0;
  static const double MAX_SHOULDER_ELBOW_OFFSET_RATIO = 0.55;
  static const double MIN_BASELINE_WIDTH_RATIO = 0.05;
  static const double MIN_ROTATION_RATIO = 0.60;
  static const double MAX_ROTATION_RATIO = 1.55;
  static const int MAX_FRAME_DELTA_MS = 250;
}

/// Static side plank hold.
///
/// The historical class/id is retained so saved sessions and report routing
/// remain compatible, but hip-dip rep counting is intentionally removed.
class SidePlankDip extends ExerciseBase {
  SidePlankDip({required this.maxSeconds});

  final int maxSeconds;

  SidePlankState plankState = SidePlankState.setupPlank;
  int _validHoldTimeMs = 0;
  int? _lastFrameTimeMs;
  double? _baselineShoulderWidth;
  double? _baselineHipWidth;
  bool _shoulderFaultSeen = false;
  bool _rotationFaultSeen = false;
  bool _bodyLineFaultSeen = false;

  final HoldSecondsAccumulator _holdSeconds = HoldSecondsAccumulator(const [
    'shoulder_seconds',
    'rotation_seconds',
    'body_line_seconds',
  ]);

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
  String get currentPhaseKey => plankState.name;

  @override
  String get currentPhaseLabel => plankState == SidePlankState.setupPlank
      ? 'Vào tư thế plank nghiêng'
      : 'Giữ plank nghiêng';

  @override
  double? get liveHoldSeconds => exerciseState == ExerciseState.activated
      ? _validHoldTimeMs / 1000.0
      : null;

  @override
  double? get liveHoldTargetSeconds => maxSeconds.toDouble();

  @override
  bool requestStop() => _validHoldTimeMs >= maxSeconds * 1000;

  @override
  void onExerciseActivated() {
    super.onExerciseActivated();
    plankState = SidePlankState.basePlank;
    _validHoldTimeMs = 0;
    _lastFrameTimeMs = null;
    _holdSeconds.reset();
  }

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return const GuidanceSignal.turnSide();
    }

    final body = _trackedBody(landmarks);
    if (body == null) {
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
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final body = _trackedBody(landmarks);
    if (body == null) {
      _lastFrameTimeMs = null;
      _holdSeconds.resetTick();
      return;
    }

    final now = frameTimestampMs;
    final previous = _lastFrameTimeMs;
    _lastFrameTimeMs = now;
    final dt = previous == null
        ? 0
        : (now - previous).clamp(0, SidePlankConfig.MAX_FRAME_DELTA_MS);

    final geometry = _geometry(body);
    final rotationStable = _rotationIsStable(body, geometry.scale);
    final formClean =
        geometry.bodyStraight && geometry.shoulderAligned && rotationStable;

    if (formClean) {
      _validHoldTimeMs += dt;
    }

    _shoulderFaultSeen |= !geometry.shoulderAligned;
    _rotationFaultSeen |= !rotationStable;
    _bodyLineFaultSeen |= !geometry.bodyStraight;

    if (!geometry.bodyStraight) {
      resultIssues.feedback['Amplitude'] =
          'Nâng hông để vai, hông và cổ chân thành một đường thẳng.';
    }
    if (!geometry.shoulderAligned) {
      resultIssues.feedback['Shoulder'] = 'Đặt khuỷu tay trụ ngay dưới vai.';
    }
    if (!rotationStable) {
      resultIssues.feedback['Rotation'] =
          'Giữ ngực và hông không đổ về trước hoặc sau.';
    }

    _holdSeconds.accumulate(
      elapsedMs: elapsedMs,
      faultingByKey: {
        'shoulder_seconds': !geometry.shoulderAligned,
        'rotation_seconds': !rotationStable,
        'body_line_seconds': !geometry.bodyStraight,
      },
    );

    resultIssues.setPhaseStatus(
        'basePlank',
        formClean
            ? 'Giữ nguyên tư thế.'
            : 'Chỉnh lại tư thế để tiếp tục tính giờ.');

    debugData['sidePlankBodyAngle'] = geometry.bodyAngle;
    debugData['sidePlankShoulderOffset'] = geometry.shoulderOffsetRatio;
    debugData['sidePlankHoldSeconds'] = _validHoldTimeMs / 1000.0;
  }

  @override
  void onSetComplete() {
    if (repCount == 0) repCount = 1;

    final faultTypes = <String>[
      if (_shoulderFaultSeen) 'shoulder',
      if (_rotationFaultSeen) 'rotation',
      if (_bodyLineFaultSeen) 'amplitude',
    ];
    correctForm = faultTypes.isEmpty;

    logger.addRepLog(RepLog(
      correctForm: correctForm,
      repNumber: repCount,
      data: {
        'hold_time': _validHoldTimeMs / 1000.0,
        'fault_types': faultTypes,
      },
    ));
    logger.pushKey('shoulder_align_fails_count', _shoulderFaultSeen ? 1 : 0);
    logger.pushKey('rotation_fails_count', _rotationFaultSeen ? 1 : 0);
    logger.pushKey('dip_depth_fails_count', _bodyLineFaultSeen ? 1 : 0);
    logger.pushKey('total_seconds', maxSeconds.toDouble());
    logger.pushKey(
      'good_seconds',
      _holdSeconds.goodSeconds.clamp(0.0, maxSeconds.toDouble()),
    );
    logger.pushKey(
      'shoulder_seconds',
      _holdSeconds.faultSecondsFor('shoulder_seconds'),
    );
    logger.pushKey(
      'rotation_seconds',
      _holdSeconds.faultSecondsFor('rotation_seconds'),
    );
    logger.pushKey(
      'body_line_seconds',
      _holdSeconds.faultSecondsFor('body_line_seconds'),
    );
    logger.pushKey('max_rep', 1);
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

    final required = [
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
