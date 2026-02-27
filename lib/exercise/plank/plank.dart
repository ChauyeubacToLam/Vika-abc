// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'package:vinafit_mobile/exercise/exercise_base.dart';

import '../../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'metrics/plank_metric_base.dart';

/* =========================================================================
   PLANK EXERCISE — McGill Short-Hold Protocol
   
   Protocol: 3 holds × 10 seconds each, with 5s rest between holds.
   State transitions are ANGLE-DRIVEN for real-time responsiveness.
   Hold timer only accumulates while in good plank position.
   
   Vietnamese context:
   - Desk workers with Lower Crossed Syndrome fatigue around 40s
   - Short holds (10s) prevent dangerous hip sag from fatigue
   - Encouraging feedback, never auto-terminate
   ========================================================================= */

class PlankConfig {
  static const int MAX_REP = 3;

  /// Hold duration in seconds (McGill protocol)
  static const double HOLD_DURATION = 10.0;

  /// Rest duration in seconds between holds
  static const double REST_DURATION = 5.0;

  /// Angle thresholds for standing decection (hip vs shoulder y-diff ratio)
  static const double STANDING_RATIO_THRESHOLD = 0.5;

  /// Trunk angle thresholds (shoulder→hip→ankle)
  /// 180° = perfectly straight. Adjust after empirical testing.
  static const double TRUNK_PIKE_LIMIT = 170.0; // < this = too piked
  static const double TRUNK_SAG_LIMIT = 185.0; // > this = too sagged
}

enum PlankState {
  setup, // User getting into position
  holding, // Active hold — timer accumulating
  resting, // Rest period between holds
}

/* =========================================================================
   PLANK LOGIC
   ========================================================================= */

class Plank extends ExerciseBase {
  PlankState plankState = PlankState.setup;
  PlankState previousPlankState = PlankState.setup;

  // -- Timer State --
  /// Accumulated hold time in milliseconds (pauses when form breaks)

  /// Timestamp when current holding period started (null if not holding)
  int? _holdStartMs;

  /// Timestamp when rest period started
  int? _restStartMs;

  final List<PlankMetricBase> _metrics = [
    // TrunkAlignmentMetric(),
    // HeadNeckMetric(),
    // KneeExtensionMetric(),
  ];

  /* -----------------------------------------------------------------------
     UI BRIDGE
     ----------------------------------------------------------------------- */
  @override
  String get exerciseName => 'Plank';

  @override
  String get currentPhaseKey => plankState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (plankState) {
      case PlankState.setup:
        return 'Chuẩn bị';
      case PlankState.holding:
        return 'Giữ!';
      case PlankState.resting:
        return 'Nghỉ';
    }
  }

  /* -----------------------------------------------------------------------
     STOP CONDITION
     ----------------------------------------------------------------------- */
  @override
  bool requestStop() {
    return repCount >= PlankConfig.MAX_REP;
  }

  /* -----------------------------------------------------------------------
     SAFETY CHECKS
     ----------------------------------------------------------------------- */
  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks,
      CameraFacing cameraFacing) {
    if (cameraFacing == CameraFacing.front) {
      return "⚠️ Xin hãy quay nghiêng để theo dõi tư thế Plank";
    }

    PoseLandmark? shoulder = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    PoseLandmark? hip = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);
    PoseLandmark? knee = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightKnee,
        leftType: PoseLandmarkType.leftKnee);
    PoseLandmark? ankle = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle);
    PoseLandmark? ear = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightEar,
        leftType: PoseLandmarkType.leftEar);

    if (shoulder == null ||
        hip == null ||
        knee == null ||
        ankle == null ||
        ear == null) {
      return "⚠️ Đảm bảo toàn bộ cơ thể trong khung hình";
    }

    if (shoulder.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        hip.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        knee.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        ankle.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        ear.likelihood < ExerciseBase.MIN_CONFIDENCE) {
      return "⚠️ Hình ảnh không rõ. Điều chỉnh ánh sáng hoặc vị trí";
    }

    return null;
  }

  /* -----------------------------------------------------------------------
     MAIN PHYSICS LOOP — Called every frame when activated.
     ----------------------------------------------------------------------- */
  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks,
      CameraFacing cameraFacing, double? scaleFactor) {
    // ---------- 1. Get Landmarks ----------
    PoseLandmark? shoulder = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    PoseLandmark? hip = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);
    PoseLandmark? knee = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightKnee,
        leftType: PoseLandmarkType.leftKnee);
    PoseLandmark? ankle = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle);
    PoseLandmark? ear = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightEar,
        leftType: PoseLandmarkType.leftEar);

    if (shoulder == null ||
        hip == null ||
        knee == null ||
        ankle == null ||
        ear == null) return;

    // ---------- 2. Calculate Geometry ----------
    double backAngle =
        calculateAngle(firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    double neckAngle =
        calculateAngle(firstPoint: ear, midPoint: shoulder, lastPoint: hip);
    double kneeAngle =
        calculateAngle(firstPoint: hip, midPoint: knee, lastPoint: ankle);

    // difference in y between hip and shoulder for identify standing or holding
    double hipShoulderRatioDiff =
        (hip.y - shoulder.y).abs() / (scaleFactor ?? 1.0);
    bool isStanding = hipShoulderRatioDiff >
        PlankConfig
            .STANDING_RATIO_THRESHOLD; // Empirical threshold for standing vs holding

    int now = DateTime.now().millisecondsSinceEpoch;

    // ---------- 3. Build RepContext ----------
    final ctx = RepContext(
      backAngle: backAngle,
      neckAngle: neckAngle,
      kneeAngle: kneeAngle,
      plankState: plankState,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    // ---------- 4. Populate Debug Data ----------
    debugData['plankState'] = plankState.toString().split('.').last;
    debugData['backAngle'] = backAngle.toStringAsFixed(1);
    debugData['neckAngle'] = neckAngle.toStringAsFixed(1);
    debugData['kneeAngle'] = kneeAngle.toStringAsFixed(1);
    debugData['holdTime'] = _currentHoldSeconds().toStringAsFixed(1);
    debugData['repCount'] = repCount.toString();
    debugData['hipShoulderDiffRatio'] =
        (hipShoulderRatioDiff).toStringAsFixed(2);
    debugData['isStanding'] = isStanding;

    // ---------- 5. Update Plank State (angle-driven) ----------
    _updatePlankState(backAngle, now, isStanding);

    // ---------- 6. Handle State Transitions ----------
    // Rep completion: holding → resting transition
    if (plankState == PlankState.resting &&
        previousPlankState == PlankState.holding) {
      _onHoldComplete(ctx);
    }

    // Rest complete: resting → holding transition after REST_DURATION
    if (plankState == PlankState.resting && _restStartMs != null) {
      final restElapsed = (now - _restStartMs!) / 1000.0;
      final restRemaining = (PlankConfig.REST_DURATION - restElapsed)
          .clamp(0.0, PlankConfig.REST_DURATION);

      resultIssues.addInstruction(
          'resting', 'Status', 'Nghỉ ${restRemaining.toStringAsFixed(1)}s');
      debugData['restRemaining'] = restRemaining.toStringAsFixed(1);
    }

    // ---------- 7. Run All Metrics (only during holding) ----------
    if (plankState == PlankState.holding && !isStanding) {
      for (final metric in _metrics) {
        metric.update(ctx);
      }

      // Hold timer feedback
      final holdSecs = _currentHoldSeconds();
      final remaining = (PlankConfig.HOLD_DURATION - holdSecs)
          .clamp(0.0, PlankConfig.HOLD_DURATION);
      resultIssues.addInstruction(
          'holding', 'Status', 'Giữ! ${remaining.toStringAsFixed(1)}s');
      debugData['holdProgress'] =
          (holdSecs / PlankConfig.HOLD_DURATION).clamp(0.0, 1.0);
    }

    // ---------- 8. Merge Metric Debug Data ----------
    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }
  }

  /* -----------------------------------------------------------------------
     STATE MACHINE (angle-driven, with transition tracking)
     ----------------------------------------------------------------------- */
  void _updatePlankState(double backAngle, int timestampMs, bool isStanding) {
    bool isPlankPosition = backAngle >= PlankConfig.TRUNK_PIKE_LIMIT &&
        backAngle <= PlankConfig.TRUNK_SAG_LIMIT;
    debugData['isPlankPosition'] = isPlankPosition;

    switch (plankState) {
      case PlankState.setup:
        // Enter holding when body aligns into plank position
        if (isPlankPosition && !isStanding) {
          _transitionState(PlankState.holding, timestampMs);
        }
        break;

      case PlankState.holding:
        // Check if hold timer completed
        if (_currentHoldSeconds() >= PlankConfig.HOLD_DURATION) {
          _transitionState(PlankState.resting, timestampMs);
        }

        break;

      case PlankState.resting:
        // Rest period complete + body back in position → start next hold
        if (_restStartMs != null) {
          final restElapsed = (timestampMs - _restStartMs!) / 1000.0;
          if (restElapsed >= PlankConfig.REST_DURATION &&
              isPlankPosition &&
              !isStanding) {
            _transitionState(PlankState.holding, timestampMs);
          }
        }
        break;
    }
  }

  void _transitionState(PlankState newState, int timestampMs) {
    previousPlankState = plankState;
    plankState = newState;

    switch (newState) {
      case PlankState.holding:
        // Starting a new hold — reset timer
        _holdStartMs = timestampMs;
        _restStartMs = null;
        // Clear previous coaching instructions
        resultIssues.instructions.clear();
        break;

      case PlankState.resting:
        // Pause any running hold timer segment
        _restStartMs = timestampMs;
        break;

      case PlankState.setup:
        break;
    }
  }

  /* -----------------------------------------------------------------------
     HOLD COMPLETE — Log rep, collect faults, reset metrics
     ----------------------------------------------------------------------- */
  void _onHoldComplete(RepContext ctx) {
    repCount += 1;
    _transitionState(PlankState.resting, DateTime.now().millisecondsSinceEpoch);
    // Collect faults from all metrics
    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      metric.finalizeHold(); // For metrics that calculate fault percentage
      allFaults.addAll(metric.faults);
    }

    // Determine correctForm
    correctForm = !allFaults.any((f) => f.affectsForm);

    // UI feedback
    if (correctForm) {
      resultIssues.feedback['Result'] = 'Tốt lắm!';
    } else {
      final summary = allFaults
          .where((f) => f.affectsForm)
          .map((f) =>
              '${f.type} ${(f.faultPercentage * 100).toStringAsFixed(0)}%')
          .join(' · ');
      resultIssues.feedback['Result'] = summary;
    }

    // Build fault map for set history
    final faultMap = <String, Map<String, String>>{};
    for (final fault in allFaults) {
      if (!faultMap.containsKey(PlankState.holding.toString())) {
        faultMap[PlankState.holding.toString()] = {};
      }
      faultMap[PlankState.holding.toString()]![fault.type] = fault.message;
    }
    setFeedback.add({correctForm: faultMap});

    // Merge debug data before reset
    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }

    // Reset metrics for next hold
    for (final metric in _metrics) {
      metric.reset();
    }
    correctForm = true;
  }

  /* -----------------------------------------------------------------------
     TIMER HELPERS
     ----------------------------------------------------------------------- */

  /// Returns total hold time in seconds (accumulated + current segment)
  double _currentHoldSeconds() {
    if (_holdStartMs == null) return 0.0;
    return (DateTime.now().millisecondsSinceEpoch - _holdStartMs!) / 1000.0;
  }
}
