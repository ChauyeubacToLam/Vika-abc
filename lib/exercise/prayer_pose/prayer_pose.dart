// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/utils/debouncer.dart';
import 'package:vika/utils/pose_math_helpers.dart';
import 'package:vika/utils/exercise_logger.dart';

import 'metrics/prayer_pose_metric_base.dart';
import 'metrics/posture_stack_metric.dart';

class PrayerPoseConfig {
  static const int MAX_REP = 1;
  static const double HOLD_DURATION = 12.0;
  static const double EXIT_DURATION = 3.0;

  static const int SETUP_STILL_FRAMES = 15;
  static const int CALIBRATION_FRAMES = 20;

  static const double ENTRY_TRUNK_TOLERANCE = 35.0;
  static const double START_SHOULDER_EASE_MIN = 0.30;
  static const double HOLD_HIP_VELOCITY_MAX = 0.06;
  static const double BREAK_HIP_VELOCITY_MIN = 0.18;
  static const double SHOULDER_EASE_RATIO_MIN = 0.70;
}

enum PrayerPoseState { entry, holding, exit }

class PrayerPose extends ExerciseBase {
  final int maxRep;

  PrayerPose({this.maxRep = PrayerPoseConfig.MAX_REP});

  PrayerPoseState prayerPoseState = PrayerPoseState.entry;
  PrayerPoseState previousPrayerPoseState = PrayerPoseState.entry;

  int? _holdStartMs;
  int? _exitStartMs;
  double? _previousHipY;
  int? _previousTimestampMs;
  bool _exitShouldCount = false;
  String? _exitRejectReason;

  final Debouncer _holdStillDebouncer =
      Debouncer(requiredFrames: PrayerPoseConfig.SETUP_STILL_FRAMES);
  final Debouncer _breakPositionDebouncer = Debouncer(requiredFrames: 8);
  final StickyDebouncer _shoulderEaseDebouncer =
      StickyDebouncer(requiredFrames: 10);

  final _postureStackMetric = PostureStackMetric();

  late final List<PrayerPoseMetricBase> _metrics = [
    _postureStackMetric,
  ];

  final List<double> _calibrationScaleSamples = [];
  final List<double> _calibrationTrunkSamples = [];
  final List<double> _calibrationCervicalSamples = [];
  final List<double> _calibrationPostureSamples = [];
  final List<double> _calibrationShoulderEaseSamples = [];
  double? _baselineScaleFactor;
  double? _trunkBaseline;
  double? _cervicalBaseline;
  double? _postureBaseline;
  double? _shoulderEaseBaseline;
  bool _isCalibrated = false;

  @override
  String get exerciseName => 'Prayer Pose';

  @override
  String get currentPhaseKey => prayerPoseState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (prayerPoseState) {
      case PrayerPoseState.entry:
        return 'Vào tư thế';
      case PrayerPoseState.holding:
        return 'Giữ!';
      case PrayerPoseState.exit:
        return 'Thoát tư thế';
    }
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final body = _resolveSideLandmarks(landmarks);
    if (body == null) return false;

    final scale = _scaleFrom(body);
    if (scale < 1.0) return false;

    final trunkClockAngle = calculateVerticalAngle(
      pivot: body.hip,
      point: body.shoulder,
    );
    final upright = body.shoulder.y < body.hip.y &&
        (body.ankle == null || body.hip.y < body.ankle!.y) &&
        clockAngleDeviation(trunkClockAngle, 0.0).abs() <=
            PrayerPoseConfig.ENTRY_TRUNK_TOLERANCE;
    final shouldersRelaxed = _shouldersRelaxedForStart(body, scale);
    final hipVelocity = _hipVelocity(body.hip.y, frameTimestampMs, scale);
    final stillEnough =
        hipVelocity.abs() <= PrayerPoseConfig.HOLD_HIP_VELOCITY_MAX;

    if (upright && shouldersRelaxed && stillEnough) {
      _collectCalibrationData(body, scale, trunkClockAngle);
    }

    debugData['startUpright'] = upright;
    debugData['startShouldersRelaxed'] = shouldersRelaxed;
    debugData['startStill'] = stillEnough;

    return upright && shouldersRelaxed && stillEnough;
  }

  void _collectCalibrationData(
    _PrayerPoseLandmarks body,
    double scale,
    double trunkClockAngle,
  ) {
    if (_isCalibrated) return;

    _calibrationScaleSamples.add(scale);
    _calibrationTrunkSamples.add(clockAngleDeviation(trunkClockAngle, 0.0));

    if (body.ear != null && body.ear!.likelihood >= 0.5) {
      final cervical = calculateAngle(
        firstPoint: body.ear!,
        midPoint: body.shoulder,
        lastPoint: body.hip,
      );
      final postureOffset =
          ((body.ear!.x - body.shoulder.x) * _forwardSign()) / scale;
      final shoulderEase = _earShoulderDistanceRatio(body, scale);

      _calibrationCervicalSamples.add(cervical);
      _calibrationPostureSamples.add(postureOffset);
      _calibrationShoulderEaseSamples.add(shoulderEase);
    }

    if (_calibrationScaleSamples.length >=
        PrayerPoseConfig.CALIBRATION_FRAMES) {
      _baselineScaleFactor = _average(_calibrationScaleSamples);
      _trunkBaseline = _average(_calibrationTrunkSamples);
      if (_calibrationCervicalSamples.isNotEmpty) {
        _cervicalBaseline = _average(_calibrationCervicalSamples);
      }
      if (_calibrationPostureSamples.isNotEmpty) {
        _postureBaseline = _average(_calibrationPostureSamples);
      }
      if (_calibrationShoulderEaseSamples.isNotEmpty) {
        _shoulderEaseBaseline = _average(_calibrationShoulderEaseSamples);
      }
      _isCalibrated = true;
    }
  }

  double _average(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey('target_holds', maxRep);
    logger.pushGoodRepCount();
    logger.pushKey('max_rep', maxRep);
    logger.pushKey(
        'posture_stack_fails_count', _postureStackMetric.faultsCount);
  }

  @override
  double? get liveHoldSeconds =>
      prayerPoseState == PrayerPoseState.holding ? _currentHoldSeconds() : null;

  @override
  double? get liveHoldTargetSeconds => PrayerPoseConfig.HOLD_DURATION;

  @override
  void onExerciseActivated() {
    if (prayerPoseState == PrayerPoseState.entry) {
      _transitionState(PrayerPoseState.holding, frameTimestampMs);
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return '⚠️ Xin hãy quay nghiêng để theo dõi tư thế Pranamasana';
    }

    final body = _resolveSideLandmarks(landmarks);
    if (body == null) {
      return '⚠️ Đảm bảo vai và hông trong khung hình';
    }

    final required = [body.shoulder, body.hip];
    if (!required.every(ExerciseBase.isLandmarkConfident)) {
      return '⚠️ Hình ảnh không rõ. Điều chỉnh ánh sáng hoặc vị trí';
    }

    return null;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final body = _resolveSideLandmarks(smoothedLandmarks);
    if (body == null) return;

    final scale = _baselineScaleFactor ?? _scaleFrom(body);
    if (scale < 1.0) return;

    final trunkClockAngle = calculateVerticalAngle(
      pivot: body.hip,
      point: body.shoulder,
    );
    final hipVelocity = _hipVelocity(body.hip.y, frameTimestampMs, scale);
    final shoulderEaseRatio = _earShoulderDistanceRatio(body, scale);

    _updatePrayerPoseState(
      hipVelocity: hipVelocity,
      timestampMs: frameTimestampMs,
    );

    final ctx = PrayerPoseContext(
      state: prayerPoseState,
      frameTimestampMs: frameTimestampMs,
      scaleFactor: scale,
      resultIssues: resultIssues,
      cameraFacing: cameraFacing,
      trunkClockAngle: trunkClockAngle,
      hipVelocity: hipVelocity,
      earShoulderDistanceRatio: shoulderEaseRatio,
      ear: body.ear,
      shoulder: body.shoulder,
      hip: body.hip,
      ankle: body.ankle,
      trunkBaseline: _trunkBaseline,
      cervicalBaseline: _cervicalBaseline,
      postureBaseline: _postureBaseline,
      shoulderEaseBaseline: _shoulderEaseBaseline,
    );

    if (prayerPoseState == PrayerPoseState.holding) {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
      _updateShoulderEaseFeedback(ctx);
    }

    _updatePhaseInstructions();

    debugData['prayerPoseState'] = prayerPoseState.toString().split('.').last;
    debugData['repCount'] = repCount.toString();
    debugData['trunkClock'] = trunkClockAngle.toStringAsFixed(1);
    debugData['hipVelocity'] = hipVelocity.toStringAsFixed(3);
    debugData['shoulderEase'] = shoulderEaseRatio.toStringAsFixed(3);
    debugData['calibrated'] = _isCalibrated;

    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }
  }

  void _updateShoulderEaseFeedback(PrayerPoseContext ctx) {
    if (ctx.ear == null || ctx.shoulderEaseBaseline == null) return;

    final relaxedMin =
        ctx.shoulderEaseBaseline! * PrayerPoseConfig.SHOULDER_EASE_RATIO_MIN;
    final shouldersHiked = _shoulderEaseDebouncer
        .update(ctx.earShoulderDistanceRatio < relaxedMin);

    if (shouldersHiked) {
      resultIssues.feedback['Shoulders'] = 'Thả lỏng vai xuống nhé';
      resultIssues.addInstruction(
        'holding',
        'shoulderEase',
        'Thả lỏng vai xuống, giữ cổ dài và ngực mềm.',
      );
    } else {
      resultIssues.feedback['Shoulders'] = 'Vai thả lỏng ✓';
    }
  }

  void _updatePhaseInstructions() {
    if (prayerPoseState == PrayerPoseState.holding) {
      final holdSecs = _currentHoldSeconds();
      final remaining = (PrayerPoseConfig.HOLD_DURATION - holdSecs)
          .clamp(0.0, PrayerPoseConfig.HOLD_DURATION);
      resultIssues.addInstruction(
        'holding',
        'Status',
        'Giữ! ${remaining.toStringAsFixed(1)}s',
      );
      debugData['holdProgress'] =
          (holdSecs / PrayerPoseConfig.HOLD_DURATION).clamp(0.0, 1.0);
    }

    if (prayerPoseState == PrayerPoseState.exit && _exitStartMs != null) {
      final elapsed = (frameTimestampMs - _exitStartMs!) / 1000.0;
      final remaining = (PrayerPoseConfig.EXIT_DURATION - elapsed)
          .clamp(0.0, PrayerPoseConfig.EXIT_DURATION);
      resultIssues.addInstruction(
        'exit',
        'Status',
        repCount >= maxRep
            ? 'Hoàn tất'
            : 'Thư giãn ${remaining.toStringAsFixed(1)}s',
      );
    }
  }

  void _updatePrayerPoseState({
    required double hipVelocity,
    required int timestampMs,
  }) {
    final stillEnough =
        hipVelocity.abs() <= PrayerPoseConfig.HOLD_HIP_VELOCITY_MAX;
    final confirmedHold = _holdStillDebouncer.update(stillEnough);
    final brokePosition = _breakPositionDebouncer.update(
      hipVelocity.abs() >= PrayerPoseConfig.BREAK_HIP_VELOCITY_MIN,
    );

    switch (prayerPoseState) {
      case PrayerPoseState.entry:
        if (confirmedHold) {
          _transitionState(PrayerPoseState.holding, timestampMs);
        }
        break;
      case PrayerPoseState.holding:
        if (_currentHoldSeconds() >= PrayerPoseConfig.HOLD_DURATION) {
          _exitShouldCount = true;
          _exitRejectReason = null;
          _transitionState(PrayerPoseState.exit, timestampMs);
        } else if (brokePosition) {
          _exitShouldCount = false;
          _exitRejectReason =
              'Rời tư thế quá sớm - giữ Cầu nguyện đủ thời gian trước khi thả lỏng.';
          _transitionState(PrayerPoseState.exit, timestampMs);
        }
        break;
      case PrayerPoseState.exit:
        if (_exitStartMs != null) {
          final elapsed = (timestampMs - _exitStartMs!) / 1000.0;
          if (elapsed >= PrayerPoseConfig.EXIT_DURATION) {
            _transitionState(PrayerPoseState.entry, timestampMs);
          }
        }
        break;
    }
  }

  void _transitionState(PrayerPoseState newState, int timestampMs) {
    previousPrayerPoseState = prayerPoseState;
    prayerPoseState = newState;

    switch (newState) {
      case PrayerPoseState.holding:
        _holdStartMs = timestampMs;
        _exitStartMs = null;
        _exitShouldCount = false;
        _exitRejectReason = null;
        resultIssues.instructions.clear();
        break;
      case PrayerPoseState.exit:
        _exitStartMs = timestampMs;
        _finalizeHold();
        break;
      case PrayerPoseState.entry:
        _holdStartMs = null;
        _resetCalibration();
        break;
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousPrayerPoseState, newState, timestampMs);
    }
  }

  void _finalizeHold() {
    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      allFaults.addAll(metric.faults);
    }

    if (!_exitShouldCount) {
      correctForm = false;
      final reason =
          _exitRejectReason ?? 'Rời tư thế quá sớm - lần này chưa được tính.';
      resultIssues.feedback['Result'] = 'Lần này chưa tính nhé';
      resultIssues.feedback['Form'] = reason;
      final faultMap = _faultMapFrom(allFaults);
      faultMap.putIfAbsent('REP_COMPLETE', () => {});
      faultMap['REP_COMPLETE']!['NoCount'] = reason;
      setFeedback.add({false: faultMap});
      for (final metric in _metrics) {
        metric.reset();
      }
      return;
    }

    repCount += 1;
    correctForm = !allFaults.any((f) => f.affectsForm);
    resultIssues.feedback['Result'] = correctForm ? 'Tốt lắm!' : 'Chỉnh tư thế';

    final faultMap = _faultMapFrom(allFaults);
    setFeedback.add({correctForm: faultMap});

    logger.addRepLog(RepLog(
      correctForm: correctForm,
      repNumber: repCount,
      data: {
        'hold_time': PrayerPoseConfig.HOLD_DURATION,
        'fault_types': allFaults.map((f) => f.type).toSet().toList(),
      },
    ));

    for (final metric in _metrics) {
      metric.resetAndCountFault();
    }
  }

  void _resetCalibration() {
    _calibrationScaleSamples.clear();
    _calibrationTrunkSamples.clear();
    _calibrationCervicalSamples.clear();
    _calibrationPostureSamples.clear();
    _calibrationShoulderEaseSamples.clear();
    _baselineScaleFactor = null;
    _trunkBaseline = null;
    _cervicalBaseline = null;
    _postureBaseline = null;
    _shoulderEaseBaseline = null;
    _isCalibrated = false;
    _previousHipY = null;
    _previousTimestampMs = null;
    _exitShouldCount = false;
    _exitRejectReason = null;
    _holdStillDebouncer.reset();
    _breakPositionDebouncer.reset();
    _shoulderEaseDebouncer.reset();
  }

  double _currentHoldSeconds() {
    if (_holdStartMs == null) return 0.0;
    return (frameTimestampMs - _holdStartMs!) / 1000.0;
  }

  double _hipVelocity(double hipY, int timestampMs, double scale) {
    double velocity = 0.0;
    if (_previousHipY != null && _previousTimestampMs != null) {
      final deltaMs = timestampMs - _previousTimestampMs!;
      if (deltaMs > 0 && scale > 1.0) {
        velocity = ((hipY - _previousHipY!) / scale) / (deltaMs / 1000.0);
      }
    }
    _previousHipY = hipY;
    _previousTimestampMs = timestampMs;
    return velocity;
  }

  Map<String, Map<String, String>> _faultMapFrom(List<FaultRecord> faults) {
    final faultMap = <String, Map<String, String>>{};
    for (final fault in faults) {
      faultMap.putIfAbsent(fault.phase, () => {});
      faultMap[fault.phase]![fault.type] = fault.message;
    }
    return faultMap;
  }

  @override
  Map<String, String> processNoPoseFrame() {
    if (prayerPoseState == PrayerPoseState.holding) {
      prayerPoseState = PrayerPoseState.entry;
      previousPrayerPoseState = PrayerPoseState.holding;
      _holdStartMs = null;
      _resetCalibration();
      for (final metric in _metrics) {
        metric.reset();
      }
      resultIssues.addInstruction(
        'entry',
        'Status',
        'Mất mốc cơ thể, đứng lại tư thế Cầu nguyện trước khi giữ.',
      );
    }
    return super.processNoPoseFrame();
  }

  double _scaleFrom(_PrayerPoseLandmarks body) {
    return calculateDistance(body.shoulder, body.hip);
  }

  double _forwardSign() {
    return cameraFacing == CameraFacing.right ? -1.0 : 1.0;
  }

  double _earShoulderDistanceRatio(_PrayerPoseLandmarks body, double scale) {
    if (body.ear == null || scale < 1.0) return 1.0;
    return (body.shoulder.y - body.ear!.y).abs() / scale;
  }

  bool _shouldersRelaxedForStart(_PrayerPoseLandmarks body, double scale) {
    if (body.ear == null || scale < 1.0) return true;
    return _earShoulderDistanceRatio(body, scale) >=
        PrayerPoseConfig.START_SHOULDER_EASE_MIN;
  }

  _PrayerPoseLandmarks? _resolveSideLandmarks(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final shoulder = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightShoulder,
      leftType: PoseLandmarkType.leftShoulder,
    );
    final hip = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightHip,
      leftType: PoseLandmarkType.leftHip,
    );
    final ankle = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightAnkle,
      leftType: PoseLandmarkType.leftAnkle,
    );
    final ear = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightEar,
      leftType: PoseLandmarkType.leftEar,
    );

    if (shoulder == null || hip == null) return null;

    return _PrayerPoseLandmarks(
      shoulder: shoulder,
      hip: hip,
      ankle: ankle,
      ear: ear,
    );
  }
}

class _PrayerPoseLandmarks {
  final PoseLandmark shoulder;
  final PoseLandmark hip;
  final PoseLandmark? ankle;
  final PoseLandmark? ear;

  _PrayerPoseLandmarks({
    required this.shoulder,
    required this.hip,
    this.ankle,
    this.ear,
  });
}
