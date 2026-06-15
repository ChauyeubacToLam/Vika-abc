import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/side_tracked_exercise_mixin.dart';
import 'package:vika/pose/vika_pose_landmark.dart';
import 'package:vika/utils/exercise_logger.dart';

import '../../utils/frame_buffer.dart';
import '../../utils/frame_snapshot.dart';
import '../../utils/pose_math_helpers.dart';
import 'metrics/knee_anchoring_metric.dart';
import 'metrics/russian_metric_base.dart';
import 'metrics/spinal_flexion_metric.dart';
import 'metrics/thoracic_rotation_metric.dart';
import 'metrics/twist_rom_metric.dart';

enum RussianTwistState { center_setup, twisting, max_point, returning }

enum TwistDirection { none, forward, backward }

class RussianTwistConfig {
  static const int MAX_REP = 20;
  static const double MIN_TRUNK_HORIZONTAL_ANGLE = 32.0;
  static const double MAX_TRUNK_HORIZONTAL_ANGLE = 72.0;
  static const double MIN_KNEE_HIP_DX_RATIO = 0.35;
  static const double START_MIN_HAND_RATIO = 0.28;
  static const double START_MAX_HAND_RATIO = 0.52;
  static const double CENTER_MIN_HAND_RATIO = 0.30;
  static const double CENTER_MAX_HAND_RATIO = 0.50;
  static const double FORWARD_ROM_RATIO = 0.60;
  static const double BACKWARD_ROM_RATIO = 0.20;
  static const double FORWARD_GOOD_ROM_RATIO = 0.66;
  static const double BACKWARD_GOOD_ROM_RATIO = 0.14;
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

  int _halfRepCount = 0;
  int _rejectedHalfTwists = 0;
  double? _centerHandSignal;
  final List<FaultRecord> _pendingFullRepFaults = [];

  static const Set<String> _blockingFaultTypes = {
    'shallow_twist',
    'arm_swinging',
    'knee_wobble',
    'upright_torso',
    'collapsed_torso',
  };

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
    logger.pushKey("thoracic_fails_count", thoracicMetric.faultsCount);
    logger.pushKey("knee_wobble_fails_count", kneeMetric.faultsCount);
    logger.pushKey("rom_fails_count", twistRomMetric.faultsCount);
    logger.pushKey("rejected_attempts_count", _rejectedHalfTwists);
    logger.pushGoodRepCount();
    logger.pushKey("max_rep", maxRep);
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      if (cameraFacing == CameraFacing.front) {
        return 'Đặt camera ngang bên hông, không quay chính diện.';
      }
      if (cameraFacing == CameraFacing.angled) {
        return 'Xoay camera sang góc ngang bên hông rồi mới tập.';
      }
      return 'Giữ vai, hông, gối và tay trong khung hình ở góc ngang bên hông.';
    }

    final sideLandmarks = getSideTrackedLandmarks(landmarks);
    if (sideLandmarks == null) {
      return 'Không nhìn thấy đủ các điểm khớp vai, hông, gối và cổ tay.';
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

    debugData['RussianSetup'] = {
      'cameraFacing': cameraFacing.name,
      'frontFacingRatio': frontFacingRatio.toStringAsFixed(2),
      'trunkAngle': trunkAngle.toStringAsFixed(1),
      'kneeHipDx': kneeHipDx.toStringAsFixed(1),
      'handRatio': handRatio.toStringAsFixed(2),
    };
    return true;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final safety = checkSafety(smoothedLandmarks);
    if (safety != null) {
      resultIssues.feedback['System'] = safety;
      return;
    }

    final sideLandmarks = getSideTrackedLandmarks(smoothedLandmarks);
    if (sideLandmarks == null) return;

    final shoulder = sideLandmarks['shoulder']!;
    final hip = sideLandmarks['hip']!;
    final knee = sideLandmarks['knee']!;
    final trackedWrist = sideLandmarks['wrist']!;
    final handPoint = _stableHandPoint(smoothedLandmarks, trackedWrist);

    final directionMultiplier = _directionMultiplier(hip, knee);
    final wristHipDx = (handPoint.x - hip.x) * directionMultiplier;
    final shoulderHipDx = (shoulder.x - hip.x) * directionMultiplier;
    var kneeHipDx = _normalizedDx(knee, hip, directionMultiplier);
    final trunkAngle = _trunkHorizontalAngle(shoulder, hip);

    if (kneeHipDx <= 1e-6) kneeHipDx = 1.0;

    final now = frameTimestampMs;
    frameBuffer.addFrame(FrameSnapshot(log: {
      'wristHipDx': wristHipDx,
      'handSignal': wristHipDx,
      'shoulderSignal': shoulderHipDx,
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

    debugData['RussianTwistDebug'] = {
      'state': russianState.name,
      'cameraFacing': cameraFacing.name,
      'frontFacingRatio': frontFacingRatio.toStringAsFixed(2),
      'direction': currentDirection.name,
      'halfRepCount': _halfRepCount,
      'repCount': repCount,
      'rejectedHalfTwists': _rejectedHalfTwists,
      'handSignal': wristHipDx.toStringAsFixed(1),
      'handRatio': (wristHipDx / kneeHipDx).toStringAsFixed(2),
      'shoulderSignal': shoulderHipDx.toStringAsFixed(1),
      'trunkAngle': trunkAngle.toStringAsFixed(1),
    };

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
      'handSignal',
      RussianTwistConfig.HAND_VELOCITY_GATE_PX,
    );
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

      if (inCenterRatio || nearCapturedCenter) {
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
        previousRussianState,
        newState,
        currentDirection,
        timestampMs,
      );
    }
  }

  void _completeHalfRep() {
    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      allFaults.addAll(metric.faults);
    }
    var countMetricFaults = false;

    final hasBlockingFault =
        allFaults.any((f) => _blockingFaultTypes.contains(f.type));

    if (!hasBlockingFault) {
      if (currentDirection == lastCompletedTwistDirection) {
        _rejectedHalfTwists++;
        resultIssues.feedback['Result'] = 'Không tính';
        setFeedback.add({
          false: {
            'General': {'duplicate_side': 'Vui lòng vặn luân phiên 2 hướng!'}
          }
        });
      } else {
        _halfRepCount++;
        lastCompletedTwistDirection = currentDirection;
        _pendingFullRepFaults.addAll(allFaults);

        if (_halfRepCount % 2 == 0) {
          repCount++;
          countMetricFaults = true;
          correctForm = !_pendingFullRepFaults.any((f) => f.affectsForm);
          resultIssues.feedback['Result'] =
              correctForm ? 'Tốt lắm!' : 'Chỉnh tư thế';

          final faultMap = <String, Map<String, String>>{};
          for (final fault in _pendingFullRepFaults) {
            faultMap.putIfAbsent(fault.phase, () => {});
            faultMap[fault.phase]![fault.type] = fault.message;
          }

          setFeedback.add({correctForm: faultMap});
          logger.addRepLog(RepLog(
            correctForm: correctForm,
            repNumber: repCount,
            data: {
              'fault_types':
                  _pendingFullRepFaults.map((f) => f.type).toSet().toList(),
              'half_rep_count': _halfRepCount,
            },
          ));
          _pendingFullRepFaults.clear();
        }
      }
    } else {
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
      if (countMetricFaults) {
        metric.resetAndCountFault();
      } else {
        metric.reset();
      }
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
