import 'dart:math' as math;

import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/side_tracked_exercise_mixin.dart';
import 'package:vika/pose/vika_pose_landmark.dart';

import '../../utils/frame_buffer.dart';
import 'package:vika/utils/exercise_logger.dart';
import '../../utils/frame_snapshot.dart';
import '../../utils/pose_math_helpers.dart';
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
  static const double MIN_TRUNK_HORIZONTAL_ANGLE = 32.0;
  static const double MAX_TRUNK_HORIZONTAL_ANGLE = 72.0;
  static const double MIN_KNEE_HIP_DX_RATIO = 0.35;
  static const double START_MIN_HAND_RATIO = 0.28;
  static const double START_MAX_HAND_RATIO = 0.52;
  static const double CENTER_MIN_HAND_RATIO = 0.30;
  static const double CENTER_MAX_HAND_RATIO = 0.50;
  static const double FORWARD_ROM_RATIO = 0.60;
  static const double BACKWARD_ROM_RATIO = 0.20;
  static const double HAND_VELOCITY_GATE_PX = 3.0;
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
  double? _centerHandSignal;

  static const Set<String> _blockingFaultTypes = {
    'shallow_twist',
    'arm_swinging',
    'knee_wobble',
    'upright_torso',
    'collapsed_torso',
  };

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
    if (cameraFacing == CameraFacing.front) {
      return "Vui lòng đặt camera chéo ngang khoảng 35-45 độ, không quay chính diện.";
    }
    if (cameraFacing == CameraFacing.undefined) {
      return "Vui lòng giữ vai, hông, gối và tay trong khung hình.";
    }
    if (cameraFacing == CameraFacing.left ||
        cameraFacing == CameraFacing.right) {
      return "Đừng đặt camera ngang 90 độ. Hãy xoay máy chéo 35-45 độ để thấy cả hai bên vai và tay.";
    }
    final sideLandmarks = getSideTrackedLandmarks(landmarks);
    if (sideLandmarks == null) {
      return "Không nhìn thấy đủ các điểm khớp vai, hông, gối và cổ tay.";
    }
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final sideLandmarks = getSideTrackedLandmarks(landmarks);
    if (sideLandmarks == null) return false;

    final shoulder = sideLandmarks['shoulder']!;
    final hip = sideLandmarks['hip']!;
    final knee = sideLandmarks['knee']!;
    final wrist = sideLandmarks['wrist']!;

    final trunkAngle = _trunkHorizontalAngle(shoulder, hip);
    if (trunkAngle > RussianTwistConfig.MAX_TRUNK_HORIZONTAL_ANGLE) {
      resultIssues.feedback['System'] =
          'Ngả lưng ra sau khoảng 35-60 độ, không ngồi thẳng lưng.';
      return false;
    }
    if (trunkAngle < RussianTwistConfig.MIN_TRUNK_HORIZONTAL_ANGLE) {
      resultIssues.feedback['System'] =
          'Nâng thân lên một chút, đừng nằm quá thấp khi chuẩn bị.';
      return false;
    }

    final directionMultiplier = _directionMultiplier(hip, knee);
    final kneeHipDx = _normalizedDx(knee, hip, directionMultiplier);
    final torsoLength = math.max(calculateDistance(shoulder, hip), 1.0);
    if (kneeHipDx < torsoLength * RussianTwistConfig.MIN_KNEE_HIP_DX_RATIO) {
      resultIssues.feedback['System'] =
          'Co gối rõ hơn và giữ đầu gối ở phía trước hông.';
      return false;
    }

    final wristHipDx = _normalizedDx(wrist, hip, directionMultiplier);
    final handRatio = wristHipDx / kneeHipDx;
    if (handRatio < RussianTwistConfig.CENTER_MIN_HAND_RATIO ||
        handRatio > RussianTwistConfig.CENTER_MAX_HAND_RATIO) {
      resultIssues.feedback['System'] =
          'Đưa hai tay về giữa thân trước khi bắt đầu.';
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
    final trackedWrist = sideLandmarks['wrist']!;
    final handPoint = _stableHandPoint(smoothedLandmarks, trackedWrist);

    // Determine facing direction. If knee is to the right of hip, they face right.
    double directionMultiplier = _directionMultiplier(hip, knee);

    // Calculate relative positions
    double wristHipDx = (handPoint.x - hip.x) * directionMultiplier;
    double shoulderHipDx = (shoulder.x - hip.x) * directionMultiplier;
    double kneeHipDx = _normalizedDx(knee, hip, directionMultiplier);
    final trunkAngle = _trunkHorizontalAngle(shoulder, hip);

    // Fallback if knee is directly under hip (shouldn't happen sitting)
    if (kneeHipDx <= 0) kneeHipDx = 1.0;

    int now = frameTimestampMs;

    frameBuffer.addFrame(FrameSnapshot(log: {
      "wristHipDx": wristHipDx,
      "handSignal": wristHipDx,
      "shoulderSignal": shoulderHipDx,
    }, timeStamp: now));

    _updateStateMachine(wristHipDx, kneeHipDx, now);

    final ctx = RussianRepContext(
      wristX: handPoint.x,
      wristY: handPoint.y,
      kneeX: knee.x,
      kneeY: knee.y,
      hipX: hip.x,
      hipY: hip.y,
      shoulderX: shoulder.x,
      shoulderY: shoulder.y,
      wristHipDx: wristHipDx,
      shoulderHipDx: shoulderHipDx,
      kneeHipDx: kneeHipDx,
      directionMultiplier: directionMultiplier,
      trunkHorizontalAngle: trunkAngle,
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
    debugData['handSignal'] = wristHipDx.toStringAsFixed(1);
    debugData['handRatio'] = (wristHipDx / kneeHipDx).toStringAsFixed(2);
    debugData['shoulderSignal'] = shoulderHipDx.toStringAsFixed(1);
    debugData['trunkAngle'] = trunkAngle.toStringAsFixed(1);

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

  void _updateStateMachine(double handSignal, double kneeHipDx, int now) {
    final handChange = frameBuffer.getChange(
        "handSignal", RussianTwistConfig.HAND_VELOCITY_GATE_PX);
    final handRatio = handSignal / kneeHipDx;

    if (russianState == RussianTwistState.center_setup) {
      _centerHandSignal = handSignal;
      if (handChange == ChangeState.increasing &&
          handRatio >= RussianTwistConfig.START_MAX_HAND_RATIO) {
        currentDirection = TwistDirection.forward;
        _transitionState(RussianTwistState.twisting, now);
      } else if (handChange == ChangeState.decreasing &&
          handRatio <= RussianTwistConfig.START_MIN_HAND_RATIO) {
        currentDirection = TwistDirection.backward;
        _transitionState(RussianTwistState.twisting, now);
      }
    } else if (russianState == RussianTwistState.twisting) {
      if (currentDirection == TwistDirection.forward &&
          handRatio >= RussianTwistConfig.FORWARD_ROM_RATIO) {
        _transitionState(RussianTwistState.max_point, now);
      } else if (currentDirection == TwistDirection.backward &&
          handRatio <= RussianTwistConfig.BACKWARD_ROM_RATIO) {
        _transitionState(RussianTwistState.max_point, now);
      }
    } else if (russianState == RussianTwistState.max_point) {
      if (currentDirection == TwistDirection.forward &&
          handChange == ChangeState.decreasing) {
        _transitionState(RussianTwistState.returning, now);
      } else if (currentDirection == TwistDirection.backward &&
          handChange == ChangeState.increasing) {
        _transitionState(RussianTwistState.returning, now);
      }
    } else if (russianState == RussianTwistState.returning) {
      final inCenterRatio =
          handRatio >= RussianTwistConfig.CENTER_MIN_HAND_RATIO &&
              handRatio <= RussianTwistConfig.CENTER_MAX_HAND_RATIO;
      final centerTolerance = (kneeHipDx.abs() * 0.12).clamp(6.0, 24.0);
      final nearCapturedCenter = _centerHandSignal != null &&
          (handSignal - _centerHandSignal!).abs() <= centerTolerance;

      if (inCenterRatio ||
          nearCapturedCenter ||
          (currentDirection == TwistDirection.forward &&
              handChange == ChangeState.increasing) ||
          (currentDirection == TwistDirection.backward &&
              handChange == ChangeState.decreasing)) {
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
    // Collect faults early to see if this attempt should count.
    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      allFaults.addAll(metric.faults);
    }

    bool hasBlockingFault =
        allFaults.any((f) => _blockingFaultTypes.contains(f.type));

    // Only process valid alternating reps if the attempt passed anti-cheat.
    // Blocking faults are ignored as a side so users cannot alternate bad reps.
    if (!hasBlockingFault) {
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
      // Failed anti-cheat, don't count it, just log the fault.
      _rejectedHalfTwists++;
      resultIssues.feedback['Result'] = 'Không tính';
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

  double _directionMultiplier(PoseLandmark hip, PoseLandmark knee) {
    return knee.x >= hip.x ? 1.0 : -1.0;
  }

  double _normalizedDx(
    PoseLandmark point,
    PoseLandmark origin,
    double directionMultiplier,
  ) {
    return (point.x - origin.x) * directionMultiplier;
  }

  double _trunkHorizontalAngle(PoseLandmark shoulder, PoseLandmark hip) {
    return calculateAbsoluteHorizontalAngle(point1: shoulder, point2: hip);
  }

  ({double x, double y}) _stableHandPoint(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    PoseLandmark trackedWrist,
  ) {
    var best = trackedWrist;
    var bestScore = _landmarkReliability(trackedWrist);

    for (final type in const [
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
    ]) {
      final candidate = landmarks[type];
      if (candidate == null || !ExerciseBase.isLandmarkConfident(candidate)) {
        continue;
      }

      final score = _landmarkReliability(candidate);
      if (score > bestScore + 0.35) {
        best = candidate;
        bestScore = score;
      }
    }

    return (x: best.x, y: best.y);
  }

  double _landmarkReliability(PoseLandmark landmark) {
    return landmark.likelihood + landmark.presence + landmark.visibility;
  }
}
