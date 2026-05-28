import 'package:vika/utils/debouncer.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/frame_snapshot.dart';
import '../../pose/vika_image_orientation.dart';
import '../exercise_base.dart';
import 'metrics/butterfly_metric_base.dart';
import 'metrics/knee_separation_metric.dart';
import 'metrics/posture_metric.dart';
import 'metrics/hold_duration_metric.dart';

class ButterflyConfig {
  static const int TARGET_HOLD_SECONDS = 30;
  static const double MAX_ANKLE_SEPARATION_NORM = 0.2;
  static const double HOLD_STABILITY_THRESHOLD = 4.0;
  static const double STRETCH_THRESHOLD = 3.0;
  static const double RELEASE_THRESHOLD = -4.0;
}

class ButterflyStretch extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  ButterflyState stretchState = ButterflyState.setup;
  ButterflyState previousState = ButterflyState.setup;

  int? _exerciseStartTimeMs;

  final KneeSeparationMetric kneeMetric = KneeSeparationMetric();
  final PostureMetric postureMetric = PostureMetric();
  final HoldDurationMetric holdMetric = HoldDurationMetric();

  late final List<ButterflyMetricBase> _metrics = [
    kneeMetric,
    postureMetric,
    holdMetric,
  ];

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
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.front) return false;

    final lKnee = landmarks[PoseLandmarkType.leftKnee];
    final rKnee = landmarks[PoseLandmarkType.rightKnee];
    final lAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final lShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rShoulder = landmarks[PoseLandmarkType.rightShoulder];

    if (lKnee == null || rKnee == null || lAnkle == null || rAnkle == null ||
        lShoulder == null || rShoulder == null) {
      return false;
    }

    double shoulderDist = (lShoulder.x - rShoulder.x).abs();
    if (shoulderDist < 10) return false;

    double ankleDist = (lAnkle.x - rAnkle.x).abs();
    if ((ankleDist / shoulderDist) > 0.6) return false;

    double kneeDist = (lKnee.x - rKnee.x).abs();
    if (kneeDist < shoulderDist * 0.8) return false;

    return true;
  }

  double get _elapsedSeconds {
    if (_exerciseStartTimeMs == null) return 0.0;
    return (frameTimestampMs - _exerciseStartTimeMs!) / 1000.0;
  }

  @override
  bool requestStop() => _elapsedSeconds >= ButterflyConfig.TARGET_HOLD_SECONDS;

  @override
  void onSetComplete() {
    logger.pushKey("total_hold_time", _elapsedSeconds);
    logger.pushKey("max_knee_separation", kneeMetric.maxSeparation);
    logger.pushKey("posture_fails_count", postureMetric.faultsCount);
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.front) return "Vui lòng đặt điện thoại chính diện.";
    return null;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final lKnee = smoothedLandmarks[PoseLandmarkType.leftKnee];
    final rKnee = smoothedLandmarks[PoseLandmarkType.rightKnee];
    final lAnkle = smoothedLandmarks[PoseLandmarkType.leftAnkle];
    final rAnkle = smoothedLandmarks[PoseLandmarkType.rightAnkle];
    final lShoulder = smoothedLandmarks[PoseLandmarkType.leftShoulder];
    final rShoulder = smoothedLandmarks[PoseLandmarkType.rightShoulder];
    final lHip = smoothedLandmarks[PoseLandmarkType.leftHip];

    if (lKnee == null || rKnee == null || lAnkle == null || rAnkle == null ||
        lShoulder == null || rShoulder == null || lHip == null) {
      return;
    }

    double kneeSep = (lKnee.x - rKnee.x).abs();
    double ankleSep = (lAnkle.x - rAnkle.x).abs();
    double avgKneeY = (lKnee.y + rKnee.y) / 2;
    double avgShoulderY = (lShoulder.y + rShoulder.y) / 2;
    double torsoHeight = (avgShoulderY - lHip.y).abs();

    final now = frameTimestampMs;
    _exerciseStartTimeMs ??= now;

    // ButterflyStretch là nguồn sự thật cho hold time.
    // Dùng thời gian trôi qua liên tục từ lúc bắt đầu
    final ctx = StretchContext(
      kneeSeparation: kneeSep,
      leftKneeY: lKnee.y,
      rightKneeY: rKnee.y,
      ankleSeparation: ankleSep,
      shoulderToHipRatio: torsoHeight,
      shoulderTilt: (lShoulder.y - rShoulder.y).abs(),
      currentState: stretchState,
      frameTimestamp: now,
      resultIssues: resultIssues,
      currentHoldSeconds: _elapsedSeconds, // <-- truyền vào ctx
    );

    frameBuffer.addFrame(FrameSnapshot(log: {"avgKneeY": avgKneeY, "kneeSep": kneeSep}, timeStamp: now));
    _updateStateBuffer(avgKneeY, kneeSep, now);

    if (stretchState != ButterflyState.setup) {
      for (final metric in _metrics) {
        metric.update(ctx);
        debugData.addAll(metric.debugData);
      }
    }

    repCount = _elapsedSeconds.toInt(); // Cập nhật repCount để UI quay vòng liên tục

    _updateHoldDisplay(now);
    _updatePhaseInstructions();
  }

  void _updateStateBuffer(double avgKneeY, double kneeSep, int timestampMs) {
    double yChange = 0.0;
    final buffer = frameBuffer.frameBuffer;
    if (buffer.length >= 2) {
      int lookback = buffer.length > 10 ? 10 : buffer.length - 1;
      double currentY = buffer.last.log["avgKneeY"] ?? 0.0;
      double pastY = buffer[buffer.length - 1 - lookback].log["avgKneeY"] ?? 0.0;
      yChange = currentY - pastY;
    }

    if (stretchState == ButterflyState.setup && yChange > ButterflyConfig.STRETCH_THRESHOLD) {
      _transitionState(ButterflyState.stretching, timestampMs);
    } else if ((stretchState == ButterflyState.stretching || stretchState == ButterflyState.release) &&
        _holdDebouncer.update(yChange.abs() < ButterflyConfig.HOLD_STABILITY_THRESHOLD)) {
      _transitionState(ButterflyState.isometric_hold, timestampMs);
    } else if (stretchState == ButterflyState.isometric_hold &&
        _releaseDebouncer.update(yChange < ButterflyConfig.RELEASE_THRESHOLD)) {
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
        resultIssues.addInstruction('setup', 'Trạng thái', 'Chụm hai lòng bàn chân');
        break;
      case ButterflyState.stretching:
        resultIssues.addInstruction('stretching', 'Trạng thái', 'Ép gối xuống từ từ');
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