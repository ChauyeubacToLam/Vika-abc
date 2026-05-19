// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/frame_snapshot.dart';
import '../exercise_base.dart';
import 'metrics/lying_leg_raise_metric_base.dart';
import 'metrics/lumbar_arching_metric.dart';
import 'metrics/vertical_leg_rom_metric.dart';
import 'metrics/eccentric_lowering_tempo_metric.dart';
import 'metrics/knee_straight_metric.dart';

class LyingLegRaise extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'Lying Leg Raise';

  @override
  String get currentPhaseKey => raiseState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (raiseState) {
      case LyingLegRaiseState.lying: return 'Chuẩn bị';
      case LyingLegRaiseState.raising: return 'Đang nâng';
      case LyingLegRaiseState.top: return 'Đỉnh điểm';
      case LyingLegRaiseState.lowering: return 'Hạ có kiểm soát';
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    return null; // No specific safety check for this exercise yet.
  }

  LyingLegRaiseState raiseState = LyingLegRaiseState.lying;
  LyingLegRaiseState previousState = LyingLegRaiseState.lying;

  int? _exerciseStartTimeMs;
  bool _isTimeout = false;

  final LumbarArchingMetric archMetric = LumbarArchingMetric();
  final VerticalLegRomMetric romMetric = VerticalLegRomMetric();
  final EccentricLoweringTempoMetric tempoMetric = EccentricLoweringTempoMetric();
  final KneeStraightMetric kneeMetric = KneeStraightMetric();

  late final List<LyingLegRaiseMetricBase> _metrics = [
    archMetric, romMetric, tempoMetric, kneeMetric
  ];

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = _getLandmarks(landmarks);
    if (lm == null) return false;

    double kneeAngle = calculateAngleNormalized(firstPoint: lm['hip']!, midPoint: lm['knee']!, lastPoint: lm['ankle']!);
    double trunkHorizontalAngle = calculateAngleToHorizontal(lm['shoulder']!, lm['hip']!).abs();
    double legHorizontalAngle = calculateAngleToHorizontal(lm['hip']!, lm['ankle']!).abs();

    debugData['Setup_Diagnostic'] = {
      'trunkHorizontal': trunkHorizontalAngle.toStringAsFixed(1),
      'kneeAngle': kneeAngle.toStringAsFixed(1),
      'legHorizontal': legHorizontalAngle.toStringAsFixed(1),
      'isBodyFlat': trunkHorizontalAngle < LegRaiseConfig.TRUNK_FLAT_TOLERANCE,
      'isKneeStraight': kneeAngle >= LegRaiseConfig.KNEE_STRAIGHT_SETUP,
    };

    // Body nằm sát đất (góc Vai-Hông so với sàn < 15 độ) và gối thẳng
    if (trunkHorizontalAngle > LegRaiseConfig.TRUNK_FLAT_TOLERANCE) return false;
    if (kneeAngle < LegRaiseConfig.KNEE_STRAIGHT_SETUP) return false;
    // Chân phải ở trạng thái thấp (gần sàn)
    if (legHorizontalAngle > 30.0) return false;

    return true;
  }

  @override
  bool requestStop() {
    if (_exerciseStartTimeMs != null && (frameTimestampMs - _exerciseStartTimeMs!) > LegRaiseConfig.MAX_DURATION_MS) {
      _isTimeout = true;
      return true;
    }
    return repCount >= LegRaiseConfig.MAX_REP;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    _exerciseStartTimeMs ??= frameTimestampMs;
    final now = frameTimestampMs;

    final lm = _getLandmarks(landmarks);
    if (lm == null) return;

    scaleFactor = calculateDistance(lm['shoulder']!, lm['hip']!);
    if (scaleFactor == 0) scaleFactor = 1;

    double trunkHorizontalAngle = calculateAngleToHorizontal(lm['shoulder']!, lm['hip']!).abs();
    double legHorizontalAngle = calculateAngleToHorizontal(lm['hip']!, lm['ankle']!).abs();
    double kneeAngle = calculateAngleNormalized(firstPoint: lm['hip']!, midPoint: lm['knee']!, lastPoint: lm['ankle']!);

    // Tính vận tốc góc (Angular velocity của chân)
    frameBuffer.addFrame(FrameSnapshot(log: {"legAngle": legHorizontalAngle}, timeStamp: now));
    double legVelocity = _calculateVelocityFromBuffer("legAngle");

    debugData['Diagnostic_Table'] = {
      'State': raiseState.name,
      'Time_s': ((now - _exerciseStartTimeMs!) / 1000).toStringAsFixed(1),
      'LegAngle': legHorizontalAngle.toStringAsFixed(1),
      'TrunkAngle': trunkHorizontalAngle.toStringAsFixed(1),
      'KneeAngle': kneeAngle.toStringAsFixed(1),
      'LegVel': legVelocity.toStringAsFixed(2),
      'Hip_Y': lm['hip']!.y.toStringAsFixed(1),
    };

    final ctx = RepContext(
      state: raiseState, frameTimestamp: now, scaleFactor: scaleFactor,
      trunkHorizontalAngle: trunkHorizontalAngle, legHorizontalAngle: legHorizontalAngle, 
      kneeAngle: kneeAngle, hipY: lm['hip']!.y, legAngularVelocity: legVelocity,
      resultIssues: resultIssues,
    );

    _updateStateMachine(ctx);

    for (final metric in _metrics) {
      metric.update(ctx);
      debugData.addAll(metric.debugData);
    }
  }

  void _updateStateMachine(RepContext ctx) {
    // Lý thuyết: Góc tăng dần khi Lifting, đạt đỉnh (vel ~ 0), giảm dần khi Lowering
    
    if (raiseState == LyingLegRaiseState.lying && ctx.legHorizontalAngle > LegRaiseConfig.LIFT_START_ANGLE && ctx.legAngularVelocity > 5.0) {
      _transitionState(LyingLegRaiseState.raising, ctx.frameTimestamp);
    } 
    else if (raiseState == LyingLegRaiseState.raising && ctx.legAngularVelocity.abs() <= LegRaiseConfig.VELOCITY_ZERO_TOLERANCE && ctx.legHorizontalAngle > 50.0) {
      _transitionState(LyingLegRaiseState.top, ctx.frameTimestamp);
    }
    // Góc bắt đầu giảm (velocity âm)
    else if (raiseState == LyingLegRaiseState.top && ctx.legAngularVelocity < -2.0) {
      _transitionState(LyingLegRaiseState.lowering, ctx.frameTimestamp);
    }
    // Trở về sát mặt đất
    else if (raiseState == LyingLegRaiseState.lowering && ctx.legHorizontalAngle < LegRaiseConfig.LIFT_START_ANGLE) {
      _completeRep(ctx);
    }
  }

  void _transitionState(LyingLegRaiseState newState, int timestampMs) {
    if (newState == raiseState) return;
    previousState = raiseState;
    raiseState = newState;
    for (final metric in _metrics) metric.onStateTransition(previousState, newState, timestampMs);
  }

  void _completeRep(RepContext ctx) {
    repCount++;
    for (final metric in _metrics) metric.evaluateRepEnd(ctx);

    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) allFaults.addAll(metric.faults);
    correctForm = !allFaults.any((f) => f.affectsForm);

    _transitionState(LyingLegRaiseState.lying, ctx.frameTimestamp);
    for (final metric in _metrics) metric.resetAndCountFault();
  }

  double _calculateVelocityFromBuffer(String key) {
    if (frameBuffer.frameBuffer.length < 3) return 0;
    var last = frameBuffer.frameBuffer.last;
    var first = frameBuffer.frameBuffer.first;
    double dAngle = (last.log[key] as num).toDouble() - (first.log[key] as num).toDouble();
    double dt = (last.timeStamp - first.timeStamp) / 1000.0;
    return dt == 0 ? 0 : dAngle / dt; 
  }

  Map<String, PoseLandmark>? _getLandmarks(Map<PoseLandmarkType, PoseLandmark> lm) {
    // Trích xuất ưu tiên side chuẩn
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
    logger.pushKey("lumbar_fails", archMetric.faultsCount);
    logger.pushKey("rom_fails", romMetric.faultsCount);
    logger.pushKey("tempo_fails", tempoMetric.faultsCount);
    logger.pushKey("knee_fails", kneeMetric.faultsCount);
    logger.pushGoodRepCount();
  }
}