// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/debouncer.dart';
import '../../utils/exercise_logger.dart';
import '../../services/bow_pose_voice_coach.dart';
import '../exercise_base.dart';
import 'metrics/bow_pose_metric_base.dart';
import 'metrics/connection_metric.dart';
import 'metrics/lift_form_metric.dart';
import 'metrics/hold_duration_metric.dart';
import 'metrics/stability_metric.dart';

class BowPoseConfig {
  static const int MAX_REP = 10;

  static const double KNEE_SETUP_ANGLE = 150.0;
  static const double CHEST_LIFT_THRESHOLD = 0.05;
  static const double THIGH_LIFT_THRESHOLD = 0.0;
  static const double RELEASE_DIST_THRESHOLD = 0.65;
  static const double HOLD_TARGET_SECONDS = 15.0;
}

class BowPose extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  final int maxRep;
  BowPose({this.maxRep = BowPoseConfig.MAX_REP});

  BowPoseState bowPoseState = BowPoseState.prone;
  BowPoseState previousState = BowPoseState.prone;

  double _baselineShoulderY = 0.0;
  final HoldSecondsAccumulator _holdSeconds = HoldSecondsAccumulator(const [
    'connection_seconds',
    'lift_form_seconds',
  ]);

  final Debouncer _stateDebouncer = Debouncer(requiredFrames: 3);

  final ConnectionMetric connectionMetric = ConnectionMetric();
  final LiftFormMetric liftFormMetric = LiftFormMetric();
  final HoldDurationMetric holdDurationMetric = HoldDurationMetric();
  final StabilityMetric stabilityMetric = StabilityMetric();

  bool lastRepWasClean = true;
  String? lastRepTopVoiceMessage;

  late final List<BowPoseMetricBase> _metrics = [
    connectionMetric,
    liftFormMetric,
    holdDurationMetric,
    stabilityMetric,
  ];

  @override
  String get exerciseName => 'Bow Pose';

  @override
  ExerciseVoiceCoach? createVoiceCoach() => BowPoseVoiceCoach();

  @override
  String get currentPhaseKey => bowPoseState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (bowPoseState) {
      case BowPoseState.prone:
        return 'Nằm sấp';
      case BowPoseState.setup:
        return 'Gập gối';
      case BowPoseState.ascending:
        return 'Lên cung';
      case BowPoseState.hold:
        return 'Giữ tĩnh';
      case BowPoseState.descending:
        return 'Hạ xuống';
    }
  }

  @override
  double? get liveHoldSeconds => bowPoseState == BowPoseState.hold
      ? holdDurationMetric.currentHoldSeconds
      : null;

  @override
  double? get liveHoldTargetSeconds => BowPoseConfig.HOLD_TARGET_SECONDS;

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    PoseLandmark? shoulder = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    PoseLandmark? hip = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);
    PoseLandmark? knee = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightKnee,
        leftType: PoseLandmarkType.leftKnee);
    PoseLandmark? ankle = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle);

    if (shoulder == null || hip == null || knee == null || ankle == null) {
      return false;
    }
    if (![shoulder, hip, knee, ankle].every(ExerciseBase.isLandmarkConfident)) {
      return false;
    }

    double refLen = calculateDistance(shoulder, hip);
    if (refLen == 0) return false;

    double yDiffShoulderHip = (shoulder.y - hip.y).abs() / refLen;
    double yDiffHipKnee = (hip.y - knee.y).abs() / refLen;

    if (yDiffShoulderHip > 0.35 || yDiffHipKnee > 0.35) return false;

    double kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);
    if (kneeAngle < 150.0) return false;

    return true;
  }

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onExerciseActivated() {
    super.onExerciseActivated();
    _holdSeconds.reset();
  }

  @override
  void onSetComplete() {
    final targetSeconds = maxRep * BowPoseConfig.HOLD_TARGET_SECONDS;
    logger.pushKey("total_seconds", targetSeconds);
    logger.pushKey(
        "good_seconds", _holdSeconds.goodSeconds.clamp(0.0, targetSeconds));
    logger.pushKey("connection_seconds",
        _holdSeconds.faultSecondsFor('connection_seconds'));
    logger.pushKey(
        "lift_form_seconds", _holdSeconds.faultSecondsFor('lift_form_seconds'));
    logger.pushMax("hold_time", "max_hold_time");
    logger.pushGoodRepCount();
    logger.pushKey("max_rep", maxRep);
  }

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return const GuidanceSignal.turnSide();
    }
    return null;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    PoseLandmark? shoulder = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    PoseLandmark? hip = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);
    PoseLandmark? knee = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightKnee,
        leftType: PoseLandmarkType.leftKnee);
    PoseLandmark? ankle = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle);
    PoseLandmark? wrist = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightWrist,
        leftType: PoseLandmarkType.leftWrist);

    if (shoulder == null ||
        hip == null ||
        knee == null ||
        ankle == null ||
        wrist == null) {
      _holdSeconds.resetTick();
      return;
    }
    if (shoulder.likelihood < 0.5 ||
        hip.likelihood < 0.5 ||
        knee.likelihood < 0.5 ||
        ankle.likelihood < 0.5 ||
        !ExerciseBase.isLandmarkConfident(wrist)) {
      _holdSeconds.resetTick();
      return;
    }

    double refLen = calculateDistance(shoulder, hip);
    if (refLen < 10) refLen = 10;

    double thighLen = calculateDistance(hip, knee);
    if (thighLen < 10) thighLen = 10;

    double wristAnkleDist = calculateDistance(wrist, ankle) / refLen;
    double chestLift = (hip.y - shoulder.y) / refLen;
    double thighLiftRelative = (hip.y - knee.y) / thighLen;
    double kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);

    int now = frameTimestampMs;

    final ctx = RepContext(
      referenceLength: refLen,
      thighLength: thighLen,
      rawShoulderY: shoulder.y,
      wristAnkleDist: wristAnkleDist,
      chestLift: chestLift,
      thighLiftRelative: thighLiftRelative,
      kneeAngle: kneeAngle,
      bowPoseState: bowPoseState,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    _updateStateMachine(ctx, now);

    // Chốt Rep
    if (bowPoseState == BowPoseState.prone &&
        previousState == BowPoseState.descending) {
      repCount += 1;

      for (final metric in _metrics) {
        metric.evaluateRep(ctx);
      }

      final allFaults = <FaultRecord>[];
      for (final metric in _metrics) allFaults.addAll(metric.faults);

      correctForm = !allFaults.any((f) => f.affectsForm);
      lastRepWasClean = correctForm;
      lastRepTopVoiceMessage = _topVoiceMessage(allFaults);

      final faultMap = <String, Map<String, String>>{};
      for (final fault in allFaults) {
        if (!faultMap.containsKey(fault.phase)) {
          faultMap[fault.phase] = {};
        }
        faultMap[fault.phase]![fault.type] = fault.message;
      }
      setFeedback.add({correctForm: faultMap});

      logger.addRepLog(RepLog(
        correctForm: correctForm,
        repNumber: repCount,
        data: {
          "hold_time": holdDurationMetric.currentHoldSeconds,
          "fault_types": allFaults.map((f) => f.type).toSet().toList(),
        },
      ));

      for (final metric in _metrics) metric.resetAndCountFault();
      _holdSeconds.resetTick();
      _stateDebouncer.reset();
      previousState = bowPoseState;
      return;
    }

    if (bowPoseState != BowPoseState.prone) {
      for (final metric in _metrics) metric.update(ctx);
    }
    if (bowPoseState == BowPoseState.hold) {
      _holdSeconds.accumulate(
        elapsedMs: elapsedMs,
        faultingByKey: {
          'connection_seconds': connectionMetric.isFaultingNow,
          'lift_form_seconds': liftFormMetric.isFaultingNow,
        },
      );
    } else {
      _holdSeconds.resetTick();
    }
    for (final metric in _metrics) debugData.addAll(metric.debugData);

    // UI Coaching State
    if (bowPoseState == BowPoseState.setup)
      resultIssues.setPhaseStatus('setup', 'Gập gối');
    else if (bowPoseState == BowPoseState.ascending)
      resultIssues.setPhaseStatus('ascending', 'Lên cung');
    else if (bowPoseState == BowPoseState.hold)
      resultIssues.setPhaseStatus('hold', 'Giữ tĩnh');
    else if (bowPoseState == BowPoseState.descending)
      resultIssues.setPhaseStatus('descending', 'Hạ xuống');
  }

  void _updateStateMachine(RepContext ctx, int now) {
    BowPoseState targetState = bowPoseState;

    if (bowPoseState == BowPoseState.prone) {
      _baselineShoulderY = ctx.rawShoulderY;
      if (ctx.kneeAngle < BowPoseConfig.KNEE_SETUP_ANGLE) {
        targetState = BowPoseState.setup;
      }
    } else if (bowPoseState == BowPoseState.setup) {
      bool grabbed = ctx.wristAnkleDist < ConnectionConfig.GRAB_THRESHOLD;
      bool shoulderRising = ctx.rawShoulderY <
          (_baselineShoulderY - (ctx.referenceLength * 0.02));

      if (grabbed && shoulderRising) {
        targetState = BowPoseState.ascending;
      }
    } else if (bowPoseState == BowPoseState.ascending &&
        ctx.chestLift > BowPoseConfig.CHEST_LIFT_THRESHOLD &&
        ctx.thighLiftRelative > BowPoseConfig.THIGH_LIFT_THRESHOLD) {
      targetState = BowPoseState.hold;
    } else if (bowPoseState == BowPoseState.hold &&
        (ctx.chestLift < 0.05 ||
            ctx.wristAnkleDist > BowPoseConfig.RELEASE_DIST_THRESHOLD)) {
      targetState = BowPoseState.descending;
    } else if (bowPoseState == BowPoseState.descending &&
        ctx.kneeAngle > 150.0) {
      targetState = BowPoseState.prone;
    }

    if (targetState != bowPoseState) {
      if (_stateDebouncer.update(true)) {
        _transitionState(targetState, now);
      }
    } else {
      _stateDebouncer.reset();
    }
  }

  void _transitionState(BowPoseState newState, int timestampMs) {
    previousState = bowPoseState;
    bowPoseState = newState;

    if (newState == BowPoseState.setup) resultIssues.phaseStatus.clear();
    if (newState == BowPoseState.hold || previousState == BowPoseState.hold) {
      _holdSeconds.resetTick();
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousState, newState, timestampMs);
    }
  }

  String? _topVoiceMessage(List<FaultRecord> faults) {
    final types = faults.map((fault) => fault.type).toSet();
    final messages = faults.map((fault) => fault.message).join(' ');
    final voices = faults.map((fault) => fault.voiceMessage ?? '').join(' ');

    if (types.contains('Connection') || voices.contains('cổ chân')) {
      return 'Nắm chân chắc hơn';
    }
    if (types.contains('HoldDuration') || messages.contains('Giữ quá ngắn')) {
      return 'Giữ lâu hơn một chút';
    }
    if (messages.contains('Ngực') || voices.contains('Ưỡn ngực')) {
      return 'Mở ngực thêm một chút';
    }
    if (messages.contains('Đùi') || voices.contains('đùi')) {
      return 'Nâng đùi cao hơn nếu lưng vẫn thoải mái';
    }
    if (types.contains('Stability')) {
      return 'Giữ người yên hơn';
    }

    return null;
  }
}
