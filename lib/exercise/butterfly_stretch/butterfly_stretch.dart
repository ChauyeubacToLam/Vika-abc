import 'dart:math' as math;

import 'package:vika/utils/debouncer.dart';
import 'package:vika/debug/tracked_metric.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/frame_snapshot.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';
import 'metrics/butterfly_metric_base.dart';
import 'metrics/foot_placement_metric.dart';
import 'metrics/knee_separation_metric.dart';
import 'metrics/posture_metric.dart';

class ButterflyConfig {
  static const int TARGET_HOLD_SECONDS = 30;
  static const double MAX_ANKLE_SEPARATION_NORM = 0.2;
  static const double HOLD_STABILITY_THRESHOLD = 0.025;
  static const double STRETCH_THRESHOLD = 0.02;
  static const double RELEASE_THRESHOLD = -0.025;
  static const int MAX_BUFFER_FRAMES = 45;
}

class ButterflyStretch extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  ButterflyState stretchState = ButterflyState.setup;
  ButterflyState previousState = ButterflyState.setup;

  int? _lastFrameTimeMs;
  int _validHoldTimeMs = 0;

  final KneeSeparationMetric kneeMetric = KneeSeparationMetric();
  final PostureMetric postureMetric = PostureMetric();
  final FootPlacementMetric footPlacementMetric = FootPlacementMetric();

  late final List<ButterflyMetricBase> _metrics = [
    kneeMetric,
    postureMetric,
    footPlacementMetric,
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

  final Debouncer _holdDebouncer = Debouncer(requiredFrames: 10);
  final Debouncer _releaseDebouncer = Debouncer(requiredFrames: 5);

  @override
  String get exerciseName => 'Butterfly Stretch';

  @override
  String get currentPhaseKey => stretchState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (stretchState) {
      case ButterflyState.setup:
        return 'Chuẩn bị';
      case ButterflyState.stretching:
        return 'Đang ép';
      case ButterflyState.isometric_hold:
        return 'Giữ nguyên!';
      case ButterflyState.release:
        return 'Thả lỏng';
    }
  }

  @override
  double? get liveHoldSeconds =>
      stretchState == ButterflyState.isometric_hold ||
              stretchState == ButterflyState.release
          ? _elapsedSeconds
          : null;

  @override
  double? get liveHoldTargetSeconds =>
      ButterflyConfig.TARGET_HOLD_SECONDS.toDouble();

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.front) return false;

    final lKnee = landmarks[PoseLandmarkType.leftKnee];
    final rKnee = landmarks[PoseLandmarkType.rightKnee];
    final lAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final lShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final lHip = landmarks[PoseLandmarkType.leftHip];
    final rHip = landmarks[PoseLandmarkType.rightHip];
    final lHeel = landmarks[PoseLandmarkType.leftHeel];
    final rHeel = landmarks[PoseLandmarkType.rightHeel];

    if (lKnee == null ||
        rKnee == null ||
        lAnkle == null ||
        rAnkle == null ||
        lShoulder == null ||
        rShoulder == null ||
        lHip == null ||
        rHip == null ||
        lHeel == null ||
        rHeel == null) {
      return false;
    }
    if (![
      lKnee,
      rKnee,
      lAnkle,
      rAnkle,
      lShoulder,
      rShoulder,
      lHip,
      rHip,
      lHeel,
      rHeel,
    ].every(ExerciseBase.isLandmarkConfident)) {
      return false;
    }

    double shoulderDist = (lShoulder.x - rShoulder.x).abs();
    if (shoulderDist < 10) return false;

    double ankleDist = (lAnkle.x - rAnkle.x).abs();
    if ((ankleDist / shoulderDist) > 0.6) return false;

    double kneeDist = (lKnee.x - rKnee.x).abs();
    if (kneeDist < shoulderDist * 0.8) return false;

    final avgShoulderY = (lShoulder.y + rShoulder.y) / 2;
    final avgHipY = (lHip.y + rHip.y) / 2;
    final torsoHeight = (avgShoulderY - avgHipY).abs();
    final footToHipDistanceNorm = _pointDistance(
          (lHip.x + rHip.x) / 2,
          avgHipY,
          (lHeel.x + rHeel.x) / 2,
          (lHeel.y + rHeel.y) / 2,
        ) /
        _bodyNormalizer(torsoHeight, shoulderDist);
    final torsoVerticalNorm =
        torsoHeight / (shoulderDist == 0 ? 1 : shoulderDist);

    if (footToHipDistanceNorm >
        FootPlacementConfig.MAX_FOOT_TO_HIP_DISTANCE_NORM) {
      return false;
    }
    if (torsoVerticalNorm < PostureConfig.COLLAPSE_THRESHOLD) return false;

    return true;
  }

  double get _elapsedSeconds {
    return _validHoldTimeMs / 1000.0;
  }

  @override
  bool requestStop() => _elapsedSeconds >= ButterflyConfig.TARGET_HOLD_SECONDS;

  @override
  void onSetComplete() {
    final allFaults = [
      ...kneeMetric.faults,
      ...postureMetric.faults,
      ...footPlacementMetric.faults,
    ];
    final holdCorrect =
        _validHoldTimeMs >= ButterflyConfig.TARGET_HOLD_SECONDS * 1000 &&
            !allFaults.any((f) => f.affectsForm);

    logger.pushKey("max_rep", 1);
    logger.pushKey("total_hold_time", _elapsedSeconds);
    logger.pushKey("max_knee_separation", kneeMetric.maxSeparation);
    logger.pushKey("knee_fails_count", kneeMetric.faults.length);
    logger.pushKey("posture_fails_count", postureMetric.faults.length);
    logger.pushKey(
        "foot_placement_fails_count", footPlacementMetric.faults.length);
    logger.addRepLog(RepLog(
      correctForm: holdCorrect,
      repNumber: 1,
      data: {
        "hold_time": _elapsedSeconds,
        "fault_types": allFaults.map((f) => f.type).toSet().toList(),
      },
    ));
    correctForm = holdCorrect;
    logger.pushGoodRepCount();
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.front) {
      return _safetyError("Vui lòng đặt điện thoại chính diện.");
    }
    final requiredLandmarks = [
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftHeel,
      PoseLandmarkType.rightHeel,
    ];
    for (final type in requiredLandmarks) {
      final landmark = landmarks[type];
      if (landmark == null || !ExerciseBase.isLandmarkConfident(landmark)) {
        return _safetyError(
            "Các điểm khớp bị khuất. Hãy ngồi trọn trong khung hình.");
      }
    }
    return null;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final now = frameTimestampMs;
    final dt = _lastFrameTimeMs == null ? 0 : now - _lastFrameTimeMs!;
    _lastFrameTimeMs = now;

    final lKnee = smoothedLandmarks[PoseLandmarkType.leftKnee];
    final rKnee = smoothedLandmarks[PoseLandmarkType.rightKnee];
    final lAnkle = smoothedLandmarks[PoseLandmarkType.leftAnkle];
    final rAnkle = smoothedLandmarks[PoseLandmarkType.rightAnkle];
    final lShoulder = smoothedLandmarks[PoseLandmarkType.leftShoulder];
    final rShoulder = smoothedLandmarks[PoseLandmarkType.rightShoulder];
    final lHip = smoothedLandmarks[PoseLandmarkType.leftHip];
    final rHip = smoothedLandmarks[PoseLandmarkType.rightHip];
    final lHeel = smoothedLandmarks[PoseLandmarkType.leftHeel];
    final rHeel = smoothedLandmarks[PoseLandmarkType.rightHeel];

    if (lKnee == null ||
        rKnee == null ||
        lAnkle == null ||
        rAnkle == null ||
        lShoulder == null ||
        rShoulder == null ||
        lHip == null ||
        rHip == null ||
        lHeel == null ||
        rHeel == null) {
      return;
    }
    if (![
      lKnee,
      rKnee,
      lAnkle,
      rAnkle,
      lShoulder,
      rShoulder,
      lHip,
      rHip,
      lHeel,
      rHeel,
    ].every(ExerciseBase.isLandmarkConfident)) {
      return;
    }

    double kneeSep = (lKnee.x - rKnee.x).abs();
    double ankleSep = (lAnkle.x - rAnkle.x).abs();
    double avgKneeY = (lKnee.y + rKnee.y) / 2;
    double avgShoulderY = (lShoulder.y + rShoulder.y) / 2;
    double avgHipY = (lHip.y + rHip.y) / 2;
    double torsoHeight = (avgShoulderY - avgHipY).abs();
    final shoulderWidth = (lShoulder.x - rShoulder.x).abs();
    final ankleSeparationNorm =
        ankleSep / (shoulderWidth == 0 ? 1 : shoulderWidth);
    final footToHipDistanceNorm = _pointDistance(
          (lHip.x + rHip.x) / 2,
          avgHipY,
          (lHeel.x + rHeel.x) / 2,
          (lHeel.y + rHeel.y) / 2,
        ) /
        _bodyNormalizer(torsoHeight, shoulderWidth);
    final torsoVerticalNorm =
        torsoHeight / (shoulderWidth == 0 ? 1 : shoulderWidth);

    // ButterflyStretch là nguồn sự thật cho hold time.
    // Dùng thời gian trôi qua liên tục từ lúc bắt đầu
    final ctx = StretchContext(
      kneeSeparation: kneeSep,
      leftKneeY: lKnee.y,
      rightKneeY: rKnee.y,
      ankleSeparation: ankleSep,
      shoulderToHipRatio: torsoHeight,
      shoulderTilt: (lShoulder.y - rShoulder.y).abs(),
      ankleSeparationNorm: ankleSeparationNorm,
      footToHipDistanceNorm: footToHipDistanceNorm,
      torsoVerticalNorm: torsoVerticalNorm,
      currentState: stretchState,
      frameTimestamp: now,
      resultIssues: resultIssues,
      currentHoldSeconds: _elapsedSeconds, // <-- truyền vào ctx
    );

    frameBuffer.addFrame(FrameSnapshot(
        log: {"avgKneeY": avgKneeY, "kneeSep": kneeSep}, timeStamp: now));
    if (frameBuffer.frameBuffer.length > ButterflyConfig.MAX_BUFFER_FRAMES) {
      frameBuffer.frameBuffer.removeAt(0);
    }
    _updateStateBuffer(avgKneeY, kneeSep, torsoHeight, now);

    if (stretchState != ButterflyState.setup) {
      for (final metric in _metrics) {
        metric.update(ctx);
        debugData.addAll(metric.debugData);
      }
    }

    final normalizedKneeDiff =
        (lKnee.y - rKnee.y).abs() / (torsoHeight == 0 ? 1 : torsoHeight);
    final normalizedShoulderTilt = (lShoulder.y - rShoulder.y).abs() /
        (torsoHeight == 0 ? 1 : torsoHeight);
    final formClean =
        normalizedKneeDiff <= KneeSeparationConfig.ASYMMETRY_THRESHOLD &&
            normalizedShoulderTilt <= PostureConfig.TILT_THRESHOLD &&
            torsoVerticalNorm >= PostureConfig.COLLAPSE_THRESHOLD &&
            ankleSeparationNorm <= ButterflyConfig.MAX_ANKLE_SEPARATION_NORM &&
            footToHipDistanceNorm <=
                FootPlacementConfig.MAX_FOOT_TO_HIP_DISTANCE_NORM;
    if (stretchState == ButterflyState.isometric_hold && formClean) {
      _validHoldTimeMs += dt;
    }

    repCount =
        _elapsedSeconds.toInt(); // Cập nhật repCount để UI quay vòng liên tục

    _updateHoldDisplay(now);
    _updatePhaseInstructions();
  }

  void _updateStateBuffer(
      double avgKneeY, double kneeSep, double torsoHeight, int timestampMs) {
    double yChange = 0.0;
    final buffer = frameBuffer.frameBuffer;
    if (buffer.length >= 2) {
      int lookback = buffer.length > 10 ? 10 : buffer.length - 1;
      double currentY = buffer.last.log["avgKneeY"] ?? 0.0;
      double pastY =
          buffer[buffer.length - 1 - lookback].log["avgKneeY"] ?? 0.0;
      yChange = currentY - pastY;
    }
    final yChangeNorm = yChange / (torsoHeight == 0 ? 1 : torsoHeight);

    if (stretchState == ButterflyState.setup &&
        yChangeNorm > ButterflyConfig.STRETCH_THRESHOLD) {
      _transitionState(ButterflyState.stretching, timestampMs);
    } else if ((stretchState == ButterflyState.stretching ||
            stretchState == ButterflyState.release) &&
        _holdDebouncer.update(
            yChangeNorm.abs() < ButterflyConfig.HOLD_STABILITY_THRESHOLD)) {
      _transitionState(ButterflyState.isometric_hold, timestampMs);
    } else if (stretchState == ButterflyState.isometric_hold &&
        _releaseDebouncer
            .update(yChangeNorm < ButterflyConfig.RELEASE_THRESHOLD)) {
      _transitionState(ButterflyState.release, timestampMs);
    }
  }

  void _transitionState(ButterflyState newState, int timestampMs) {
    if (newState == stretchState) return;

    previousState = stretchState;
    stretchState = newState;

    for (final metric in _metrics) {
      metric.onStateTransition(previousState, newState, timestampMs);
    }
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

  String _safetyError(String message) {
    _lastFrameTimeMs = frameTimestampMs;
    return message;
  }

  /// Duy nhất nơi ghi feedback['Thời gian'] — không còn HoldDurationMetric ghi đè.
  void _updateHoldDisplay(int now) {
    final displayed = _elapsedSeconds;
    resultIssues.feedback['Thời gian'] =
        '${displayed.toStringAsFixed(1)}s / ${ButterflyConfig.TARGET_HOLD_SECONDS}s';
    debugData['total_hold'] = displayed.toStringAsFixed(1);
  }

  void _updatePhaseInstructions() {
    switch (stretchState) {
      case ButterflyState.setup:
        resultIssues.addInstruction(
            'setup', 'Trạng thái', 'Chụm hai lòng bàn chân');
        break;
      case ButterflyState.stretching:
        resultIssues.addInstruction(
            'stretching', 'Trạng thái', 'Ép gối xuống từ từ');
        break;
      case ButterflyState.isometric_hold:
        resultIssues.addInstruction('hold', 'Trạng thái', 'Giữ nguyên ở đây!');
        break;
      case ButterflyState.release:
        resultIssues.addInstruction('release', 'Trạng thái', 'Thả lỏng');
        break;
    }
  }
}
