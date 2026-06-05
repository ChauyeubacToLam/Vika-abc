import 'package:vika/exercise/exercise_base.dart';
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
        'shoulder': (
          right: PoseLandmarkType.rightShoulder,
          left: PoseLandmarkType.leftShoulder
        ),
        'hip': (
          right: PoseLandmarkType.rightHip,
          left: PoseLandmarkType.leftHip
        ),
        'knee': (
          right: PoseLandmarkType.rightKnee,
          left: PoseLandmarkType.leftKnee
        ),
        'wrist': (
          right: PoseLandmarkType.rightWrist,
          left: PoseLandmarkType.leftWrist
        ),
      };

  final int maxRep;
  RussianTwist({this.maxRep = RussianTwistConfig.MAX_REP});

  RussianTwistState russianState = RussianTwistState.center_setup;
  RussianTwistState previousRussianState = RussianTwistState.center_setup;
  TwistDirection currentDirection = TwistDirection.none;
  TwistDirection lastCompletedTwistDirection = TwistDirection.none;

  int _halfRepCount = 0; // count twists, 2 twists = 1 rep
  int _rejectedHalfTwists = 0;
  double? _centerRotationSignal;

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
    logger.pushKey("rejected_attempts_count", _rejectedHalfTwists);
    logger.pushGoodRepCount();
    logger.pushKey("max_rep", repCount);
    logger.pushKey("target_rep", maxRep);
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front ||
        cameraFacing == CameraFacing.undefined) {
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
    double shoulderHipDx = (shoulder.x - hip.x) * directionMultiplier;
    double kneeHipDx = (knee.x - hip.x) * directionMultiplier;

    // Fallback if knee is directly under hip (shouldn't happen sitting)
    if (kneeHipDx <= 0) kneeHipDx = 1.0;

    int now = frameTimestampMs;

    frameBuffer.addFrame(FrameSnapshot(log: {
      "wristHipDx": wristHipDx,
      "rotationSignal": shoulderHipDx,
    }, timeStamp: now));

    _updateStateMachine(shoulderHipDx, kneeHipDx, now);

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
    debugData['rotationSignal'] = shoulderHipDx.toStringAsFixed(1);

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

  void _updateStateMachine(double rotationSignal, double kneeHipDx, int now) {
    final rotationChange = frameBuffer.getChange("rotationSignal", 3);

    if (russianState == RussianTwistState.center_setup) {
      _centerRotationSignal = rotationSignal;
      // If the torso rotates forward or backward.
      if (rotationChange == ChangeState.increasing) {
        currentDirection = TwistDirection.forward;
        _transitionState(RussianTwistState.twisting, now);
      } else if (rotationChange == ChangeState.decreasing) {
        currentDirection = TwistDirection.backward;
        _transitionState(RussianTwistState.twisting, now);
      }
    } else if (russianState == RussianTwistState.twisting) {
      // Reached max point when velocity stops
      if (currentDirection == TwistDirection.forward &&
          rotationChange != ChangeState.increasing) {
        _transitionState(RussianTwistState.max_point, now);
      } else if (currentDirection == TwistDirection.backward &&
          rotationChange != ChangeState.decreasing) {
        _transitionState(RussianTwistState.max_point, now);
      }
    } else if (russianState == RussianTwistState.max_point) {
      // Started returning
      if (currentDirection == TwistDirection.forward &&
          rotationChange == ChangeState.decreasing) {
        _transitionState(RussianTwistState.returning, now);
      } else if (currentDirection == TwistDirection.backward &&
          rotationChange == ChangeState.increasing) {
        _transitionState(RussianTwistState.returning, now);
      }
    } else if (russianState == RussianTwistState.returning) {
      // We consider returning to center when velocity stops again, OR when it crosses the middle.
      // A common pattern is sweeping from forward to backward directly.
      // So if velocity changes direction, or we cross the center zone, we reset.

      final centerTolerance = (kneeHipDx.abs() * 0.12).clamp(6.0, 24.0);
      final inCenterZone = _centerRotationSignal != null &&
          (rotationSignal - _centerRotationSignal!).abs() <= centerTolerance;

      if (inCenterZone ||
          (currentDirection == TwistDirection.forward &&
              rotationChange == ChangeState.increasing) ||
          (currentDirection == TwistDirection.backward &&
              rotationChange == ChangeState.decreasing)) {
        _transitionState(RussianTwistState.center_setup, now);
        _completeHalfRep();
      }
    }
  }

  void _transitionState(RussianTwistState newState, int timestampMs) {
    if (newState == russianState) return;

    previousRussianState = russianState;
    russianState = newState;

    if (newState == RussianTwistState.twisting &&
        previousRussianState == RussianTwistState.center_setup) {
      resultIssues.instructions.clear();
    }

    for (final metric in _metrics) {
      metric.onStateTransition(
          previousRussianState, newState, currentDirection, timestampMs);
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
        _rejectedHalfTwists++;
        resultIssues.feedback['Result'] = 'Không tính';
        setFeedback.add({
          false: {
            'General': {'duplicate_side': 'Vui lòng vặn luân phiên 2 bên!'}
          }
        });
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
          resultIssues.feedback['Result'] =
              correctForm ? 'Tốt lắm!' : 'Sửa form';

          setFeedback.add({correctForm: faultMap});
          logger.addRepLog(
              RepLog(correctForm: correctForm, repNumber: repCount, data: {
            "fault_types": allFaults.map((f) => f.type).toSet().toList(),
          }));
        }
      }
    } else {
      // Shallow twist, don't count it, just log the fault.
      _rejectedHalfTwists++;
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
