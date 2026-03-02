// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'package:vinafit_mobile/exercise/exercise_base.dart';

import '../../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'metrics/plank_metric_base.dart';
import 'metrics/trunk_alignment_metric.dart';
import 'metrics/head_neck_metric.dart';
import 'metrics/knee_extension_metric.dart';

/* =========================================================================
   PLANK EXERCISE — McGill Short-Hold Protocol
   
   Protocol: 3 holds × 10 seconds each, with 5s rest between holds.
   State transitions are ANGLE-DRIVEN for real-time responsiveness.
   Timer runs continuously during hold — fault percentage judges quality.
   
   Trunk assessment uses calculateVerticalAngle (shoulder + hip only).
   Ankle is OPTIONAL — only needed for knee extension metric.
   This solves the small Vietnamese apartment problem where full body
   may not fit in frame from side view.
   
   Vietnamese context:
   - Desk workers with Lower Crossed Syndrome fatigue around 40s
   - Short holds (10s) prevent dangerous hip sag from fatigue
   - Encouraging feedback, never auto-terminate
   ========================================================================= */

class PlankConfig {
  static const int MAX_REP = 5;

  /// Hold duration in seconds (McGill protocol)
  static const double HOLD_DURATION = 15.0;

  /// Rest duration in seconds between holds
  static const double REST_DURATION = 5.0;

  // Hip to floor to be consider standing
  static const double STANDING_HIP_FLOOR_THRESHOLD =
      0.5; // in meters; > this = standing

  /// Trunk clock angle for "horizontal" per facing direction.
  /// Left-facing: shoulder is left of hip → clock angle ~270°
  /// Right-facing: shoulder is right of hip → clock angle ~90°
  static const double HORIZONTAL_CLOCK_LEFT = 270.0;
  static const double HORIZONTAL_CLOCK_RIGHT = 90.0;

  /// Max deviation from horizontal to count as valid plank position (degrees)
  /// For state machine: wider tolerance to enter/stay in holding
  static const double PLANK_POSITION_TOLERANCE = 25.0;

  /// Trunk deviation thresholds for form assessment (used by metric)
  /// These are degrees of deviation from perfect horizontal
  /// Sag (hips dropping) — more lenient, common issue
  static const double SAG_GOOD_MAX = 4.5;
  static const double SAG_WARNING_MAX = 5.5; // adjust after testing

  ///Pike (hips too high) — stricter, less common
  static const double PIKE_GOOD_MAX = 1.5;
  static const double PIKE_WARNING_MAX = 3.0; // adjust after testing
  // Above WARNING_MAX = error
}

enum PlankState {
  setup, // User getting into position
  holding, // Active hold — timer running
  resting, // Rest period between holds
}

/* =========================================================================
   PLANK LOGIC
   ========================================================================= */

class Plank extends ExerciseBase {
  PlankState plankState = PlankState.setup;
  PlankState previousPlankState = PlankState.setup;

  // -- Timer State --
  int? _holdStartMs;
  int? _restStartMs;

  // -- Ankle availability --
  bool _ankleAvailable = true;

  // -- Metrics --
  final TrunkAlignmentMetric trunkAlignmentMetric = TrunkAlignmentMetric();
  final HeadNeckMetric headNeckMetric = HeadNeckMetric();
  final KneeExtensionMetric kneeExtensionMetric = KneeExtensionMetric();

  late final List<PlankMetricBase> _metrics = [
    trunkAlignmentMetric,
    headNeckMetric,
    kneeExtensionMetric,
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
     INITIALIZATION
     ----------------------------------------------------------------------- */
  /* =========================================================================
   ADD THESE TO plank.dart (Plank class)
   ========================================================================= */
  @override
  bool isInStartPosition(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing facing,
    double? scaleFactor,
  ) {
    // Check: user is in plank position (horizontal trunk)
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

    // Trunk must be roughly horizontal (within 25° of horizontal)
    double trunkClockAngle =
        calculateVerticalAngle(pivot: hip, point: shoulder);
    double horizontalTarget = facing == CameraFacing.right
        ? PlankConfig.HORIZONTAL_CLOCK_RIGHT
        : PlankConfig.HORIZONTAL_CLOCK_LEFT;
    double diff = trunkClockAngle - horizontalTarget;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    if (diff.abs() > 25.0) return false;

    return true;
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

    // Critical landmarks (always required)
    PoseLandmark? shoulder = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    PoseLandmark? hip = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);
    PoseLandmark? ear = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightEar,
        leftType: PoseLandmarkType.leftEar);
    PoseLandmark? knee = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightKnee,
        leftType: PoseLandmarkType.leftKnee);

    if (shoulder == null || hip == null || ear == null || knee == null) {
      return "⚠️ Đảm bảo phần trên cơ thể trong khung hình";
    }

    if (shoulder.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        hip.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        ear.likelihood < ExerciseBase.MIN_CONFIDENCE) {
      return "⚠️ Hình ảnh không rõ. Điều chỉnh ánh sáng hoặc vị trí";
    }

    // Optional landmarks (ankle + knee for knee extension metric)
    PoseLandmark? ankle = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle);

    _ankleAvailable = ankle != null &&
        ankle.likelihood >= ExerciseBase.MIN_CONFIDENCE &&
        knee.likelihood >= ExerciseBase.MIN_CONFIDENCE;

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
    PoseLandmark? ear = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightEar,
        leftType: PoseLandmarkType.leftEar);
    PoseLandmark? knee = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightKnee,
        leftType: PoseLandmarkType.leftKnee);

    if (shoulder == null || hip == null || ear == null || knee == null) return;

    // Optional: knee + ankle for knee extension
    PoseLandmark? ankle = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle);

    // ---------- 2. Calculate Geometry ----------

    // Trunk: clock angle from vertical (0°=up, 90°=right, 270°=left)
    double trunkClockAngle =
        calculateVerticalAngle(pivot: hip, point: shoulder);

    // Deviation from horizontal (positive = one direction, negative = other)
    double horizontalTarget = cameraFacing == CameraFacing.right
        ? PlankConfig.HORIZONTAL_CLOCK_RIGHT
        : PlankConfig.HORIZONTAL_CLOCK_LEFT;
    double trunkDeviation =
        clockAngleDeviation(trunkClockAngle, horizontalTarget);

    // Neck: ear→shoulder→hip (unsigned 0–180° is fine)
    double neckAngle =
        calculateAngle(firstPoint: ear, midPoint: shoulder, lastPoint: hip);

    // Knee: only if ankle visible
    double? kneeAngle;
    if (_ankleAvailable && ankle != null) {
      kneeAngle =
          calculateAngle(firstPoint: hip, midPoint: knee, lastPoint: ankle);
    }
    // Get any foot-level landmark (doesn't need high confidence for floor reference)
    PoseLandmark? foot = smoothedLandmarks[PoseLandmarkType.leftFootIndex] ??
        smoothedLandmarks[PoseLandmarkType.rightFootIndex];
    PoseLandmark? heel = smoothedLandmarks[PoseLandmarkType.leftHeel] ??
        smoothedLandmarks[PoseLandmarkType.rightHeel];

    double floorY = foot?.y ?? heel?.y ?? knee.y;

    double hipToFloor = (floorY - hip.y).abs() / (scaleFactor ?? 1.0);
    bool isStanding = hipToFloor > PlankConfig.STANDING_HIP_FLOOR_THRESHOLD;
    int now = DateTime.now().millisecondsSinceEpoch;

    // ---------- 3. Build RepContext ----------
    final ctx = RepContext(
      trunkDeviation: trunkDeviation,
      neckAngle: neckAngle,
      kneeAngle: kneeAngle,
      plankState: plankState,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    // ---------- 4. Populate Debug Data ----------
    debugData['plankState'] = plankState.toString().split('.').last;
    debugData['trunkClock'] = trunkClockAngle.toStringAsFixed(1);
    debugData['trunkDev'] =
        '${trunkDeviation >= 0 ? "+" : ""}${trunkDeviation.toStringAsFixed(1)}°';
    debugData['neckAngle'] = neckAngle.toStringAsFixed(1);
    debugData['kneeAngle'] = kneeAngle?.toStringAsFixed(1) ?? 'N/A';
    debugData['holdTime'] = _currentHoldSeconds().toStringAsFixed(1);
    debugData['repCount'] = repCount.toString();
    debugData['isStanding'] = isStanding;
    debugData['ankleAvail'] = _ankleAvailable;

    // ---------- 5. Update Plank State ----------
    _updatePlankState(trunkDeviation, now, isStanding);

    // ---------- 6. Rest period feedback ----------
    if (plankState == PlankState.resting && _restStartMs != null) {
      final restElapsed = (now - _restStartMs!) / 1000.0;
      final restRemaining = (PlankConfig.REST_DURATION - restElapsed)
          .clamp(0.0, PlankConfig.REST_DURATION);

      resultIssues.addInstruction(
          'resting', 'Status', 'Nghỉ ${restRemaining.toStringAsFixed(1)}s');
      debugData['restRemaining'] = restRemaining.toStringAsFixed(1);
    }

    // ---------- 7. Run Metrics (only during holding) ----------
    if (plankState == PlankState.holding) {
      for (final metric in _metrics) {
        // Skip knee metric if ankle not visible
        if (metric == kneeExtensionMetric && !_ankleAvailable) continue;
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
     STATE MACHINE
     ----------------------------------------------------------------------- */
  void _updatePlankState(
      double trunkDeviation, int timestampMs, bool isStanding) {
    bool isPlankPosition =
        trunkDeviation.abs() <= PlankConfig.PLANK_POSITION_TOLERANCE &&
            !isStanding;

    debugData['isPlankPosition'] = isPlankPosition;

    switch (plankState) {
      case PlankState.setup:
        if (isPlankPosition) {
          _transitionState(PlankState.holding, timestampMs);
        }
        break;

      case PlankState.holding:
        if (_currentHoldSeconds() >= PlankConfig.HOLD_DURATION) {
          _transitionState(PlankState.resting, timestampMs);
        }
        break;

      case PlankState.resting:
        if (_restStartMs != null) {
          final restElapsed = (timestampMs - _restStartMs!) / 1000.0;
          if (restElapsed >= PlankConfig.REST_DURATION && isPlankPosition) {
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
        _holdStartMs = timestampMs;
        _restStartMs = null;
        resultIssues.instructions.clear();
        break;

      case PlankState.resting:
        _restStartMs = timestampMs;
        _onHoldComplete();
        break;

      case PlankState.setup:
        break;
    }
  }

  /* -----------------------------------------------------------------------
     HOLD COMPLETE
     ----------------------------------------------------------------------- */
  void _onHoldComplete() {
    repCount += 1;

    // Finalize and collect faults
    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      metric.finalizeHold();
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
      faultMap.putIfAbsent('HOLDING', () => {});
      faultMap['HOLDING']![fault.type] = fault.message;
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
     HELPERS
     ----------------------------------------------------------------------- */

  double _currentHoldSeconds() {
    if (_holdStartMs == null) return 0.0;
    return (DateTime.now().millisecondsSinceEpoch - _holdStartMs!) / 1000.0;
  }
}
