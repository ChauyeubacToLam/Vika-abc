// ignore_for_file: non_constant_identifier_names, curly_braces_in_flow_control_structures
import 'dart:math' as math;

import 'package:vika/utils/debouncer.dart';
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
  static const double REST_DURATION_SECONDS = 5.0;

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

  // Outer anti-cheat ring. These are deliberately much looser than the form
  // thresholds above: ordinary form faults stay coachable inside the hold.
  static const double OUTER_ENTRY_BODY_MIN = 115.0;
  static const double OUTER_ENTRY_ARM_MIN = 100.0;
  static const double OUTER_ENTRY_KNEE_MIN = 100.0;
  static const double OUTER_ENTRY_SAG_MAX = 0.38;
  static const double OUTER_ENTRY_TORSO_TILT_MAX = 40.0;
  static const double OUTER_EXIT_BODY_MIN = 105.0;
  static const double OUTER_EXIT_ARM_MIN = 90.0;
  static const double OUTER_EXIT_KNEE_MIN = 90.0;
  static const double OUTER_EXIT_SAG_MAX = 0.45;
  static const double OUTER_EXIT_TORSO_TILT_MAX = 55.0;
}

class HighPlank extends ExerciseBase {
  HighPlank({
    required this.maxHolds,
    required this.holdSeconds,
  }) : super(targetReps: maxHolds, targetSeconds: holdSeconds);

  final int maxHolds;
  final int holdSeconds;

  HighPlankState state = HighPlankState.setup;
  HighPlankState previousState = HighPlankState.setup;
  int? _exerciseStartTimeMs;
  int? _restStartMs;
  int? _reArmHoldStartMs;
  int _completedHoldingTimeMs = 0;
  String? _outerBreakFaultId;
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
  bool get usesRepCountedHolds => true;

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
      case HighPlankState.resting:
        return 'Nghỉ';
      case HighPlankState.reArming:
        return 'Vào tư thế';
    }
  }

  @override
  bool get isReArmingHold => state == HighPlankState.reArming;

  @override
  int? get holdStillElapsedMs {
    if (!isReArmingHold) return super.holdStillElapsedMs;
    final startedAt = _reArmHoldStartMs;
    return startedAt == null ? null : frameTimestampMs - startedAt;
  }

  @override
  double? get activationProgress {
    if (!isReArmingHold) return super.activationProgress;
    final elapsedMs = holdStillElapsedMs;
    if (elapsedMs == null) return null;
    return (elapsedMs /
            ExerciseBase.HOLD_STILL_REQUIRED_DURATION.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  @override
  double? get liveHoldSeconds =>
      state == HighPlankState.holding || state == HighPlankState.dropping
          ? timerMetric.totalHoldingTimeMs / 1000.0
          : null;

  @override
  double? get liveHoldTargetSeconds => holdSeconds.toDouble();

  @override
  double? get liveRestSeconds {
    final startedAt = _restStartMs;
    if (state != HighPlankState.resting || startedAt == null) return null;
    final elapsedSeconds = (frameTimestampMs - startedAt) / 1000.0;
    return (HighPlankConfig.REST_DURATION_SECONDS - elapsedSeconds)
        .clamp(0.0, HighPlankConfig.REST_DURATION_SECONDS);
  }

  @override
  double? get liveRestTargetSeconds => HighPlankConfig.REST_DURATION_SECONDS;

  @override
  List<FaultRecord> get liveFaults {
    if (state == HighPlankState.holding) {
      return <FaultRecord>[
        if (saggingMetric.isFaultingNow)
          FaultRecord(
            phase: state.name,
            type: 'sagging',
            message: 'Võng lưng',
            affectsForm: true,
            priority: 0,
          ),
        if (elbowMetric.isFaultingNow)
          FaultRecord(
            phase: state.name,
            type: 'elbow',
            message: 'Khuỷu tay bị gập',
            affectsForm: true,
            priority: 1,
          ),
        if (pikedHipMetric.isFaultingNow)
          FaultRecord(
            phase: state.name,
            type: 'piked',
            message: 'Hông nâng quá cao',
            affectsForm: true,
            priority: 2,
          ),
      ];
    }
    final breakId = _outerBreakFaultId;
    if (state != HighPlankState.dropping || breakId == null) {
      return const <FaultRecord>[];
    }
    return <FaultRecord>[
      FaultRecord(
        phase: state.name,
        type: breakId,
        message: 'Mất tư thế plank',
        affectsForm: true,
        priority: 0,
      ),
    ];
  }

  @override
  GuidanceSignal? checkSafety(
      Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      _interruptReArm();
      return const GuidanceSignal.turnSide();
    }
    final lm = _getLandmarks(smoothedLandmarks);
    if (lm == null || !lm.values.every(ExerciseBase.isLandmarkConfident)) {
      _interruptActiveHold('wall_guard');
      _interruptReArm();
      return const GuidanceSignal.bodyInFrame();
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
  bool requestStop() => repCount >= maxHolds;

  @override
  Map<String, String> processNoPoseFrame() {
    final feedback = super.processNoPoseFrame();
    _interruptActiveHold('wall_guard');
    _interruptReArm();
    _advanceRestOnClock(frameTimestampMs);
    return feedback;
  }

  @override
  void onExerciseActivated() {
    super.onExerciseActivated();
    _resetSetState();
  }

  @override
  void onPauseReactivationStarted() {
    if (state != HighPlankState.holding && state != HighPlankState.dropping) {
      return;
    }

    // A base pause/re-hold is a real interruption, unlike the exercise's
    // brief dropping phase. Discard only the current partial hold; completed
    // holds and their logs remain set progress.
    _transitionState(HighPlankState.setup, frameTimestampMs);
    _outerBreakFaultId = null;
    correctForm = true;
    resultIssues.phaseStatus.clear();
    for (final metric in _metrics) {
      if (!identical(metric, timerMetric)) {
        metric.reset();
      }
    }
  }

  @override
  void onSetComplete() {
    final targetSeconds = (maxHolds * holdSeconds).toDouble();
    // Target denominator for scoring, not elapsed hold time.
    logger.pushKey("total_seconds", targetSeconds);
    logger.pushKey(
        "good_seconds", _holdSeconds.goodSeconds.clamp(0.0, targetSeconds));
    logger.pushKey("max_rep", maxHolds);
    logger.pushKey(
        "sagging_seconds", _holdSeconds.faultSecondsFor('sagging_seconds'));
    logger.pushKey(
        "piked_seconds", _holdSeconds.faultSecondsFor('piked_seconds'));
    logger.pushKey(
        "elbow_seconds", _holdSeconds.faultSecondsFor('elbow_seconds'));
    final currentPartialMs =
        state == HighPlankState.holding || state == HighPlankState.dropping
            ? timerMetric.totalHoldingTimeMs
            : 0;
    logger.pushKey(
      "total_perfect_time_ms",
      _completedHoldingTimeMs + currentPartialMs,
    );

    logger.pushGoodRepCount();

    if (isDebugModeActive) {
      StringBuffer dump = StringBuffer();
      dump.writeln("=== DIAGNOSTIC LOG (HIGH PLANK) ===");
      dump.writeln("Time(s) | State | S-H-A | S-E-W | HipDev | TorsoTiltDeg");
      for (var log in _diagnosticLog) {
        dump.writeln(
            "${log['time']} | ${log['state']} | ${log['body'].toStringAsFixed(1)} | ${log['arm'].toStringAsFixed(1)} | ${log['dev'].toStringAsFixed(2)} | ${log['torso_tilt'].toStringAsFixed(1)}");
      }
      logger.pushKey("diagnostic_dump", dump.toString());
    }
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final now = frameTimestampMs;
    _exerciseStartTimeMs ??= now;

    final lm = _getLandmarks(landmarks);
    if (lm == null) {
      _interruptActiveHold('wall_guard');
      _interruptReArm();
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
      _interruptActiveHold('wall_guard');
      _interruptReArm();
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
      _interruptActiveHold('wall_guard');
      _interruptReArm();
      _publishReArmGuidance();
      return;
    }
    double bodyAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    double armAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
    double kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);
    final torsoTiltDeg = math.atan2(
          (shoulder.y - hip.y).abs(),
          (shoulder.x - hip.x).abs(),
        ) *
        180 /
        math.pi;

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
        'dev': hipDeviation,
        'torso_tilt': torsoTiltDeg,
      });
      _lastDiagnosticTime = now;
    }

    _updateStateMachine(
      bodyAngle,
      armAngle,
      hipDeviation,
      kneeAngle,
      torsoTiltDeg,
      now,
    );
    _publishReArmGuidance();
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

    resultIssues.setPhaseStatus(state.name, currentPhaseLabel);
  }

  int get _targetTimeMs => holdSeconds * 1000;

  void _resetSetState() {
    state = HighPlankState.setup;
    previousState = HighPlankState.setup;
    _exerciseStartTimeMs = null;
    _restStartMs = null;
    _reArmHoldStartMs = null;
    _completedHoldingTimeMs = 0;
    _outerBreakFaultId = null;
    _holdSeconds.reset();
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

  void _updateStateMachine(
    double bodyAngle,
    double armAngle,
    double hipDev,
    double kneeAngle,
    double torsoTiltDeg,
    int now,
  ) {
    final isInsideOuterEntry =
        bodyAngle >= HighPlankConfig.OUTER_ENTRY_BODY_MIN &&
            armAngle >= HighPlankConfig.OUTER_ENTRY_ARM_MIN &&
            kneeAngle >= HighPlankConfig.OUTER_ENTRY_KNEE_MIN &&
            hipDev < HighPlankConfig.OUTER_ENTRY_SAG_MAX &&
            torsoTiltDeg <= HighPlankConfig.OUTER_ENTRY_TORSO_TILT_MAX;
    final isOutsideOuterRing =
        bodyAngle < HighPlankConfig.OUTER_EXIT_BODY_MIN ||
            armAngle < HighPlankConfig.OUTER_EXIT_ARM_MIN ||
            kneeAngle < HighPlankConfig.OUTER_EXIT_KNEE_MIN ||
            hipDev >= HighPlankConfig.OUTER_EXIT_SAG_MAX ||
            torsoTiltDeg > HighPlankConfig.OUTER_EXIT_TORSO_TILT_MAX;
    final confirmedOuterPose = _holdingDebouncer.update(isInsideOuterEntry);

    if (state == HighPlankState.setup || state == HighPlankState.dropping) {
      if (confirmedOuterPose) {
        _transitionState(HighPlankState.holding, now);
      }
    } else if (state == HighPlankState.holding) {
      if (_droppingDebouncer.update(isOutsideOuterRing)) {
        // Keep the structural clock-stop signal distinct from inner metric
        // faults so same-fault-once does not suppress it after a coached sag.
        _outerBreakFaultId = 'wall_guard';
        _transitionState(HighPlankState.dropping, now);
      } else if (timerMetric.totalHoldingTimeMs >= _targetTimeMs) {
        _transitionState(HighPlankState.resting, now);
      }
    } else if (state == HighPlankState.resting) {
      _advanceRestOnClock(now);
    } else if (state == HighPlankState.reArming) {
      if (!confirmedOuterPose) {
        _reArmHoldStartMs = null;
      } else {
        _reArmHoldStartMs ??= now;
        if (now - _reArmHoldStartMs! >=
            ExerciseBase.HOLD_STILL_REQUIRED_DURATION.inMilliseconds) {
          _transitionState(HighPlankState.holding, now);
        }
      }
    }
  }

  void _advanceRestOnClock(int now) {
    final restStartedAt = _restStartMs;
    if (state != HighPlankState.resting || restStartedAt == null) return;
    final restSeconds = (now - restStartedAt) / 1000.0;
    if (restSeconds >= HighPlankConfig.REST_DURATION_SECONDS) {
      _transitionState(HighPlankState.reArming, now);
    }
  }

  void _publishReArmGuidance() {
    if (state != HighPlankState.reArming) return;
    if (_reArmHoldStartMs == null) {
      // Not yet posed: reuse set-start's "get into position" signage + its
      // stuck-user voice re-tell.
      publishGuidanceSignal(
        const GuidanceSignal.setupPosition(
          title: 'Vào vị trí',
          body: 'Vào tư thế và giữ yên để bắt đầu.',
        ),
      );
    } else {
      // Once posed: clear the signage so re-arm is LINELESS (mirrors set-start's
      // hold-still) and the _CenterOverlay activation countdown RING renders.
      // A holdStill banner here would set guidanceCopy and suppress the ring.
      clearGuidanceSignal();
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

    switch (newState) {
      case HighPlankState.holding:
        // A drop pauses the current hold. Setup/rest begin a fresh hold.
        if (previousState != HighPlankState.dropping) {
          timerMetric.resetForNextHold();
        }
        _restStartMs = null;
        _reArmHoldStartMs = null;
        _outerBreakFaultId = null;
        _holdSeconds.resetTick();
        break;
      case HighPlankState.dropping:
        timerMetric.pause();
        _holdSeconds.resetTick();
        break;
      case HighPlankState.resting:
        timerMetric.pause();
        _holdSeconds.resetTick();
        _restStartMs = now;
        _reArmHoldStartMs = null;
        _onHoldComplete();
        break;
      case HighPlankState.reArming:
        timerMetric.pause();
        _holdSeconds.resetTick();
        _restStartMs = null;
        _reArmHoldStartMs = null;
        break;
      case HighPlankState.setup:
        timerMetric.resetForNextHold();
        _restStartMs = null;
        _reArmHoldStartMs = null;
        _holdSeconds.resetTick();
        break;
    }
  }

  void _interruptActiveHold(String faultId) {
    if (state != HighPlankState.holding) return;
    _outerBreakFaultId = faultId;
    _transitionState(HighPlankState.dropping, frameTimestampMs);
  }

  void _interruptReArm() {
    if (state != HighPlankState.reArming) return;
    _reArmHoldStartMs = null;
    _holdingDebouncer.reset();
  }

  void _onHoldComplete() {
    repCount += 1;
    final measuredHoldTimeMs =
        timerMetric.totalHoldingTimeMs.clamp(0, _targetTimeMs);
    _completedHoldingTimeMs += measuredHoldTimeMs;

    final faultsById = <String, FaultRecord>{
      if (saggingMetric.faults.isNotEmpty)
        'sagging': saggingMetric.faults.first,
      if (elbowMetric.faults.isNotEmpty) 'elbow': elbowMetric.faults.first,
      if (pikedHipMetric.faults.isNotEmpty)
        'piked': pikedHipMetric.faults.first,
    };
    correctForm = !faultsById.values.any((fault) => fault.affectsForm);

    final faultMap = <String, Map<String, String>>{
      if (faultsById.isNotEmpty)
        'HOLDING': <String, String>{
          for (final entry in faultsById.entries)
            entry.key: entry.value.message,
        },
    };
    setFeedback.add({correctForm: faultMap});
    logger.addRepLog(
      RepLog(
        correctForm: correctForm,
        repNumber: repCount,
        data: {
          'hold_time': measuredHoldTimeMs / 1000.0,
          'fault_types': faultsById.keys.toList(),
          'fault_affects_form': <String, bool>{
            for (final entry in faultsById.entries)
              entry.key: entry.value.affectsForm,
          },
          'fault_priorities': const <String, int>{
            'sagging': 0,
            'elbow': 1,
            'piked': 2,
          },
        },
      ),
    );

    for (final metric in _metrics) {
      if (!identical(metric, timerMetric)) metric.resetAndCountFault();
    }
    correctForm = true;
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
