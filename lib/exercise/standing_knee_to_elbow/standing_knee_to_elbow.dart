import 'package:vika/exercise/exercise_base.dart';
import '../../utils/pose_math_helpers.dart';
import 'package:vika/utils/exercise_logger.dart';
import 'package:vika/exercise/side_tracked_exercise_mixin.dart';
import 'package:vika/utils/debouncer.dart';

import '../../utils/frame_snapshot.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'metrics/standing_kte_metric_base.dart';
import 'metrics/knee_valgus_metric.dart';
import 'metrics/core_drive_metric.dart';
import 'metrics/cross_rom_metric.dart';
import 'metrics/pelvic_drop_metric.dart';
import '../../voice/policy_voice_coach.dart';
import '../../voice/voice_coach.dart';
import '../../voice/voice_content.dart';
import '../../voice/voice_policy.dart';
import '../../voice/voice_sink.dart';

enum KteState { standing_base, approaching, touch, returning }

class StandingKneeToElbowConfig {
  static const int MAX_REP = 30; // 15 per side
  static const double KNEE_LIFT_START_RATIO = 0.12;
  static const double RETURN_KNEE_RATIO = 0.10;
  static const double TOUCH_EXIT_KNEE_RATIO = 0.22;
  static const double MIN_CROSS_DISTANCE_REDUCTION_RATIO = 0.20;
  static const double MIN_CROSS_X_REDUCTION_RATIO = 0.08;
  static const double TOUCH_RELEASE_DISTANCE_RATIO = 0.08;
  static const int MIN_APPROACH_MS = 120;
  static const int MIN_TOUCH_MS = 120;
  static const int MIN_REP_CYCLE_MS = 500;
}

class StandingKneeToElbow extends ExerciseBase {
  static const List<String> _voiceFaultIds = [
    'core_drive',
    'knee_valgus',
    'pelvic_drop',
  ];

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.portrait,
      };

  final int maxRep;
  StandingKneeToElbow({this.maxRep = StandingKneeToElbowConfig.MAX_REP})
      : super(targetReps: maxRep);

  KteState kteState = KteState.standing_base;
  KteState previousKteState = KteState.standing_base;

  // Track legs dynamically
  TrackedSide _liftingLegSide = TrackedSide.left;
  TrackedSide _standingLegSide = TrackedSide.right;
  int? _attemptStartedAtMs;
  int _stateEnteredAtMs = 0;
  bool _baseReady = true;
  double? _leftBaseCrossDistance;
  double? _rightBaseCrossDistance;
  double? _leftBaseCrossXGap;
  double? _rightBaseCrossXGap;
  double? _attemptBaselineDistance;
  double? _attemptBaselineXGap;
  double _minAttemptDistance = double.infinity;

  final Debouncer _approachDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _touchDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _returnDebouncer = Debouncer(requiredFrames: 3);
  final Debouncer _baseDebouncer = Debouncer(requiredFrames: 4);

  // Metrics
  final KneeValgusMetric kneeValgusMetric = KneeValgusMetric();
  final CoreDriveMetric coreDriveMetric = CoreDriveMetric();
  final CrossRomMetric crossRomMetric = CrossRomMetric();
  final PelvicDropMetric pelvicDropMetric = PelvicDropMetric();

  late final List<StandingKteMetricBase> _metrics = [
    kneeValgusMetric,
    coreDriveMetric,
    crossRomMetric,
    pelvicDropMetric,
  ];

  @override
  String get exerciseName => 'Standing Knee-to-Elbow';

  @override
  List<FaultRecord> get liveFaults =>
      [for (final metric in _metrics) ...metric.faults];

  @override
  ExerciseVoiceCoach createVoiceCoach() {
    return PolicyVoiceCoach(
      script: VoiceScript.from(
        VoiceDefaults.repBased,
        slug: 'standing_kte',
        faultIds: _voiceFaultIds,
        reminderPools: const {
          'core_drive': ['standing_kte.core_drive_reminder'],
        },
        repStartPhaseKeys: const {'approaching'},
      ),
      targetReps: targetReps,
      coach: VoiceCoach(
        sink: AssetVoiceSink(),
        policy: VoicePolicy(),
      ),
    );
  }

  @override
  String get currentPhaseKey => kteState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (kteState) {
      case KteState.standing_base:
        return 'Đứng thẳng';
      case KteState.approaching:
        return 'Kéo lên';
      case KteState.touch:
        return 'Chạm';
      case KteState.returning:
        return 'Thu về';
    }
  }

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey("knee_valgus_fails_count", kneeValgusMetric.faultsCount);
    logger.pushKey("core_drive_fails_count", coreDriveMetric.faultsCount);
    logger.pushKey("cross_rom_fails_count", crossRomMetric.faultsCount);
    logger.pushKey("pelvic_drop_fails_count", pelvicDropMetric.faultsCount);
    logger.pushGoodRepCount();
    logger.pushKey("max_rep", maxRep);
  }

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.front) {
      return const GuidanceSignal.faceCamera();
    }
    return null; // The strict safety gate for vestibular/knee issues should be done in UI, but this text is a fallback.
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.front) return false;

    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];

    if (leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null ||
        leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null) {
      return false;
    }

    double leftLegAngle = calculateAngleNormalized(
        firstPoint: leftHip, midPoint: leftKnee, lastPoint: leftAnkle);
    double rightLegAngle = calculateAngleNormalized(
        firstPoint: rightHip, midPoint: rightKnee, lastPoint: rightAnkle);

    if (leftLegAngle < 165.0 || rightLegAngle < 165.0) {
      resultIssues.feedback['System'] = 'Hãy đứng thẳng cả 2 chân.';
      return false;
    }

    double shoulderTilt = (leftShoulder.y - rightShoulder.y).abs();
    double shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    double torsoLength = (leftShoulder.y - leftHip.y).abs();

    // Check if shoulders are roughly level (tilt < 10% of width)
    if (shoulderWidth > 0 && shoulderTilt / shoulderWidth > 0.15) {
      resultIssues.feedback['System'] = 'Giữ 2 vai thăng bằng.';
      return false;
    }

    if (leftElbow.y > leftShoulder.y + torsoLength * 0.35 ||
        rightElbow.y > rightShoulder.y + torsoLength * 0.35) {
      resultIssues.feedback['System'] = 'Nâng hai khuỷu tay lên gần ngang vai.';
      return false;
    }

    _leftBaseCrossDistance = calculateDistance(leftKnee, rightElbow);
    _rightBaseCrossDistance = calculateDistance(rightKnee, leftElbow);
    _leftBaseCrossXGap = (leftKnee.x - rightElbow.x).abs();
    _rightBaseCrossXGap = (rightKnee.x - leftElbow.x).abs();

    return true;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final leftHip = smoothedLandmarks[PoseLandmarkType.leftHip];
    final rightHip = smoothedLandmarks[PoseLandmarkType.rightHip];
    final leftKnee = smoothedLandmarks[PoseLandmarkType.leftKnee];
    final rightKnee = smoothedLandmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = smoothedLandmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = smoothedLandmarks[PoseLandmarkType.rightAnkle];
    final leftShoulder = smoothedLandmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = smoothedLandmarks[PoseLandmarkType.rightShoulder];
    final leftElbow = smoothedLandmarks[PoseLandmarkType.leftElbow];
    final rightElbow = smoothedLandmarks[PoseLandmarkType.rightElbow];

    if (leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null ||
        leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null) {
      return;
    }
    if (![
      leftHip,
      rightHip,
      leftKnee,
      rightKnee,
      leftAnkle,
      rightAnkle,
      leftShoulder,
      rightShoulder,
      leftElbow,
      rightElbow,
    ].every(ExerciseBase.isLandmarkConfident)) {
      return;
    }

    int now = frameTimestampMs;

    final hipWidth = (leftHip.x - rightHip.x).abs();
    final torsoLength = (leftShoulder.y - leftHip.y).abs();

    // Activation gives us several seconds in the standing setup. Preserve the
    // cross-body elbow-to-knee geometry from that base pose, then qualify a
    // touch by how much the X/Y distance closes instead of requiring two noisy
    // landmarks to hit one absolute threshold.
    final kneesAtBase = torsoLength > 0 &&
        (leftKnee.y - rightKnee.y).abs() <=
            torsoLength * StandingKneeToElbowConfig.RETURN_KNEE_RATIO;
    if (kteState == KteState.standing_base && kneesAtBase) {
      _leftBaseCrossDistance = calculateDistance(leftKnee, rightElbow);
      _rightBaseCrossDistance = calculateDistance(rightKnee, leftElbow);
      _leftBaseCrossXGap = (leftKnee.x - rightElbow.x).abs();
      _rightBaseCrossXGap = (rightKnee.x - leftElbow.x).abs();
    }

    // Dynamic Leg Detection based on Knee Y movement
    double leftKneeY = leftKnee.y;
    double rightKneeY = rightKnee.y;

    frameBuffer.addFrame(FrameSnapshot(log: {
      "leftKneeY": leftKneeY,
      "rightKneeY": rightKneeY,
    }, timeStamp: now));

    if (kteState == KteState.standing_base) {
      final torsoLengthForSide = (leftShoulder.y - leftHip.y).abs();
      final leftLiftRatio = torsoLengthForSide <= 0
          ? 0.0
          : (rightKneeY - leftKneeY) / torsoLengthForSide;
      final rightLiftRatio = torsoLengthForSide <= 0
          ? 0.0
          : (leftKneeY - rightKneeY) / torsoLengthForSide;

      if (leftLiftRatio > StandingKneeToElbowConfig.KNEE_LIFT_START_RATIO &&
          leftLiftRatio >= rightLiftRatio) {
        _liftingLegSide = TrackedSide.left;
        _standingLegSide = TrackedSide.right;
      } else if (rightLiftRatio >
          StandingKneeToElbowConfig.KNEE_LIFT_START_RATIO) {
        _liftingLegSide = TrackedSide.right;
        _standingLegSide = TrackedSide.left;
      }
    }

    PoseLandmark liftingKnee =
        _liftingLegSide == TrackedSide.left ? leftKnee : rightKnee;
    PoseLandmark opposingElbow =
        _liftingLegSide == TrackedSide.left ? rightElbow : leftElbow;

    PoseLandmark liftingHip =
        _liftingLegSide == TrackedSide.left ? leftHip : rightHip;
    PoseLandmark standingHip =
        _standingLegSide == TrackedSide.left ? leftHip : rightHip;

    PoseLandmark liftingShoulder =
        _liftingLegSide == TrackedSide.left ? leftShoulder : rightShoulder;

    PoseLandmark standingKnee =
        _standingLegSide == TrackedSide.left ? leftKnee : rightKnee;
    PoseLandmark standingAnkle =
        _standingLegSide == TrackedSide.left ? leftAnkle : rightAnkle;

    double distanceD = calculateDistance(opposingElbow, liftingKnee);
    final crossXGap = (opposingElbow.x - liftingKnee.x).abs();
    final baselineDistance = _liftingLegSide == TrackedSide.left
        ? _leftBaseCrossDistance
        : _rightBaseCrossDistance;
    final baselineXGap = _liftingLegSide == TrackedSide.left
        ? _leftBaseCrossXGap
        : _rightBaseCrossXGap;

    frameBuffer.addFrame(FrameSnapshot(log: {
      "distanceD": distanceD,
    }, timeStamp: now));

    _updateStateMachine(
      distanceD,
      crossXGap,
      baselineDistance,
      baselineXGap,
      liftingKnee.y,
      standingKnee.y,
      torsoLength,
      now,
    );

    final ctx = StandingKteRepContext(
      standingLegSide: _standingLegSide,
      standingKnee: standingKnee,
      standingAnkle: standingAnkle,
      liftingKnee: liftingKnee,
      standingHip: standingHip,
      liftingHip: liftingHip,
      liftingShoulder: liftingShoulder,
      opposingElbow: opposingElbow,
      hipWidth: hipWidth,
      torsoLength: torsoLength,
      distanceD: distanceD,
      state: kteState,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    if (kteState == KteState.standing_base) {
      coreDriveMetric.update(ctx);
    } else {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
    }

    debugData['kteState'] = kteState.name;
    debugData['liftingLeg'] = _liftingLegSide.name;
    debugData['distanceD'] = distanceD;
    debugData['crossDistanceReduction'] = _attemptBaselineDistance == null
        ? 0.0
        : _attemptBaselineDistance! - distanceD;
    debugData['crossXReduction'] =
        _attemptBaselineXGap == null ? 0.0 : _attemptBaselineXGap! - crossXGap;

    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }

    if (kteState == KteState.approaching) {
      resultIssues.setPhaseStatus('approaching', 'Kéo chéo!');
    } else if (kteState == KteState.touch) {
      resultIssues.setPhaseStatus('touch', 'Chạm!');
    } else if (kteState == KteState.returning) {
      resultIssues.setPhaseStatus('returning', 'Thu chân');
    }
  }

  void _updateStateMachine(
    double distanceD,
    double crossXGap,
    double? baselineDistance,
    double? baselineXGap,
    double liftingKneeY,
    double standingKneeY,
    double torsoLength,
    int now,
  ) {
    final kneeLifted = liftingKneeY <
        standingKneeY -
            torsoLength * StandingKneeToElbowConfig.KNEE_LIFT_START_RATIO;
    if (kteState == KteState.standing_base) {
      if (!_baseReady) {
        _baseReady = _baseDebouncer.update(
          (liftingKneeY - standingKneeY).abs() <= torsoLength * 0.10,
        );
        _approachDebouncer.update(false);
        return;
      }
      if (_approachDebouncer.update(kneeLifted)) {
        _attemptStartedAtMs = now;
        _attemptBaselineDistance = baselineDistance;
        _attemptBaselineXGap = baselineXGap;
        _minAttemptDistance = distanceD;
        _transitionState(KteState.approaching, now);
      }
    } else if (kteState == KteState.approaching) {
      if (distanceD < _minAttemptDistance) {
        _minAttemptDistance = distanceD;
      }
      final approachOldEnough =
          now - _stateEnteredAtMs >= StandingKneeToElbowConfig.MIN_APPROACH_MS;
      final distanceReduction =
          (_attemptBaselineDistance ?? distanceD) - distanceD;
      final crossXReduction = (_attemptBaselineXGap ?? crossXGap) - crossXGap;
      final hasClearCrossApproach = distanceReduction >=
              torsoLength *
                  StandingKneeToElbowConfig
                      .MIN_CROSS_DISTANCE_REDUCTION_RATIO &&
          crossXReduction >=
              torsoLength *
                  StandingKneeToElbowConfig.MIN_CROSS_X_REDUCTION_RATIO;
      if (_touchDebouncer
          .update(approachOldEnough && kneeLifted && hasClearCrossApproach)) {
        _transitionState(KteState.touch, now);
      } else if (liftingKneeY >
              standingKneeY -
                  torsoLength * StandingKneeToElbowConfig.RETURN_KNEE_RATIO &&
          !hasClearCrossApproach) {
        // Returned early without reaching touch distance
        _cancelAttempt(now);
      }
    } else if (kteState == KteState.touch) {
      if (distanceD < _minAttemptDistance) {
        _minAttemptDistance = distanceD;
      }
      final touchOldEnough =
          now - _stateEnteredAtMs >= StandingKneeToElbowConfig.MIN_TOUCH_MS;
      if (touchOldEnough &&
          (distanceD >
                  _minAttemptDistance +
                      torsoLength *
                          StandingKneeToElbowConfig
                              .TOUCH_RELEASE_DISTANCE_RATIO ||
              liftingKneeY >
                  standingKneeY -
                      torsoLength *
                          StandingKneeToElbowConfig.TOUCH_EXIT_KNEE_RATIO)) {
        _transitionState(KteState.returning, now);
      }
    } else if (kteState == KteState.returning) {
      final returnedToBase = liftingKneeY >
          standingKneeY -
              torsoLength * StandingKneeToElbowConfig.RETURN_KNEE_RATIO;
      if (_returnDebouncer.update(returnedToBase)) {
        final cycleMs = now - (_attemptStartedAtMs ?? now);
        if (cycleMs >= StandingKneeToElbowConfig.MIN_REP_CYCLE_MS) {
          _completeRep();
        }
        _baseReady = false;
        _attemptStartedAtMs = null;
        _transitionState(KteState.standing_base, now);
      }
    }
  }

  void _cancelAttempt(int now) {
    _attemptStartedAtMs = null;
    _attemptBaselineDistance = null;
    _attemptBaselineXGap = null;
    _minAttemptDistance = double.infinity;
    _baseReady = false;
    resultIssues.feedback['Result'] = 'Không tính rep';
    resultIssues.feedback['CrossRom'] =
        'Đưa gối chạm khuỷu tay đối diện trước khi hạ chân.';
    for (final metric in _metrics) {
      metric.reset();
    }
    _transitionState(KteState.standing_base, now);
  }

  void _transitionState(KteState newState, int timestampMs) {
    if (newState == kteState) return;

    previousKteState = kteState;
    kteState = newState;
    _stateEnteredAtMs = timestampMs;

    if (newState == KteState.approaching &&
        previousKteState == KteState.standing_base) {
      resultIssues.phaseStatus.clear();
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousKteState, newState, timestampMs);
    }
  }

  void _completeRep() {
    repCount++;

    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      allFaults.addAll(metric.faults);
    }

    correctForm = !allFaults.any((f) => f.affectsForm);
    resultIssues.feedback['Result'] = correctForm ? 'Good Rep!' : 'Fix Form';

    final faultMap = <String, Map<String, String>>{};
    for (final fault in allFaults) {
      faultMap.putIfAbsent(fault.phase, () => {});
      faultMap[fault.phase]![fault.type] = fault.message;
    }

    setFeedback.add({correctForm: faultMap});

    final faultAffectsForm = <String, bool>{};
    final faultPriorities = <String, int>{};
    for (final fault in allFaults) {
      faultAffectsForm[fault.type] =
          (faultAffectsForm[fault.type] ?? false) || fault.affectsForm;
      final previousPriority = faultPriorities[fault.type];
      if (previousPriority == null || fault.priority < previousPriority) {
        faultPriorities[fault.type] = fault.priority;
      }
    }

    logger
        .addRepLog(RepLog(correctForm: correctForm, repNumber: repCount, data: {
      "fault_types": allFaults.map((f) => f.type).toSet().toList(),
      "fault_affects_form": faultAffectsForm,
      "fault_priorities": faultPriorities,
    }));

    correctForm = true;
    _attemptBaselineDistance = null;
    _attemptBaselineXGap = null;
    _minAttemptDistance = double.infinity;
    for (final metric in _metrics) {
      metric.resetAndCountFault();
    }
  }
}
