// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/debug/tracked_metric.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/utils/debouncer.dart';
import 'package:vika/utils/pose_math_helpers.dart';
import 'package:vika/utils/exercise_logger.dart';

import 'metrics/raised_arms_metric_base.dart';
import 'metrics/lumbar_backbend_metric.dart';
import 'metrics/cervical_safety_metric.dart';
import 'metrics/arm_position_metric.dart';

class RaisedArmsConfig {
  static const int MAX_REP = 1;
  static const double HOLD_DURATION = 12.0;
  static const double EXIT_DURATION = 4.0;

  static const int SETUP_STILL_FRAMES = 10;
  static const int CALIBRATION_FRAMES = 20;

  static const double ENTRY_TRUNK_TOLERANCE = 35.0;
  static const double HOLD_HIP_VELOCITY_MAX = 0.025;
  static const double BREAK_HIP_VELOCITY_MIN = 0.09;
  static const double LUMBAR_EXIT_BACK_LEAN = 25.0;
}

enum RaisedArmsState { entry, holding, exit }

class RaisedArms extends ExerciseBase {
  final int maxRep;

  RaisedArms({this.maxRep = RaisedArmsConfig.MAX_REP});

  RaisedArmsState raisedArmsState = RaisedArmsState.entry;
  RaisedArmsState previousRaisedArmsState = RaisedArmsState.entry;

  int? _holdStartMs;
  int? _exitStartMs;
  double? _previousHipY;
  int? _previousTimestampMs;
  bool _exitShouldCount = false;
  String? _exitRejectReason;

  final Debouncer _holdStillDebouncer =
      Debouncer(requiredFrames: RaisedArmsConfig.SETUP_STILL_FRAMES);
  final Debouncer _breakPositionDebouncer = Debouncer(requiredFrames: 8);
  final StickyDebouncer _lumbarExitDebouncer =
      StickyDebouncer(requiredFrames: 20, currentState: false);

  final _lumbarBackbendMetric = LumbarBackbendMetric();
  final _cervicalSafetyMetric = CervicalSafetyMetric();
  final _armPositionMetric = ArmPositionMetric();

  late final List<RaisedArmsMetricBase> _metrics = [
    _lumbarBackbendMetric,
    _cervicalSafetyMetric,
    _armPositionMetric,
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

  final List<double> _calibrationScaleSamples = [];
  final List<double> _calibrationTrunkSamples = [];
  final List<double> _calibrationCervicalSamples = [];
  double? _baselineScaleFactor;
  double? _trunkBaseline;
  double? _cervicalBaseline;
  bool _isCalibrated = false;

  @override
  String get exerciseName => 'Raised Arms Pose';

  @override
  String get currentPhaseKey => raisedArmsState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (raisedArmsState) {
      case RaisedArmsState.entry:
        return 'Vào tư thế';
      case RaisedArmsState.holding:
        return 'Giữ!';
      case RaisedArmsState.exit:
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
    final trunkVertical = clockAngleDeviation(trunkClockAngle, 0.0).abs() <=
        RaisedArmsConfig.ENTRY_TRUNK_TOLERANCE;
    final shoulderAboveHip = body.shoulder.y < body.hip.y;
    final wristAboveShoulder =
        body.wrist != null && body.wrist!.y < body.shoulder.y;

    final inStart = shoulderAboveHip && wristAboveShoulder && trunkVertical;
    if (inStart) _collectCalibrationData(body, scale, trunkClockAngle);

    return inStart;
  }

  void _collectCalibrationData(
    _RaisedArmsLandmarks body,
    double scale,
    double trunkClockAngle,
  ) {
    if (_isCalibrated) return;

    _calibrationScaleSamples.add(scale);
    _calibrationTrunkSamples.add(trunkClockAngle);

    if (body.ear != null && body.ear!.likelihood >= 0.5) {
      _calibrationCervicalSamples.add(
        calculateAngle(
          firstPoint: body.ear!,
          midPoint: body.shoulder,
          lastPoint: body.hip,
        ),
      );
    }

    if (_calibrationScaleSamples.length >=
        RaisedArmsConfig.CALIBRATION_FRAMES) {
      _baselineScaleFactor = _average(_calibrationScaleSamples);
      _trunkBaseline = _averageClockAngles(_calibrationTrunkSamples);
      if (_calibrationCervicalSamples.isNotEmpty) {
        _cervicalBaseline = _average(_calibrationCervicalSamples);
      }
      _isCalibrated = true;
    }
  }

  double _average(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _averageClockAngles(List<double> values) {
    if (values.isEmpty) return 0.0;
    final normalized = values.map((v) {
      final diff = clockAngleDeviation(v, 0.0);
      return diff;
    }).toList();
    return _average(normalized);
  }

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushGoodRepCount();
    logger.pushKey('max_rep', maxRep);
    logger.pushKey(
        'lumbar_backbend_fails_count', _lumbarBackbendMetric.faultsCount);
    logger.pushKey('cervical_fails_count', _cervicalSafetyMetric.faultsCount);
    logger.pushKey('arm_position_fails_count', _armPositionMetric.faultsCount);
  }

  @override
  void onExerciseActivated() {
    if (raisedArmsState == RaisedArmsState.entry) {
      _transitionState(RaisedArmsState.holding, frameTimestampMs);
    }
  }

  @override
  double? get liveHoldSeconds =>
      raisedArmsState == RaisedArmsState.holding ? _currentHoldSeconds() : null;

  @override
  double? get liveHoldTargetSeconds => RaisedArmsConfig.HOLD_DURATION;

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return '⚠️ Xin hãy quay nghiêng để theo dõi tư thế Hasta Uttanasana';
    }

    final body = _resolveSideLandmarks(landmarks);
    if (body == null) {
      return '⚠️ Đảm bảo vai, hông, khuỷu tay và cổ tay trong khung hình';
    }

    final required = [body.shoulder, body.hip, body.elbow];
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
    final backLean = _backLeanFromVertical(trunkClockAngle);
    final hipVelocity = _hipVelocity(body.hip.y, frameTimestampMs, scale);
    final armVerticalAngle = _armVerticalAngle(body);
    final elbowAngle = _elbowAngle(body);
    final cervicalAngle = _cervicalAngle(body);
    final wristVisible =
        body.wrist != null && ExerciseBase.isLandmarkConfident(body.wrist!);

    _updateRaisedArmsState(
      hipVelocity: hipVelocity,
      armVerticalAngle: armVerticalAngle,
      backLean: backLean,
      timestampMs: frameTimestampMs,
    );

    final ctx = RaisedArmsContext(
      state: raisedArmsState,
      frameTimestampMs: frameTimestampMs,
      scaleFactor: scale,
      resultIssues: resultIssues,
      cameraFacing: cameraFacing,
      trunkClockAngle: trunkClockAngle,
      backLean: backLean,
      hipVelocity: hipVelocity,
      cervicalAngle: cervicalAngle,
      armVerticalAngle: armVerticalAngle,
      elbowAngle: elbowAngle,
      wristVisible: wristVisible,
      shoulder: body.shoulder,
      hip: body.hip,
      elbow: body.elbow,
      wrist: body.wrist,
      ear: body.ear,
      trunkBaseline: _trunkBaseline,
      cervicalBaseline: _cervicalBaseline,
    );

    if (raisedArmsState == RaisedArmsState.holding) {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
    }

    _updatePhaseInstructions();

    debugData['raisedArmsState'] = raisedArmsState.toString().split('.').last;
    debugData['repCount'] = repCount.toString();
    debugData['trunkClock'] = trunkClockAngle.toStringAsFixed(1);
    debugData['backLean'] = backLean.toStringAsFixed(1);
    debugData['hipVelocity'] = hipVelocity.toStringAsFixed(3);
    debugData['armVertical'] = armVerticalAngle.toStringAsFixed(1);
    debugData['elbowAngle'] = elbowAngle.toStringAsFixed(1);
    debugData['wristVisible'] = wristVisible;
    debugData['calibrated'] = _isCalibrated;

    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }
  }

  void _updatePhaseInstructions() {
    if (raisedArmsState == RaisedArmsState.holding) {
      final holdSecs = _currentHoldSeconds();
      final remaining = (RaisedArmsConfig.HOLD_DURATION - holdSecs)
          .clamp(0.0, RaisedArmsConfig.HOLD_DURATION);
      resultIssues.addInstruction(
        'holding',
        'Status',
        'Giữ! ${remaining.toStringAsFixed(1)}s',
      );
      debugData['holdProgress'] =
          (holdSecs / RaisedArmsConfig.HOLD_DURATION).clamp(0.0, 1.0);
    }

    if (raisedArmsState == RaisedArmsState.exit && _exitStartMs != null) {
      final elapsed = (frameTimestampMs - _exitStartMs!) / 1000.0;
      final remaining = (RaisedArmsConfig.EXIT_DURATION - elapsed)
          .clamp(0.0, RaisedArmsConfig.EXIT_DURATION);
      resultIssues.addInstruction(
        'exit',
        'Status',
        repCount >= maxRep
            ? 'Hoàn tất'
            : 'Thả tay xuống ${remaining.toStringAsFixed(1)}s',
      );
    }
  }

  void _updateRaisedArmsState({
    required double hipVelocity,
    required double armVerticalAngle,
    required double backLean,
    required int timestampMs,
  }) {
    final armsUp = armVerticalAngle <= 50.0;
    final stillEnough =
        hipVelocity.abs() <= RaisedArmsConfig.HOLD_HIP_VELOCITY_MAX;
    final confirmedHold = _holdStillDebouncer.update(armsUp && stillEnough);
    final brokePosition = _breakPositionDebouncer.update(
      !armsUp || hipVelocity.abs() >= RaisedArmsConfig.BREAK_HIP_VELOCITY_MIN,
    );
    final unsafeBackbend = _lumbarExitDebouncer.update(
      backLean > RaisedArmsConfig.LUMBAR_EXIT_BACK_LEAN,
    );

    switch (raisedArmsState) {
      case RaisedArmsState.entry:
        if (confirmedHold) {
          _transitionState(RaisedArmsState.holding, timestampMs);
        }
        break;
      case RaisedArmsState.holding:
        if (_currentHoldSeconds() >= RaisedArmsConfig.HOLD_DURATION) {
          _exitShouldCount = true;
          _exitRejectReason = null;
          _transitionState(RaisedArmsState.exit, timestampMs);
        } else if (brokePosition || unsafeBackbend) {
          _exitShouldCount = false;
          _exitRejectReason = unsafeBackbend
              ? 'Ngả lưng quá sâu - đứng thẳng lại rồi giữ từ đầu.'
              : 'Rời tư thế quá sớm - giữ Vươn tay đủ thời gian trước khi thả tay.';
          _transitionState(RaisedArmsState.exit, timestampMs);
        }
        break;
      case RaisedArmsState.exit:
        if (_exitStartMs != null) {
          final elapsed = (timestampMs - _exitStartMs!) / 1000.0;
          if (elapsed >= RaisedArmsConfig.EXIT_DURATION) {
            _transitionState(RaisedArmsState.entry, timestampMs);
          }
        }
        break;
    }
  }

  void _transitionState(RaisedArmsState newState, int timestampMs) {
    previousRaisedArmsState = raisedArmsState;
    raisedArmsState = newState;

    switch (newState) {
      case RaisedArmsState.holding:
        _holdStartMs = timestampMs;
        _exitStartMs = null;
        _exitShouldCount = false;
        _exitRejectReason = null;
        resultIssues.instructions.clear();
        break;
      case RaisedArmsState.exit:
        _exitStartMs = timestampMs;
        _finalizeHold();
        break;
      case RaisedArmsState.entry:
        _holdStartMs = null;
        _resetCalibration();
        break;
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousRaisedArmsState, newState, timestampMs);
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
        'hold_time': RaisedArmsConfig.HOLD_DURATION,
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
    _baselineScaleFactor = null;
    _trunkBaseline = null;
    _cervicalBaseline = null;
    _isCalibrated = false;
    _previousHipY = null;
    _previousTimestampMs = null;
    _exitShouldCount = false;
    _exitRejectReason = null;
    _holdStillDebouncer.reset();
    _breakPositionDebouncer.reset();
    _lumbarExitDebouncer.reset();
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
    if (raisedArmsState == RaisedArmsState.holding) {
      raisedArmsState = RaisedArmsState.entry;
      previousRaisedArmsState = RaisedArmsState.holding;
      _holdStartMs = null;
      _resetCalibration();
      for (final metric in _metrics) {
        metric.reset();
      }
      resultIssues.addInstruction(
        'entry',
        'Status',
        'Mất mốc cơ thể, vào lại tư thế Vươn tay trước khi giữ.',
      );
    }
    return super.processNoPoseFrame();
  }

  double _scaleFrom(_RaisedArmsLandmarks body) {
    return calculateDistance(body.shoulder, body.hip);
  }

  double _backLeanFromVertical(double trunkClockAngle) {
    final diff = clockAngleDeviation(trunkClockAngle, 0.0);
    return cameraFacing == CameraFacing.right ? -diff : diff;
  }

  double _armVerticalAngle(_RaisedArmsLandmarks body) {
    if (body.wrist == null) return 0.0;
    final armClock = calculateVerticalAngle(
      pivot: body.shoulder,
      point: body.wrist!,
    );
    return clockAngleDeviation(armClock, 0.0).abs();
  }

  double _elbowAngle(_RaisedArmsLandmarks body) {
    if (body.wrist == null) return 180.0;
    return calculateAngle(
      firstPoint: body.shoulder,
      midPoint: body.elbow,
      lastPoint: body.wrist!,
    );
  }

  double _cervicalAngle(_RaisedArmsLandmarks body) {
    if (body.ear == null) return 180.0;
    return calculateAngle(
      firstPoint: body.ear!,
      midPoint: body.shoulder,
      lastPoint: body.hip,
    );
  }

  _RaisedArmsLandmarks? _resolveSideLandmarks(
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
    final elbow = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightElbow,
      leftType: PoseLandmarkType.leftElbow,
    );
    final wrist = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightWrist,
      leftType: PoseLandmarkType.leftWrist,
    );
    final ear = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightEar,
      leftType: PoseLandmarkType.leftEar,
    );

    if (shoulder == null || hip == null || elbow == null) return null;

    return _RaisedArmsLandmarks(
      shoulder: shoulder,
      hip: hip,
      elbow: elbow,
      wrist: wrist,
      ear: ear,
    );
  }
}

class _RaisedArmsLandmarks {
  final PoseLandmark shoulder;
  final PoseLandmark hip;
  final PoseLandmark elbow;
  final PoseLandmark? wrist;
  final PoseLandmark? ear;

  _RaisedArmsLandmarks({
    required this.shoulder,
    required this.hip,
    required this.elbow,
    this.wrist,
    this.ear,
  });
}
