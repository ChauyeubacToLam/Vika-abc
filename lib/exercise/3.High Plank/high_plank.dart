// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures
import 'package:vika/utils/debouncer.dart';
import 'package:vika/debug/tracked_metric.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';
import 'metrics/high_plank_metric_base.dart';
import 'metrics/sagging_metric.dart';
import 'metrics/piked_hip_metric.dart';
import 'metrics/elbow_metric.dart';
import 'metrics/timer_metric.dart';

class HighPlankConfig {
  static const int TARGET_TIME_MS = 30000; // 30s form chuẩn
  static const int TIMEOUT_MS = 90000; // 90s timeout

  // Start Position (Tay duỗi, lưng thẳng, gối thẳng)
  static const double START_ARM_MIN = 150.0;
  static const double START_BODY_MIN = 160.0;
  static const double START_KNEE_MIN = 145.0;
  static const double FLOOR_CONTACT_Y_TOLERANCE = 0.45;
  static const double WRIST_BELOW_SHOULDER_MIN = 0.45;
  static const double ANKLE_BELOW_HIP_MIN = 0.10;

  // State Transition Thresholds
  // SETUP/DROPPING -> HOLDING (ngưỡng vào, chuẩn)
  static const double HOLDING_BODY_THRESHOLD = 160.0;
  static const double HOLDING_ARM_THRESHOLD = 150.0;
  static const double HOLDING_KNEE_THRESHOLD = 145.0;
  static const double HOLDING_SAG_DEVIATION = 0.08;

  // State Transition Thresholds
  // HOLDING -> DROPPING (ngưỡng ra, lỏng hơn = tạo hysteresis band)
  static const double DROPPING_PIKE_ANGLE = 150.0;
  static const double DROPPING_ARM_ANGLE = 140.0;
  static const double DROPPING_KNEE_ANGLE = 135.0; // Gối cong quá
  static const double DROPPING_SAG_DEVIATION = 0.12; // Sụp hông > 12% chiều dài
}

class HighPlank extends ExerciseBase {
  HighPlank({
    this.maxSeconds = HighPlankConfig.TARGET_TIME_MS ~/ 1000,
  });

  final int maxSeconds;

  HighPlankState state = HighPlankState.setup;
  HighPlankState previousState = HighPlankState.setup;

  int? _exerciseStartTimeMs;
  int? _lastFrameTimeMs;
  bool _timeoutReached = false;
  bool _setCompletionLogged = false;
  // Clean in-form hold time only; raw elapsed holding time stays in TimerMetric.
  int _goodHoldingTimeMs = 0;
  double _saggingFaultSeconds = 0.0;
  double _pikedFaultSeconds = 0.0;
  double _elbowFaultSeconds = 0.0;

  // DIAGNOSTIC LOG
  final List<Map<String, dynamic>> _diagnosticLog = [];
  int _lastDiagnosticTime = 0;

  final SaggingMetric saggingMetric = SaggingMetric();
  final PikedHipMetric pikedHipMetric = PikedHipMetric();
  final ElbowMetric elbowMetric = ElbowMetric();
  final TimerMetric timerMetric = TimerMetric();

  late final List<HighPlankMetricBase> _metrics = [
    saggingMetric,
    pikedHipMetric,
    elbowMetric,
    timerMetric
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

  final Debouncer _holdingDebouncer = Debouncer(requiredFrames: 4);
  final Debouncer _droppingDebouncer = Debouncer(requiredFrames: 2);

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'High Plank';

  @override
  String get currentPhaseKey => state.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case HighPlankState.setup:
        return 'Chuẩn bị form...';
      case HighPlankState.holding:
        return 'Giữ vững! Đang đếm giờ';
      case HighPlankState.dropping:
        return 'Mất form! Sửa lại ngay';
    }
  }

  @override
  double? get liveHoldSeconds =>
      state == HighPlankState.holding || state == HighPlankState.dropping
          ? timerMetric.totalHoldingTimeMs / 1000.0
          : null;

  @override
  double? get liveHoldTargetSeconds => maxSeconds.toDouble();

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return 'Vui lòng quay ngang người 100% với camera!';
    }
    final lm = _getLandmarks(smoothedLandmarks);
    if (lm == null || !lm.values.every(ExerciseBase.isLandmarkConfident)) {
      return 'Giữ vai, tay, hông, gối và cổ chân rõ trong khung hình.';
    }
    return null;
  }

  Map<String, PoseLandmark>? _getLandmarks(
      Map<PoseLandmarkType, PoseLandmark> lm) {
    bool hasLeft = lm.containsKey(PoseLandmarkType.leftShoulder) &&
        lm.containsKey(PoseLandmarkType.leftHip) &&
        lm.containsKey(PoseLandmarkType.leftAnkle) &&
        lm.containsKey(PoseLandmarkType.leftElbow) &&
        lm.containsKey(PoseLandmarkType.leftWrist) &&
        lm.containsKey(PoseLandmarkType.leftKnee);

    bool hasRight = lm.containsKey(PoseLandmarkType.rightShoulder) &&
        lm.containsKey(PoseLandmarkType.rightHip) &&
        lm.containsKey(PoseLandmarkType.rightAnkle) &&
        lm.containsKey(PoseLandmarkType.rightElbow) &&
        lm.containsKey(PoseLandmarkType.rightWrist) &&
        lm.containsKey(PoseLandmarkType.rightKnee);

    if (!hasLeft && !hasRight) return null;

    double leftScore = 0;
    if (hasLeft) {
      leftScore = lm[PoseLandmarkType.leftShoulder]!.likelihood +
          lm[PoseLandmarkType.leftHip]!.likelihood +
          lm[PoseLandmarkType.leftAnkle]!.likelihood;
    }
    double rightScore = 0;
    if (hasRight) {
      rightScore = lm[PoseLandmarkType.rightShoulder]!.likelihood +
          lm[PoseLandmarkType.rightHip]!.likelihood +
          lm[PoseLandmarkType.rightAnkle]!.likelihood;
    }

    if (hasLeft && leftScore >= rightScore) {
      return {
        'shoulder': lm[PoseLandmarkType.leftShoulder]!,
        'elbow': lm[PoseLandmarkType.leftElbow]!,
        'wrist': lm[PoseLandmarkType.leftWrist]!,
        'hip': lm[PoseLandmarkType.leftHip]!,
        'knee': lm[PoseLandmarkType.leftKnee]!,
        'ankle': lm[PoseLandmarkType.leftAnkle]!,
      };
    } else {
      return {
        'shoulder': lm[PoseLandmarkType.rightShoulder]!,
        'elbow': lm[PoseLandmarkType.rightElbow]!,
        'wrist': lm[PoseLandmarkType.rightWrist]!,
        'hip': lm[PoseLandmarkType.rightHip]!,
        'knee': lm[PoseLandmarkType.rightKnee]!,
        'ankle': lm[PoseLandmarkType.rightAnkle]!,
      };
    }
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = _getLandmarks(landmarks);
    if (lm == null) return false;

    final shoulder = lm['shoulder']!;
    final elbow = lm['elbow']!;
    final wrist = lm['wrist']!;
    final hip = lm['hip']!;
    final knee = lm['knee']!;
    final ankle = lm['ankle']!;

    // FIX 1: Đảm bảo camera đã nhận diện rõ ràng toàn bộ cơ thể (không bị che lấp chân/hông dẫn đến nội suy sai)
    if (![shoulder, elbow, wrist, hip, knee, ankle]
        .every(ExerciseBase.isLandmarkConfident)) {
      return false;
    }

    // Cơ thể nằm ngang (khoảng cách X lớn hơn Y)
    double dx = (shoulder.x - ankle.x).abs();
    double dy = (shoulder.y - ankle.y).abs();
    bool isHorizontal = dx > dy * 1.2;
    if (!isHorizontal) return false;

    // Khoảng cách thân
    double torso = calculateDistance(shoulder, hip);
    if (torso == 0) torso = 1;

    // CHỐNG NGOẠI SUY VÀ NẰM BẸP TRÊN SÀN:
    // Cổ tay phải nằm DƯỚI vai một khoảng đáng kể (trục Y hướng xuống nên Y cổ tay > Y vai)
    // Chứng tỏ tay đang chống đẩy thân người lên khỏi mặt đất
    double armVerticalLift = wrist.y - shoulder.y;
    if (armVerticalLift < torso * 0.45) {
      return false;
    }

    if (!_hasFloorSupport(
      shoulder: shoulder,
      wrist: wrist,
      hip: hip,
      ankle: ankle,
      torso: torso,
    )) {
      resultIssues.feedback['System'] =
          'Hãy chống tay trên sàn, không tập plank trên tường.';
      return false;
    }

    double armAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
    double bodyAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    double kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);

    // FIX 2: Đo góc giữa cánh tay và thân người để tránh trường hợp nằm duỗi thẳng trên sàn (Superman pose)
    double armBodyAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: shoulder, lastPoint: wrist);

    if (armAngle < HighPlankConfig.START_ARM_MIN) return false;
    if (bodyAngle < HighPlankConfig.START_BODY_MIN) return false;
    if (kneeAngle < HighPlankConfig.START_KNEE_MIN) return false;

    // Trong Plank, cánh tay chống đẩy cơ thể lên nên sẽ tạo góc với lưng, không được duỗi song song với cơ thể
    if (armBodyAngle < 40.0 || armBodyAngle > 140.0) return false;

    return true;
  }

  @override
  bool requestStop() =>
      _timeoutReached || timerMetric.totalHoldingTimeMs >= _targetTimeMs;

  @override
  Map<String, String> processNoPoseFrame() {
    timerMetric.pause();
    _lastFrameTimeMs = null;
    return super.processNoPoseFrame();
  }

  @override
  void onExerciseActivated() {
    _resetSetState();
  }

  @override
  void onSetComplete() {
    final formFaults = <FaultRecord>[
      ...saggingMetric.faults,
      ...pikedHipMetric.faults,
      ...elbowMetric.faults,
    ];
    final holdCorrect = !formFaults.any((f) => f.affectsForm);

    final goodSeconds = _goodHoldingTimeMs / 1000.0;
    final targetSeconds = maxSeconds.toDouble();
    // Target denominator for scoring, not elapsed hold time.
    logger.pushKey("total_seconds", targetSeconds);
    logger.pushKey("good_seconds", goodSeconds.clamp(0.0, targetSeconds));
    logger.pushKey("max_rep", 1);
    logger.pushKey("sagging_fails_count", saggingMetric.faults.length);
    logger.pushKey("piked_fails_count", pikedHipMetric.faults.length);
    logger.pushKey("elbow_fails_count", elbowMetric.faults.length);
    logger.pushKey("sagging_fault_seconds", _saggingFaultSeconds);
    logger.pushKey("piked_fault_seconds", _pikedFaultSeconds);
    logger.pushKey("elbow_fault_seconds", _elbowFaultSeconds);
    logger.pushKey("total_perfect_time_ms", timerMetric.totalHoldingTimeMs);

    if (!_setCompletionLogged) {
      logger.addRepLog(RepLog(correctForm: holdCorrect, repNumber: 1, data: {
        "perfect_hold_time": timerMetric.totalHoldingTimeMs / 1000.0,
        "fault_types": formFaults.map((e) => e.type).toSet().toList(),
      }));
      _setCompletionLogged = true;
    }

    logger.pushGoodRepCount();

    StringBuffer dump = StringBuffer();
    dump.writeln("=== DIAGNOSTIC LOG (HIGH PLANK) ===");
    dump.writeln("Time(s) | State | S-H-A | S-E-W | HipDev");
    for (var log in _diagnosticLog) {
      dump.writeln(
          "${log['time']} | ${log['state']} | ${log['body'].toStringAsFixed(1)} | ${log['arm'].toStringAsFixed(1)} | ${log['dev'].toStringAsFixed(2)}");
    }
    logger.pushKey("diagnostic_dump", dump.toString());
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final now = frameTimestampMs;
    _exerciseStartTimeMs ??= now;

    if (now - _exerciseStartTimeMs! >= HighPlankConfig.TIMEOUT_MS) {
      _timeoutReached = true;
      return;
    }

    final lm = _getLandmarks(landmarks);
    if (lm == null) {
      timerMetric.pause();
      _lastFrameTimeMs = null;
      return;
    }

    final shoulder = lm['shoulder']!;
    final elbow = lm['elbow']!;
    final wrist = lm['wrist']!;
    final hip = lm['hip']!;
    final knee = lm['knee']!;
    final ankle = lm['ankle']!;

    // Bổ sung chặn rác dữ liệu: Nếu đang tập mà có vật cản che khuất tay/chân/hông thì tạm bỏ qua frame này
    if (![shoulder, elbow, wrist, hip, knee, ankle]
        .every(ExerciseBase.isLandmarkConfident)) {
      timerMetric.pause();
      _lastFrameTimeMs = null;
      return;
    }

    scaleFactor = calculateDistance(shoulder, hip);
    if (!_hasFloorSupport(
      shoulder: shoulder,
      wrist: wrist,
      hip: hip,
      ankle: ankle,
      torso: scaleFactor == 0 ? 1 : scaleFactor,
    )) {
      resultIssues.feedback['System'] =
          'Hãy chống tay trên sàn, không tập plank trên tường.';
      if (state == HighPlankState.holding) {
        _transitionState(HighPlankState.dropping, now);
      }
      timerMetric.pause();
      _lastFrameTimeMs = null;
      return;
    }
    double bodyAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    double armAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
    double kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);

    double expectedHipY = _interpolateY(shoulder, ankle, hip.x);
    double rawDeviation = hip.y - expectedHipY;
    double hipDeviation = scaleFactor > 0 ? rawDeviation / scaleFactor : 0;
    final dtMs = _lastFrameTimeMs == null ? 0 : now - _lastFrameTimeMs!;
    _lastFrameTimeMs = now;
    final wasHolding = state == HighPlankState.holding;

    if (now - _lastDiagnosticTime > 500 || state != previousState) {
      _diagnosticLog.add({
        'time': ((now - _exerciseStartTimeMs!) / 1000).toStringAsFixed(1),
        'state': state.name,
        'body': bodyAngle,
        'arm': armAngle,
        'dev': hipDeviation
      });
      _lastDiagnosticTime = now;
    }

    _updateStateMachine(bodyAngle, armAngle, hipDeviation, kneeAngle, now);
    _accumulateGoodHoldTime(
      dtMs: dtMs,
      wasHolding: wasHolding,
      bodyAngle: bodyAngle,
      armAngle: armAngle,
      hipDeviation: hipDeviation,
    );
    _accumulateFaultSeconds(
      dtMs: dtMs,
      wasHolding: wasHolding,
      bodyAngle: bodyAngle,
      armAngle: armAngle,
      hipDeviation: hipDeviation,
    );

    final ctx = HighPlankRepContext(
      shoulderHipAnkleAngle: bodyAngle,
      shoulderElbowWristAngle: armAngle,
      hipDeviation: hipDeviation,
      scaleFactor: scaleFactor,
      state: state,
      frameTimestampMs: now,
      resultIssues: resultIssues,
    );

    for (final metric in _metrics) metric.update(ctx);

    repCount = timerMetric.totalHoldingTimeMs ~/ 1000;

    resultIssues.addInstruction(state.name, 'Status', currentPhaseLabel);
  }

  int get _targetTimeMs => maxSeconds * 1000;

  void _resetSetState() {
    state = HighPlankState.setup;
    previousState = HighPlankState.setup;
    _exerciseStartTimeMs = null;
    _lastFrameTimeMs = null;
    _timeoutReached = false;
    _setCompletionLogged = false;
    _goodHoldingTimeMs = 0;
    _saggingFaultSeconds = 0.0;
    _pikedFaultSeconds = 0.0;
    _elbowFaultSeconds = 0.0;
    _diagnosticLog.clear();
    _lastDiagnosticTime = 0;
    repCount = 0;
    correctForm = true;
    logger.clear();
    timerMetric.reset();
    _holdingDebouncer.reset();
    _droppingDebouncer.reset();
    for (final metric in _metrics) {
      if (!identical(metric, timerMetric)) {
        metric.reset();
      }
    }
  }

  void _updateStateMachine(double bodyAngle, double armAngle, double hipDev,
      double kneeAngle, int now) {
    bool isFormGoodToHold =
        bodyAngle >= HighPlankConfig.HOLDING_BODY_THRESHOLD &&
            armAngle >= HighPlankConfig.HOLDING_ARM_THRESHOLD &&
            kneeAngle >= HighPlankConfig.HOLDING_KNEE_THRESHOLD &&
            hipDev < HighPlankConfig.HOLDING_SAG_DEVIATION;

    bool isFormBadToDrop = bodyAngle < HighPlankConfig.DROPPING_PIKE_ANGLE ||
        armAngle < HighPlankConfig.DROPPING_ARM_ANGLE ||
        kneeAngle < HighPlankConfig.DROPPING_KNEE_ANGLE ||
        hipDev >= HighPlankConfig.DROPPING_SAG_DEVIATION;

    if (state == HighPlankState.setup || state == HighPlankState.dropping) {
      if (_holdingDebouncer.update(isFormGoodToHold)) {
        _transitionState(HighPlankState.holding, now);
      }
    } else if (state == HighPlankState.holding) {
      if (_droppingDebouncer.update(isFormBadToDrop)) {
        _transitionState(HighPlankState.dropping, now);
      }
    }
  }

  void _transitionState(HighPlankState newState, int now) {
    if (newState == state) return;
    previousState = state;
    state = newState;
    _holdingDebouncer.reset();
    _droppingDebouncer.reset();
    for (var metric in _metrics)
      metric.onStateTransition(previousState, newState, now);
  }

  void _accumulateGoodHoldTime({
    required int dtMs,
    required bool wasHolding,
    required double bodyAngle,
    required double armAngle,
    required double hipDeviation,
  }) {
    if (!wasHolding || state != HighPlankState.holding || dtMs <= 0) return;
    if (!_hasActiveFormFault(
      bodyAngle: bodyAngle,
      armAngle: armAngle,
      hipDeviation: hipDeviation,
    )) {
      _goodHoldingTimeMs += dtMs;
    }
  }

  bool _hasActiveFormFault({
    required double bodyAngle,
    required double armAngle,
    required double hipDeviation,
  }) {
    return _isSaggingFault(hipDeviation) ||
        _isPikedFault(bodyAngle, hipDeviation) ||
        _isElbowFault(armAngle);
  }

  bool _isSaggingFault(double hipDeviation) =>
      hipDeviation > HighPlankConfig.DROPPING_SAG_DEVIATION;

  bool _isPikedFault(double bodyAngle, double hipDeviation) =>
      bodyAngle < HighPlankConfig.DROPPING_PIKE_ANGLE && hipDeviation < -0.05;

  bool _isElbowFault(double armAngle) =>
      armAngle < HighPlankConfig.HOLDING_ARM_THRESHOLD;

  void _accumulateFaultSeconds({
    required int dtMs,
    required bool wasHolding,
    required double bodyAngle,
    required double armAngle,
    required double hipDeviation,
  }) {
    if (!wasHolding || dtMs <= 0) return;
    final seconds = dtMs / 1000.0;
    // Fault-second buckets are independent: overlapping faults each receive
    // the same frame delta, so these are relative indicators, not elapsed time.
    if (_isSaggingFault(hipDeviation)) {
      _saggingFaultSeconds += seconds;
    }
    if (_isPikedFault(bodyAngle, hipDeviation)) {
      _pikedFaultSeconds += seconds;
    }
    if (_isElbowFault(armAngle)) {
      _elbowFaultSeconds += seconds;
    }
  }

  double _interpolateY(PoseLandmark p1, PoseLandmark p2, double targetX) {
    if (p1.x == p2.x) return p1.y;
    double t = (targetX - p1.x) / (p2.x - p1.x);
    return p1.y + t * (p2.y - p1.y);
  }

  bool _hasFloorSupport({
    required PoseLandmark shoulder,
    required PoseLandmark wrist,
    required PoseLandmark hip,
    required PoseLandmark ankle,
    required double torso,
  }) {
    final safeTorso = torso <= 0 ? 1.0 : torso;
    final wristAnkleYGap = (wrist.y - ankle.y).abs() / safeTorso;
    final wristBelowShoulder = (wrist.y - shoulder.y) / safeTorso;
    final ankleBelowHip = (ankle.y - hip.y) / safeTorso;

    return wristAnkleYGap <= HighPlankConfig.FLOOR_CONTACT_Y_TOLERANCE &&
        wristBelowShoulder >= HighPlankConfig.WRIST_BELOW_SHOULDER_MIN &&
        ankleBelowHip >= HighPlankConfig.ANKLE_BELOW_HIP_MIN;
  }
}
