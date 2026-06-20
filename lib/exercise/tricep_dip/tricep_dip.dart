import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/debug/tracked_metric.dart';
import 'package:vika/utils/exercise_logger.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/frame_buffer.dart';
import '../../utils/frame_snapshot.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../side_tracked_exercise_mixin.dart';
import 'metrics/tricep_metric_base.dart';
import 'metrics/hip_thrust_metric.dart';
import 'metrics/tricep_rom_metric.dart';
import 'metrics/full_extension_metric.dart';
import 'metrics/scapular_elevation_metric.dart';

enum TricepDipState { setup_top, descending, bottom, ascending }

class TricepDipConfig {
  static const int MAX_REP = 15;
  static const double DESCENDING_ELBOW_ANGLE = 145.0;
  static const double BOTTOM_ELBOW_ANGLE = 125.0;
  static const double ASCENDING_ELBOW_ANGLE = 150.0;
}

class TricepDip extends ExerciseBase with SideTrackedExerciseMixin {
  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  final int maxRep;
  TricepDip({this.maxRep = TricepDipConfig.MAX_REP});

  TricepDipState tricepState = TricepDipState.setup_top;
  TricepDipState previousTricepState = TricepDipState.setup_top;
  double _minElbowAngleThisRep = 180.0;
  bool _hasStartedAscending = false;

  // Metrics
  final HipThrustMetric hipThrustMetric = HipThrustMetric();
  final TricepRomMetric tricepRomMetric = TricepRomMetric();
  final FullExtensionMetric fullExtensionMetric = FullExtensionMetric();
  final ScapularElevationMetric scapularElevationMetric =
      ScapularElevationMetric();

  late final List<TricepMetricBase> _metrics = [
    hipThrustMetric,
    tricepRomMetric,
    fullExtensionMetric,
    scapularElevationMetric,
  ];
  late final List<TrackedMetric> _trackedMetrics =
      _metrics.map(TrackedMetric.new).toList();

  @override
  List<TrackedMetric> get trackedDebugMetrics =>
      List<TrackedMetric>.unmodifiable(
        [
          ...super.trackedDebugMetrics,
          ..._trackedMetrics,
        ],
      );

  @override
  Map<String, SideLandmarkPair> get requiredSideLandmarks => const {
        'shoulder': (
          right: PoseLandmarkType.rightShoulder,
          left: PoseLandmarkType.leftShoulder
        ),
        'elbow': (
          right: PoseLandmarkType.rightElbow,
          left: PoseLandmarkType.leftElbow
        ),
        'wrist': (
          right: PoseLandmarkType.rightWrist,
          left: PoseLandmarkType.leftWrist
        ),
        'hip': (
          right: PoseLandmarkType.rightHip,
          left: PoseLandmarkType.leftHip
        ),
        'ankle': (
          right: PoseLandmarkType.rightAnkle,
          left: PoseLandmarkType.leftAnkle
        ),
      };

  @override
  Map<String, SideLandmarkPair> get optionalSideLandmarks => const {
        'ear': (
          right: PoseLandmarkType.rightEar,
          left: PoseLandmarkType.leftEar
        ),
      };

  @override
  String get exerciseName => 'Tricep Dip (Floor)';

  @override
  String get currentPhaseKey => tricepState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (tricepState) {
      case TricepDipState.setup_top:
        return 'Vị trí bắt đầu';
      case TricepDipState.descending:
        return 'Hạ xuống';
      case TricepDipState.bottom:
        return 'Giữ';
      case TricepDipState.ascending:
        return 'Đẩy lên';
    }
  }

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey("hip_thrust_fails_count", hipThrustMetric.faultsCount);
    logger.pushKey("rom_fails_count", tricepRomMetric.faultsCount);
    logger.pushKey("extension_fails_count", fullExtensionMetric.faultsCount);
    logger.pushKey(
        "shrugging_fails_count", scapularElevationMetric.faultsCount);
    logger.pushGoodRepCount();
    logger.pushKey("max_rep", maxRep);
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return "⚠️ Bài tập này yêu cầu quay mặt ngang hông (Side Camera).";
    }
    final req = getSideTrackedLandmarks(landmarks);
    if (req == null) return "⚠️ Không thấy rõ cơ thể. Hãy điều chỉnh góc máy.";
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) return false;
    final req = getSideTrackedLandmarks(landmarks);
    if (req == null) return false;

    final shoulder = req['shoulder']!;
    final elbow = req['elbow']!;
    final wrist = req['wrist']!;
    final hip = req['hip']!;
    final ankle = req['ankle']!;

    // 1. Arm almost vertical / straight
    double elbowAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
    if (elbowAngle < 155.0) {
      resultIssues.feedback['System'] = 'Duỗi thẳng cánh tay.';
      return false;
    }

    // 2. Hip is off the ground (Y is smaller than ankle Y)
    // Note: mlkit Y increases downwards. So hip.y < ankle.y means hip is higher.
    if (hip.y >= ankle.y - 0.02) {
      resultIssues.feedback['System'] = 'Nhấc hông lên khỏi mặt đất.';
      return false;
    }

    return true;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final req = getSideTrackedLandmarks(smoothedLandmarks);
    if (req == null) return;

    final shoulder = req['shoulder']!;
    final elbow = req['elbow']!;
    final wrist = req['wrist']!;
    final hip = req['hip']!;
    final ear = req['ear'];

    double elbowAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
    double forearmLength = calculateDistance(elbow, wrist);

    int now = frameTimestampMs;

    frameBuffer.addFrame(FrameSnapshot(log: {
      "shoulderY": shoulder.y,
      "hipY": hip.y,
      "elbowAngle": elbowAngle,
    }, timeStamp: now));

    _updateStateMachine(elbowAngle, now);

    if (tricepState == TricepDipState.setup_top &&
        previousTricepState != TricepDipState.setup_top) {
      _completeRep();
      return;
    }

    final ctx = TricepRepContext(
      elbowAngle: elbowAngle,
      shoulder: shoulder,
      elbow: elbow,
      wrist: wrist,
      hip: hip,
      ear: ear,
      forearmLength: forearmLength,
      state: tricepState,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    if (tricepState != TricepDipState.setup_top) {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
    }

    debugData['tricepState'] = tricepState.name;
    debugData['elbowAngle'] = elbowAngle;

    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }

    if (tricepState == TricepDipState.descending) {
      resultIssues.addInstruction('descending', 'Status', 'Gập tay xuống...');
    } else if (tricepState == TricepDipState.bottom) {
      resultIssues.addInstruction('bottom', 'Status', 'Đẩy lên!');
    } else if (tricepState == TricepDipState.ascending) {
      resultIssues.addInstruction('ascending', 'Status', 'Duỗi thẳng tay!');
    }
  }

  void _updateStateMachine(double elbowAngle, int now) {
    final hipYChange = frameBuffer.getChange("hipY", 3);
    final elbowAngleChange = frameBuffer.getChange("elbowAngle", 3);

    if (tricepState == TricepDipState.setup_top) {
      if (elbowAngle < TricepDipConfig.DESCENDING_ELBOW_ANGLE) {
        _minElbowAngleThisRep = elbowAngle;
        _hasStartedAscending = false;
        _transitionState(TricepDipState.descending, now);
      }
    } else if (tricepState == TricepDipState.descending) {
      _minElbowAngleThisRep = elbowAngle < _minElbowAngleThisRep
          ? elbowAngle
          : _minElbowAngleThisRep;
      if (elbowAngle <= TricepRomMetric.MIN_DEPTH_ANGLE &&
          (hipYChange == ChangeState.decreasing ||
              elbowAngleChange == ChangeState.increasing)) {
        _transitionState(TricepDipState.bottom, now);
      }
    } else if (tricepState == TricepDipState.bottom) {
      if (hipYChange == ChangeState.decreasing ||
          elbowAngleChange == ChangeState.increasing) {
        _hasStartedAscending = true;
        _transitionState(TricepDipState.ascending, now);
      }
    } else if (tricepState == TricepDipState.ascending) {
      if (elbowAngleChange == ChangeState.increasing) {
        _hasStartedAscending = true;
      }
      if (_hasStartedAscending &&
          elbowAngle > TricepDipConfig.ASCENDING_ELBOW_ANGLE) {
        _transitionState(TricepDipState.setup_top, now);
      } else if (elbowAngleChange == ChangeState.decreasing &&
          elbowAngle < TricepDipConfig.ASCENDING_ELBOW_ANGLE - 10) {
        // Started another descent before finishing the rep: reject this attempt.
        _transitionState(TricepDipState.descending, now);
        for (final metric in _metrics) {
          metric.reset();
        }
      }
    }
  }

  void _transitionState(TricepDipState newState, int timestampMs) {
    if (newState == tricepState) return;

    previousTricepState = tricepState;
    tricepState = newState;

    if (newState == TricepDipState.descending &&
        previousTricepState == TricepDipState.setup_top) {
      resultIssues.instructions.clear();
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousTricepState, newState, timestampMs);
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

    logger
        .addRepLog(RepLog(correctForm: correctForm, repNumber: repCount, data: {
      "fault_types": allFaults.map((f) => f.type).toSet().toList(),
    }));

    correctForm = true;
    for (final metric in _metrics) {
      metric.resetAndCountFault();
    }
  }
}
