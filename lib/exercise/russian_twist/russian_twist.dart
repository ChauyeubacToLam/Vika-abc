import 'package:vika/exercise/exercise_base.dart';
import '../../pose/vika_image_orientation.dart';
import 'package:vika/exercise/side_tracked_exercise_mixin.dart';

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
enum TwistDirection { none, forward, backward }

class RussianTwistConfig {
  static const int MAX_REP = 20; // 10 per side
}

class RussianTwist extends ExerciseBase with SideTrackedExerciseMixin {
  @override
  Set<VikaImageOrientation> get supportedOrientations => <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
        VikaImageOrientation.portrait,
      };

  @override
  Map<String, SideLandmarkPair> get requiredSideLandmarks => const {
        'shoulder': (right: PoseLandmarkType.rightShoulder, left: PoseLandmarkType.leftShoulder),
        'hip': (right: PoseLandmarkType.rightHip, left: PoseLandmarkType.leftHip),
        'knee': (right: PoseLandmarkType.rightKnee, left: PoseLandmarkType.leftKnee),
        'wrist': (right: PoseLandmarkType.rightWrist, left: PoseLandmarkType.leftWrist),
      };

  final int maxRep;
  RussianTwist({this.maxRep = RussianTwistConfig.MAX_REP});

  RussianTwistState russianState = RussianTwistState.center_setup;
  RussianTwistState previousRussianState = RussianTwistState.center_setup;
  TwistDirection currentDirection = TwistDirection.none;
  TwistDirection lastCompletedTwistDirection = TwistDirection.none;

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
        return 'Sẵn sàng';
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
    if (cameraFacing == CameraFacing.front || cameraFacing == CameraFacing.undefined) {
      return "⚠️ Vui lòng đặt camera ở góc ngang hoặc ngang lệch để hệ thống thấy rõ lưng và chân của bạn.";
    }
    final sideLandmarks = getSideTrackedLandmarks(landmarks);
    if (sideLandmarks == null) {
      return "⚠️ Không nhìn thấy đủ các điểm khớp (Vai, Hông, Đầu gối, Cổ tay).";
    }
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final sideLandmarks = getSideTrackedLandmarks(landmarks);
    if (sideLandmarks == null) return false;

    final shoulder = sideLandmarks['shoulder']!;
    final hip = sideLandmarks['hip']!;

    // Y increases downwards. Shoulder must be higher (smaller Y) than Hip
    if (shoulder.y > hip.y - 10) {
      resultIssues.feedback['System'] = 'Ngồi dậy, nâng vai cao hơn hông.';
      return false;
    }

    return true;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final sideLandmarks = getSideTrackedLandmarks(smoothedLandmarks);
    if (sideLandmarks == null) return;

    final shoulder = sideLandmarks['shoulder']!;
    final hip = sideLandmarks['hip']!;
    final knee = sideLandmarks['knee']!;
    final wrist = sideLandmarks['wrist']!;

    // Determine facing direction. If knee is to the right of hip, they face right.
    double directionMultiplier = (knee.x > hip.x) ? 1.0 : -1.0;

    // Calculate relative positions
    double wristHipDx = (wrist.x - hip.x) * directionMultiplier;
    double kneeHipDx = (knee.x - hip.x) * directionMultiplier;
    
    // Fallback if knee is directly under hip (shouldn't happen sitting)
    if (kneeHipDx <= 0) kneeHipDx = 1.0;

    int now = frameTimestampMs;

    frameBuffer.addFrame(FrameSnapshot(log: {
      "wristHipDx": wristHipDx,
    }, timeStamp: now));

    _updateStateMachine(wristHipDx, kneeHipDx, now);

    final ctx = RussianRepContext(
      wristX: wrist.x,
      wristY: wrist.y,
      kneeX: knee.x,
      kneeY: knee.y,
      hipX: hip.x,
      hipY: hip.y,
      shoulderX: shoulder.x,
      shoulderY: shoulder.y,
      wristHipDx: wristHipDx,
      kneeHipDx: kneeHipDx,
      directionMultiplier: directionMultiplier,
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
    debugData['halfRepCount'] = _halfRepCount;
    
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

  void _updateStateMachine(double wristHipDx, double kneeHipDx, int now) {
    final wristChange = frameBuffer.getChange("wristHipDx", 3);

    if (russianState == RussianTwistState.center_setup) {
      // If moving forward (towards knees) or backward (towards hips)
      if (wristChange == ChangeState.increasing) {
        currentDirection = TwistDirection.forward;
        _transitionState(RussianTwistState.twisting, now);
      } else if (wristChange == ChangeState.decreasing) {
        currentDirection = TwistDirection.backward;
        _transitionState(RussianTwistState.twisting, now);
      }
    } else if (russianState == RussianTwistState.twisting) {
      // Reached max point when velocity stops
      if (currentDirection == TwistDirection.forward && wristChange != ChangeState.increasing) {
         _transitionState(RussianTwistState.max_point, now);
      } else if (currentDirection == TwistDirection.backward && wristChange != ChangeState.decreasing) {
         _transitionState(RussianTwistState.max_point, now);
      }
    } else if (russianState == RussianTwistState.max_point) {
      // Started returning
      if (currentDirection == TwistDirection.forward && wristChange == ChangeState.decreasing) {
        _transitionState(RussianTwistState.returning, now);
      } else if (currentDirection == TwistDirection.backward && wristChange == ChangeState.increasing) {
        _transitionState(RussianTwistState.returning, now);
      }
    } else if (russianState == RussianTwistState.returning) {
      // We consider returning to center when velocity stops again, OR when it crosses the middle.
      // A common pattern is sweeping from forward to backward directly.
      // So if velocity changes direction, or we cross the center zone, we reset.
      
      // Center zone is around 30% to 50% of kneeHipDx.
      double centerMin = kneeHipDx * 0.25;
      double centerMax = kneeHipDx * 0.55;

      bool inCenterZone = wristHipDx > centerMin && wristHipDx < centerMax;
      
      if (inCenterZone || (currentDirection == TwistDirection.forward && wristChange == ChangeState.increasing) || (currentDirection == TwistDirection.backward && wristChange == ChangeState.decreasing)) {
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
    // Collect faults early to see if rom failed
    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      allFaults.addAll(metric.faults);
    }
    
    bool hasRomFault = allFaults.any((f) => f.type == 'shallow_twist');

    // Only process valid alternating reps if ROM was good enough.
    // If ROM failed, we don't count it as a valid twist side.
    if (!hasRomFault) {
      if (currentDirection == lastCompletedTwistDirection) {
        // Repeated the same side!
        resultIssues.feedback['Result'] = 'Lỗi!';
        setFeedback.add({false: {'General': {'duplicate_side': 'Vui lòng vặn luân phiên 2 bên!'}}});
        logger.addRepLog(RepLog(correctForm: false, repNumber: repCount, data: {
          "fault_types": ['duplicate_side'],
        }));
      } else {
        // Valid alternate twist
        _halfRepCount++;
        lastCompletedTwistDirection = currentDirection;

        bool isGoodHalf = !allFaults.any((f) => f.affectsForm);

        final faultMap = <String, Map<String, String>>{};
        for (final fault in allFaults) {
          faultMap.putIfAbsent(fault.phase, () => {});
          faultMap[fault.phase]![fault.type] = fault.message;
        }

        // Every 2 valid half reps = 1 full rep count
        if (_halfRepCount % 2 == 0) {
          repCount++;
          correctForm = isGoodHalf;
          resultIssues.feedback['Result'] = correctForm ? 'Good Rep!' : 'Fix Form';
          
          setFeedback.add({correctForm: faultMap});
          logger.addRepLog(RepLog(correctForm: correctForm, repNumber: repCount, data: {
            "fault_types": allFaults.map((f) => f.type).toSet().toList(),
          }));
        }
      }
    } else {
      // Shallow twist, don't count it, just log the fault.
      final faultMap = <String, Map<String, String>>{};
      for (final fault in allFaults) {
        faultMap.putIfAbsent(fault.phase, () => {});
        faultMap[fault.phase]![fault.type] = fault.message;
      }
      setFeedback.add({false: faultMap});
    }

    for (final metric in _metrics) {
      metric.resetAndCountFault();
    }
    
    currentDirection = TwistDirection.none;
  }
}
