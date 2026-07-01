// ignore_for_file: constant_identifier_names

/* =========================================================================
   DownwardDog — Adho Mukha Svanasana (Downward-Facing Dog)
   Camera: Side view | Tech: Pose Landmarker, 33 landmarks
   Target: Vietnamese desk workers

   State machine: ENTRY → HOLD → EXIT (hold-based, not rep-based).
   Default hold duration: 30 seconds.

   Metrics:
   - SpineRoundMetric     (Metric 1 — safety, affectsForm = true)
   - ShoulderShrugMetric  (Metric 2 — coaching, affectsForm = false)
   - LegStraightnessMetric(Check 5  — coaching, affectsForm = false)

   Embedded checks (no separate class):
   - Check 3: Hip Height / V Apex (shoulder–hip–ankle angle)
   - Check 4: Arm-Torso Line (reuses spineAngle from Metric 1)

   Baseline capture (during isInStartPosition hold-still, 3 seconds):
   - scaleFactor    = shoulder-to-hip distance
   - spineBaseline  = wrist-shoulder-hip angle
   - apexBaseline   = shoulder-hip-ankle angle
   - earShoulderBaseline = normalized ear-shoulder distance

   Reference: Warrior I (hold-based state machine) + Plank (trunk-line pattern).
   Do NOT modify exercise_base.dart or lib/utils/.
   ========================================================================= */

import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/debug/tracked_metric.dart';
import 'package:vika/utils/exercise_logger.dart';
import '../../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'metrics/downward_dog_metric_base.dart';
import 'metrics/spine_round_metric.dart';
import 'metrics/shoulder_shrug_metric.dart';
import 'metrics/leg_straightness_metric.dart';

export 'metrics/downward_dog_metric_base.dart';

// ─────────────────────────────────────────────────────────────
// State Machine
// ─────────────────────────────────────────────────────────────

enum DownwardDogState {
  /// User stepping into the inverted-V shape.
  entry,

  /// Static hold — all metrics active, hold timer running.
  hold,

  /// User stepping out, hold timer expired, or safety ceiling hit.
  exit,
}

// ─────────────────────────────────────────────────────────────
// Configuration
// ─────────────────────────────────────────────────────────────

class DownwardDogConfig {
  /// Default hold target (seconds).
  static const double HOLD_DURATION_SEC = 20.0;

  /// Hip Y-velocity threshold (px/frame) below which we consider the pose static.
  static const double HIP_VELOCITY_STILL_THRESHOLD = 6.0;

  /// Consecutive frames of stillness required to transition ENTRY → HOLD.
  static const int STILL_FRAMES_REQUIRED = 4;

  /// Consecutive frames of still required during isInStartPosition check (3s).
  static const int START_POSITION_FRAMES = 5;

  // --- Embedded Check 3: Hip Height / V Apex (shoulder–hip–ankle) ---

  /// Good V-apex range: desk workers typically land in 70°–100°.
  static const double APEX_GOOD_MIN = 55.0;
  static const double APEX_GOOD_MAX = 115.0;

  /// Above this: hips are dropping toward a plank.
  static const double APEX_TOO_LOW = 135.0;

  // --- Embedded Check 4: Arm-Torso Line ---
  // Reads the same wrist-shoulder-hip angle as SpineRoundMetric.
  // Fires as a coaching cue (not safety) when arm-torso line breaks
  // despite the spine being otherwise long.
  static const double ARM_TORSO_COACHING_ANGLE = 135.0;

  /// Minimum wrist-shoulder-hip angle to confirm starting position.
  static const double START_POSITION_LINE_ANGLE = 100.0;

  /// Sustained broken shape frames before aborting an active hold.
  static const int HOLD_BREAK_FRAMES = 6;
}

// ─────────────────────────────────────────────────────────────
// DownwardDog — Main Exercise Class
// ─────────────────────────────────────────────────────────────

class DownwardDog extends ExerciseBase {
  DownwardDog({required this.maxHolds}) {
    _spineMetric = SpineRoundMetric();
    _shoulderMetric = ShoulderShrugMetric();
    _legMetric = LegStraightnessMetric();

    _metrics = [_spineMetric, _shoulderMetric, _legMetric];
    _trackedMetrics = _metrics.map(TrackedMetric.new).toList();
  }

  final int maxHolds;

  // --- State ---
  DownwardDogState _state = DownwardDogState.entry;
  DownwardDogState get state => _state;

  @override
  String get exerciseName => 'Downward Dog';

  @override
  String get currentPhaseKey => _state.name;

  @override
  String get currentPhaseLabel =>
      _state == DownwardDogState.hold ? 'Giữ tư thế' : 'Vào tư thế';

  @override
  double? get liveHoldSeconds =>
      _state == DownwardDogState.hold ? _currentHoldSeconds() : null;

  @override
  double? get liveHoldTargetSeconds => DownwardDogConfig.HOLD_DURATION_SEC;

  @override
  bool requestStop() => repCount >= maxHolds;

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return 'Hãy quay nghiêng để theo dõi tư thế Chó cúi mặt.';
    }

    final required = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftEar,
      PoseLandmarkType.rightEar,
    ];

    for (final type in required) {
      final landmark = landmarks[type];
      if (landmark == null || !ExerciseBase.isLandmarkConfident(landmark)) {
        return 'Giữ toàn thân trong khung hình, thấy rõ tay, vai, hông, gối và cổ chân.';
      }
    }

    return null;
  }

  @override
  void onSetComplete() {
    logger.pushKey('max_rep', maxHolds);
    final targetSeconds = maxHolds * DownwardDogConfig.HOLD_DURATION_SEC;
    logger.pushKey('total_seconds', targetSeconds);
    logger.pushKey(
        'good_seconds', _holdSeconds.goodSeconds.clamp(0.0, targetSeconds));
    logger.pushKey('spine_round_seconds',
        _holdSeconds.faultSecondsFor('spine_round_seconds'));
    logger.pushKey('shoulder_shrug_seconds',
        _holdSeconds.faultSecondsFor('shoulder_shrug_seconds'));
    logger.pushKey('leg_straightness_seconds',
        _holdSeconds.faultSecondsFor('leg_straightness_seconds'));
    logger.pushGoodRepCount();
  }

  @override
  void onExerciseActivated() {
    super.onExerciseActivated();
    _holdSeconds.reset();
    activateHold(frameTimestampMs);
  }

  // --- Hold timer ---
  int? _holdStartMs;
  final HoldSecondsAccumulator _holdSeconds = HoldSecondsAccumulator(const [
    'spine_round_seconds',
    'shoulder_shrug_seconds',
    'leg_straightness_seconds',
  ]);

  bool get holdComplete =>
      _currentHoldSeconds() >= DownwardDogConfig.HOLD_DURATION_SEC;

  // --- Baseline values (captured at hold-still) ---
  double? _scaleFactor;
  double? _spineBaseline;
  double? _apexBaseline;
  double? _earShoulderBaseline;

  // --- Start-position detection ---
  int _stillFrameCount = 0;
  double? _lastHipY;
  bool _startPositionConfirmed = false;
  int _brokenHoldFrames = 0;

  // --- Metrics ---
  late final SpineRoundMetric _spineMetric;
  late final ShoulderShrugMetric _shoulderMetric;
  late final LegStraightnessMetric _legMetric;

  late final List<DownwardDogMetricBase> _metrics;
  late final List<TrackedMetric> _trackedMetrics;

  @override
  List<TrackedMetric> get trackedDebugMetrics =>
      List<TrackedMetric>.unmodifiable(
        [
          ...super.trackedDebugMetrics,
          ..._trackedMetrics,
        ],
      );

  // --- Fault accumulation across holds ---
  int holdCount = 0;

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final side = _resolveSideLandmarks(landmarks);

    if (side == null) {
      _holdSeconds.resetTick();
      return;
    }

    final spineAngle = calculateAngleNormalized(
      firstPoint: side.wrist,
      midPoint: side.shoulder,
      lastPoint: side.hip,
    );
    final apexAngle = calculateAngleNormalized(
      firstPoint: side.shoulder,
      midPoint: side.hip,
      lastPoint: side.ankle,
    );
    final kneeAngle = calculateAngleNormalized(
      firstPoint: side.hip,
      midPoint: side.knee,
      lastPoint: side.ankle,
    );
    final earShoulderDist = calculateDistance(side.ear, side.shoulder);

    processFrame(
      spineAngle: spineAngle,
      apexAngle: apexAngle,
      kneeAngle: kneeAngle,
      earShoulderDist: earShoulderDist,
      hipY: side.hip.y,
      scaleFactor: scaleFactor,
      timestampMs: frameTimestampMs,
    );
  }

  // ───────────────────────────────────────────────────────────
  // isInStartPosition
  // Called every frame in ENTRY state.
  // Returns true when the user has held the shape for 3 seconds:
  //   (1) hips are the highest landmark (hip Y < shoulder Y & hip Y < knee Y)
  //   (2) wrist and ankle near frame floor (grounded)
  //   (3) wrist-shoulder-hip angle > 150° (arm-torso line roughly present)
  // ───────────────────────────────────────────────────────────
  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final side = _resolveSideLandmarks(landmarks);
    if (side == null) return false;

    final hipY = side.hip.y;
    final shoulderY = side.shoulder.y;
    final kneeY = side.knee.y;
    final wristY = side.wrist.y;
    final ankleY = side.ankle.y;

    final spineAngle = calculateAngleNormalized(
      firstPoint: side.wrist,
      midPoint: side.shoulder,
      lastPoint: side.hip,
    );
    final apexAngle = calculateAngleNormalized(
      firstPoint: side.shoulder,
      midPoint: side.hip,
      lastPoint: side.ankle,
    );
    final earShoulderDist = calculateDistance(side.ear, side.shoulder);

    // In ML Kit, Y increases downward. Hips are the highest point means
    // hip Y is the smallest (closest to top of frame).
    final bool hipsHighest = hipY < shoulderY && hipY < kneeY;

    // Wrist and ankle are normally lower than the hip in the inverted V.
    final bool grounded = wristY > hipY && ankleY > hipY;

    // Arm-torso line: wrist-shoulder-hip > 150°.
    final bool linePresent =
        spineAngle >= DownwardDogConfig.START_POSITION_LINE_ANGLE;

    final bool posePresent = hipsHighest && grounded && linePresent;

    // Hip velocity check — must be still.
    double hipVelocity = 0.0;
    if (_lastHipY != null) {
      hipVelocity = (hipY - _lastHipY!).abs();
    }
    _lastHipY = hipY;

    final bool still =
        hipVelocity < DownwardDogConfig.HIP_VELOCITY_STILL_THRESHOLD;

    if (posePresent && still) {
      _stillFrameCount++;
    } else {
      _stillFrameCount = 0;
    }

    debugData['startFrames'] = _stillFrameCount;
    debugData['posePresent'] = posePresent;
    debugData['still'] = still;

    if (_stillFrameCount >= DownwardDogConfig.START_POSITION_FRAMES) {
      // Capture baselines.
      final localScale = calculateDistance(side.shoulder, side.hip);
      if (localScale < 1.0) return false;

      _scaleFactor = localScale;
      _spineBaseline = spineAngle;
      _apexBaseline = apexAngle;
      _earShoulderBaseline = earShoulderDist / localScale;
      _startPositionConfirmed = true;

      debugData['scaleFactor'] = localScale;
      debugData['spineBaseline'] = _spineBaseline;
      debugData['apexBaseline'] = _apexBaseline;
      debugData['earShoulderBaseline'] = _earShoulderBaseline;

      return true;
    }
    return false;
  }

  // ───────────────────────────────────────────────────────────
  // processFrame
  // Called every frame during HOLD state.
  // ───────────────────────────────────────────────────────────
  void processFrame({
    required double spineAngle,
    required double apexAngle,
    required double kneeAngle,
    required double earShoulderDist,
    required double hipY,
    required double scaleFactor,
    required int timestampMs,
  }) {
    // Clear per-frame feedback.
    resultIssues.feedback.clear();

    if (_state != DownwardDogState.hold) {
      _holdSeconds.resetTick();
      return;
    }

    final ctx = HoldContext(
      spineAngle: spineAngle,
      apexAngle: apexAngle,
      kneeAngle: kneeAngle,
      earShoulderDist: earShoulderDist,
      scaleFactor: _scaleFactor ?? scaleFactor,
      spineBaseline: _spineBaseline,
      earShoulderBaseline: _earShoulderBaseline,
      apexBaseline: _apexBaseline,
      holdState: _state,
      frameTimestamp: timestampMs,
      resultIssues: resultIssues,
    );

    final stillDownwardDogShape =
        spineAngle >= DownwardDogConfig.START_POSITION_LINE_ANGLE &&
            apexAngle <= DownwardDogConfig.APEX_TOO_LOW + 10.0;
    if (stillDownwardDogShape) {
      _brokenHoldFrames = 0;
    } else {
      _brokenHoldFrames++;
      debugData['brokenHoldFrames'] = _brokenHoldFrames;
      if (_brokenHoldFrames >= DownwardDogConfig.HOLD_BREAK_FRAMES) {
        _abortHold('Vào lại hình chữ V rồi giữ tiếp nhé.');
        return;
      }
    }

    // Run all metrics.
    for (final m in _metrics) {
      m.update(ctx);
    }

    // --- Embedded Check 3: Hip Height / V Apex ---
    _checkVApex(ctx);

    // --- Embedded Check 4: Arm-Torso Line (coaching) ---
    _checkArmTorsoLine(ctx);

    _holdSeconds.accumulate(
      elapsedMs: elapsedMs,
      faultingByKey: {
        'spine_round_seconds': _spineMetric.isFaultingNow,
        'shoulder_shrug_seconds': _shoulderMetric.isFaultingNow,
        'leg_straightness_seconds': _legMetric.isFaultingNow,
      },
      goodBlockingKeys: const ['spine_round_seconds'],
    );

    // --- Auto-EXIT: safety ceiling — spine rounding sustained ---
    if (_spineMetric.status == MetricStatus.fault) {
      debugData['autoExit'] = 'spine_round_safety';
      // Do not auto-exit here; surface the warning and let the hold timer
      // govern the exit unless the product team decides otherwise.
      // To auto-exit: call _transitionTo(DownwardDogState.exit, timestampMs);
    }

    // --- Hold complete ---
    if (holdComplete) {
      _evaluateAndExit(ctx, timestampMs);
    }

    debugData['state'] = _state.name;
    debugData['elapsedSec'] = _currentHoldSeconds().toStringAsFixed(1);
    debugData['spineAngle'] = spineAngle;
    debugData['apexAngle'] = apexAngle;
    debugData['kneeAngle'] = kneeAngle;
  }

  // ───────────────────────────────────────────────────────────
  // Embedded Check 3: Hip Height / V Apex
  // shoulder–hip–ankle angle. Smaller = deeper V.
  // ───────────────────────────────────────────────────────────
  void _checkVApex(HoldContext ctx) {
    if (ctx.apexAngle > DownwardDogConfig.APEX_TOO_LOW) {
      ctx.resultIssues.feedback['hip_height'] =
          'Đẩy hông lên cao và ra sau hơn nhé!';
      debugData['apexStatus'] = 'too low (hips dropping)';
    } else if (ctx.apexAngle >= DownwardDogConfig.APEX_GOOD_MIN &&
        ctx.apexAngle <= DownwardDogConfig.APEX_GOOD_MAX) {
      ctx.resultIssues.feedback['hip_height'] = 'Hông cao, tuyệt!';
      debugData['apexStatus'] = 'good V';
    } else {
      ctx.resultIssues.feedback['hip_height'] = 'Đẩy hông lên cao hơn nhé!';
      debugData['apexStatus'] = 'low V (coaching)';
    }
  }

  // ───────────────────────────────────────────────────────────
  // Embedded Check 4: Arm-Torso Line (coaching only)
  // Fires when arm line breaks despite spine being otherwise OK.
  // ───────────────────────────────────────────────────────────
  void _checkArmTorsoLine(HoldContext ctx) {
    // Only surface if spine is not already faulting (avoid cue overload).
    if (_spineMetric.status == MetricStatus.fault) return;

    if (ctx.spineAngle < DownwardDogConfig.ARM_TORSO_COACHING_ANGLE) {
      ctx.resultIssues.feedback['arm_torso'] =
          'Vươn ngực về phía đùi, kéo dài tay.';
      debugData['armTorsoStatus'] = 'coaching (not pressing back enough)';
    } else {
      debugData['armTorsoStatus'] = 'good';
    }
  }

  // ───────────────────────────────────────────────────────────
  // Evaluate & Exit
  // Called when the hold timer expires (or safety ceiling forces exit).
  // ───────────────────────────────────────────────────────────
  void _evaluateAndExit(HoldContext ctx, int timestampMs) {
    // Leg straightness post-hold coaching.
    _legMetric.evaluateHold(ctx);

    // Post-hold hip-height instruction.
    if (ctx.apexAngle > DownwardDogConfig.APEX_TOO_LOW) {
      ctx.resultIssues.addInstruction(
        'exit',
        'hip_height',
        'Đẩy hông lên cao và ra sau hơn nhé!',
      );
    }

    // Arm-torso line post-hold coaching.
    if (ctx.spineAngle < DownwardDogConfig.ARM_TORSO_COACHING_ANGLE &&
        _spineMetric.status != MetricStatus.fault) {
      ctx.resultIssues.addInstruction(
        'exit',
        'arm_torso',
        'Vươn ngực về phía đùi, kéo dài tay.',
      );
    }

    _transitionTo(DownwardDogState.exit, timestampMs);
    holdCount++;
    repCount += 1;

    final allFaults = this.allFaults;
    correctForm = !allFaults.any((f) => f.affectsForm);
    resultIssues.feedback['Result'] =
        correctForm ? 'Tốt lắm!' : 'Chú ý giữ lưng dài hơn';

    final faultMap = <String, Map<String, String>>{};
    for (final fault in allFaults) {
      faultMap.putIfAbsent(fault.phase, () => {});
      faultMap[fault.phase]![fault.type] = fault.message;
    }
    setFeedback.add({correctForm: faultMap});

    logger.addRepLog(
      RepLog(
        correctForm: correctForm,
        repNumber: repCount,
        data: {
          'hold_time': DownwardDogConfig.HOLD_DURATION_SEC,
          'fault_types': allFaults.map((f) => f.type).toSet().toList(),
          'spine_angle': ctx.spineAngle,
          'apex_angle': ctx.apexAngle,
          'knee_angle': ctx.kneeAngle,
        },
      ),
    );

    for (final metric in _metrics) {
      metric.resetAndCountFault();
    }
  }

  // ───────────────────────────────────────────────────────────
  // State Transition
  // ───────────────────────────────────────────────────────────
  void _transitionTo(DownwardDogState next, int timestampMs) {
    final prev = _state;
    _state = next;

    if (next == DownwardDogState.hold) {
      _holdSeconds.resetTick();
      _holdStartMs = timestampMs;
      // Clear per-hold instructions when new hold begins.
      resultIssues.instructions.clear();
    } else if (prev == DownwardDogState.hold) {
      _holdSeconds.resetTick();
    }

    for (final m in _metrics) {
      m.onStateTransition(prev, next, timestampMs);
    }

    debugData['lastTransition'] = '${prev.name}→${next.name}';
  }

  /// Called externally (by the exercise screen) when start position confirmed.
  void activateHold(int timestampMs) {
    if (_state == DownwardDogState.entry && _startPositionConfirmed) {
      _transitionTo(DownwardDogState.hold, timestampMs);
    }
  }

  _DownwardDogSide? _resolveSideLandmarks(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    PoseLandmark? shoulder = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightShoulder,
      leftType: PoseLandmarkType.leftShoulder,
    );
    PoseLandmark? hip = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightHip,
      leftType: PoseLandmarkType.leftHip,
    );
    PoseLandmark? knee = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightKnee,
      leftType: PoseLandmarkType.leftKnee,
    );
    PoseLandmark? ankle = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightAnkle,
      leftType: PoseLandmarkType.leftAnkle,
    );
    PoseLandmark? wrist = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightWrist,
      leftType: PoseLandmarkType.leftWrist,
    );
    PoseLandmark? ear = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightEar,
      leftType: PoseLandmarkType.leftEar,
    );

    if (shoulder == null ||
        hip == null ||
        knee == null ||
        ankle == null ||
        wrist == null ||
        ear == null) {
      return null;
    }

    return _DownwardDogSide(
      shoulder: shoulder,
      hip: hip,
      knee: knee,
      ankle: ankle,
      wrist: wrist,
      ear: ear,
    );
  }

  /// Collect all faults from all metrics.
  List<FaultRecord> get allFaults => _metrics.expand((m) => m.faults).toList()
    ..sort((a, b) => a.priority.compareTo(b.priority));

  /// Whether the current hold has any form-critical faults.
  bool get hasFormFault =>
      _metrics.any((m) => m.faults.any((f) => f.affectsForm));

  /// Returns a progress value 0.0–1.0 for the hold timer.
  double get holdProgress =>
      (_currentHoldSeconds() / DownwardDogConfig.HOLD_DURATION_SEC)
          .clamp(0.0, 1.0);

  /// Reset between holds (e.g. for multi-set workouts).
  void resetHold() {
    for (final m in _metrics) {
      m.resetAndCountFault();
    }
    _state = DownwardDogState.entry;
    _holdStartMs = null;
    _stillFrameCount = 0;
    _lastHipY = null;
    _startPositionConfirmed = false;
    _scaleFactor = null;
    _spineBaseline = null;
    _apexBaseline = null;
    _earShoulderBaseline = null;
    resultIssues.feedback.clear();
    debugData.clear();
    _holdSeconds.reset();
  }

  @override
  Map<String, String> processNoPoseFrame() {
    if (_state == DownwardDogState.hold) {
      _abortHold('Mất mốc cơ thể, vào lại tư thế Chó cúi mặt để tiếp tục.');
    }
    return super.processNoPoseFrame();
  }

  double _currentHoldSeconds() {
    if (_holdStartMs == null) return 0.0;
    return (frameTimestampMs - _holdStartMs!) / 1000.0;
  }

  void _abortHold(String message) {
    _state = DownwardDogState.entry;
    _brokenHoldFrames = 0;
    _holdStartMs = null;
    _holdSeconds.resetTick();
    _stillFrameCount = 0;
    _lastHipY = null;
    _startPositionConfirmed = false;
    _scaleFactor = null;
    _spineBaseline = null;
    _apexBaseline = null;
    _earShoulderBaseline = null;
    for (final metric in _metrics) {
      metric.reset();
    }
    resultIssues.addInstruction('entry', 'Status', message);
    resultIssues.feedback['System'] = message;
  }

  // ───────────────────────────────────────────────────────────
  // Debug metric sources (for debug overlay)
  // ───────────────────────────────────────────────────────────
  List<DownwardDogMetricBase> get debugMetrics => List.unmodifiable(_metrics);
}

class _DownwardDogSide {
  final PoseLandmark shoulder;
  final PoseLandmark hip;
  final PoseLandmark knee;
  final PoseLandmark ankle;
  final PoseLandmark wrist;
  final PoseLandmark ear;

  _DownwardDogSide({
    required this.shoulder,
    required this.hip,
    required this.knee,
    required this.ankle,
    required this.wrist,
    required this.ear,
  });
}
