// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/utils/debouncer.dart';
import 'package:vika/utils/pose_math_helpers.dart';
import 'package:vika/utils/exercise_logger.dart';

import 'metrics/ashtanga_metric_base.dart';
import 'metrics/hip_collapse_metric.dart';
import 'metrics/cervical_safety_metric.dart';

enum AshtangaMode { transient, microHold }

enum AshtangaState { entry, recognized, holding, exit }

class AshtangaConfig {
  static const int MAX_REP = 1;
  static const double MICRO_HOLD_DURATION = 4.0;
  static const double EXIT_DURATION = 2.0;
  static const int RECOGNITION_WINDOW_MS = 500;
  static const int SETUP_STILL_FRAMES = 6;
  static const int CALIBRATION_FRAMES = 12;

  static const double START_HIP_RATIO_MIN = 0.12;
  static const double START_KNEE_ANKLE_MAX = 1.0;
  static const double START_CHEST_LOW_MIN = 0.05;
  static const double HOLD_VELOCITY_MAX = 0.08;
  static const double BREAK_VELOCITY_MIN = 0.22;
}

class AshtangaNamaskara extends ExerciseBase {
  final int maxRep;
  final AshtangaMode mode;

  AshtangaNamaskara({
    this.maxRep = AshtangaConfig.MAX_REP,
    this.mode = AshtangaMode.transient,
  });

  AshtangaState ashtangaState = AshtangaState.entry;
  AshtangaState previousAshtangaState = AshtangaState.entry;

  int? _holdStartMs;
  int? _exitStartMs;
  int? _recognizedStartMs;
  double? _previousShoulderY;
  int? _previousTimestampMs;
  bool _exitShouldCount = false;
  String? _exitRejectReason;

  final Debouncer _shapeDebouncer =
      Debouncer(requiredFrames: AshtangaConfig.SETUP_STILL_FRAMES);
  final Debouncer _breakDebouncer = Debouncer(requiredFrames: 6);

  final _hipCollapseMetric = HipCollapseMetric();
  final _cervicalSafetyMetric = CervicalSafetyMetric();

  late final List<AshtangaMetricBase> _metrics = [
    _hipCollapseMetric,
    _cervicalSafetyMetric,
  ];

  final List<double> _calibrationScaleSamples = [];
  final List<double> _calibrationCervicalSamples = [];
  double? _baselineScaleFactor;
  double? _baselineCervicalAngle;
  bool _isCalibrated = false;

  @override
  String get exerciseName => 'Ashtanga Namaskara';

  @override
  String get currentPhaseKey => ashtangaState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (ashtangaState) {
      case AshtangaState.entry:
        return 'Vào tư thế';
      case AshtangaState.recognized:
        return 'Đã nhận';
      case AshtangaState.holding:
        return 'Giữ!';
      case AshtangaState.exit:
        return 'Thoát tư thế';
    }
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final body = _resolveSideLandmarks(landmarks);
    if (body == null) return false;

    final scale = _scaleFrom(body);
    if (scale < 1.0) return false;

    final shape = _shapeFrom(body, scale);
    final inStart = shape.kneesGrounded &&
        shape.hipPositionRatio >= AshtangaConfig.START_HIP_RATIO_MIN &&
        shape.chestLow;

    if (inStart) _collectCalibrationData(body, scale);

    debugData['startHipRatio'] = shape.hipPositionRatio.toStringAsFixed(3);
    debugData['startKneesGrounded'] = shape.kneesGrounded;
    debugData['startChestLow'] = shape.chestLow;

    return inStart;
  }

  void _collectCalibrationData(_AshtangaLandmarks body, double scale) {
    if (_isCalibrated) return;

    _calibrationScaleSamples.add(scale);
    if (body.ear != null && body.ear!.likelihood >= 0.5) {
      _calibrationCervicalSamples.add(
        calculateAngle(
          firstPoint: body.ear!,
          midPoint: body.shoulder,
          lastPoint: body.hip,
        ),
      );
    }

    if (_calibrationScaleSamples.length >= AshtangaConfig.CALIBRATION_FRAMES) {
      _baselineScaleFactor = _average(_calibrationScaleSamples);
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
    logger.pushKey('mode', mode.name);
    logger.pushKey('hip_collapse_fails_count', _hipCollapseMetric.faultsCount);
    logger.pushKey('cervical_fails_count', _cervicalSafetyMetric.faultsCount);
  }

  @override
  double? get liveHoldSeconds =>
      ashtangaState == AshtangaState.holding ? _currentHoldSeconds() : null;

  @override
  double? get liveHoldTargetSeconds => mode == AshtangaMode.microHold
      ? AshtangaConfig.MICRO_HOLD_DURATION
      : null;

  @override
  void onExerciseActivated() {
    if (ashtangaState == AshtangaState.entry) {
      _transitionState(
        mode == AshtangaMode.transient
            ? AshtangaState.recognized
            : AshtangaState.holding,
        frameTimestampMs,
      );
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return '⚠️ Xin hãy quay nghiêng để theo dõi tư thế Ashtanga';
    }

    final body = _resolveSideLandmarks(landmarks);
    if (body == null) {
      return '⚠️ Đảm bảo vai, hông, gối và cổ chân trong khung hình';
    }

    final required = [body.shoulder, body.hip, body.knee, body.ankle];
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

    final shape = _shapeFrom(body, scale);
    final cervicalAngle = body.ear == null
        ? 180.0
        : calculateAngle(
            firstPoint: body.ear!,
            midPoint: body.shoulder,
            lastPoint: body.hip,
          );
    final shoulderVelocity =
        _shoulderVelocity(body.shoulder.y, frameTimestampMs, scale);

    final ctx = AshtangaContext(
      state: ashtangaState,
      mode: mode,
      frameTimestampMs: frameTimestampMs,
      scaleFactor: scale,
      resultIssues: resultIssues,
      cameraFacing: cameraFacing,
      hipPositionRatio: shape.hipPositionRatio,
      cervicalAngle: cervicalAngle,
      kneesGrounded: shape.kneesGrounded,
      chestLow: shape.chestLow,
      shoulderHipDelta: shape.shoulderHipDelta,
      kneeAnkleDelta: shape.kneeAnkleDelta,
      shoulder: body.shoulder,
      hip: body.hip,
      knee: body.knee,
      ankle: body.ankle,
      ear: body.ear,
      cervicalBaseline: _baselineCervicalAngle,
    );

    _updateAshtangaState(
      shape: shape,
      shoulderVelocity: shoulderVelocity,
      timestampMs: frameTimestampMs,
    );

    if (ashtangaState == AshtangaState.recognized ||
        ashtangaState == AshtangaState.holding) {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
      _updateEffectivenessFeedback(ctx);
    }

    _updatePhaseInstructions();

    debugData['ashtangaState'] = ashtangaState.toString().split('.').last;
    debugData['mode'] = mode.name;
    debugData['repCount'] = repCount.toString();
    debugData['hipPositionRatio'] = shape.hipPositionRatio.toStringAsFixed(3);
    debugData['kneesGrounded'] = shape.kneesGrounded;
    debugData['chestLow'] = shape.chestLow;
    debugData['shoulderVelocity'] = shoulderVelocity.toStringAsFixed(3);
    debugData['calibrated'] = _isCalibrated;

    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }
  }

  void _updateEffectivenessFeedback(AshtangaContext ctx) {
    if (!ctx.kneesGrounded) {
      resultIssues.feedback['Knees'] = 'Hạ gối xuống sàn trước';
      resultIssues.addInstruction(
        ctx.state.name,
        'kneesGrounded',
        'Hạ gối xuống sàn trước, rồi mới hạ ngực.',
      );
    }

    if (!ctx.chestLow) {
      resultIssues.feedback['Chest'] = 'Hạ ngực xuống sát sàn nhé';
      resultIssues.addInstruction(
        ctx.state.name,
        'chestDescent',
        'Hạ ngực xuống thấp hơn, giữ hông vẫn cao.',
      );
    } else {
      resultIssues.feedback['Chest'] = 'Ngực hạ thấp tốt ✓';
    }
  }

  void _updatePhaseInstructions() {
    if (ashtangaState == AshtangaState.holding) {
      final holdSecs = _currentHoldSeconds();
      final remaining = (AshtangaConfig.MICRO_HOLD_DURATION - holdSecs)
          .clamp(0.0, AshtangaConfig.MICRO_HOLD_DURATION);
      resultIssues.addInstruction(
        'holding',
        'Status',
        'Giữ! ${remaining.toStringAsFixed(1)}s',
      );
      debugData['holdProgress'] =
          (holdSecs / AshtangaConfig.MICRO_HOLD_DURATION).clamp(0.0, 1.0);
    }

    if (ashtangaState == AshtangaState.recognized) {
      resultIssues.addInstruction(
        'recognized',
        'Status',
        'Đã nhận tư thế Ashtanga',
      );
    }

    if (ashtangaState == AshtangaState.exit && _exitStartMs != null) {
      final elapsed = (frameTimestampMs - _exitStartMs!) / 1000.0;
      final remaining = (AshtangaConfig.EXIT_DURATION - elapsed)
          .clamp(0.0, AshtangaConfig.EXIT_DURATION);
      resultIssues.addInstruction(
        'exit',
        'Status',
        repCount >= maxRep
            ? 'Hoàn tất'
            : 'Thoát tư thế ${remaining.toStringAsFixed(1)}s',
      );
    }
  }

  void _updateAshtangaState({
    required _AshtangaShape shape,
    required double shoulderVelocity,
    required int timestampMs,
  }) {
    final shapePresent = shape.kneesGrounded &&
        shape.chestLow &&
        shape.hipPositionRatio >= AshtangaConfig.START_HIP_RATIO_MIN;
    final stillEnough =
        shoulderVelocity.abs() <= AshtangaConfig.HOLD_VELOCITY_MAX;
    final confirmedShape = _shapeDebouncer.update(shapePresent && stillEnough);
    final brokeShape = _breakDebouncer.update(
      !shapePresent ||
          shoulderVelocity.abs() >= AshtangaConfig.BREAK_VELOCITY_MIN,
    );

    switch (ashtangaState) {
      case AshtangaState.entry:
        if (confirmedShape) {
          _transitionState(
            mode == AshtangaMode.transient
                ? AshtangaState.recognized
                : AshtangaState.holding,
            timestampMs,
          );
        }
        break;
      case AshtangaState.recognized:
        if (brokeShape) {
          _exitShouldCount = false;
          _exitRejectReason =
              'Rời tư thế Ashtanga quá sớm - vào lại 8 điểm chạm rồi giữ ổn định.';
          _transitionState(AshtangaState.exit, timestampMs);
        } else if (_recognizedStartMs != null &&
            timestampMs - _recognizedStartMs! >=
                AshtangaConfig.RECOGNITION_WINDOW_MS) {
          _exitShouldCount = true;
          _exitRejectReason = null;
          _transitionState(AshtangaState.exit, timestampMs);
        }
        break;
      case AshtangaState.holding:
        if (_currentHoldSeconds() >= AshtangaConfig.MICRO_HOLD_DURATION) {
          _exitShouldCount = true;
          _exitRejectReason = null;
          _transitionState(AshtangaState.exit, timestampMs);
        } else if (brokeShape) {
          _exitShouldCount = false;
          _exitRejectReason =
              'Rời tư thế Ashtanga quá sớm - giữ đủ thời gian trước khi thoát.';
          _transitionState(AshtangaState.exit, timestampMs);
        }
        break;
      case AshtangaState.exit:
        if (_exitStartMs != null) {
          final elapsed = (timestampMs - _exitStartMs!) / 1000.0;
          if (elapsed >= AshtangaConfig.EXIT_DURATION) {
            _transitionState(AshtangaState.entry, timestampMs);
          }
        }
        break;
    }
  }

  void _transitionState(AshtangaState newState, int timestampMs) {
    previousAshtangaState = ashtangaState;
    ashtangaState = newState;

    switch (newState) {
      case AshtangaState.recognized:
        _recognizedStartMs = timestampMs;
        _holdStartMs = null;
        _exitStartMs = null;
        _exitShouldCount = false;
        _exitRejectReason = null;
        resultIssues.instructions.clear();
        break;
      case AshtangaState.holding:
        _holdStartMs = timestampMs;
        _recognizedStartMs = null;
        _exitStartMs = null;
        _exitShouldCount = false;
        _exitRejectReason = null;
        resultIssues.instructions.clear();
        break;
      case AshtangaState.exit:
        _exitStartMs = timestampMs;
        _recognizedStartMs = null;
        _holdStartMs = null;
        _finalizePose();
        break;
      case AshtangaState.entry:
        _recognizedStartMs = null;
        _holdStartMs = null;
        _resetCalibration();
        break;
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousAshtangaState, newState, timestampMs);
    }
  }

  void _finalizePose() {
    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      allFaults.addAll(metric.faults);
    }

    if (!_exitShouldCount || repCount >= maxRep) {
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

    logger.addRepLog(
      RepLog(
        correctForm: correctForm,
        repNumber: repCount,
        data: {
          'hold_time': mode == AshtangaMode.microHold
              ? AshtangaConfig.MICRO_HOLD_DURATION
              : AshtangaConfig.RECOGNITION_WINDOW_MS / 1000.0,
          'mode': mode.name,
          'fault_types': allFaults.map((f) => f.type).toSet().toList(),
        },
      ),
    );

    for (final metric in _metrics) {
      metric.resetAndCountFault();
    }
  }

  void _resetCalibration() {
    _calibrationScaleSamples.clear();
    _calibrationCervicalSamples.clear();
    _baselineScaleFactor = null;
    _baselineCervicalAngle = null;
    _isCalibrated = false;
    _previousShoulderY = null;
    _previousTimestampMs = null;
    _exitShouldCount = false;
    _exitRejectReason = null;
    _shapeDebouncer.reset();
    _breakDebouncer.reset();
  }

  double _currentHoldSeconds() {
    if (_holdStartMs == null) return 0.0;
    return (frameTimestampMs - _holdStartMs!) / 1000.0;
  }

  double _shoulderVelocity(double shoulderY, int timestampMs, double scale) {
    double velocity = 0.0;
    if (_previousShoulderY != null && _previousTimestampMs != null) {
      final deltaMs = timestampMs - _previousTimestampMs!;
      if (deltaMs > 0 && scale > 1.0) {
        velocity =
            ((shoulderY - _previousShoulderY!) / scale) / (deltaMs / 1000.0);
      }
    }
    _previousShoulderY = shoulderY;
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
    if (ashtangaState == AshtangaState.recognized ||
        ashtangaState == AshtangaState.holding) {
      ashtangaState = AshtangaState.entry;
      previousAshtangaState = AshtangaState.exit;
      _holdStartMs = null;
      _recognizedStartMs = null;
      _resetCalibration();
      for (final metric in _metrics) {
        metric.reset();
      }
      resultIssues.addInstruction(
        'entry',
        'Status',
        'Mất mốc cơ thể, vào lại tư thế 8 điểm chạm trước khi giữ.',
      );
    }
    return super.processNoPoseFrame();
  }

  double _scaleFrom(_AshtangaLandmarks body) {
    return calculateDistance(body.shoulder, body.hip);
  }

  _AshtangaShape _shapeFrom(_AshtangaLandmarks body, double scale) {
    final shoulderHipDelta = body.shoulder.y - body.hip.y;
    final kneeAnkleDelta = (body.knee.y - body.ankle.y).abs();
    final hipPositionRatio = shoulderHipDelta / scale;
    final kneeAnkleRatio = kneeAnkleDelta / scale;
    final chestLow =
        shoulderHipDelta / scale >= AshtangaConfig.START_CHEST_LOW_MIN;
    final kneesGrounded = kneeAnkleRatio <= AshtangaConfig.START_KNEE_ANKLE_MAX;

    return _AshtangaShape(
      hipPositionRatio: hipPositionRatio,
      kneesGrounded: kneesGrounded,
      chestLow: chestLow,
      shoulderHipDelta: shoulderHipDelta,
      kneeAnkleDelta: kneeAnkleRatio,
    );
  }

  _AshtangaLandmarks? _resolveSideLandmarks(
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
    final knee = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightKnee,
      leftType: PoseLandmarkType.leftKnee,
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

    if (shoulder == null || hip == null || knee == null || ankle == null) {
      return null;
    }

    return _AshtangaLandmarks(
      shoulder: shoulder,
      hip: hip,
      knee: knee,
      ankle: ankle,
      ear: ear,
    );
  }
}

class _AshtangaLandmarks {
  final PoseLandmark shoulder;
  final PoseLandmark hip;
  final PoseLandmark knee;
  final PoseLandmark ankle;
  final PoseLandmark? ear;

  _AshtangaLandmarks({
    required this.shoulder,
    required this.hip,
    required this.knee,
    required this.ankle,
    this.ear,
  });
}

class _AshtangaShape {
  final double hipPositionRatio;
  final bool kneesGrounded;
  final bool chestLow;
  final double shoulderHipDelta;
  final double kneeAnkleDelta;

  _AshtangaShape({
    required this.hipPositionRatio,
    required this.kneesGrounded,
    required this.chestLow,
    required this.shoulderHipDelta,
    required this.kneeAnkleDelta,
  });
}
