// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures
import 'package:vika/utils/debouncer.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../../services/high_plank_voice_coach.dart';
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
  static const double START_ARM_MIN = 140.0;
  static const double START_BODY_MIN = 150.0;
  static const double START_KNEE_MIN = 135.0;
  static const double FLOOR_CONTACT_Y_TOLERANCE = 0.55;
  static const double WRIST_BELOW_SHOULDER_MIN = 0.35;
  static const double ANKLE_BELOW_HIP_MIN = 0.06;

  // State Transition Thresholds
  // SETUP/DROPPING -> HOLDING (ngưỡng vào, chuẩn)
  static const double HOLDING_BODY_THRESHOLD = 150.0;
  static const double HOLDING_ARM_THRESHOLD = 140.0;
  static const double HOLDING_KNEE_THRESHOLD = 135.0;
  static const double HOLDING_SAG_DEVIATION = 0.12;

  // State Transition Thresholds
  // HOLDING -> DROPPING (ngưỡng ra, lỏng hơn = tạo hysteresis band)
  static const double DROPPING_PIKE_ANGLE = 140.0;
  static const double DROPPING_ARM_ANGLE = 130.0;
  static const double DROPPING_KNEE_ANGLE = 125.0; // Gối cong quá
  static const double DROPPING_SAG_DEVIATION = 0.18; // Sụp hông > 12% chiều dài
}

class HighPlank extends ExerciseBase {
  HighPlank({
    required this.maxSeconds,
  });

  final int maxSeconds;

  HighPlankState state = HighPlankState.setup;
  HighPlankState previousState = HighPlankState.setup;
  String? lastHoldFaultVoiceMessage;

  int? _exerciseStartTimeMs;
  bool _timeoutReached = false;
  bool _setCompletionLogged = false;
  final HoldSecondsAccumulator _holdSeconds = HoldSecondsAccumulator(const [
    'sagging_seconds',
    'piked_seconds',
    'elbow_seconds',
  ]);

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
  ExerciseVoiceCoach? createVoiceCoach() => HighPlankVoiceCoach();

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
    _holdSeconds.resetTick();
    return super.processNoPoseFrame();
  }

  @override
  void onExerciseActivated() {
    super.onExerciseActivated();
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

    final targetSeconds = maxSeconds.toDouble();
    // Target denominator for scoring, not elapsed hold time.
    logger.pushKey("total_seconds", targetSeconds);
    logger.pushKey(
        "good_seconds", _holdSeconds.goodSeconds.clamp(0.0, targetSeconds));
    logger.pushKey("max_rep", 1);
    logger.pushKey(
        "sagging_seconds", _holdSeconds.faultSecondsFor('sagging_seconds'));
    logger.pushKey(
        "piked_seconds", _holdSeconds.faultSecondsFor('piked_seconds'));
    logger.pushKey(
        "elbow_seconds", _holdSeconds.faultSecondsFor('elbow_seconds'));
    logger.pushKey("total_perfect_time_ms", timerMetric.totalHoldingTimeMs);

    if (!_setCompletionLogged) {
      logger.addRepLog(RepLog(correctForm: holdCorrect, repNumber: 1, data: {
        "perfect_hold_time": timerMetric.totalHoldingTimeMs / 1000.0,
        "fault_types": formFaults.map((e) => e.type).toSet().toList(),
      }));
      _setCompletionLogged = true;
    }

    logger.pushGoodRepCount();

    if (isDebugModeActive) {
      StringBuffer dump = StringBuffer();
      dump.writeln("=== DIAGNOSTIC LOG (HIGH PLANK) ===");
      dump.writeln("Time(s) | State | S-H-A | S-E-W | HipDev");
      for (var log in _diagnosticLog) {
        dump.writeln(
            "${log['time']} | ${log['state']} | ${log['body'].toStringAsFixed(1)} | ${log['arm'].toStringAsFixed(1)} | ${log['dev'].toStringAsFixed(2)}");
      }
      logger.pushKey("diagnostic_dump", dump.toString());
    }
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
      _holdSeconds.resetTick();
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
      _holdSeconds.resetTick();
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
      _holdSeconds.resetTick();
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
    final wasHolding = state == HighPlankState.holding;

    if (isDebugModeActive &&
        (now - _lastDiagnosticTime > 500 || state != previousState)) {
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

    if (state == HighPlankState.holding) {
      _holdSeconds.accumulate(
        elapsedMs: elapsedMs,
        faultingByKey: {
          'sagging_seconds': saggingMetric.isFaultingNow,
          'piked_seconds': pikedHipMetric.isFaultingNow,
          'elbow_seconds': elbowMetric.isFaultingNow,
        },
      );
    } else if (wasHolding) {
      _holdSeconds.resetTick();
    }

    repCount = timerMetric.totalHoldingTimeMs ~/ 1000;

    resultIssues.addInstruction(state.name, 'Status', currentPhaseLabel);
  }

  int get _targetTimeMs => maxSeconds * 1000;

  void _resetSetState() {
    state = HighPlankState.setup;
    previousState = HighPlankState.setup;
    _exerciseStartTimeMs = null;
    _timeoutReached = false;
    _setCompletionLogged = false;
    _holdSeconds.reset();
    _diagnosticLog.clear();
    _lastDiagnosticTime = 0;
    repCount = 0;
    correctForm = true;
    lastHoldFaultVoiceMessage = null;
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
        lastHoldFaultVoiceMessage = null;
        _transitionState(HighPlankState.holding, now);
      }
    } else if (state == HighPlankState.holding) {
      if (_droppingDebouncer.update(isFormBadToDrop)) {
        lastHoldFaultVoiceMessage = _voiceForHoldBreak(
          bodyAngle: bodyAngle,
          armAngle: armAngle,
          hipDev: hipDev,
          kneeAngle: kneeAngle,
        );
        _transitionState(HighPlankState.dropping, now);
      }
    }
  }

  String _voiceForHoldBreak({
    required double bodyAngle,
    required double armAngle,
    required double hipDev,
    required double kneeAngle,
  }) {
    if (hipDev >= HighPlankConfig.DROPPING_SAG_DEVIATION) {
      return 'Siết chặt bụng, nâng hông lên một chút';
    }
    if (armAngle < HighPlankConfig.DROPPING_ARM_ANGLE) {
      return 'Duỗi thẳng cánh tay ra';
    }
    if (bodyAngle < HighPlankConfig.DROPPING_PIKE_ANGLE || hipDev < -0.05) {
      return 'Hạ thấp mông xuống bằng với vai';
    }
    if (kneeAngle < HighPlankConfig.DROPPING_KNEE_ANGLE) {
      return 'Duỗi thẳng cánh tay ra';
    }
    return 'Giữ người thẳng trên sàn';
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
