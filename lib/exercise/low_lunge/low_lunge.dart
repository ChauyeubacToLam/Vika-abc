// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/utils/debouncer.dart';
import 'package:vika/utils/pose_math_helpers.dart';
import 'package:vika/utils/exercise_logger.dart';

import 'metrics/low_lunge_metric_base.dart';
import 'metrics/knee_travel_metric.dart';
import 'metrics/cervical_safety_metric.dart';

class LowLungeConfig {
  static const int MAX_REP = 2;
  static const double HOLD_DURATION = 30.0;
  static const double EXIT_DURATION = 4.0;

  static const int SETUP_STILL_FRAMES = 6;
  static const int CALIBRATION_FRAMES = 20;

  static const double MIN_STANCE_RATIO = 0.55;
  static const double BACK_KNEE_GROUNDED_MAX = 0.80;
  static const double FRONT_KNEE_SETUP_MAX = 165.0;

  static const double HOLD_HIP_VELOCITY_MAX = 0.06;
  static const double BREAK_HIP_VELOCITY_MIN = 0.18;

  static const double FRONT_KNEE_GOOD_MIN = 85.0;
  static const double FRONT_KNEE_GOOD_MAX = 120.0;
  static const double FRONT_KNEE_SHALLOW = 130.0;
  static const double CHEST_LIFT_MIN = 35.0;
}

enum LowLungeState { entry, holding, exit }

class LowLunge extends ExerciseBase {
  final int maxRep;

  LowLunge({this.maxRep = LowLungeConfig.MAX_REP});

  LowLungeState lowLungeState = LowLungeState.entry;
  LowLungeState previousLowLungeState = LowLungeState.entry;

  int? _holdStartMs;
  int? _exitStartMs;
  double? _previousHipY;
  int? _previousTimestampMs;
  bool _exitShouldCount = false;
  String? _exitRejectReason;

  final Debouncer _holdStillDebouncer =
      Debouncer(requiredFrames: LowLungeConfig.SETUP_STILL_FRAMES);
  final Debouncer _breakPositionDebouncer = Debouncer(requiredFrames: 8);

  final _kneeTravelMetric = KneeTravelMetric();
  final _cervicalSafetyMetric = CervicalSafetyMetric();

  late final List<LowLungeMetricBase> _metrics = [
    _kneeTravelMetric,
    _cervicalSafetyMetric,
  ];

  final List<double> _calibrationScaleSamples = [];
  final List<double> _calibrationCervicalSamples = [];
  final List<double> _calibrationFrontAnkleXSamples = [];
  double? _baselineScaleFactor;
  double? _baselineCervicalAngle;
  double? _frontAnkleBaselineX;
  bool _isCalibrated = false;

  @override
  String get exerciseName => 'Low Lunge';

  @override
  String get currentPhaseKey => lowLungeState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (lowLungeState) {
      case LowLungeState.entry:
        return 'Vào tư thế';
      case LowLungeState.holding:
        return 'Giữ!';
      case LowLungeState.exit:
        return 'Đổi bên';
    }
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lunge = _resolveLungeLandmarks(landmarks);
    if (lunge == null) return false;

    final scale = _scaleFrom(lunge);
    if (scale < 1.0) return false;

    final stanceRatio = (lunge.frontAnkle.x - lunge.backAnkle.x).abs() / scale;
    final backKneeGrounded =
        (lunge.backKnee.y - lunge.backAnkle.y).abs() / scale <=
            LowLungeConfig.BACK_KNEE_GROUNDED_MAX;
    final frontKneeAngle = calculateAngleNormalized(
      firstPoint: lunge.frontHip,
      midPoint: lunge.frontKnee,
      lastPoint: lunge.frontAnkle,
    );

    final inStart = stanceRatio > LowLungeConfig.MIN_STANCE_RATIO &&
        backKneeGrounded &&
        frontKneeAngle < LowLungeConfig.FRONT_KNEE_SETUP_MAX;

    if (inStart) _collectCalibrationData(landmarks, lunge, scale);

    debugData['startStanceRatio'] = stanceRatio.toStringAsFixed(2);
    debugData['startBackKneeGrounded'] = backKneeGrounded;
    debugData['startFrontKneeAngle'] = frontKneeAngle.toStringAsFixed(1);

    return inStart;
  }

  void _collectCalibrationData(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    _LungeLandmarks lunge,
    double scale,
  ) {
    if (_isCalibrated) return;

    _calibrationScaleSamples.add(scale);
    _calibrationFrontAnkleXSamples.add(lunge.frontAnkle.x);

    final ear = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightEar,
      leftType: PoseLandmarkType.leftEar,
    );
    if (ear != null && ear.likelihood >= 0.5) {
      _calibrationCervicalSamples.add(
        calculateAngleNormalized(
          firstPoint: ear,
          midPoint: lunge.frontShoulder,
          lastPoint: lunge.frontHip,
        ),
      );
    }

    if (_calibrationScaleSamples.length >= LowLungeConfig.CALIBRATION_FRAMES) {
      _baselineScaleFactor = _average(_calibrationScaleSamples);
      _frontAnkleBaselineX = _average(_calibrationFrontAnkleXSamples);
      if (_calibrationCervicalSamples.isNotEmpty) {
        _baselineCervicalAngle = _average(_calibrationCervicalSamples);
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
    logger.pushGoodRepCount();
    logger.pushKey('max_rep', maxRep);
    logger.pushKey('knee_travel_fails_count', _kneeTravelMetric.faultsCount);
    logger.pushKey('cervical_fails_count', _cervicalSafetyMetric.faultsCount);
  }

  @override
  double? get liveHoldSeconds =>
      lowLungeState == LowLungeState.holding ? _currentHoldSeconds() : null;

  @override
  double? get liveHoldTargetSeconds => LowLungeConfig.HOLD_DURATION;

  @override
  void onExerciseActivated() {
    if (lowLungeState == LowLungeState.entry) {
      _transitionState(LowLungeState.holding, frameTimestampMs);
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return '⚠️ Xin hãy quay nghiêng để theo dõi tư thế Low Lunge';
    }

    final lunge = _resolveLungeLandmarks(landmarks);
    if (lunge == null) {
      return '⚠️ Đảm bảo toàn thân và hai chân trong khung hình';
    }

    final required = [
      lunge.frontShoulder,
      lunge.frontHip,
      lunge.frontKnee,
      lunge.frontAnkle,
      lunge.backKnee,
      lunge.backAnkle,
    ];

    if (!required.every(ExerciseBase.isLandmarkConfident)) {
      return '⚠️ Hình ảnh không rõ. Điều chỉnh ánh sáng hoặc vị trí';
    }

    return null;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final lunge = _resolveLungeLandmarks(smoothedLandmarks);
    if (lunge == null) return;

    final scale = _baselineScaleFactor ?? _scaleFrom(lunge);
    if (scale < 1.0) return;

    final ear = getSideLandmark(
      landmarks: smoothedLandmarks,
      rightType: PoseLandmarkType.rightEar,
      leftType: PoseLandmarkType.leftEar,
    );

    final frontKneeAngle = calculateAngleNormalized(
      firstPoint: lunge.frontHip,
      midPoint: lunge.frontKnee,
      lastPoint: lunge.frontAnkle,
    );
    final backKneeGrounded =
        (lunge.backKnee.y - lunge.backAnkle.y).abs() / scale <=
            LowLungeConfig.BACK_KNEE_GROUNDED_MAX;
    final trunkClockAngle = calculateVerticalAngle(
      pivot: lunge.frontHip,
      point: lunge.frontShoulder,
    );
    final hipVelocity = _hipVelocity(lunge.frontHip.y, frameTimestampMs, scale);

    _updateLowLungeState(
      hipVelocity: hipVelocity,
      frontKneeAngle: frontKneeAngle,
      backKneeGrounded: backKneeGrounded,
      timestampMs: frameTimestampMs,
    );

    final ctx = LowLungeContext(
      state: lowLungeState,
      frameTimestampMs: frameTimestampMs,
      scaleFactor: scale,
      resultIssues: resultIssues,
      cameraFacing: cameraFacing,
      frontSide: lunge.frontSide,
      lungeDirection: lunge.direction,
      trunkClockAngle: trunkClockAngle,
      hipVelocity: hipVelocity,
      frontShoulder: lunge.frontShoulder,
      frontHip: lunge.frontHip,
      frontKnee: lunge.frontKnee,
      frontAnkle: lunge.frontAnkle,
      backHip: lunge.backHip,
      backKnee: lunge.backKnee,
      backAnkle: lunge.backAnkle,
      ear: ear,
      baselineCervicalAngle: _baselineCervicalAngle,
      frontAnkleBaselineX: _frontAnkleBaselineX,
    );

    if (lowLungeState == LowLungeState.holding) {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
      _updateEffectivenessFeedback(
        frontKneeAngle: frontKneeAngle,
        backKneeGrounded: backKneeGrounded,
        trunkClockAngle: trunkClockAngle,
      );
    }

    _updatePhaseInstructions();

    debugData['lowLungeState'] = lowLungeState.toString().split('.').last;
    debugData['repCount'] = repCount.toString();
    debugData['frontSide'] = lunge.frontSide.name;
    debugData['frontKneeAngle'] = frontKneeAngle.toStringAsFixed(1);
    debugData['backKneeGrounded'] = backKneeGrounded;
    debugData['hipVelocity'] = hipVelocity.toStringAsFixed(3);
    debugData['trunkClock'] = trunkClockAngle.toStringAsFixed(1);
    debugData['calibrated'] = _isCalibrated;

    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }
  }

  void _updateEffectivenessFeedback({
    required double frontKneeAngle,
    required bool backKneeGrounded,
    required double trunkClockAngle,
  }) {
    if (!backKneeGrounded) {
      resultIssues.feedback['Back knee'] = 'Hạ gối sau xuống sàn nhé';
      resultIssues.addInstruction(
        'holding',
        'backKneeLifted',
        'Hạ gối sau xuống sàn để vào Low Lunge.',
      );
    }

    if (frontKneeAngle > LowLungeConfig.FRONT_KNEE_SHALLOW) {
      resultIssues.feedback['Depth'] = 'Hạ hông thấp hơn nếu thoải mái';
      resultIssues.addInstruction(
        'holding',
        'frontKneeShallow',
        'Gối trước gập sâu hơn một chút, giữ cảm giác dễ chịu.',
      );
    } else if (frontKneeAngle >= LowLungeConfig.FRONT_KNEE_GOOD_MIN &&
        frontKneeAngle <= LowLungeConfig.FRONT_KNEE_GOOD_MAX) {
      resultIssues.feedback['Depth'] = 'Độ sâu tốt ✓';
    }

    final chestLift = _chestLiftScore(trunkClockAngle);
    debugData['chestLift'] = chestLift.toStringAsFixed(1);
    if (chestLift < LowLungeConfig.CHEST_LIFT_MIN) {
      resultIssues.feedback['Chest'] = 'Nâng nhẹ ngực lên';
      resultIssues.addInstruction(
        'holding',
        'chestLift',
        'Thả lỏng hông xuống, nâng nhẹ ngực bằng lưng giữa.',
      );
    }
  }

  void _updatePhaseInstructions() {
    if (lowLungeState == LowLungeState.holding) {
      final holdSecs = _currentHoldSeconds();
      final remaining = (LowLungeConfig.HOLD_DURATION - holdSecs)
          .clamp(0.0, LowLungeConfig.HOLD_DURATION);
      resultIssues.addInstruction(
        'holding',
        'Status',
        'Giữ! ${remaining.toStringAsFixed(1)}s',
      );
      debugData['holdProgress'] =
          (holdSecs / LowLungeConfig.HOLD_DURATION).clamp(0.0, 1.0);
    }

    if (lowLungeState == LowLungeState.exit && _exitStartMs != null) {
      final elapsed = (frameTimestampMs - _exitStartMs!) / 1000.0;
      final remaining = (LowLungeConfig.EXIT_DURATION - elapsed)
          .clamp(0.0, LowLungeConfig.EXIT_DURATION);
      resultIssues.addInstruction(
        'exit',
        'Status',
        repCount >= maxRep
            ? 'Hoàn tất'
            : 'Đổi bên ${remaining.toStringAsFixed(1)}s',
      );
    }
  }

  void _updateLowLungeState({
    required double hipVelocity,
    required double frontKneeAngle,
    required bool backKneeGrounded,
    required int timestampMs,
  }) {
    final lungeShape = frontKneeAngle < LowLungeConfig.FRONT_KNEE_SETUP_MAX &&
        backKneeGrounded;
    final stillEnough =
        hipVelocity.abs() <= LowLungeConfig.HOLD_HIP_VELOCITY_MAX;
    final confirmedHold = _holdStillDebouncer.update(lungeShape && stillEnough);
    final brokePosition = _breakPositionDebouncer.update(
      !lungeShape || hipVelocity.abs() >= LowLungeConfig.BREAK_HIP_VELOCITY_MIN,
    );

    switch (lowLungeState) {
      case LowLungeState.entry:
        if (confirmedHold) _transitionState(LowLungeState.holding, timestampMs);
        break;
      case LowLungeState.holding:
        if (_currentHoldSeconds() >= LowLungeConfig.HOLD_DURATION) {
          _exitShouldCount = true;
          _exitRejectReason = null;
          _transitionState(LowLungeState.exit, timestampMs);
        } else if (brokePosition) {
          _exitShouldCount = false;
          _exitRejectReason =
              'Rời tư thế quá sớm - giữ Low Lunge đủ thời gian trước khi đổi bên.';
          _transitionState(LowLungeState.exit, timestampMs);
        }
        break;
      case LowLungeState.exit:
        if (_exitStartMs != null) {
          final elapsed = (timestampMs - _exitStartMs!) / 1000.0;
          if (elapsed >= LowLungeConfig.EXIT_DURATION) {
            _transitionState(LowLungeState.entry, timestampMs);
          }
        }
        break;
    }
  }

  void _transitionState(LowLungeState newState, int timestampMs) {
    previousLowLungeState = lowLungeState;
    lowLungeState = newState;

    switch (newState) {
      case LowLungeState.holding:
        _holdStartMs = timestampMs;
        _exitStartMs = null;
        _exitShouldCount = false;
        _exitRejectReason = null;
        resultIssues.instructions.clear();
        break;
      case LowLungeState.exit:
        _exitStartMs = timestampMs;
        _finalizeHold();
        break;
      case LowLungeState.entry:
        _holdStartMs = null;
        _resetCalibration();
        break;
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousLowLungeState, newState, timestampMs);
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
        'hold_time': LowLungeConfig.HOLD_DURATION,
        'fault_types': allFaults.map((f) => f.type).toSet().toList(),
      },
    ));

    for (final metric in _metrics) {
      metric.resetAndCountFault();
    }
  }

  void _resetCalibration() {
    _calibrationScaleSamples.clear();
    _calibrationCervicalSamples.clear();
    _calibrationFrontAnkleXSamples.clear();
    _baselineScaleFactor = null;
    _baselineCervicalAngle = null;
    _frontAnkleBaselineX = null;
    _isCalibrated = false;
    _previousHipY = null;
    _previousTimestampMs = null;
    _exitShouldCount = false;
    _exitRejectReason = null;
    _holdStillDebouncer.reset();
    _breakPositionDebouncer.reset();
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
    if (lowLungeState == LowLungeState.holding) {
      lowLungeState = LowLungeState.entry;
      previousLowLungeState = LowLungeState.holding;
      _holdStartMs = null;
      _resetCalibration();
      for (final metric in _metrics) {
        metric.reset();
      }
      resultIssues.addInstruction(
        'entry',
        'Status',
        'Mất mốc cơ thể, vào lại Low Lunge trước khi giữ.',
      );
    }
    return super.processNoPoseFrame();
  }

  double _scaleFrom(_LungeLandmarks lunge) {
    return calculateDistance(lunge.frontShoulder, lunge.frontHip);
  }

  double _chestLiftScore(double trunkClockAngle) {
    final verticalTarget = cameraFacing == CameraFacing.right ? 0.0 : 180.0;
    final diff = clockAngleDeviation(trunkClockAngle, verticalTarget).abs();
    return (90.0 - diff).clamp(0.0, 90.0);
  }

  _LungeLandmarks? _resolveLungeLandmarks(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];

    if (leftHip == null ||
        leftKnee == null ||
        leftAnkle == null ||
        leftShoulder == null ||
        rightHip == null ||
        rightKnee == null ||
        rightAnkle == null ||
        rightShoulder == null) return null;

    final leftIsFront = cameraFacing == CameraFacing.right
        ? leftAnkle.x < rightAnkle.x
        : leftAnkle.x > rightAnkle.x;

    return _LungeLandmarks(
      frontSide: leftIsFront ? BodySide.left : BodySide.right,
      direction: leftIsFront
          ? (leftAnkle.x - rightAnkle.x).sign
          : (rightAnkle.x - leftAnkle.x).sign,
      frontShoulder: leftIsFront ? leftShoulder : rightShoulder,
      frontHip: leftIsFront ? leftHip : rightHip,
      frontKnee: leftIsFront ? leftKnee : rightKnee,
      frontAnkle: leftIsFront ? leftAnkle : rightAnkle,
      backHip: leftIsFront ? rightHip : leftHip,
      backKnee: leftIsFront ? rightKnee : leftKnee,
      backAnkle: leftIsFront ? rightAnkle : leftAnkle,
    );
  }
}

enum BodySide { left, right }

class _LungeLandmarks {
  final BodySide frontSide;
  final double direction;
  final PoseLandmark frontShoulder;
  final PoseLandmark frontHip;
  final PoseLandmark frontKnee;
  final PoseLandmark frontAnkle;
  final PoseLandmark backHip;
  final PoseLandmark backKnee;
  final PoseLandmark backAnkle;

  _LungeLandmarks({
    required this.frontSide,
    required this.direction,
    required this.frontShoulder,
    required this.frontHip,
    required this.frontKnee,
    required this.frontAnkle,
    required this.backHip,
    required this.backKnee,
    required this.backAnkle,
  });
}
