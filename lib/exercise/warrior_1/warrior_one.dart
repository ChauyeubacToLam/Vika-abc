// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

/* =========================================================================
   Warrior I (Virabhadrasana I)

   STATIC HOLD exercise — NOT rep-based. Cycle: ENTRY → HOLD → EXIT.
   Hold one side for HOLD_DURATION seconds, prompt a side switch, hold the
   other side, then stop. Side view, BlazePose 33 landmarks.

   Pattern sources:
     - Hold state machine + timer  → Plank
     - Per-metric MetricBase        → Lunge / Push-up
     - Front/back leg detection     → Lunge (_detectFrontLeg)

   Checks:
     Metric classes : trunk_lean (SAFETY), cervical_safety, arm_position, back_knee
     In this file   : Check 3 front-knee depth, Check 4 stance length
   ========================================================================= */

import 'dart:math' as math;

import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/utils/exercise_logger.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../utils/pose_math_helpers.dart';
import '../../utils/debouncer.dart';
import 'metrics/warrior_one_metric_base.dart';
import 'metrics/trunk_lean_metric.dart';
import 'metrics/cervical_safety_metric.dart';
import 'metrics/arm_position_metric.dart';
import 'metrics/back_knee_metric.dart';
import 'metrics/back_straight_metric.dart';

// --- Config (Week 1-4 launch defaults; tighten per spec threshold table) ---

class WarriorOneConfig {
  /// Seconds to hold each side.
  static const double HOLD_DURATION = 20.0;

  /// Hip Y-velocity (normalized units / sec) below which the user is "still".
  /// ESTIMATE — tune on device. BlazePose y is normalized [0,1].
  static const double STILL_VELOCITY_THRESHOLD = 2.5;

  /// Frames the user must be still to enter HOLD (~500ms at 30fps).
  static const int STILL_FRAMES = 10;

  /// isInStartPosition: trunk must be within this many degrees of vertical.
  static const double START_TRUNK_TOLERANCE = 40.0;

  /// isInStartPosition / Check 4: minimum stance ratio to count as "feet apart".
  static const double START_STANCE_MIN = 0.65;

  /// Entry gate: hold timer starts only after the full Warrior I shape appears.
  static const double ENTRY_FRONT_KNEE_MAX = 165.0;
  static const double ENTRY_BACK_KNEE_MIN = 140.0;
  static const double ENTRY_ARM_MAX = 60.0;

  // --- Check 3: front-knee depth (coaching only) ---
  static const double DEPTH_GOOD_MIN = 85.0; // desk-worker band
  static const double DEPTH_GOOD_MAX = 165.0;
  static const double DEPTH_SHALLOW = 170.0; // > this = shallow
  static const double DEPTH_DECAY_LIMIT = 18.0; // angle creep during hold

  // --- Check 4: stance length (coaching only), normalized by scaleFactor ---
  static const double STANCE_GOOD_MIN = 0.9;
  static const double STANCE_GOOD_MAX = 2.4;
  static const double STANCE_TOO_SHORT = 0.75;
  static const double STANCE_TOO_LONG = 2.7;
}

enum WarriorOneState { entry, hold, exit }

// --- Warrior I ---

class WarriorOne extends ExerciseBase {
  final int maxHolds;

  WarriorOne({required this.maxHolds});

  WarriorOneState holdState = WarriorOneState.entry;
  WarriorOneState previousHoldState = WarriorOneState.entry;

  // --- Metrics ---
  final TrunkLeanMetric trunkLeanMetric = TrunkLeanMetric();
  final CervicalSafetyMetric cervicalMetric = CervicalSafetyMetric();
  final ArmPositionMetric armMetric = ArmPositionMetric();
  final BackKneeMetric backKneeMetric = BackKneeMetric();
  final BackStraightMetric backStraightMetric = BackStraightMetric();

  late final List<WarriorOneMetricBase> _metrics = [
    trunkLeanMetric,
    cervicalMetric,
    armMetric,
    backKneeMetric,
    backStraightMetric,
  ];

  // --- Hold timing ---
  int? _holdStartMs;
  final StickyDebouncer _stillDebouncer = StickyDebouncer(
      requiredFrames: WarriorOneConfig.STILL_FRAMES, currentState: false);
  double? _prevHipY;
  final HoldSecondsAccumulator _holdSeconds = HoldSecondsAccumulator(const [
    'trunk_lean_seconds',
    'cervical_seconds',
    'arm_seconds',
    'back_knee_seconds',
    'back_straight_seconds',
  ]);

  // --- Baselines (captured at ENTRY → HOLD) ---
  double? _trunkBaseline;
  double? _cervicalBaseline;

  // --- Check 3 (depth) + Check 4 (stance) state ---
  double? _minFrontKnee;
  double? _maxFrontKnee;
  bool _stanceChecked = false;

  // --- Front-leg detection (ported from Lunge) ---
  // The FRONT (lead) leg is the one that bends. getSideLandmark() does NOT
  // detect this — it picks the camera-near body side. We detect front/back
  // by ankle X relative to camera facing, debounce, and lock per hold.
  bool? _isLeftLegFront;
  bool _frontLegLocked = false;
  final StickyDebouncer _frontLegDebouncer =
      StickyDebouncer(requiredFrames: 5, currentState: true);

  bool? _detectFrontLeg(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    if (leftAnkle == null || rightAnkle == null) return _isLeftLegFront;

    bool leftIsFront;
    if (cameraFacing == CameraFacing.left) {
      leftIsFront = leftAnkle.x < rightAnkle.x;
    } else if (cameraFacing == CameraFacing.right) {
      leftIsFront = leftAnkle.x > rightAnkle.x;
    } else {
      return _isLeftLegFront;
    }
    return _frontLegDebouncer.update(leftIsFront);
  }

  ({PoseLandmark? hip, PoseLandmark? knee, PoseLandmark? ankle}) _frontLeg(
      Map<PoseLandmarkType, PoseLandmark> lm) {
    final isLeft = _isLeftLegFront ?? true;
    return (
      hip: lm[isLeft ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip],
      knee: lm[isLeft ? PoseLandmarkType.leftKnee : PoseLandmarkType.rightKnee],
      ankle:
          lm[isLeft ? PoseLandmarkType.leftAnkle : PoseLandmarkType.rightAnkle],
    );
  }

  ({PoseLandmark? hip, PoseLandmark? knee, PoseLandmark? ankle}) _backLeg(
      Map<PoseLandmarkType, PoseLandmark> lm) {
    final isLeft = _isLeftLegFront ?? true;
    return (
      hip: lm[isLeft ? PoseLandmarkType.rightHip : PoseLandmarkType.leftHip],
      knee: lm[isLeft ? PoseLandmarkType.rightKnee : PoseLandmarkType.leftKnee],
      ankle:
          lm[isLeft ? PoseLandmarkType.rightAnkle : PoseLandmarkType.leftAnkle],
    );
  }

  // --- UI Bridge ---

  @override
  String get exerciseName => 'Warrior I';

  // Warrior I is one two-sided hold inside a single set. Replaying advice from
  // the process-wide generic voice cache can inject stale cues from an older
  // workout before the normal setup sequence.
  @override
  bool get shouldReplayPreviousSetVoiceFaults => false;

  @override
  String get currentPhaseKey => holdState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (holdState) {
      case WarriorOneState.entry:
        return 'Chuẩn bị';
      case WarriorOneState.hold:
        return 'Giữ!';
      case WarriorOneState.exit:
        return 'Xong';
    }
  }

  @override
  double? get liveHoldSeconds =>
      holdState == WarriorOneState.hold ? _currentHoldSeconds() : null;

  @override
  double? get liveHoldTargetSeconds => WarriorOneConfig.HOLD_DURATION;

  // --- Stop Condition ---

  @override
  bool requestStop() => repCount >= maxHolds;

  @override
  void onExerciseActivated() {
    super.onExerciseActivated();
    _holdSeconds.reset();
  }

  @override
  void onSetComplete() {
    logger.pushKey('max_rep', maxHolds);
    final targetSeconds = maxHolds * WarriorOneConfig.HOLD_DURATION;
    logger.pushKey('total_seconds', targetSeconds);
    logger.pushKey(
        'good_seconds', _holdSeconds.goodSeconds.clamp(0.0, targetSeconds));
    logger.pushKey('trunk_lean_seconds',
        _holdSeconds.faultSecondsFor('trunk_lean_seconds'));
    logger.pushKey(
        'cervical_seconds', _holdSeconds.faultSecondsFor('cervical_seconds'));
    logger.pushKey('arm_seconds', _holdSeconds.faultSecondsFor('arm_seconds'));
    logger.pushKey(
        'back_knee_seconds', _holdSeconds.faultSecondsFor('back_knee_seconds'));
    logger.pushKey('back_straight_seconds',
        _holdSeconds.faultSecondsFor('back_straight_seconds'));
    logger.pushGoodRepCount();
  }

  // --- Safety Checks (needs BOTH legs, like Lunge) ---

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return const GuidanceSignal.turnSide();
    }

    final required = [
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ];

    final pts = required.map((t) => landmarks[t]).toList();
    if (pts.any((l) => l == null)) {
      return const GuidanceSignal.bodyInFrame();
    }
    if (pts.any((l) => !ExerciseBase.isLandmarkConfident(l!))) {
      return const GuidanceSignal.lighting();
    }
    return null;
  }

  // --- Start Position (held ~3s; framework gates activation) ---

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return false;
    }

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
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    if (shoulder == null ||
        hip == null ||
        leftAnkle == null ||
        rightAnkle == null) return false;

    // 1. Shoulder above hip (standing upright).
    if (shoulder.y >= hip.y) return false;

    // 2. Trunk roughly vertical.
    final clock = calculateVerticalAngle(pivot: hip, point: shoulder);
    final lean = convertClockAngleToTrunkLean(clock, cameraFacing).abs();
    if (lean > WarriorOneConfig.START_TRUNK_TOLERANCE) return false;

    // 3. Feet spaced apart (stance ratio > 0.8).
    if (scaleFactor <= 0) return false;
    final stance = _dist(leftAnkle, rightAnkle) / scaleFactor;
    if (stance < WarriorOneConfig.START_STANCE_MIN) return false;

    return true;
  }

  // --- Main Loop ---

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    // 1. Front leg (until locked at HOLD entry).
    if (!_frontLegLocked) {
      _isLeftLegFront = _detectFrontLeg(smoothedLandmarks);
    }

    // 2. Torso/head/arm singletons via camera-near side.
    final shoulder = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    final hip = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);
    final ear = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightEar,
        leftType: PoseLandmarkType.leftEar);
    final elbow = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightElbow,
        leftType: PoseLandmarkType.leftElbow);
    final wrist = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightWrist,
        leftType: PoseLandmarkType.leftWrist);

    // 3. Legs via front/back detection.
    final front = _frontLeg(smoothedLandmarks);
    final back = _backLeg(smoothedLandmarks);

    if (shoulder == null ||
        hip == null ||
        ear == null ||
        elbow == null ||
        wrist == null ||
        front.hip == null ||
        front.knee == null ||
        front.ankle == null ||
        back.hip == null ||
        back.knee == null ||
        back.ankle == null) {
      return;
    }

    final int now = frameTimestampMs;

    // 4. Geometry.
    final double clockAngle =
        calculateVerticalAngle(pivot: hip, point: shoulder);
    final double trunkLean =
        convertClockAngleToTrunkLean(clockAngle, cameraFacing);

    final double cervicalAngle = calculateAngleNormalized(
        firstPoint: ear, midPoint: shoulder, lastPoint: hip);

    // Arm "overhead-ness": deviation of wrist→shoulder line from straight up.
    final double armClock =
        calculateVerticalAngle(pivot: shoulder, point: wrist);
    final double armVerticalAngle = math.min(armClock, 360.0 - armClock);

    final double elbowAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);

    final double backKneeAngle = calculateAngleNormalized(
        firstPoint: back.hip!, midPoint: back.knee!, lastPoint: back.ankle!);

    final double frontKneeAngle = calculateAngleNormalized(
        firstPoint: front.hip!, midPoint: front.knee!, lastPoint: front.ankle!);
    final double spineAngle = calculateAngleNormalized(
        firstPoint: ear, midPoint: shoulder, lastPoint: hip);

    final bool wristVisible =
        ExerciseBase.isLandmarkConfident(wrist) && wrist.y > 0.0;

    final double stance =
        scaleFactor > 0 ? _dist(front.ankle!, back.ankle!) / scaleFactor : 0.0;

    // 5. Hip Y-velocity → "is still?".
    final bool isStill = _updateStill(hip.y, now);
    final bool frontKneeReady =
        frontKneeAngle <= WarriorOneConfig.ENTRY_FRONT_KNEE_MAX;
    final bool backLegReady =
        backKneeAngle >= WarriorOneConfig.ENTRY_BACK_KNEE_MIN;
    final bool armsReady = armVerticalAngle <= WarriorOneConfig.ENTRY_ARM_MAX;
    final bool readyToHold = frontKneeReady && backLegReady && armsReady;

    // 6. Build HoldContext.
    final ctx = HoldContext(
      trunkLean: trunkLean,
      cervicalAngle: cervicalAngle,
      armVerticalAngle: armVerticalAngle,
      elbowAngle: elbowAngle,
      backKneeAngle: backKneeAngle,
      spineAngle: spineAngle,
      wristVisible: wristVisible,
      holdState: holdState,
      frameTimestamp: now,
      scaleFactor: scaleFactor,
      trunkBaseline: _trunkBaseline,
      cervicalBaseline: _cervicalBaseline,
      resultIssues: resultIssues,
    );

    final debugEnabled = isDebugModeActive;
    // 7. Debug.
    debugData['holdState'] = holdState.name;
    debugData['frontLeg'] = (_isLeftLegFront ?? true) ? 'Left' : 'Right';
    debugData['trunkLean'] =
        '${trunkLean >= 0 ? "+" : ""}${trunkLean.toStringAsFixed(1)}°';
    debugData['cervicalAngle'] = cervicalAngle.toStringAsFixed(1);
    debugData['armVertical'] = armVerticalAngle.toStringAsFixed(1);
    debugData['elbowAngle'] = elbowAngle.toStringAsFixed(1);
    debugData['spineAngle'] = spineAngle.toStringAsFixed(1);
    debugData['frontKnee'] = frontKneeAngle.toStringAsFixed(1);
    debugData['backKnee'] = backKneeAngle.toStringAsFixed(1);
    debugData['stance'] = stance.toStringAsFixed(2);
    debugData['isStill'] = isStill;
    debugData['readyToHold'] = readyToHold;
    debugData['holdTime'] = _currentHoldSeconds().toStringAsFixed(1);
    debugData['repCount'] = repCount.toString();

    // 8. State machine.
    _updateState(isStill, readyToHold, trunkLean, cervicalAngle, now);

    // 9. Phase-specific work.
    switch (holdState) {
      case WarriorOneState.entry:
        _holdSeconds.resetTick();
        _runEntry(
          stance,
          frontKneeReady: frontKneeReady,
          backLegReady: backLegReady,
          armsReady: armsReady,
        );
        break;

      case WarriorOneState.hold:
        // Track depth + decay for Check 3.
        _minFrontKnee =
            (_minFrontKnee == null || frontKneeAngle < _minFrontKnee!)
                ? frontKneeAngle
                : _minFrontKnee;
        _maxFrontKnee =
            (_maxFrontKnee == null || frontKneeAngle > _maxFrontKnee!)
                ? frontKneeAngle
                : _maxFrontKnee;

        for (final metric in _metrics) {
          metric.update(ctx);
        }

        _holdSeconds.accumulate(
          elapsedMs: elapsedMs,
          faultingByKey: {
            'trunk_lean_seconds': trunkLeanMetric.isFaultingNow,
            'cervical_seconds': cervicalMetric.isFaultingNow,
            'arm_seconds': armMetric.isFaultingNow,
            'back_knee_seconds': backKneeMetric.isFaultingNow,
            'back_straight_seconds': backStraightMetric.isFaultingNow,
          },
          goodBlockingKeys: const ['trunk_lean_seconds', 'arm_seconds'],
        );

        final remaining =
            (WarriorOneConfig.HOLD_DURATION - _currentHoldSeconds())
                .clamp(0.0, WarriorOneConfig.HOLD_DURATION);
        resultIssues.setPhaseStatus(
            'hold', 'Giữ! ${remaining.toStringAsFixed(0)}s');
        debugData['holdProgress'] =
            (_currentHoldSeconds() / WarriorOneConfig.HOLD_DURATION)
                .clamp(0.0, 1.0);
        break;

      case WarriorOneState.exit:
        _holdSeconds.resetTick();
        break;
    }

    // 10. Merge metric debug.
    if (debugEnabled) {
      for (final metric in _metrics) {
        debugData.addAll(metric.debugData);
      }
    }
  }

  // --- ENTRY: one-time stance check (Check 4) ---

  void _runEntry(
    double stance, {
    required bool frontKneeReady,
    required bool backLegReady,
    required bool armsReady,
  }) {
    resultIssues.setPhaseStatus(
        'entry',
        _entryGuidance(
          frontKneeReady: frontKneeReady,
          backLegReady: backLegReady,
          armsReady: armsReady,
        ));

    if (!frontKneeReady) {
      // Legacy UI instruction copy: Hạ gối chân trước xuống thêm một chút.
    }
    if (!backLegReady) {
      // Legacy UI instruction copy: Duỗi thẳng chân sau trước khi giữ.
    }
    if (!armsReady) {
      // Legacy UI instruction copy: Giơ hai tay lên cao rồi giữ yên.
    }

    if (_stanceChecked || scaleFactor <= 0) return;
    _stanceChecked = true;

    if (stance < WarriorOneConfig.STANCE_TOO_SHORT) {
      // Legacy UI instruction copy: Bước dài hơn một chút để tăng hiệu quả nhé!
    } else if (stance > WarriorOneConfig.STANCE_TOO_LONG) {
      // Legacy UI instruction copy: Bước ngắn lại một chút để giữ thăng bằng nhé!
    }
  }

  String _entryGuidance({
    required bool frontKneeReady,
    required bool backLegReady,
    required bool armsReady,
  }) {
    if (frontKneeReady && backLegReady && armsReady) {
      return 'Giữ yên tư thế Warrior I để bắt đầu đếm.';
    }
    if (!frontKneeReady) return 'Hạ gối chân trước xuống thêm một chút.';
    if (!backLegReady) return 'Duỗi thẳng chân sau trước khi giữ.';
    return 'Giơ hai tay lên cao rồi giữ yên.';
  }

  // --- HOLD complete: finalize, score, depth coaching, side switch ---

  void _onHoldComplete() {
    repCount += 1;

    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      allFaults.addAll(metric.faults);
    }

    // Only trunk_lean (affectsForm) can fail the hold.
    correctForm = !allFaults.any((f) => f.affectsForm);
    resultIssues.feedback['Result'] = correctForm ? 'Tốt lắm!' : 'Chú ý lưng';

    // Check 3: front-knee depth post-hold coaching.
    if (_minFrontKnee != null &&
        _minFrontKnee! > WarriorOneConfig.DEPTH_SHALLOW) {
      // Legacy UI instruction copy: Hạ thấp hơn một chút nếu bạn cảm thấy thoải mái nhé.
    }
    if (_minFrontKnee != null &&
        _maxFrontKnee != null &&
        (_maxFrontKnee! - _minFrontKnee!) >
            WarriorOneConfig.DEPTH_DECAY_LIMIT) {
      // Knee crept up during the hold — fatigue / position decay.
      // Legacy UI instruction copy: Cố giữ độ sâu đều trong suốt thời gian giữ nhé.
    }

    // Build phase→type→message map for the result screen (Lunge pattern).
    final faultMap = <String, Map<String, String>>{};
    for (final fault in allFaults) {
      faultMap.putIfAbsent(fault.phase, () => {});
      faultMap[fault.phase]![fault.type] = fault.message;
    }
    setFeedback.add({correctForm: faultMap});
    logger.addRepLog(RepLog(
      correctForm: correctForm,
      repNumber: repCount,
      data: {
        'hold_time': WarriorOneConfig.HOLD_DURATION,
        'fault_types': allFaults.map((f) => f.type).toSet().toList(),
      },
    ));
    for (final metric in _metrics) {
      metric.resetAndCountFault();
    }
  }

  // --- State Machine ---

  void _updateState(bool isStill, bool readyToHold, double trunkLean,
      double cervicalAngle, int now) {
    switch (holdState) {
      case WarriorOneState.entry:
        // Stable → begin the hold and capture baselines.
        if (isStill && readyToHold) {
          _transition(WarriorOneState.hold, now);
          _holdStartMs = now;
          _trunkBaseline = trunkLean;
          _cervicalBaseline = cervicalAngle;
        }
        break;

      case WarriorOneState.hold:
        if (_currentHoldSeconds() >= WarriorOneConfig.HOLD_DURATION) {
          _transition(WarriorOneState.exit, now);
        }
        break;

      case WarriorOneState.exit:
        // Finalize once, then either prompt a side switch (back to ENTRY)
        // or stop (requestStop fires when repCount >= maxHolds).
        if (repCount < maxHolds) {
          resultIssues.phaseStatus.clear();
          resultIssues.setPhaseStatus(
              'entry', 'Đổi chân! Đưa chân kia ra trước.');
          _resetForNextSide();
          _transition(WarriorOneState.entry, now);
        }
        break;
    }
  }

  void _transition(WarriorOneState newState, int now) {
    previousHoldState = holdState;
    holdState = newState;

    // Lock the front leg for the duration of the hold.
    if (newState == WarriorOneState.hold) {
      _holdSeconds.resetTick();
      _frontLegLocked = true;
      resultIssues.phaseStatus.clear();
    } else if (newState == WarriorOneState.exit) {
      _holdSeconds.resetTick();
      _onHoldComplete();
    } else if (newState == WarriorOneState.entry) {
      _holdSeconds.resetTick();
      _frontLegLocked = false;
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousHoldState, newState, now);
    }
  }

  void _resetForNextSide() {
    _holdStartMs = null;
    _holdSeconds.resetTick();
    _prevHipY = null;
    _stillDebouncer.reset();
    _trunkBaseline = null;
    _cervicalBaseline = null;
    _minFrontKnee = null;
    _maxFrontKnee = null;
    _stanceChecked = false;
    _isLeftLegFront = null;
    _frontLegDebouncer.reset();
    for (final metric in _metrics) {
      metric.reset();
    }
  }

  @override
  Map<String, String> processNoPoseFrame() {
    if (holdState == WarriorOneState.hold) {
      _holdSeconds.resetTick();
      _resetForNextSide();
      previousHoldState = holdState;
      holdState = WarriorOneState.entry;
      resultIssues.setPhaseStatus(
          'entry', 'Mất mốc cơ thể, vào lại tư thế trước khi giữ.');
    }
    return super.processNoPoseFrame();
  }

  // --- Helpers ---

  /// Hip Y-velocity gate. True once velocity has been below threshold for
  /// STILL_FRAMES consecutive frames.
  bool _updateStill(double hipY, int now) {
    bool stillFrame = false;
    if (_prevHipY != null) {
      final deltaPx = (hipY - _prevHipY!).abs(); // pixels/frame
      debugData['hipVel'] = deltaPx.toStringAsFixed(2);
      stillFrame = deltaPx < WarriorOneConfig.STILL_VELOCITY_THRESHOLD;
    }
    _prevHipY = hipY;
    return _stillDebouncer.update(stillFrame);
  }

  double _currentHoldSeconds() {
    if (_holdStartMs == null) return 0.0;
    return (frameTimestampMs - _holdStartMs!) / 1000.0;
  }

  double _dist(PoseLandmark a, PoseLandmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
