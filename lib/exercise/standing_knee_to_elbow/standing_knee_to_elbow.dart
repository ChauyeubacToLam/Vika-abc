import 'package:vika/exercise/exercise_base.dart';
import '../../pose/vika_image_orientation.dart';
import '../../utils/pose_math_helpers.dart';
import 'package:vika/utils/exercise_logger.dart';
import 'package:vika/exercise/side_tracked_exercise_mixin.dart';

import '../../utils/frame_snapshot.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'metrics/standing_kte_metric_base.dart';
import 'metrics/knee_valgus_metric.dart';
import 'metrics/core_drive_metric.dart';
import 'metrics/cross_rom_metric.dart';
import 'metrics/pelvic_drop_metric.dart';

enum KteState { standing_base, approaching, touch, returning }

class StandingKneeToElbowConfig {
  static const int MAX_REP = 30; // 15 per side
}

class StandingKneeToElbow extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.portrait,
      };

  final int maxRep;
  StandingKneeToElbow({this.maxRep = StandingKneeToElbowConfig.MAX_REP});

  KteState kteState = KteState.standing_base;
  KteState previousKteState = KteState.standing_base;

  // Track legs dynamically
  TrackedSide _liftingLegSide = TrackedSide.left;
  TrackedSide _standingLegSide = TrackedSide.right;

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
    logger.pushKey("knee_valgus_fails", kneeValgusMetric.faultsCount);
    logger.pushKey("core_drive_fails", coreDriveMetric.faultsCount);
    logger.pushKey("cross_rom_fails", crossRomMetric.faultsCount);
    logger.pushKey("pelvic_drop_fails", pelvicDropMetric.faultsCount);
    logger.pushGoodRepCount();
    logger.pushKey("max_rep", maxRep);
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.front) {
      return "⚠️ Bài tập này yêu cầu góc máy chính diện (Front Camera).";
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
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];

    if (leftHip == null || rightHip == null || leftKnee == null || rightKnee == null || 
        leftAnkle == null || rightAnkle == null || leftShoulder == null || rightShoulder == null ||
        leftWrist == null || rightWrist == null) {
      return false;
    }

    double leftLegAngle = calculateAngleNormalized(firstPoint: leftHip, midPoint: leftKnee, lastPoint: leftAnkle);
    double rightLegAngle = calculateAngleNormalized(firstPoint: rightHip, midPoint: rightKnee, lastPoint: rightAnkle);

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

    if (leftWrist.y > leftShoulder.y + torsoLength * 0.1 || rightWrist.y > rightShoulder.y + torsoLength * 0.1) {
      resultIssues.feedback['System'] = 'Hãy đặt 2 tay sau đầu.';
      return false;
    }

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

    if (leftHip == null || rightHip == null || leftKnee == null || rightKnee == null || 
        leftAnkle == null || rightAnkle == null || leftShoulder == null || rightShoulder == null ||
        leftElbow == null || rightElbow == null) {
      return;
    }

    int now = frameTimestampMs;
    
    // Dynamic Leg Detection based on Knee Y movement
    double leftKneeY = leftKnee.y;
    double rightKneeY = rightKnee.y;

    frameBuffer.addFrame(FrameSnapshot(log: {
      "leftKneeY": leftKneeY,
      "rightKneeY": rightKneeY,
    }, timeStamp: now));

    if (kteState == KteState.standing_base) {
      // Fast movement: check if knee is significantly lifted relative to torso length
      double torsoLength = (leftShoulder.y - leftHip.y).abs();
      if (leftKneeY < rightKneeY - torsoLength * 0.15) {
        _liftingLegSide = TrackedSide.left;
        _standingLegSide = TrackedSide.right;
      } else if (rightKneeY < leftKneeY - torsoLength * 0.15) {
        _liftingLegSide = TrackedSide.right;
        _standingLegSide = TrackedSide.left;
      }
    }

    PoseLandmark liftingKnee = _liftingLegSide == TrackedSide.left ? leftKnee : rightKnee;
    PoseLandmark opposingElbow = _liftingLegSide == TrackedSide.left ? rightElbow : leftElbow;
    
    PoseLandmark liftingHip = _liftingLegSide == TrackedSide.left ? leftHip : rightHip;
    PoseLandmark standingHip = _standingLegSide == TrackedSide.left ? leftHip : rightHip;
    
    PoseLandmark liftingShoulder = _liftingLegSide == TrackedSide.left ? leftShoulder : rightShoulder;
    
    PoseLandmark standingKnee = _standingLegSide == TrackedSide.left ? leftKnee : rightKnee;
    PoseLandmark standingAnkle = _standingLegSide == TrackedSide.left ? leftAnkle : rightAnkle;

    double hipWidth = (leftHip.x - rightHip.x).abs();
    double torsoLength = (leftShoulder.y - leftHip.y).abs(); // Approx torso length
    double distanceD = calculateDistance(opposingElbow, liftingKnee);

    frameBuffer.addFrame(FrameSnapshot(log: {
      "distanceD": distanceD,
    }, timeStamp: now));

    _updateStateMachine(distanceD, liftingKnee.y, standingKnee.y, torsoLength, now);

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

    if (kteState != KteState.standing_base) {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
    }

    debugData['kteState'] = kteState.name;
    debugData['liftingLeg'] = _liftingLegSide.name;
    debugData['distanceD'] = distanceD;
    
    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }

    if (kteState == KteState.approaching) {
      resultIssues.addInstruction('approaching', 'Status', 'Kéo chéo!');
    } else if (kteState == KteState.touch) {
      resultIssues.addInstruction('touch', 'Status', 'Chạm!');
    } else if (kteState == KteState.returning) {
      resultIssues.addInstruction('returning', 'Status', 'Thu chân');
    }
  }

  void _updateStateMachine(double distanceD, double liftingKneeY, double standingKneeY, double torsoLength, int now) {
    if (kteState == KteState.standing_base) {
      if (liftingKneeY < standingKneeY - torsoLength * 0.15) {
        _transitionState(KteState.approaching, now);
      }
    } else if (kteState == KteState.approaching) {
      // Relaxed entry threshold from 0.6 to 0.85
      if (distanceD < torsoLength * 0.85) {
        _transitionState(KteState.touch, now);
      } else if (liftingKneeY > standingKneeY - torsoLength * 0.1) {
        // Returned early without reaching touch distance
        _transitionState(KteState.standing_base, now);
      }
    } else if (kteState == KteState.touch) {
      // Relaxed exit threshold from 0.8 to 1.0 to give time to reach peak
      if (distanceD > torsoLength * 1.0 || liftingKneeY > standingKneeY - torsoLength * 0.2) {
        _transitionState(KteState.returning, now);
      }
    } else if (kteState == KteState.returning) {
      // Check if lifting knee returned back to normal level
      if (liftingKneeY > standingKneeY - torsoLength * 0.1) {
        _completeRep();
        _transitionState(KteState.standing_base, now);
      }
    }
  }

  void _transitionState(KteState newState, int timestampMs) {
    if (newState == kteState) return;
    
    previousKteState = kteState;
    kteState = newState;

    if (newState == KteState.approaching && previousKteState == KteState.standing_base) {
      resultIssues.instructions.clear();
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

    logger.addRepLog(RepLog(correctForm: correctForm, repNumber: repCount, data: {
      "fault_types": allFaults.map((f) => f.type).toSet().toList(),
    }));

    correctForm = true;
    for (final metric in _metrics) {
      metric.resetAndCountFault();
    }
  }
}
