// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/debouncer.dart';
import '../exercise_base.dart';
import 'metrics/superman_metric_base.dart';
import 'metrics/limb_elevation_metric.dart';
import 'metrics/hip_grounding_metric.dart';
import 'metrics/hold_time_metric.dart';
import 'metrics/lumbar_extension_metric.dart';

class Superman extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'Superman';

  SupermanState superState = SupermanState.setup;
  SupermanState previousState = SupermanState.setup;
  int? _startTimeMs;
  bool _isTimeout = false;
  double? _baselineHipY; // Biến lưu vị trí hông ban đầu để so sánh khi nâng người

  final LimbElevationMetric elevationMetric = LimbElevationMetric();
  final HipGroundingMetric hipMetric = HipGroundingMetric();
  final HoldTimeMetric holdMetric = HoldTimeMetric();
  final LumbarExtensionMetric lumbarMetric = LumbarExtensionMetric();

  late final List<SupermanMetricBase> _metrics = [
    elevationMetric, 
    hipMetric, 
    holdMetric, 
    lumbarMetric
  ];
  
  final Debouncer _liftDebouncer = Debouncer(requiredFrames: 3);
  final Debouncer _lowerDebouncer = Debouncer(requiredFrames: 3);

  @override
  String get currentPhaseKey => superState.name;

  @override
  String get currentPhaseLabel {
    switch (superState) {
      case SupermanState.setup: return 'Nằm sấp';
      case SupermanState.lifting: return 'Nâng lên';
      case SupermanState.hold: return 'Giữ';
      case SupermanState.lowering: return 'Hạ xuống';
    }
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front)
      return "Hãy quay ngang người theo đúng tay vươn.";
    return null;
  }

  // Ràng buộc BẮT BUỘC nằm sấp (Prone)
  bool _isProne(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final nose = landmarks[PoseLandmarkType.nose];
    final ear = landmarks[PoseLandmarkType.leftEar] ?? landmarks[PoseLandmarkType.rightEar];
    
    if (nose != null && ear != null) {
      // Trục Y hướng xuống. Nằm sấp thì mũi thường hướng xuống đất hoặc ngang bằng -> (nose.y >= ear.y).
      // Biên độ bù trừ góc camera 0.05
      return nose.y > (ear.y - 0.05); 
    }
    return true; 
  }

  // Lấy độ cao THẤP NHẤT giữa bên trái và bên phải (Bắt buộc nhấc cả 2 bên)
  double _getStrictLimbElevation(
      PoseLandmark? leftJoint, PoseLandmark? rightJoint, 
      PoseLandmark? leftBase, PoseLandmark? rightBase, 
      double scaleFactor) {
    
    List<double> elevations = [];
    // Tính khi landmark có độ tin cậy > 0.3
    if (leftJoint != null && leftBase != null && leftJoint.likelihood > 0.3) {
      elevations.add((leftBase.y - leftJoint.y) / scaleFactor);
    }
    if (rightJoint != null && rightBase != null && rightJoint.likelihood > 0.3) {
      elevations.add((rightBase.y - rightJoint.y) / scaleFactor);
    }
    
    if (elevations.isEmpty) return 0.0;
    // Trả về mức nâng thấp nhất để ép người dùng phải nhấc cả hai bên
    return elevations.reduce((a, b) => a < b ? a : b); 
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = _getLandmarks(landmarks);
    if (lm == null) return false;

    // Chặn trường hợp nằm ngửa gập bụng
    if (!_isProne(landmarks)) return false;

    final shoulderHipDiff = (lm['shoulder']!.y - lm['hip']!.y).abs();
    final torso = calculateDistance(lm['shoulder']!, lm['hip']!);
    
    bool isHorizontal = torso > 0 && shoulderHipDiff / torso < 0.25;
    
    // Lưu lại vị trí hông lúc thả lỏng làm mốc
    if (isHorizontal) {
      _baselineHipY = lm['hip']!.y;
    }
    
    return isHorizontal;
  }

  @override
  bool requestStop() {
    if (_startTimeMs != null && (frameTimestampMs - _startTimeMs!) > SupermanConfig.MAX_DURATION_MS) {
      _isTimeout = true;
      return true;
    }
    return repCount >= SupermanConfig.MAX_REP;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    _startTimeMs ??= frameTimestampMs;
    final now = frameTimestampMs;
    
    final lm = _getLandmarks(landmarks);
    if (lm == null) return;

    scaleFactor = calculateDistance(lm['shoulder']!, lm['hip']!);
    if (scaleFactor == 0) scaleFactor = 1;

    // Tính toán khắt khe: Bắt buộc nhấc cả 2 tay và 2 chân
    final armElevation = _getStrictLimbElevation(
      landmarks[PoseLandmarkType.leftWrist], landmarks[PoseLandmarkType.rightWrist],
      landmarks[PoseLandmarkType.leftShoulder], landmarks[PoseLandmarkType.rightShoulder],
      scaleFactor
    );

    final legElevation = _getStrictLimbElevation(
      landmarks[PoseLandmarkType.leftAnkle], landmarks[PoseLandmarkType.rightAnkle],
      landmarks[PoseLandmarkType.leftHip], landmarks[PoseLandmarkType.rightHip],
      scaleFactor
    );

    // Tính toán độ nâng hông (Chống hít đất/plank)
    double hipElevation = 0.0;
    if (_baselineHipY != null) {
      hipElevation = (_baselineHipY! - lm['hip']!.y) / scaleFactor;
      if (hipElevation < 0) hipElevation = 0.0; 
    }

    final spineAngle = calculateHorizontalAngle(point1: lm['shoulder']!, point2: lm['hip']!);

    debugData['arm_elev'] = armElevation.toStringAsFixed(3);
    debugData['leg_elev'] = legElevation.toStringAsFixed(3);
    debugData['hip_elev'] = hipElevation.toStringAsFixed(3);
    debugData['state'] = superState.name;

    final ctx = SupermanRepContext(
      armElevation: armElevation,
      legElevation: legElevation,
      hipElevation: hipElevation, 
      spineAngle: spineAngle,
      scaleFactor: scaleFactor,
      currentState: superState,
      frameTimestampMs: now,
      resultIssues: resultIssues,
    );

    _updateStateMachine(ctx);

    for (final m in _metrics) {
      m.update(ctx);
      debugData.addAll(m.debugData);
    }
  }

  void _updateStateMachine(SupermanRepContext ctx) {
    bool isLifted = ctx.armElevation > SupermanConfig.LIFT_THRESHOLD &&
                    ctx.legElevation > SupermanConfig.LIFT_THRESHOLD;
    bool isLowered = ctx.armElevation <= 0 && ctx.legElevation <= 0;

    switch (superState) {
      case SupermanState.setup:
        if (_liftDebouncer.update(isLifted)) _transition(SupermanState.lifting, ctx.frameTimestampMs);
        break;
      case SupermanState.lifting:
        if (isLifted) _transition(SupermanState.hold, ctx.frameTimestampMs);
        break;
      case SupermanState.hold:
        if (_lowerDebouncer.update(!isLifted)) _transition(SupermanState.lowering, ctx.frameTimestampMs);
        break;
      case SupermanState.lowering:
        if (isLowered) _completeRep(ctx);
        break;
    }
  }

  void _transition(SupermanState to, int ts) {
    if (to == superState) return;
    final from = superState;
    superState = to;
    for (final m in _metrics) m.onStateTransition(from, to, ts);
  }

  void _completeRep(SupermanRepContext ctx) {
    repCount++;
    for (final m in _metrics) m.evaluateRepEnd(ctx);

    final faults = <FaultRecord>[];
    for (final m in _metrics) faults.addAll(m.faults);
    correctForm = !faults.any((f) => f.affectsForm);

    _transition(SupermanState.setup, ctx.frameTimestampMs);
    for (final m in _metrics) m.resetAndCountFault();
  }

  @override
  void onSetComplete() {
    logger.pushKey("timeout", _isTimeout);
    logger.pushKey("elevation_fails", elevationMetric.faultsCount);
    logger.pushKey("hip_fails", hipMetric.faultsCount);
    logger.pushKey("hold_fails", holdMetric.faultsCount);
    logger.pushKey("lumbar_fails", lumbarMetric.faultsCount); 
    logger.pushGoodRepCount();
  }

  Map<String, PoseLandmark>? _getLandmarks(Map<PoseLandmarkType, PoseLandmark> lm) {
    final shoulder = lm[PoseLandmarkType.leftShoulder] ?? lm[PoseLandmarkType.rightShoulder];
    final hip      = lm[PoseLandmarkType.leftHip]      ?? lm[PoseLandmarkType.rightHip];
    final wrist    = lm[PoseLandmarkType.leftWrist]    ?? lm[PoseLandmarkType.rightWrist];
    final ankle    = lm[PoseLandmarkType.leftAnkle]    ?? lm[PoseLandmarkType.rightAnkle];

    if (shoulder == null || hip == null || wrist == null || ankle == null) return null;
    return {'shoulder': shoulder, 'hip': hip, 'wrist': wrist, 'ankle': ankle};
  }
}