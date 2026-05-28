import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../../pose/vika_image_orientation.dart';
import '../exercise_base.dart';
import 'metrics/seated_forward_metric_base.dart';
import 'metrics/knee_extension_metric.dart';
import 'metrics/spinal_alignment_metric.dart';
import 'metrics/hold_tempo_metric.dart';
import 'metrics/ankle_dorsiflexion_metric.dart';

class SeatedForwardFold extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  SeatedForwardState state = SeatedForwardState.setup;
  SeatedForwardState prevState = SeatedForwardState.setup;
  bool isLeftTracked = true;

  double _minHipAngleThisRep = 999.0;
  double _lastMaxDepth = 0.0;
  double? _userMaxRom;

  double _lastHipAngle = -1.0;
  int _lastTimestampMs = -1;
  double _currentVelocity = 0.0; 
  int? _stableStartTimeMs;       

  final KneeExtensionMetric kneeMetric = KneeExtensionMetric();
  final SpinalAlignmentMetric spineMetric = SpinalAlignmentMetric();
  final HoldTempoMetric tempoMetric = HoldTempoMetric();
  final AnkleDorsiflexionMetric ankleMetric = AnkleDorsiflexionMetric();

  late final List<SeatedForwardMetricBase> _metrics = [
    kneeMetric, spineMetric, tempoMetric, ankleMetric
  ];

  @override
  String get exerciseName => 'Seated Forward Fold';

  @override
  bool requestStop() {
    if (state == SeatedForwardState.isometricHold) {
      tempoMetric.flushCurrentSegment(frameTimestampMs);
    }
    return repCount >= 3;
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) return "Vui lòng đặt camera quay ngang hông (Side View).";
    final req = [
      PoseLandmarkType.leftEar, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee, PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex,
    ];
    for (final type in req) {
      if (landmarks[type] == null || !ExerciseBase.isLandmarkConfident(landmarks[type]!)) {
        return "Các điểm khớp bị khuất. Hãy ngồi trọn trong khung hình.";
      }
    }
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final shoulder = isLeftTracked ? landmarks[PoseLandmarkType.leftShoulder] : landmarks[PoseLandmarkType.rightShoulder];
    final hip      = isLeftTracked ? landmarks[PoseLandmarkType.leftHip]      : landmarks[PoseLandmarkType.rightHip];
    final knee     = isLeftTracked ? landmarks[PoseLandmarkType.leftKnee]     : landmarks[PoseLandmarkType.rightKnee];
    final heel     = isLeftTracked ? landmarks[PoseLandmarkType.leftHeel]     : landmarks[PoseLandmarkType.rightHeel];

    if (shoulder == null || hip == null || knee == null || heel == null) return false;
    double ah = calculateAngleNormalized(firstPoint: shoulder, midPoint: hip, lastPoint: knee);
    double ak = calculateAngleNormalized(firstPoint: hip, midPoint: knee, lastPoint: heel);
    return ak >= SeatedForwardConfig.Ak_Start_Knee_Angle && 
           ah >= SeatedForwardConfig.Ah_Start_Hip_Angle[0] && 
           ah <= SeatedForwardConfig.Ah_Start_Hip_Angle[1];
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final ear      = isLeftTracked ? smoothedLandmarks[PoseLandmarkType.leftEar]      : smoothedLandmarks[PoseLandmarkType.rightEar];
    final shoulder = isLeftTracked ? smoothedLandmarks[PoseLandmarkType.leftShoulder] : smoothedLandmarks[PoseLandmarkType.rightShoulder];
    final hip      = isLeftTracked ? smoothedLandmarks[PoseLandmarkType.leftHip]      : smoothedLandmarks[PoseLandmarkType.rightHip];
    final knee     = isLeftTracked ? smoothedLandmarks[PoseLandmarkType.leftKnee]     : smoothedLandmarks[PoseLandmarkType.rightKnee];
    final heel     = isLeftTracked ? smoothedLandmarks[PoseLandmarkType.leftHeel]     : smoothedLandmarks[PoseLandmarkType.rightHeel];
    final toe      = isLeftTracked ? smoothedLandmarks[PoseLandmarkType.leftFootIndex] : smoothedLandmarks[PoseLandmarkType.rightFootIndex];

    if (ear == null || shoulder == null || hip == null || knee == null || heel == null || toe == null) return;

    double ah = calculateAngleNormalized(firstPoint: shoulder, midPoint: hip, lastPoint: knee);
    
    if (_lastHipAngle >= 0 && _lastTimestampMs > 0) {
      double dt = (frameTimestampMs - _lastTimestampMs) / 1000.0;
      if (dt > 0) {
        _currentVelocity = (ah - _lastHipAngle) / dt;
      }
    }
    _lastHipAngle = ah;
    _lastTimestampMs = frameTimestampMs;

    final scaleFactor = calculateDistance(shoulder, hip);

    final ctx = SeatedForwardContext(
      kneeAngle: calculateAngleNormalized(firstPoint: hip, midPoint: knee, lastPoint: heel), 
      hipAngle: ah, 
      hipVelocity: _currentVelocity,
      spineAngle: calculateAngleNormalized(firstPoint: ear, midPoint: shoulder, lastPoint: hip), 
      ankleAngle: calculateAngleNormalized(firstPoint: knee, midPoint: heel, lastPoint: toe), 
      scaleFactor: scaleFactor,
      state: state,
      frameTimestampMs: frameTimestampMs,
      resultIssues: resultIssues,
    );

    _updateStateBuffer(ctx);

    if (state != SeatedForwardState.setup) {
      for (final m in _metrics) {
        m.update(ctx);
        debugData.addAll(m.debugData);
      }
    }
  }

  void _updateStateBuffer(SeatedForwardContext ctx) {
    SeatedForwardState newState = state;

    switch (state) {
      case SeatedForwardState.setup:
        if (ctx.hipAngle < SeatedForwardConfig.Ah_Start_Hip_Angle[0] && ctx.hipVelocity < -10.0) {
          newState = SeatedForwardState.descending;
        }
        break;
      
      case SeatedForwardState.descending:
        if (ctx.hipAngle < _minHipAngleThisRep) {
          _minHipAngleThisRep = ctx.hipAngle;
        }
        
        double targetDepth = _userMaxRom != null ? _userMaxRom! * 1.15 : 120.0;
        
        if (ctx.hipAngle < targetDepth && 
            ctx.hipVelocity.abs() < SeatedForwardConfig.Av_Stable_Velocity) {
              
          if (_stableStartTimeMs == null) {
            _stableStartTimeMs = ctx.frameTimestampMs;
          } else if (ctx.frameTimestampMs - _stableStartTimeMs! >= 2000) {
            newState = SeatedForwardState.isometricHold;
            _stableStartTimeMs = null;
          }
        } else {
          _stableStartTimeMs = null; 
        }
        break;

      case SeatedForwardState.isometricHold:
        if (ctx.hipAngle < _minHipAngleThisRep) {
          _minHipAngleThisRep = ctx.hipAngle;
        }
        if (ctx.hipAngle > _minHipAngleThisRep + SeatedForwardConfig.Ascending_Threshold) {
          newState = SeatedForwardState.ascending;
        }
        break;

      case SeatedForwardState.ascending:
        if (ctx.hipAngle > SeatedForwardConfig.Ah_Start_Hip_Angle[0] - 10) {
          newState = SeatedForwardState.setup;
        }
        break;
    }

    if (newState != state) {
      for (final m in _metrics) {
        m.onStateTransition(state, newState, ctx.frameTimestampMs);
      }
      prevState = state;
      state = newState;

      if (state == SeatedForwardState.setup && prevState == SeatedForwardState.ascending) {
        _completeRep(ctx);
      }
    }
  }

  void _completeRep(SeatedForwardContext ctx) {
    repCount += 1;
    _lastMaxDepth = _minHipAngleThisRep;
    if (_userMaxRom == null || _lastMaxDepth < _userMaxRom!) {
      _userMaxRom = _lastMaxDepth;
    }

    final allFaults = <FaultRecord>[
      ...kneeMetric.faults, ...spineMetric.faults, 
      ...tempoMetric.faults, ...ankleMetric.faults,
    ];
    
    correctForm = !allFaults.any((f) => 
      f.priority == SeatedForwardFaultVoicePriority.kneeBent || 
      f.priority == SeatedForwardFaultVoicePriority.spineRound);

    logger.addRepLog(RepLog(
      repNumber: repCount,
      correctForm: correctForm,
      data: {
        "max_depth_angle": _lastMaxDepth,
        "hold_time": tempoMetric.activeHoldSeconds, 
        "fault_types": allFaults.map((f) => f.type).toSet().toList(),
      },
    ));

    _minHipAngleThisRep = 999.0;
    _stableStartTimeMs = null;
    for (final m in _metrics) {
      m.resetAndCountFault();
    }
  }

  @override
  String get currentPhaseKey => state.name;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case SeatedForwardState.setup:    return 'Chuẩn bị';
      case SeatedForwardState.descending: return 'Gập người';
      case SeatedForwardState.isometricHold: return 'Giữ tĩnh';
      case SeatedForwardState.ascending:  return 'Nhả cơ';
    }
  }

  @override
  void onSetComplete() {
    logger.pushKey("knee_bent_fails_count", kneeMetric.faultsCount);
    logger.pushKey("spine_round_fails_count", spineMetric.faultsCount);
    logger.pushKey("tempo_fails_count", tempoMetric.faultsCount);
  }
}