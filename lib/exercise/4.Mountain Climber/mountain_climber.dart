// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/frame_snapshot.dart';
import '../exercise_base.dart';
import 'metrics/mountain_climber_metric_base.dart';
import 'metrics/trunk_stability_metric.dart';
import 'metrics/knee_drive_rom_metric.dart';
// import 'metrics/pace_metric.dart'; // Tuỳ chọn thêm

class MountainClimber extends ExerciseBase {
  @override
  String get exerciseName => 'Mountain Climber';

  @override
  String get currentPhaseKey => climberState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (climberState) {
      case ClimberState.high_plank_base: return 'Chuẩn bị';
      case ClimberState.knee_driving_in: return 'Kéo gối lên';
      case ClimberState.max_flexion: return 'Chạm đỉnh';
      case ClimberState.knee_driving_out: return 'Duỗi chân về';
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    return null; // No specific safety check for this exercise yet.
  }

  ClimberState climberState = ClimberState.high_plank_base;
  ClimberState previousState = ClimberState.high_plank_base;
  
  int? _exerciseStartTimeMs;
  bool _isTimeout = false;

  final TrunkStabilityMetric trunkMetric = TrunkStabilityMetric();
  final KneeDriveRomMetric romMetric = KneeDriveRomMetric();
  late final List<ClimberMetricBase> _metrics = [trunkMetric, romMetric];

  // --- Start Position ---
  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = _getLandmarks(landmarks);
    if (lm == null) return false;

    double armAngle = calculateAngleNormalized(firstPoint: lm['shoulder']!, midPoint: lm['elbow']!, lastPoint: lm['wrist']!);
    double trunkAngle = calculateAngleNormalized(firstPoint: lm['shoulder']!, midPoint: lm['hip']!, lastPoint: lm['ankle']!);

    // Bảng Diagnostic cho Setup Phase
    debugData['Setup_Diagnostic'] = {
      'armAngle': armAngle.toStringAsFixed(1),
      'trunkAngle': trunkAngle.toStringAsFixed(1),
      'isArmStraight': armAngle > ClimberConfig.ARM_STRAIGHT_THRESHOLD,
      'isTrunkStraight': trunkAngle >= ClimberConfig.TRUNK_STRAIGHT_RANGE[0] && trunkAngle <= ClimberConfig.TRUNK_STRAIGHT_RANGE[1],
    };

    if (armAngle <= ClimberConfig.ARM_STRAIGHT_THRESHOLD) return false;
    if (trunkAngle < ClimberConfig.TRUNK_STRAIGHT_RANGE[0] || trunkAngle > ClimberConfig.TRUNK_STRAIGHT_RANGE[1]) return false;

    return true;
  }

  // --- Stop Condition ---
  @override
  bool requestStop() {
    if (_exerciseStartTimeMs != null && (frameTimestampMs - _exerciseStartTimeMs!) > ClimberConfig.MAX_DURATION_MS) {
      _isTimeout = true;
      return true;
    }
    return repCount >= ClimberConfig.MAX_REP;
  }

  // --- Main Loop ---
  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    _exerciseStartTimeMs ??= frameTimestampMs;
    final now = frameTimestampMs;

    final lm = _getLandmarks(landmarks);
    if (lm == null) return;

    // Geometry
    final shoulder = lm['shoulder']!;
    final hip = lm['hip']!;
    final activeKnee = lm['knee']!; // Simplify: Assume we are tracking the closest side
    
    scaleFactor = calculateDistance(shoulder, hip);
    double armAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: lm['elbow']!, lastPoint: lm['wrist']!);
    double trunkAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: hip, lastPoint: lm['ankle']!);

    // Ghi buffer để tính vận tốc (Knee X Velocity)
    frameBuffer.addFrame(FrameSnapshot(log: {"kneeX": activeKnee.x}, timeStamp: now));
    
    // Tính velocity: (X_hiện_tại - X_trước_đó) / dt. 
    // Nếu đối mặt bên phải, X giảm nghĩa là gối tiến về ngực.
    double kneeVel = _calculateVelocityFromBuffer("kneeX");

    // --- BẢNG CHẨN ĐOÁN (DIAGNOSTIC TABLE) ---
    // Log toàn bộ dữ liệu ra màn hình/file để biết vì sao kẹt state
    debugData['Diagnostic_Table'] = {
      'State': climberState.name,
      'TimeElapsed_s': ((now - _exerciseStartTimeMs!) / 1000).toStringAsFixed(1),
      'ArmAngle': armAngle.toStringAsFixed(1),
      'TrunkAngle': trunkAngle.toStringAsFixed(1),
      'Hip_Y': hip.y.toStringAsFixed(1),
      'Knee_X': activeKnee.x.toStringAsFixed(1),
      'Shoulder_X': shoulder.x.toStringAsFixed(1),
      'Knee_Vel_X': kneeVel.toStringAsFixed(3),
      'ScaleFactor': scaleFactor.toStringAsFixed(1),
    };

    // Build Context
    final ctx = RepContext(
      state: climberState,
      frameTimestamp: now,
      scaleFactor: scaleFactor,
      armAngle: armAngle,
      trunkAngle: trunkAngle,
      hipY: hip.y,
      shoulderX: shoulder.x,
      hipX: hip.x,
      activeKneeX: activeKnee.x,
      activeKneeXVelocity: kneeVel,
      resultIssues: resultIssues,
    );

    _updateStateMachine(ctx);

    // Run metrics
    for (final metric in _metrics) {
      metric.update(ctx);
      debugData.addAll(metric.debugData);
    }
  }

  void _updateStateMachine(RepContext ctx) {
    // Logic đổi state dựa vào vận tốc Knee X
    bool isMovingIn = ctx.activeKneeXVelocity.abs() > ClimberConfig.KNEE_VELOCITY_THRESHOLD; // Giả sử cam quay phải, X giảm
    bool isStopped = ctx.activeKneeXVelocity.abs() <= ClimberConfig.KNEE_VELOCITY_THRESHOLD;

    if (climberState == ClimberState.high_plank_base && isMovingIn) {
      _transitionState(ClimberState.knee_driving_in, ctx.frameTimestamp);
    } 
    else if (climberState == ClimberState.knee_driving_in && isStopped) {
      _transitionState(ClimberState.max_flexion, ctx.frameTimestamp);
    }
    else if (climberState == ClimberState.max_flexion && isMovingIn) { // Đảo chiều X
      _transitionState(ClimberState.knee_driving_out, ctx.frameTimestamp);
    }
    else if (climberState == ClimberState.knee_driving_out && isStopped) {
      _completeRep(ctx);
    }
  }

  void _transitionState(ClimberState newState, int timestampMs) {
    if (newState == climberState) return;
    previousState = climberState;
    climberState = newState;
    
    for (final metric in _metrics) metric.onStateTransition(previousState, newState, timestampMs);
  }

  void _completeRep(RepContext ctx) {
    repCount++;
    romMetric.evaluateRepEnd(ctx);

    // Thu thập Faults
    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) allFaults.addAll(metric.faults);
    
    correctForm = !allFaults.any((f) => f.affectsForm);

    _transitionState(ClimberState.high_plank_base, ctx.frameTimestamp);
    for (final metric in _metrics) metric.resetAndCountFault();
  }

  double _calculateVelocityFromBuffer(String key) {
    if (frameBuffer.frameBuffer.length < 2) return 0;
    var last = frameBuffer.frameBuffer.last;
    var first = frameBuffer.frameBuffer.first; // Hoặc n frames trước
    double dx = (last.log[key] as num).toDouble() - (first.log[key] as num).toDouble();
    double dt = (last.timeStamp - first.timeStamp) / 1000.0;
    return dt == 0 ? 0 : dx / dt;
  }

  Map<String, PoseLandmark>? _getLandmarks(Map<PoseLandmarkType, PoseLandmark> lm) {
    // Trích xuất ưu tiên side đang quay cam. (Logic tương tự squat _buildRequiredLandmarksForSide)
    // Cần: shoulder, elbow, wrist, hip, knee, ankle
    return {
      'shoulder': lm[PoseLandmarkType.leftShoulder]!,
      'elbow': lm[PoseLandmarkType.leftElbow]!,
      'wrist': lm[PoseLandmarkType.leftWrist]!,
      'hip': lm[PoseLandmarkType.leftHip]!,
      'knee': lm[PoseLandmarkType.leftKnee]!,
      'ankle': lm[PoseLandmarkType.leftAnkle]!,
    };
  }

  @override
  void onSetComplete() {
    logger.pushKey("timeout_triggered", _isTimeout);
    logger.pushKey("trunk_fails_count", trunkMetric.faultsCount);
    logger.pushKey("rom_fails_count", romMetric.faultsCount);
    logger.pushGoodRepCount();
  }
}