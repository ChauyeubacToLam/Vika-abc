import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/utils/exercise_logger.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/frame_buffer.dart';
import '../../utils/frame_snapshot.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'metrics/cossack_metric_base.dart';
import 'metrics/knee_valgus_metric.dart';
import 'metrics/heel_lift_metric.dart';
import 'metrics/working_depth_metric.dart';
import 'metrics/straight_leg_metric.dart';
import 'metrics/torso_verticality_metric.dart';
import '../../voice/policy_voice_coach.dart';
import '../../voice/voice_coach.dart';
import '../../voice/voice_content.dart';
import '../../voice/voice_policy.dart';
import '../../voice/voice_sink.dart';

enum CossackState { standing, descending, bottom, ascending }

enum WorkingLeg { none, left, right }

class CossackConfig {
  static const double STANDING_HIP_VELOCITY_Y_THRESHOLD = 0.01;
  static const double BOTTOM_KNEE_ANGLE_THRESHOLD =
      110.0; // Angle to consider bottom
  static const double STANDING_KNEE_ANGLE_THRESHOLD = 150.0;
  static const double CLEAN_REP_LEFT_KNEE_ANGLE = 172.1;
  static const double CLEAN_REP_LEFT_KNEE_TOLERANCE = 12.0;
  static const double CLEAN_REP_RIGHT_KNEE_ANGLE = 179.6;
  static const double CLEAN_REP_RIGHT_KNEE_TOLERANCE = 12.0;
  static const double CLEAN_REP_TORSO_ANGLE = 329.3;
  static const double CLEAN_REP_TORSO_TOLERANCE = 18.0;
  static const double CLEAN_REP_KNEE_VALGUS_NORM = 0.160;
  static const double CLEAN_REP_KNEE_VALGUS_NORM_TOLERANCE = 0.12;
}

class CossackSquat extends ExerciseBase {
  static const List<String> _voiceFaultIds = [
    'heel',
    'knee_valgus',
    'straight_leg',
    'torso',
    'depth_deep',
    'depth_shallow',
  ];

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.portrait,
      };

  final int maxRep;
  CossackSquat({required this.maxRep}) : super(targetReps: maxRep);

  CossackState cossackState = CossackState.standing;
  CossackState previousCossackState = CossackState.standing;
  bool _reachedBottomThisRep = false;
  int _rejectedShallowAttempts = 0;

  WorkingLeg currentWorkingLeg = WorkingLeg.none;

  // Metrics
  final CossackKneeValgusMetric kneeValgusMetric = CossackKneeValgusMetric();
  final CossackHeelLiftMetric heelLiftMetric = CossackHeelLiftMetric();
  final CossackWorkingDepthMetric depthMetric = CossackWorkingDepthMetric();
  final CossackStraightLegMetric straightLegMetric = CossackStraightLegMetric();
  final CossackTorsoVerticalityMetric torsoMetric =
      CossackTorsoVerticalityMetric();

  late final List<CossackMetricBase> _metrics = [
    kneeValgusMetric,
    heelLiftMetric,
    depthMetric,
    straightLegMetric,
    torsoMetric,
  ];

  @override
  String get exerciseName => 'Cossack Squat';

  @override
  List<FaultRecord> get liveFaults =>
      [for (final metric in _metrics) ...metric.faults];

  @override
  ExerciseVoiceCoach createVoiceCoach() {
    return PolicyVoiceCoach(
      script: VoiceScript.from(
        VoiceDefaults.repBased,
        slug: 'cossack_squat',
        faultIds: _voiceFaultIds,
      ),
      targetReps: targetReps,
      coach: VoiceCoach(
        sink: AssetVoiceSink(),
        policy: VoicePolicy(),
      ),
    );
  }

  @override
  String get currentPhaseKey => cossackState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (cossackState) {
      case CossackState.standing:
        return 'Đứng thẳng';
      case CossackState.descending:
        return 'Xuống';
      case CossackState.bottom:
        return 'Giữ';
      case CossackState.ascending:
        return 'Đứng lên';
    }
  }

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey("knee_valgus_fails_count", kneeValgusMetric.faultsCount);
    logger.pushKey("heel_lift_fails_count", heelLiftMetric.faultsCount);
    logger.pushKey("depth_fails_count", depthMetric.faultsCount);
    logger.pushKey("straight_leg_fails_count", straightLegMetric.faultsCount);
    logger.pushKey("torso_lean_fails_count", torsoMetric.faultsCount);
    logger.pushGoodRepCount();
    logger.pushKey("max_rep", maxRep);
  }

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.front) {
      return const GuidanceSignal.faceCamera();
    }

    final requiredTypes = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.leftFootIndex,
      PoseLandmarkType.rightFootIndex,
    ];

    for (var type in requiredTypes) {
      final lm = landmarks[type];
      if (lm == null || !ExerciseBase.isLandmarkConfident(lm)) {
        return const GuidanceSignal.bodyInFrame();
      }
    }
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.front) return false;

    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];

    if (leftAnkle == null ||
        rightAnkle == null ||
        leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null) {
      return false;
    }

    final ankleDistance = (leftAnkle.x - rightAnkle.x).abs();
    final shoulderDistance = (leftShoulder.x - rightShoulder.x).abs();

    // Stance must be very wide (> 1.5x shoulder width)
    if (ankleDistance < shoulderDistance * 1.5) {
      resultIssues.feedback['System'] =
          'Hãy bước 2 chân rộng hơn nữa (gấp 1.5 - 2 lần vai).';
      return false;
    }

    // Both legs must be straight (> 170 degrees)
    final leftLegAngle = calculateAngleNormalized(
        firstPoint: leftHip, midPoint: leftKnee, lastPoint: leftAnkle);
    final rightLegAngle = calculateAngleNormalized(
        firstPoint: rightHip, midPoint: rightKnee, lastPoint: rightAnkle);

    if (leftLegAngle < 165.0 || rightLegAngle < 165.0) {
      // Slight leniency
      resultIssues.feedback['System'] = 'Hãy đứng thẳng cả hai chân.';
      return false;
    }

    return true;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final leftHip = smoothedLandmarks[PoseLandmarkType.leftHip]!;
    final rightHip = smoothedLandmarks[PoseLandmarkType.rightHip]!;
    final leftKnee = smoothedLandmarks[PoseLandmarkType.leftKnee]!;
    final rightKnee = smoothedLandmarks[PoseLandmarkType.rightKnee]!;
    final leftAnkle = smoothedLandmarks[PoseLandmarkType.leftAnkle]!;
    final rightAnkle = smoothedLandmarks[PoseLandmarkType.rightAnkle]!;
    final leftShoulder = smoothedLandmarks[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = smoothedLandmarks[PoseLandmarkType.rightShoulder]!;
    final leftFoot = smoothedLandmarks[PoseLandmarkType.leftFootIndex]!;
    final rightFoot = smoothedLandmarks[PoseLandmarkType.rightFootIndex]!;
    final leftHeel = smoothedLandmarks[PoseLandmarkType.leftHeel];
    final rightHeel = smoothedLandmarks[PoseLandmarkType.rightHeel];

    final hipCenterX = (leftHip.x + rightHip.x) / 2;
    final hipCenterY = (leftHip.y + rightHip.y) / 2;
    final shoulderCenterX = (leftShoulder.x + rightShoulder.x) / 2;
    final shoulderCenterY = (leftShoulder.y + rightShoulder.y) / 2;
    scaleFactor = (leftShoulder.x - rightShoulder.x).abs();
    if (scaleFactor <= 1e-6) return;

    // Create a virtual mid-shoulder and mid-hip for torso angle
    final torsoAngle = calculateVerticalAngle(
        pivot: PoseLandmark(
            type: PoseLandmarkType.leftHip,
            x: hipCenterX,
            y: hipCenterY,
            z: 0,
            likelihood: 1.0),
        point: PoseLandmark(
            type: PoseLandmarkType.leftShoulder,
            x: shoulderCenterX,
            y: shoulderCenterY,
            z: 0,
            likelihood: 1.0));

    double leftKneeAngle = calculateAngleNormalized(
        firstPoint: leftHip, midPoint: leftKnee, lastPoint: leftAnkle);
    double rightKneeAngle = calculateAngleNormalized(
        firstPoint: rightHip, midPoint: rightKnee, lastPoint: rightAnkle);

    double leftHeelDist = leftHeel != null ? (leftFoot.y - leftHeel.y) : 0.0;
    double rightHeelDist =
        rightHeel != null ? (rightFoot.y - rightHeel.y) : 0.0;

    int now = frameTimestampMs;

    frameBuffer.addFrame(FrameSnapshot(log: {
      "hipY": hipCenterY,
      "hipX": hipCenterX,
      "leftKneeAngle": leftKneeAngle,
      "rightKneeAngle": rightKneeAngle,
    }, timeStamp: now));

    if (cossackState == CossackState.standing) {
      // Detect working leg if we start descending
      final angleChange = frameBuffer.getChange(
          "hipY", 3); // If hipY increases, user is going down
      if (angleChange == ChangeState.increasing) {
        // Hip is moving down. Which way is it moving horizontally?
        // Note: X coordinates are mirrored if front camera.
        // Actually, let's just use knee angles to determine working leg.
        // The leg that bends more is the working leg.
        if (leftKneeAngle < rightKneeAngle - 10) {
          currentWorkingLeg = WorkingLeg.left;
          _transitionState(CossackState.descending, now);
        } else if (rightKneeAngle < leftKneeAngle - 10) {
          currentWorkingLeg = WorkingLeg.right;
          _transitionState(CossackState.descending, now);
        }
      }
    } else {
      _updateStateMachine(leftKneeAngle, rightKneeAngle, hipCenterY, now);
    }

    if (cossackState == CossackState.standing &&
        previousCossackState != CossackState.standing) {
      if (!_reachedBottomThisRep) {
        _rejectedShallowAttempts++;
        resultIssues.feedback['Result'] = 'Không tính';
        previousCossackState = CossackState.standing;
        currentWorkingLeg = WorkingLeg.none;
        _reachedBottomThisRep = false;
        for (final metric in _metrics) {
          metric.reset();
        }
        return;
      }

      // Rep completed
      _completeRep(
        leftKneeAngle: leftKneeAngle,
        rightKneeAngle: rightKneeAngle,
        torsoAngle: torsoAngle,
      );
      previousCossackState = cossackState;
      _reachedBottomThisRep = false;
      return;
    }

    // Build Rep Context
    double workingKneeAngle = 180.0;
    double straightKneeAngle = 180.0;
    double workingHeelDistance = 0.0;
    double workingKneeX = 0.0;
    double workingAnkleX = 0.0;
    double workingFootIndexX = 0.0;

    if (currentWorkingLeg == WorkingLeg.left) {
      workingKneeAngle = leftKneeAngle;
      straightKneeAngle = rightKneeAngle;
      workingHeelDistance = leftHeelDist / scaleFactor;
      workingKneeX = leftKnee.x;
      workingAnkleX = leftAnkle.x;
      workingFootIndexX = leftFoot.x;
    } else if (currentWorkingLeg == WorkingLeg.right) {
      workingKneeAngle = rightKneeAngle;
      straightKneeAngle = leftKneeAngle;
      workingHeelDistance = rightHeelDist / scaleFactor;
      workingKneeX = rightKnee.x;
      workingAnkleX = rightAnkle.x;
      workingFootIndexX = rightFoot.x;
    }

    final ctx = CossackRepContext(
      workingLeg: currentWorkingLeg,
      workingKneeAngle: workingKneeAngle,
      straightKneeAngle: straightKneeAngle,
      torsoAngle: torsoAngle,
      workingHeelDistance: workingHeelDistance,
      workingKneeX: workingKneeX,
      workingAnkleX: workingAnkleX,
      workingFootIndexX: workingFootIndexX,
      scaleFactor: scaleFactor,
      state: cossackState,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    // Update metrics
    if (cossackState != CossackState.standing) {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
      _publishFaultFeedback(_metrics.expand((metric) => metric.faults));
    }

    // Debug data
    debugData['cossackState'] = cossackState.name;
    debugData['workingLeg'] = currentWorkingLeg.name;
    debugData['reachedBottomThisRep'] = _reachedBottomThisRep;
    debugData['rejectedShallowAttempts'] = _rejectedShallowAttempts;
    debugData['leftKneeAngle'] = leftKneeAngle;
    debugData['rightKneeAngle'] = rightKneeAngle;
    debugData['torsoAngle'] = torsoAngle;
    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }

    // UI Instructions
    if (cossackState == CossackState.descending) {
      resultIssues.setPhaseStatus('descending', 'Đang xuống...');
    } else if (cossackState == CossackState.bottom) {
      resultIssues.setPhaseStatus('bottom', 'Đứng lên!');
    } else if (cossackState == CossackState.ascending) {
      resultIssues.setPhaseStatus('ascending', 'Đẩy hông về giữa!');
    }
  }

  void _updateStateMachine(
      double leftKneeAngle, double rightKneeAngle, double hipY, int now) {
    double workingKneeAngle =
        currentWorkingLeg == WorkingLeg.left ? leftKneeAngle : rightKneeAngle;
    final hipYChange = frameBuffer.getChange("hipY", 3);

    if (cossackState == CossackState.descending) {
      // Reached bottom if hip stops moving down or knee is very bent
      if (workingKneeAngle <= CossackConfig.BOTTOM_KNEE_ANGLE_THRESHOLD ||
          (hipYChange == ChangeState.decreasing &&
              workingKneeAngle <=
                  CossackConfig.BOTTOM_KNEE_ANGLE_THRESHOLD + 10)) {
        _transitionState(CossackState.bottom, now);
      }
    } else if (cossackState == CossackState.bottom) {
      // Ascending if hip starts moving up
      if (hipYChange == ChangeState.increasing ||
          workingKneeAngle > CossackConfig.BOTTOM_KNEE_ANGLE_THRESHOLD + 10) {
        _transitionState(CossackState.ascending, now);
      }
    } else if (cossackState == CossackState.ascending) {
      // Standing if legs are straight again
      if (leftKneeAngle > CossackConfig.STANDING_KNEE_ANGLE_THRESHOLD &&
          rightKneeAngle > CossackConfig.STANDING_KNEE_ANGLE_THRESHOLD) {
        _transitionState(CossackState.standing, now);
      }
    }
  }

  void _transitionState(CossackState newState, int timestampMs) {
    if (newState == cossackState) return;

    previousCossackState = cossackState;
    cossackState = newState;

    if (newState == CossackState.descending &&
        previousCossackState == CossackState.standing) {
      _reachedBottomThisRep = false;
      resultIssues.phaseStatus.clear();
    } else if (newState == CossackState.bottom) {
      _reachedBottomThisRep = true;
    } else if (newState == CossackState.standing) {
      currentWorkingLeg = WorkingLeg.none;
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousCossackState, newState, timestampMs);
    }
  }

  void _completeRep({
    required double leftKneeAngle,
    required double rightKneeAngle,
    required double torsoAngle,
  }) {
    repCount++;

    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      allFaults.addAll(metric.faults);
    }

    _matchesCalibratedCleanRep(
      leftKneeAngle: leftKneeAngle,
      rightKneeAngle: rightKneeAngle,
      torsoAngle: torsoAngle,
    );

    correctForm = !allFaults.any((f) => f.affectsForm);
    resultIssues.feedback['Result'] = correctForm ? 'Good Rep!' : 'Fix Form';
    _publishFaultFeedback(allFaults);

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
    for (final metric in _metrics) {
      metric.resetAndCountFault();
    }
  }

  void _publishFaultFeedback(Iterable<FaultRecord> faults) {
    final sorted = faults.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    for (final fault in sorted) {
      final key = _feedbackKeyForFault(fault);
      final message = fault.voiceMessage ?? fault.message;
      resultIssues.feedback[key] = message;
    }
  }

  String _feedbackKeyForFault(FaultRecord fault) {
    switch (fault.type) {
      case 'heel':
        return 'heel';
      case 'knee_valgus':
        return 'knee_valgus';
      case 'straight_leg':
        return 'straight_leg';
      case 'torso':
        return 'torso';
      case 'depth_deep':
        return 'depth_deep';
      case 'depth_shallow':
        return 'depth_shallow';
      default:
        return fault.type;
    }
  }

  bool _matchesCalibratedCleanRep({
    required double leftKneeAngle,
    required double rightKneeAngle,
    required double torsoAngle,
  }) {
    final kneeValgusNorm =
        _readDebugDouble(kneeValgusMetric.debugData['kneeValgusNorm']) ?? 0.0;

    final isMatch = _reachedBottomThisRep &&
        _within(
          leftKneeAngle,
          CossackConfig.CLEAN_REP_LEFT_KNEE_ANGLE,
          CossackConfig.CLEAN_REP_LEFT_KNEE_TOLERANCE,
        ) &&
        _within(
          rightKneeAngle,
          CossackConfig.CLEAN_REP_RIGHT_KNEE_ANGLE,
          CossackConfig.CLEAN_REP_RIGHT_KNEE_TOLERANCE,
        ) &&
        _withinCircularDegrees(
          torsoAngle,
          CossackConfig.CLEAN_REP_TORSO_ANGLE,
          CossackConfig.CLEAN_REP_TORSO_TOLERANCE,
        ) &&
        _within(
          kneeValgusNorm,
          CossackConfig.CLEAN_REP_KNEE_VALGUS_NORM,
          CossackConfig.CLEAN_REP_KNEE_VALGUS_NORM_TOLERANCE,
        );

    debugData['calibratedCleanRep'] = isMatch;
    debugData['calibratedLeftKneeDelta'] =
        leftKneeAngle - CossackConfig.CLEAN_REP_LEFT_KNEE_ANGLE;
    debugData['calibratedRightKneeDelta'] =
        rightKneeAngle - CossackConfig.CLEAN_REP_RIGHT_KNEE_ANGLE;
    debugData['calibratedTorsoDelta'] = _circularDegreeDelta(
      torsoAngle,
      CossackConfig.CLEAN_REP_TORSO_ANGLE,
    );
    debugData['calibratedKneeValgusNormDelta'] =
        kneeValgusNorm - CossackConfig.CLEAN_REP_KNEE_VALGUS_NORM;

    return isMatch;
  }

  static double? _readDebugDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool _within(double value, double target, double tolerance) {
    return (value - target).abs() <= tolerance;
  }

  static bool _withinCircularDegrees(
    double value,
    double target,
    double tolerance,
  ) {
    return _circularDegreeDelta(value, target).abs() <= tolerance;
  }

  static double _circularDegreeDelta(double value, double target) {
    final normalized = ((value - target + 180) % 360) - 180;
    return normalized == -180 ? 180 : normalized;
  }
}
