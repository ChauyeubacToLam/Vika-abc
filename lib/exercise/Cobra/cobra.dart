// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/utils/debouncer.dart';
import 'package:vika/utils/pose_math_helpers.dart';
import 'package:vika/utils/exercise_logger.dart';

import 'metrics/cobra_metric_base.dart';
import 'metrics/cobra_elevation_metric.dart';
import 'metrics/cobra_elbow_metric.dart';
import 'metrics/cobra_hand_placement_metric.dart';
import 'metrics/cobra_cervical_metric.dart';
import 'metrics/cobra_descent_metric.dart';
import 'metrics/cobra_hold_stability_metric.dart';
// --- Config ---

class CobraConfig {
  static const int MAX_REP = 3;
  static const double HOLD_DURATION = 15.0;
  static const double REST_DURATION = 5.0;

  // Hip-to-floor ratio above which user is considered standing
  static const double STANDING_HIP_FLOOR_THRESHOLD = 0.5;

  // Trunk horizontal targets per facing direction
  static const double HORIZONTAL_CLOCK_LEFT = 270.0;
  static const double HORIZONTAL_CLOCK_RIGHT = 90.0;

  // In prone position, trunk is roughly horizontal
  static const double PRONE_TOLERANCE = 25.0;

  // For Cobra holding, trunk must be elevated by at least 25 degrees from horizontal
  static const double COBRA_MIN_ELEVATION = 25.0;

  // Calibration: frames to average for baseline
  static const int CALIBRATION_FRAMES = 20;
}

enum CobraState { setup, holding, resting }

class Cobra extends ExerciseBase {
  final int maxRep;

  Cobra({this.maxRep = CobraConfig.MAX_REP});

  CobraState cobraState = CobraState.setup;
  CobraState previousCobraState = CobraState.setup;

  int? _holdStartMs;
  int? _restStartMs;

  final Debouncer _positionDebouncer = Debouncer(requiredFrames: 2);
  
  // --- All Metrics (MET-1 through MET-6) ---
  final _pelvicMetric = CobraPelvicMetric();
  final _elbowMetric = CobraElbowMetric();
  final _handPlacementMetric = CobraHandPlacementMetric();
  final _cervicalMetric = CobraCervicalMetric();
  final _descentMetric = CobraDescentMetric();
  final _holdStabilityMetric = CobraHoldStabilityMetric();

  late final List<CobraMetricBase> _metrics = [
    _elbowMetric,          // MET-1: CRITICAL
    _handPlacementMetric,  // MET-2: IMPORTANT
    _cervicalMetric,       // MET-3: CRITICAL (safety)
    _descentMetric,        // MET-4: IMPORTANT
    _pelvicMetric,         // MET-5: IMPORTANT (safety)
    _holdStabilityMetric,  // MET-6: NICE-TO-HAVE
  ];

  // --- MET-7: Calibration Baselines ---
  final List<double> _calibrationHipYSamples = [];
  final List<double> _calibrationTrunkLengthSamples = [];
  final List<double> _calibrationCervicalSamples = [];
  double? _baselineHipY;
  double? _baselineTrunkLength;
  double? _baselineCervicalAngle;
  bool _isCalibrated = false;

  @override
  String get exerciseName => 'Cobra Pose';

  @override
  String get currentPhaseKey => cobraState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (cobraState) {
      case CobraState.setup:
        return 'Chuẩn bị';
      case CobraState.holding:
        return 'Giữ!';
      case CobraState.resting:
        return 'Nghỉ';
    }
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final shoulder = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightShoulder,
      leftType: PoseLandmarkType.leftShoulder,
    );
    final hip = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightHip,
      leftType: PoseLandmarkType.leftHip,
    );

    if (shoulder == null || hip == null) return false;

    // Trunk must be roughly horizontal (within 25°) for prone setup
    double trunkClockAngle =
        calculateVerticalAngle(pivot: hip, point: shoulder);
    double horizontalTarget = cameraFacing == CameraFacing.right
        ? CobraConfig.HORIZONTAL_CLOCK_RIGHT
        : CobraConfig.HORIZONTAL_CLOCK_LEFT;
    double diff = trunkClockAngle - horizontalTarget;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    if (diff.abs() > CobraConfig.PRONE_TOLERANCE) return false;

    // --- MET-7: Calibration during hold-still activation ---
    _collectCalibrationData(landmarks, shoulder, hip);

    return true;
  }

  /// MET-7: Collect calibration data during the 3-second hold-still activation.
  void _collectCalibrationData(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    PoseLandmark shoulder,
    PoseLandmark hip,
  ) {
    // 1. Hip Y baseline
    _calibrationHipYSamples.add(hip.y);

    // 2. Trunk length (shoulder-to-hip distance)
    final trunkLen = calculateDistance(shoulder, hip);
    _calibrationTrunkLengthSamples.add(trunkLen);

    // 3. Cervical baseline (ear-shoulder angle if ear visible)
    final ear = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightEar,
      leftType: PoseLandmarkType.leftEar,
    );
    if (ear != null && ear.likelihood >= 0.5) {
      final trunkAngle = calculateVerticalAngle(pivot: hip, point: shoulder);
      final neckAngle = calculateVerticalAngle(pivot: shoulder, point: ear);
      double cervical = neckAngle - trunkAngle;
      if (cervical > 180) cervical -= 360;
      if (cervical < -180) cervical += 360;
      _calibrationCervicalSamples.add(cervical);
    }

    // Finalize when enough samples collected
    if (_calibrationHipYSamples.length >= CobraConfig.CALIBRATION_FRAMES &&
        !_isCalibrated) {
      _baselineHipY = _average(_calibrationHipYSamples);
      _baselineTrunkLength = _average(_calibrationTrunkLengthSamples);
      if (_calibrationCervicalSamples.isNotEmpty) {
        _baselineCervicalAngle = _average(_calibrationCervicalSamples);
      }
      _isCalibrated = true;
    }
  }

  double _average(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushGoodRepCount();
    logger.pushKey("max_rep", maxRep);
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return "⚠️ Xin hãy quay nghiêng để theo dõi tư thế Cobra";
    }

    PoseLandmark? shoulder = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    PoseLandmark? hip = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);

    if (shoulder == null || hip == null) {
      return "⚠️ Đảm bảo phần trên cơ thể trong khung hình";
    }

    if (!ExerciseBase.isLandmarkConfident(shoulder) ||
        !ExerciseBase.isLandmarkConfident(hip)) {
      return "⚠️ Hình ảnh không rõ. Điều chỉnh ánh sáng hoặc vị trí";
    }

    return null;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    // --- Get all landmarks ---
    PoseLandmark? shoulder = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    PoseLandmark? hip = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);

    if (shoulder == null || hip == null) return;

    PoseLandmark? elbow = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightElbow,
        leftType: PoseLandmarkType.leftElbow);
    PoseLandmark? wrist = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightWrist,
        leftType: PoseLandmarkType.leftWrist);
    PoseLandmark? ear = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightEar,
        leftType: PoseLandmarkType.leftEar);
    PoseLandmark? knee = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightKnee,
        leftType: PoseLandmarkType.leftKnee);

    // --- Trunk calculations ---
    double trunkClockAngle =
        calculateVerticalAngle(pivot: hip, point: shoulder);

    double horizontalTarget = cameraFacing == CameraFacing.right
        ? CobraConfig.HORIZONTAL_CLOCK_RIGHT
        : CobraConfig.HORIZONTAL_CLOCK_LEFT;
    
    double trunkDeviation =
        clockAngleDeviation(trunkClockAngle, horizontalTarget);

    // --- Floor & standing detection ---
    PoseLandmark? foot = smoothedLandmarks[PoseLandmarkType.leftFootIndex] ??
        smoothedLandmarks[PoseLandmarkType.rightFootIndex];
    PoseLandmark? heel = smoothedLandmarks[PoseLandmarkType.leftHeel] ??
        smoothedLandmarks[PoseLandmarkType.rightHeel];

    double floorY = foot?.y ?? heel?.y ?? knee?.y ?? hip.y;
    double hipToFloor = (floorY - hip.y).abs() / scaleFactor;
    bool isStanding = hipToFloor > CobraConfig.STANDING_HIP_FLOOR_THRESHOLD;
    
    int now = frameTimestampMs;

    _updateCobraState(trunkDeviation, now, isStanding, trunkClockAngle);

    // --- Build RepContext with all data ---
    final ctx = RepContext(
      trunkClockAngle: trunkClockAngle,
      trunkDeviation: trunkDeviation,
      isStanding: isStanding,
      state: cobraState,
      frameTimestampMs: now,
      scaleFactor: scaleFactor,
      resultIssues: resultIssues,
      cameraFacing: cameraFacing,
      // Landmarks
      shoulder: shoulder,
      hip: hip,
      elbow: elbow,
      wrist: wrist,
      ear: ear,
      knee: knee,
      // Calibration baselines
      baselineHipY: _baselineHipY,
      baselineTrunkLength: _baselineTrunkLength,
      baselineCervicalAngle: _baselineCervicalAngle,
    );

    // --- Run all metrics ---
    // MET-2 (hand placement) runs in all phases including setup
    _handPlacementMetric.update(ctx);

    // Other metrics run only when not in setup
    if (cobraState != CobraState.setup) {
      for (final metric in _metrics) {
        if (metric != _handPlacementMetric) {
          metric.update(ctx);
        }
      }
    }

    _updatePhaseInstructions(now);

    // --- Debug data ---
    debugData['cobraState'] = cobraState.toString().split('.').last;
    debugData['trunkClock'] = trunkClockAngle.toStringAsFixed(1);
    debugData['trunkDev'] =
        '${trunkDeviation >= 0 ? "+" : ""}${trunkDeviation.toStringAsFixed(1)}°';
    debugData['holdTime'] = _currentHoldSeconds().toStringAsFixed(1);
    debugData['repCount'] = repCount.toString();
    debugData['isStanding'] = isStanding;
    debugData['calibrated'] = _isCalibrated;
    
    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }
  }

  void _updatePhaseInstructions(int now) {
    if (cobraState == CobraState.resting && _restStartMs != null) {
      final restElapsed = (now - _restStartMs!) / 1000.0;
      final restRemaining = (CobraConfig.REST_DURATION - restElapsed)
          .clamp(0.0, CobraConfig.REST_DURATION);

      resultIssues.addInstruction(
          'resting', 'Status', 'Nghỉ ${restRemaining.toStringAsFixed(1)}s');
      debugData['restRemaining'] = restRemaining.toStringAsFixed(1);
    }

    if (cobraState == CobraState.holding) {
      final holdSecs = _currentHoldSeconds();
      final remaining = (CobraConfig.HOLD_DURATION - holdSecs)
          .clamp(0.0, CobraConfig.HOLD_DURATION);
      resultIssues.addInstruction(
          'holding', 'Status', 'Giữ! ${remaining.toStringAsFixed(1)}s');
      debugData['holdProgress'] =
          (holdSecs / CobraConfig.HOLD_DURATION).clamp(0.0, 1.0);
    }
  }

  void _updateCobraState(
      double trunkDeviation, int timestampMs, bool isStanding, double trunkClockAngle) {
    
    bool isCobraPosition = false;
    if (!isStanding) {
      if (cameraFacing == CameraFacing.right) {
         isCobraPosition = trunkClockAngle < (CobraConfig.HORIZONTAL_CLOCK_RIGHT - CobraConfig.COBRA_MIN_ELEVATION);
      } else if (cameraFacing == CameraFacing.left) {
         isCobraPosition = trunkClockAngle > (CobraConfig.HORIZONTAL_CLOCK_LEFT + CobraConfig.COBRA_MIN_ELEVATION);
      }
    }

    bool confirmedCobra = _positionDebouncer.update(isCobraPosition);

    debugData['isCobraPosition'] = confirmedCobra;

    switch (cobraState) {
      case CobraState.setup:
        if (confirmedCobra) {
          _transitionState(CobraState.holding, timestampMs);
        }
        break;

      case CobraState.holding:
        if (_currentHoldSeconds() >= CobraConfig.HOLD_DURATION) {
          _transitionState(CobraState.resting, timestampMs);
        } else if (!confirmedCobra) {
          if (trunkDeviation.abs() < CobraConfig.PRONE_TOLERANCE) {
              _transitionState(CobraState.setup, timestampMs);
          }
        }
        break;

      case CobraState.resting:
        if (_restStartMs != null) {
          final restElapsed = (timestampMs - _restStartMs!) / 1000.0;
          if (restElapsed >= CobraConfig.REST_DURATION && confirmedCobra) {
            _transitionState(CobraState.holding, timestampMs);
          }
        }
        break;
    }
  }

  void _transitionState(CobraState newState, int timestampMs) {
    previousCobraState = cobraState;
    cobraState = newState;

    switch (newState) {
      case CobraState.holding:
        _holdStartMs = timestampMs;
        _restStartMs = null;
        resultIssues.instructions.clear();
        break;

      case CobraState.resting:
        _restStartMs = timestampMs;
        _onHoldComplete();
        break;

      case CobraState.setup:
        _holdStartMs = null;
        break;
    }
    
    for (final metric in _metrics) {
      metric.onStateTransition(previousCobraState, newState, timestampMs);
    }
  }

  void _onHoldComplete() {
    repCount += 1;
    
    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      allFaults.addAll(metric.faults);
    }
    
    correctForm = !allFaults.any((f) => f.affectsForm);
    resultIssues.feedback['Result'] = correctForm ? 'Tốt lắm!' : 'Chỉnh tư thế';

    final faultMap = <String, Map<String, String>>{};
    setFeedback.add({correctForm: faultMap});

    logger.addRepLog(RepLog(correctForm: correctForm, repNumber: repCount, data: {}));
    
    for (final metric in _metrics) {
      metric.resetAndCountFault();
    }
  }

  double _currentHoldSeconds() {
    if (_holdStartMs == null) return 0.0;
    return (frameTimestampMs - _holdStartMs!) / 1000.0;
  }
}
