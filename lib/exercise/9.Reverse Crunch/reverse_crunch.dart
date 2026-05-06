// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/frame_snapshot.dart';
import '../exercise_base.dart';
import 'metrics/reverse_crunch_metric_base.dart';
import 'metrics/swinging_momentum_metric.dart';
import 'metrics/pelvic_curl_metric.dart';
import 'metrics/eccentric_tempo_metric.dart';

class ReverseCrunch extends ExerciseBase {
  @override
  String get exerciseName => 'Reverse Crunch';

  ReverseCrunchState crunchState = ReverseCrunchState.lying;
  ReverseCrunchState previousState = ReverseCrunchState.lying;
  int? _exerciseStartTimeMs;
  bool _isTimeout = false;
  double? _baselineTrunkKneeAngle;

  final SwingingMomentumMetric momentumMetric = SwingingMomentumMetric();
  final PelvicCurlMetric curlMetric = PelvicCurlMetric();
  final EccentricTempoMetric tempoMetric = EccentricTempoMetric();
  
  late final List<ReverseCrunchMetricBase> _metrics = [
    momentumMetric, curlMetric, tempoMetric
  ];

  // =========================================================================
  // FIX: THÊM CÁC OVERRIDE BẮT BUỘC TỪ ExerciseBase
  // =========================================================================
  @override
  String get currentPhaseKey => crunchState.name;

  @override
  String get currentPhaseLabel {
    switch (crunchState) {
      case ReverseCrunchState.lying: return 'Nằm chuẩn bị';
      case ReverseCrunchState.curling: return 'Cuộn lên';
      case ReverseCrunchState.top: return 'Đỉnh';
      case ReverseCrunchState.lowering: return 'Hạ xuống';
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return "Vui lòng đặt camera quay ngang (Side View).";
    }
    return null;
  }
  // =========================================================================

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = _getLandmarks(landmarks);
    if (lm == null) return false;
    
    double kneeAngle = calculateAngleNormalized(firstPoint: lm['hip']!, midPoint: lm['knee']!, lastPoint: lm['ankle']!);
    // Đánh giá góc người so với mặt sàn. (Mặt sàn ~ phương ngang)
    double trunkHorizontalAngle = calculateAngleToHorizontal(lm['shoulder']!, lm['hip']!);
    
    debugData['Setup_Diagnostic'] = {
      'kneeAngle': kneeAngle.toStringAsFixed(1),
      'trunkHorizontal': trunkHorizontalAngle.toStringAsFixed(1),
      'isKneeLocked': kneeAngle >= ReverseCrunchConfig.SETUP_KNEE_ANGLE_RANGE[0] && kneeAngle <= ReverseCrunchConfig.SETUP_KNEE_ANGLE_RANGE[1],
      'isLyingFlat': trunkHorizontalAngle < 15.0,
    };

    if (kneeAngle < ReverseCrunchConfig.SETUP_KNEE_ANGLE_RANGE[0] || kneeAngle > ReverseCrunchConfig.SETUP_KNEE_ANGLE_RANGE[1]) return false;
    if (trunkHorizontalAngle > 15.0) return false;
    return true;
  }

  @override
  bool requestStop() {
    if (_exerciseStartTimeMs != null && (frameTimestampMs - _exerciseStartTimeMs!) > ReverseCrunchConfig.MAX_DURATION_MS) {
      _isTimeout = true;
      return true;
    }
    return repCount >= ReverseCrunchConfig.MAX_REP;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    _exerciseStartTimeMs ??= frameTimestampMs;
    final now = frameTimestampMs;
    final lm = _getLandmarks(landmarks);
    if (lm == null) return;
    
    scaleFactor = calculateDistance(lm['shoulder']!, lm['hip']!);
    if (scaleFactor == 0) scaleFactor = 1;

    double trunkKneeAngle = calculateAngleNormalized(firstPoint: lm['shoulder']!, midPoint: lm['hip']!, lastPoint: lm['knee']!);
    double kneeAngle = calculateAngleNormalized(firstPoint: lm['hip']!, midPoint: lm['knee']!, lastPoint: lm['ankle']!);

    if (crunchState == ReverseCrunchState.lying) {
      _baselineTrunkKneeAngle = trunkKneeAngle;
    }

    // Dùng FrameBuffer để tính vận tốc cuộn (TrunkKneeAngle)
    frameBuffer.addFrame(FrameSnapshot(log: {"trunkKneeAngle": trunkKneeAngle}, timeStamp: now));
    double trunkKneeVelocity = _calculateVelocityFromBuffer("trunkKneeAngle");

    debugData['Diagnostic_Table'] = {
      'State': crunchState.name,
      'Time_s': ((now - _exerciseStartTimeMs!) / 1000).toStringAsFixed(1),
      'TrunkKneeAngle': trunkKneeAngle.toStringAsFixed(1),
      'KneeAngle': kneeAngle.toStringAsFixed(1),
      'TrunkKneeVel': trunkKneeVelocity.toStringAsFixed(2),
      'Hip_Y': lm['hip']!.y.toStringAsFixed(1),
    };

    final ctx = RepContext(
      state: crunchState, frameTimestamp: now, scaleFactor: scaleFactor,
      trunkKneeAngle: trunkKneeAngle, kneeAngle: kneeAngle,
      hipY: lm['hip']!.y, trunkKneeVelocity: trunkKneeVelocity,
      resultIssues: resultIssues,
    );

    _updateStateMachine(ctx);
    for (final metric in _metrics) {
      metric.update(ctx);
      debugData.addAll(metric.debugData);
    }
  }

  void _updateStateMachine(RepContext ctx) {
    if (_baselineTrunkKneeAngle == null) return;

    // Curling: Góc bắt đầu giảm đi đang cuộn vào (velocity âm)
    if (crunchState == ReverseCrunchState.lying && 
        ctx.trunkKneeAngle < _baselineTrunkKneeAngle! - ReverseCrunchConfig.LIFT_START_ANGLE_DROP && 
        ctx.trunkKneeVelocity < -15.0) {
      _transitionState(ReverseCrunchState.curling, ctx.frameTimestamp);
    } 
    // Top: Dừng góc, góc bắt đầu có chiều hướng mở ra (velocity đảo chiều sang dương)
    else if (crunchState == ReverseCrunchState.curling && ctx.trunkKneeVelocity > 5.0) {
      _transitionState(ReverseCrunchState.top, ctx.frameTimestamp);
      // Tự động nhảy sang lowering ngay sau điểm TOP thường chỉ là 1 khoảnh khắc
      Future.delayed(Duration(milliseconds: 100), () {
        if (crunchState == ReverseCrunchState.top) {
          _transitionState(ReverseCrunchState.lowering, ctx.frameTimestamp);
        }
      });
    }
    // Lying: Đã trở về setup
    else if (crunchState == ReverseCrunchState.lowering && 
             ctx.trunkKneeAngle >= _baselineTrunkKneeAngle! - 5.0) {
      _completeRep(ctx);
    }
  }

  void _transitionState(ReverseCrunchState newState, int timestampMs) {
    if (newState == crunchState) return;
    previousState = crunchState;
    crunchState = newState;
    for (final metric in _metrics) metric.onStateTransition(previousState, newState, timestampMs);
  }

  void _completeRep(RepContext ctx) {
    repCount++;
    for (final metric in _metrics) metric.evaluateRepEnd(ctx);
    
    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) allFaults.addAll(metric.faults);
    
    correctForm = !allFaults.any((f) => f.affectsForm);
    _transitionState(ReverseCrunchState.lying, ctx.frameTimestamp);
    for (final metric in _metrics) metric.resetAndCountFault();
  }

  double _calculateVelocityFromBuffer(String key) {
    if (frameBuffer.frameBuffer.length < 3) return 0;
    var last = frameBuffer.frameBuffer.last;
    var first = frameBuffer.frameBuffer.first;
    double dAngle = (last.log[key] as num).toDouble() - (first.log[key] as num).toDouble();
    double dt = (last.timeStamp - first.timeStamp) / 1000.0;
    return dt == 0 ? 0 : dAngle / dt; // degrees per second
  }

  Map<String, PoseLandmark>? _getLandmarks(Map<PoseLandmarkType, PoseLandmark> lm) {
    return {
      'shoulder': lm[PoseLandmarkType.leftShoulder]!,
      'hip': lm[PoseLandmarkType.leftHip]!,
      'knee': lm[PoseLandmarkType.leftKnee]!,
      'ankle': lm[PoseLandmarkType.leftAnkle]!,
    };
  }

  @override
  void onSetComplete() {
    logger.pushKey("timeout", _isTimeout);
    logger.pushKey("momentum_fails", momentumMetric.faultsCount);
    logger.pushKey("curl_fails", curlMetric.faultsCount);
    logger.pushKey("tempo_fails", tempoMetric.faultsCount);
    logger.pushGoodRepCount();
  }
}