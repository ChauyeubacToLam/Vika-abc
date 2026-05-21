import 'package:vika/exercise/exercise_base.dart';

import '../../utils/frame_buffer.dart';
import 'package:vika/utils/exercise_logger.dart';

import '../../utils/frame_snapshot.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'metrics/russian_metric_base.dart';
import 'metrics/thoracic_rotation_metric.dart';
import 'metrics/knee_anchoring_metric.dart';
import 'metrics/twist_rom_metric.dart';
import 'metrics/spinal_flexion_metric.dart';

enum RussianTwistState { center_setup, twisting, max_point, returning }
enum TwistDirection { none, left, right }

class RussianTwistConfig {
  static const int MAX_REP = 20; // 10 per side
  static const double WRIST_VELOCITY_THRESHOLD = 0.5; 
}

class RussianTwist extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.portrait,
      };

  final int maxRep;
  RussianTwist({this.maxRep = RussianTwistConfig.MAX_REP});

  RussianTwistState russianState = RussianTwistState.center_setup;
  RussianTwistState previousRussianState = RussianTwistState.center_setup;
  TwistDirection currentDirection = TwistDirection.none;
  int _halfRepCount = 0; // count twists, 2 twists = 1 rep

  // Metrics
  final ThoracicRotationMetric thoracicMetric = ThoracicRotationMetric();
  final KneeAnchoringMetric kneeMetric = KneeAnchoringMetric();
  final TwistRomMetric twistRomMetric = TwistRomMetric();
  final SpinalFlexionMetric spinalMetric = SpinalFlexionMetric();

  late final List<RussianMetricBase> _metrics = [
    thoracicMetric,
    kneeMetric,
    twistRomMetric,
    spinalMetric,
  ];

  @override
  String get exerciseName => 'Russian Twist';

  @override
  String get currentPhaseKey => russianState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (russianState) {
      case RussianTwistState.center_setup:
        return 'Vị trí giữa';
      case RussianTwistState.twisting:
        return 'Vặn mình';
      case RussianTwistState.max_point:
        return 'Chạm đích';
      case RussianTwistState.returning:
        return 'Quay về';
    }
  }

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey("thoracic_fails", thoracicMetric.faultsCount);
    logger.pushKey("knee_wobble_fails", kneeMetric.faultsCount);
    logger.pushKey("rom_fails", twistRomMetric.faultsCount);
    logger.pushGoodRepCount();
    logger.pushKey("max_rep", maxRep);
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.front) {
      return "⚠️ Bài tập này yêu cầu góc máy chính diện (Front Camera).";
    }
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.front) return false;
    
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];

    if (leftShoulder == null || rightShoulder == null || leftHip == null || rightHip == null) return false;

    double midShoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    double midHipY = (leftHip.y + rightHip.y) / 2;

    // Y increases downwards. Shoulder must be higher (smaller Y) than Hip
    // Add a margin to ensure they are upright or sitting
    if (midShoulderY > midHipY - 10) {
      resultIssues.feedback['System'] = 'Ngồi dậy, nâng vai cao hơn hông.';
      return false;
    }

    return true;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final leftShoulder = smoothedLandmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = smoothedLandmarks[PoseLandmarkType.rightShoulder];
    final leftHip = smoothedLandmarks[PoseLandmarkType.leftHip];
    final rightHip = smoothedLandmarks[PoseLandmarkType.rightHip];
    final leftKnee = smoothedLandmarks[PoseLandmarkType.leftKnee];
    final rightKnee = smoothedLandmarks[PoseLandmarkType.rightKnee];
    final leftWrist = smoothedLandmarks[PoseLandmarkType.leftWrist];
    final rightWrist = smoothedLandmarks[PoseLandmarkType.rightWrist];

    if (leftShoulder == null || rightShoulder == null || 
        leftHip == null || rightHip == null || 
        leftKnee == null || rightKnee == null || 
        leftWrist == null || rightWrist == null) {
      return;
    }

    double midWristX = (leftWrist.x + rightWrist.x) / 2;
    double midKneeX = (leftKnee.x + rightKnee.x) / 2;
    double midShoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    double midHipY = (leftHip.y + rightHip.y) / 2;

    double shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    double hipWidth = (leftHip.x - rightHip.x).abs();
    double shoulderToHipY = (midHipY - midShoulderY).abs();

    int now = frameTimestampMs;

    frameBuffer.addFrame(FrameSnapshot(log: {
      "midWristX": midWristX,
    }, timeStamp: now));

    _updateStateMachine(midWristX, leftHip.x, rightHip.x, now);

    final ctx = RussianRepContext(
      midWristX: midWristX,
      midKneeX: midKneeX,
      shoulderWidth: shoulderWidth,
      hipWidth: hipWidth,
      shoulderToHipY: shoulderToHipY,
      leftHipX: leftHip.x,
      rightHipX: rightHip.x,
      state: russianState,
      direction: currentDirection,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    for (final metric in _metrics) {
      metric.update(ctx);
    }

    debugData['russianState'] = russianState.name;
    debugData['direction'] = currentDirection.name;
    
    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }

    if (russianState == RussianTwistState.center_setup) {
      resultIssues.addInstruction('center', 'Status', 'Sẵn sàng vặn');
    } else if (russianState == RussianTwistState.twisting) {
      resultIssues.addInstruction('twisting', 'Status', 'Vặn người!');
    } else if (russianState == RussianTwistState.returning) {
      resultIssues.addInstruction('returning', 'Status', 'Quay về giữa');
    }
  }

  void _updateStateMachine(double midWristX, double leftHipX, double rightHipX, int now) {
    final wristXChange = frameBuffer.getAngleChange("midWristX");
    double minHip = leftHipX < rightHipX ? leftHipX : rightHipX;
    double maxHip = leftHipX > rightHipX ? leftHipX : rightHipX;

    if (russianState == RussianTwistState.center_setup) {
      // If moving right (X increasing strongly) or left (X decreasing strongly)
      if (wristXChange == AngleChangeState.increasing) {
        currentDirection = TwistDirection.right;
        _transitionState(RussianTwistState.twisting, now);
      } else if (wristXChange == AngleChangeState.decreasing) {
        currentDirection = TwistDirection.left;
        _transitionState(RussianTwistState.twisting, now);
      }
    } else if (russianState == RussianTwistState.twisting) {
      // Reached max when velocity stops and we crossed the hip boundary (or at least moved significantly)
      if (currentDirection == TwistDirection.right && wristXChange != AngleChangeState.increasing && midWristX > minHip + (maxHip - minHip)/2) {
         _transitionState(RussianTwistState.max_point, now);
      } else if (currentDirection == TwistDirection.left && wristXChange != AngleChangeState.decreasing && midWristX < minHip + (maxHip - minHip)/2) {
         _transitionState(RussianTwistState.max_point, now);
      }
    } else if (russianState == RussianTwistState.max_point) {
      // Started returning
      if (currentDirection == TwistDirection.right && wristXChange == AngleChangeState.decreasing) {
        _transitionState(RussianTwistState.returning, now);
      } else if (currentDirection == TwistDirection.left && wristXChange == AngleChangeState.increasing) {
        _transitionState(RussianTwistState.returning, now);
      }
    } else if (russianState == RussianTwistState.returning) {
      // Reached center setup again (midWrist is within the inner 50% of the hips)
      double centerMin = minHip + (maxHip - minHip) * 0.25;
      double centerMax = maxHip - (maxHip - minHip) * 0.25;
      if (midWristX > centerMin && midWristX < centerMax) {
        _transitionState(RussianTwistState.center_setup, now);
        _completeHalfRep();
      }
    }
  }

  void _transitionState(RussianTwistState newState, int timestampMs) {
    if (newState == russianState) return;
    
    previousRussianState = russianState;
    russianState = newState;

    if (newState == RussianTwistState.twisting && previousRussianState == RussianTwistState.center_setup) {
      resultIssues.instructions.clear();
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousRussianState, newState, currentDirection, timestampMs);
    }
  }

  void _completeHalfRep() {
    _halfRepCount++;
    
    // Evaluate faults for this side
    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      allFaults.addAll(metric.faults);
    }

    bool isGoodHalf = !allFaults.any((f) => f.affectsForm);

    final faultMap = <String, Map<String, String>>{};
    for (final fault in allFaults) {
      faultMap.putIfAbsent(fault.phase, () => {});
      faultMap[fault.phase]![fault.type] = fault.message;
    }

    // Every 2 half reps = 1 full rep count
    if (_halfRepCount % 2 == 0) {
      repCount++;
      correctForm = isGoodHalf; // simplify, if second half is good, rep is good (ideally both are good)
      resultIssues.feedback['Result'] = correctForm ? 'Good Rep!' : 'Fix Form';
      
      setFeedback.add({correctForm: faultMap});
      logger.addRepLog(RepLog(correctForm: correctForm, repNumber: repCount, data: {
        "fault_types": allFaults.map((f) => f.type).toSet().toList(),
      }));

      for (final metric in _metrics) {
        metric.resetAndCountFault();
      }
    } else {
      // Clear faults for next half
      // Actually we should wait until full rep to reset and count fault.
      // But user might only be bad on one side.
      // Let's count fault per half rep for fine-grained analytics.
      for (final metric in _metrics) {
        metric.resetAndCountFault();
      }
    }
    
    currentDirection = TwistDirection.none;
  }
}
