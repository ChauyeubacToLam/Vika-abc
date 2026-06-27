// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'package:vika/debug/tracked_metric.dart';
import 'package:vika/utils/debouncer.dart';

import '../../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../exercise_base.dart';
import '../side_tracked_exercise_mixin.dart';
import '../../utils/exercise_logger.dart';
import 'metrics/glute_bridge_metric_base.dart';
import 'metrics/glute_bridge_hip_extension.dart';
import 'metrics/glute_bridge_knee_angle.dart';
import 'metrics/glute_bridge_speed_control.dart';
import 'metrics/glute_bridge_neck_head.dart';

/* =========================================================================
   CONFIGURATION & THRESHOLDS
   ========================================================================= */
class GluteBridgeConfig {
  // --- Velocity thresholds (hip y pixels/frame at ~30 fps) ---
  // Screen coords: y increases downward.
  //   Hip RISING  → velocity NEGATIVE
  //   Hip FALLING → velocity POSITIVE
  static const double ASCENDING_VELOCITY_THRESHOLD = -1.8;
  static const double DESCENDING_VELOCITY_THRESHOLD = 1.8;
  static const double REST_VELOCITY_THRESHOLD = 2.0;

  // --- Hip elevation thresholds (fraction of scaleFactor) ---
  /// Minimum rise to be counted as elevated (TOP_HOLD detection).
  static const double HIP_ELEVATED_RATIO = 0.07;

  /// Pixel fallback when scaleFactor is unavailable.
  static const double HIP_ELEVATED_PIXELS = 10.0;

  /// Hip must return within this fraction of scaleFactor to baseline.
  static const double BOTTOM_TOLERANCE_RATIO = 0.12;
  static const double BOTTOM_TOLERANCE_PIXELS = 18.0;

  // --- Start-position geometry ---
  /// Trunk clock-angle target (degrees from vertical, clockwise).
  /// Matches push-up horizontal target approach.
  static const double HORIZONTAL_CLOCK_LEFT = 270.0;
  static const double HORIZONTAL_CLOCK_RIGHT = 90.0;

  /// Tolerance around horizontal target (degrees).
  static const double HORIZONTAL_TOLERANCE = 40.0;
  static const double START_TRUNK_HORIZ_MAX = 28.0;

  /// Acceptable knee flexion range for starting posture (hip–knee–ankle).
  static const double KNEE_ANGLE_MIN = 60.0;
  static const double KNEE_ANGLE_MAX = 160.0;

  /// Max hip-to-shoulder vertical offset for flat-lying check.
  static const double HIP_SHOULDER_RATIO = 0.55; // fraction of scaleFactor
  static const double HIP_SHOULDER_PIXELS = 55.0;
}

/* =========================================================================
   STATE MACHINE STATES
   ========================================================================= */
enum GluteBridgeState {
  bottom, // Lying flat — resting / starting position
  ascending, // Hip rising from floor
  topHold, // Peak — hip elevated, nearly still
  descending, // Hip lowering back to floor
}

/* =========================================================================
   GLUTE BRIDGE LOGIC
   ========================================================================= */
class GluteBridge extends ExerciseBase with SideTrackedExerciseMixin {
  final int maxRep;

  GluteBridge({required this.maxRep});

  GluteBridgeState gluteState = GluteBridgeState.bottom;
  GluteBridgeState previousGluteState = GluteBridgeState.bottom;

  // --- Hip y-velocity tracking (rolling window) ---
  final List<double> _hipYHistory = [];
  static const int _VELOCITY_WINDOW = 5;

  // --- Calibrated baseline (captured during hold-still) ---
  double? _baselineHipY;

  // --- Peak hip position tracked during ascending ---
  double? _peakHipY;
  int? _topHoldStartMs;

  // --- Angle and deviation at peak hip (for HipExtension per-rep check) ---
  double? _peakShoulderHipKneeAngle;
  double? _peakNormalizedDeviation;

  // --- Knee angle at peak hip (for KneeAngle per-rep check) ---
  double? _peakKneeAngle;

  // --- State transition debouncers ---
  final Debouncer _ascendDebouncer = Debouncer(requiredFrames: 3);
  final Debouncer _topHoldDebouncer = Debouncer(requiredFrames: 5);
  final Debouncer _descendDebouncer = Debouncer(requiredFrames: 3);
  final Debouncer _bottomDebouncer = Debouncer(requiredFrames: 3);

  // --- Metrics ---
  final HipExtensionMetric hipExtensionMetric = HipExtensionMetric();
  final KneeAngleMetric kneeAngleMetric = KneeAngleMetric();
  final SpeedControlMetric speedControlMetric = SpeedControlMetric();
  final NeckHeadMetric neckHeadMetric = NeckHeadMetric();

  late final List<GluteBridgeMetricBase> _metrics = [
    hipExtensionMetric,
    kneeAngleMetric,
    speedControlMetric,
    neckHeadMetric,
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
          left: PoseLandmarkType.leftShoulder,
        ),
        'hip': (
          right: PoseLandmarkType.rightHip,
          left: PoseLandmarkType.leftHip,
        ),
        'knee': (
          right: PoseLandmarkType.rightKnee,
          left: PoseLandmarkType.leftKnee,
        ),
        'ankle': (
          right: PoseLandmarkType.rightAnkle,
          left: PoseLandmarkType.leftAnkle,
        ),
      };

  @override
  Map<String, SideLandmarkPair> get optionalSideLandmarks => const {
        'ear': (
          right: PoseLandmarkType.rightEar,
          left: PoseLandmarkType.leftEar,
        ),
      };

  @override
  double? get liveHoldSeconds =>
      gluteState == GluteBridgeState.topHold && _topHoldStartMs != null
          ? (frameTimestampMs - _topHoldStartMs!) / 1000.0
          : null;

  /* -----------------------------------------------------------------------
     UI BRIDGE
     ----------------------------------------------------------------------- */
  @override
  String get exerciseName => 'Glute Bridge';

  // Glute Bridge starts from a floor setup that can take time to settle.
  // Replaying old faults here sounds like a fault from the current set before
  // the user has completed any movement.
  @override
  bool get shouldReplayPreviousSetVoiceFaults => false;

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get currentPhaseKey => gluteState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (gluteState) {
      case GluteBridgeState.bottom:
        return 'Chuẩn bị';
      case GluteBridgeState.ascending:
        return 'Nâng hông';
      case GluteBridgeState.topHold:
        return 'Giữ';
      case GluteBridgeState.descending:
        return 'Hạ xuống';
    }
  }

  /* -----------------------------------------------------------------------
     START POSITION — User is supine with knees bent.

     Checks:
       1. Trunk is roughly horizontal (person lying flat on back).
       2. Knees are bent (hip-knee-ankle angle 70–150°).
       3. Hip and shoulder are at approximately the same y-coordinate
          (hip is not already elevated).
     ----------------------------------------------------------------------- */
  @override
  bool isInStartPosition(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final tracked = getSideTrackedLandmarks(landmarks);
    if (tracked == null) return false;

    final shoulder = tracked['shoulder']!;
    final hip = tracked['hip']!;
    final knee = tracked['knee']!;
    final ankle = tracked['ankle']!;

    // 1. Trunk must be roughly horizontal (clock angle near 90° or 270°).
    final trunkHoriz =
        calculateAbsoluteHorizontalAngle(point1: shoulder, point2: hip);
    if (trunkHoriz > GluteBridgeConfig.START_TRUNK_HORIZ_MAX) return false;

    // 2. Knees must be bent — hip-knee-ankle angle 70–150°.
    double kneeAngle = calculateAngleNormalized(
      firstPoint: hip,
      midPoint: knee,
      lastPoint: ankle,
    );
    if (kneeAngle < GluteBridgeConfig.KNEE_ANGLE_MIN ||
        kneeAngle > GluteBridgeConfig.KNEE_ANGLE_MAX) return false;

    // 3. Hip not elevated — hip.y close to shoulder.y (both at floor level).
    double yTolerance = scaleFactor > 0
        ? scaleFactor * GluteBridgeConfig.HIP_SHOULDER_RATIO
        : GluteBridgeConfig.HIP_SHOULDER_PIXELS;
    if ((hip.y - shoulder.y).abs() > yTolerance) return false;

    // Capture calibration baseline during the hold-still window.
    _baselineHipY = hip.y;

    return true;
  }

  /* -----------------------------------------------------------------------
     STOP CONDITION
     ----------------------------------------------------------------------- */
  @override
  bool requestStop() {
    return repCount >= maxRep;
  }

  @override
  void onSetComplete() {
    logger.pushKey("hip_extension_fails_count", hipExtensionMetric.faultsCount);
    logger.pushKey("knee_angle_fails_count", kneeAngleMetric.faultsCount);
    logger.pushKey("speed_control_fails_count", speedControlMetric.faultsCount);
    logger.pushKey("neck_head_fails_count", neckHeadMetric.faultsCount);

    logger.pushMax("peak_hip_extension_angle", "max_hip_extension_angle");
    logger.pushMax(
        "peak_normalized_hip_deviation", "max_normalized_hip_deviation");
    logger.pushMin("peak_knee_angle", "min_peak_knee_angle");

    logger.pushGoodRepCount();
    logger.pushKey("max_rep", maxRep);
  }

  /* -----------------------------------------------------------------------
     SAFETY CHECKS
     ----------------------------------------------------------------------- */
  @override
  String? checkSafety(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return "⚠️ Xin hãy quay nghiêng để theo dõi tư thế Glute Bridge";
    }

    if (getSideTrackedLandmarks(landmarks) != null) {
      return null;
    }

    final shoulder = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    final hip = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);
    final knee = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightKnee,
        leftType: PoseLandmarkType.leftKnee);

    if (shoulder == null || hip == null || knee == null) {
      return "⚠️ Đảm bảo vai, hông và gối trong khung hình";
    }

    if (!ExerciseBase.isLandmarkConfident(shoulder) ||
        !ExerciseBase.isLandmarkConfident(hip) ||
        !ExerciseBase.isLandmarkConfident(knee)) {
      return "⚠️ Hình ảnh không rõ. Điều chỉnh ánh sáng hoặc vị trí";
    }

    return null;
  }

  /* -----------------------------------------------------------------------
     MAIN PHYSICS LOOP — Called every frame when activated.
     ----------------------------------------------------------------------- */
  @override
  void checkingPose(
    Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks,
  ) {
    // ---------- 1. Get Landmarks ----------

    final tracked = getSideTrackedLandmarks(smoothedLandmarks);
    if (tracked == null) return;

    final shoulder = tracked['shoulder']!;
    final hip = tracked['hip']!;
    final knee = tracked['knee']!;
    final ankle = tracked['ankle']!;

    // Head: prefer camera-side ear, fall back to nose.
    final ear = tracked['ear'];
    final nose = smoothedLandmarks[PoseLandmarkType.nose];

    // Explicit null fallback hierarchy to prevent bypass when head goes out of frame
    final double headY = (ear != null && ExerciseBase.isLandmarkConfident(ear))
        ? ear.y
        : (nose != null && ExerciseBase.isLandmarkConfident(nose))
            ? nose.y
            : shoulder.y; // Fallback if head is totally lost.

    // ---------- 2. Calculate Geometry ----------

    final double hipY = hip.y;
    final double hipVelocity = _computeHipVelocity(hipY);

    // Primary angle: shoulder-hip-knee internal angle at the hip.
    // ~165-175° when flat; lower when well-bridged.
    final double shoulderHipKneeAngle = calculateAngleNormalized(
      firstPoint: shoulder,
      midPoint: hip,
      lastPoint: knee,
    );

    // Perpendicular deviation of hip from the shoulder-knee line,
    // normalized by shoulder-knee segment length.
    // Positive = hip above line (hyperextension), Negative = below (sag).
    final double normalizedHipDeviation =
        _computeNormalizedHipDeviation(shoulder, hip, knee);

    // Knee angle (hip-knee-ankle) — null if ankle not visible.
    final double kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);

    final int now = frameTimestampMs;

    // Ensure baseline exists (fallback in case activation was unusual).
    _baselineHipY ??= hipY;

    // Track peak elevation during ascending and topHold.
    // Also capture the angle and deviation at the peak frame for per-rep eval.
    if (gluteState == GluteBridgeState.ascending ||
        gluteState == GluteBridgeState.topHold) {
      if (_peakHipY == null || hipY < _peakHipY!) {
        _peakHipY = hipY;
        _peakShoulderHipKneeAngle = shoulderHipKneeAngle;
        _peakNormalizedDeviation = normalizedHipDeviation;
        _peakKneeAngle = kneeAngle;
      }
    }

    // Derived thresholds normalised to body size.
    final double hipElevatedThreshold = scaleFactor > 0
        ? scaleFactor * GluteBridgeConfig.HIP_ELEVATED_RATIO
        : GluteBridgeConfig.HIP_ELEVATED_PIXELS;

    // ---------- 3. Build RepContext ----------

    final ctx = RepContext(
      hipY: hipY,
      shoulderY: shoulder.y,
      hipVelocity: hipVelocity,
      shoulderHipKneeAngle: shoulderHipKneeAngle,
      normalizedHipDeviation: normalizedHipDeviation,
      kneeAngle: kneeAngle,
      scaleFactor: scaleFactor > 0 ? scaleFactor : null,
      headY: headY,
      state: gluteState,
      frameTimestamp: now,
      baselineHipY: _baselineHipY!,
      resultIssues: resultIssues,
    );

    final debugEnabled = isDebugModeActive;
    // ---------- 4. Populate Debug Data ----------

    debugData['gluteState'] = gluteState.toString().split('.').last;
    debugData['hipY'] = hipY.toStringAsFixed(1);
    debugData['hipVel'] =
        '${hipVelocity >= 0 ? "+" : ""}${hipVelocity.toStringAsFixed(2)}';
    debugData['shKneeAngle'] = shoulderHipKneeAngle.toStringAsFixed(1);
    debugData['hipDev'] =
        '${normalizedHipDeviation >= 0 ? "+" : ""}${normalizedHipDeviation.toStringAsFixed(3)}';
    debugData['kneeAngle'] = kneeAngle.toStringAsFixed(1);
    debugData['baseline'] = _baselineHipY?.toStringAsFixed(1) ?? 'N/A';
    debugData['peak'] = _peakHipY?.toStringAsFixed(1) ?? 'N/A';

    // ---------- 5. Update State Machine ----------

    _updateGluteState(
        hipY, hipVelocity, hipElevatedThreshold, scaleFactor, now);

    // ---------- 6. Run All Metrics ----------

    if (gluteState == GluteBridgeState.bottom) {
      for (final metric in _metrics) {
        metric.onBottomFrame(ctx);
      }
    } else {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
    }

    // Merge metric debug data.
    if (debugEnabled) {
      for (final metric in _metrics) {
        debugData.addAll(metric.debugData);
      }
    }

    // ---------- 7. Status Coaching ----------

    if (gluteState == GluteBridgeState.bottom) {
      resultIssues.addInstruction('bottom', 'Status', 'Nâng hông lên!');
    } else if (gluteState == GluteBridgeState.ascending) {
      resultIssues.addInstruction('ascending', 'Status', 'Đang nâng...');
    } else if (gluteState == GluteBridgeState.topHold) {
      resultIssues.addInstruction('topHold', 'Status', 'Giữ vững!');
    } else if (gluteState == GluteBridgeState.descending) {
      resultIssues.addInstruction('descending', 'Status', 'Hạ từ từ...');
    }
  }

  /* -----------------------------------------------------------------------
     HIP VELOCITY — Smoothed over a rolling window.

     Returns pixels/frame (negative = hip rising, positive = hip falling).
     ----------------------------------------------------------------------- */
  double _computeHipVelocity(double currentHipY) {
    _hipYHistory.add(currentHipY);
    if (_hipYHistory.length > _VELOCITY_WINDOW + 1) {
      _hipYHistory.removeAt(0);
    }
    if (_hipYHistory.length < 2) return 0.0;

    double sum = 0.0;
    for (int i = 1; i < _hipYHistory.length; i++) {
      sum += _hipYHistory[i] - _hipYHistory[i - 1];
    }
    double rawVelocity = sum / (_hipYHistory.length - 1);

    // Scale velocity to base 30 FPS logic
    return rawVelocity * fpsRatio;
  }

  /* -----------------------------------------------------------------------
     NORMALIZED HIP DEVIATION — perpendicular distance from HIP to the
     SHOULDER-KNEE line, divided by the SHOULDER-KNEE segment length.

     sign convention (matches spec):
       Positive = hip above the shoulder-knee line → hyperextension risk
       Negative = hip below the line → sagging / insufficient extension
     ----------------------------------------------------------------------- */
  double _computeNormalizedHipDeviation(
    PoseLandmark shoulder,
    PoseLandmark hip,
    PoseLandmark knee,
  ) {
    final double skLen = calculateDistance(shoulder, knee);
    if (skLen < 1.0) return 0.0;

    // Interpolate the y value on the shoulder-knee line at hip.x position.
    // Clamp t to [0,1] to avoid extrapolation artifacts.
    final double dx = knee.x - shoulder.x;
    double lineY;
    if (dx.abs() < 0.5) {
      // Nearly vertical line — fall back to midpoint y.
      lineY = (shoulder.y + knee.y) / 2.0;
    } else {
      final double t = ((hip.x - shoulder.x) / dx).clamp(0.0, 1.0);
      lineY = shoulder.y + t * (knee.y - shoulder.y);
    }

    // Perpendicular component (vertical proxy for a nearly horizontal line).
    // lineY > hip.y in screen coords → hip is above the line → positive.
    final double signedPixelDev = lineY - hip.y;

    // True perpendicular (cross-product magnitude) for robustness.
    final double cross = (knee.x - shoulder.x) * (hip.y - shoulder.y) -
        (knee.y - shoulder.y) * (hip.x - shoulder.x);
    final double perpAbs = cross.abs() / skLen;

    // Apply sign from the vertical-proxy approach and normalize.
    final double sign = signedPixelDev >= 0 ? 1.0 : -1.0;
    return sign * perpAbs / skLen;
  }

  /* -----------------------------------------------------------------------
     STATE MACHINE — Velocity-based transitions.

     BOTTOM → ASCENDING : velocity < ASCENDING_THRESHOLD for 3+ frames
     ASCENDING → TOP_HOLD: |velocity| < REST for 5+ frames AND hip elevated
     TOP_HOLD → DESCENDING: velocity > DESCENDING_THRESHOLD for 3+ frames
                             → rep is counted here
     DESCENDING → BOTTOM : |velocity| < REST for 3+ frames AND hip ≈ baseline
     ----------------------------------------------------------------------- */
  void _updateGluteState(
    double hipY,
    double hipVelocity,
    double hipElevatedThreshold,
    double scaleFactor,
    int timestampMs,
  ) {
    final double baseline = _baselineHipY!;
    final double bottomTolerance = scaleFactor > 0
        ? scaleFactor * GluteBridgeConfig.BOTTOM_TOLERANCE_RATIO
        : GluteBridgeConfig.BOTTOM_TOLERANCE_PIXELS;

    final bool isAscending =
        hipVelocity < GluteBridgeConfig.ASCENDING_VELOCITY_THRESHOLD;
    final bool isDescending =
        hipVelocity > GluteBridgeConfig.DESCENDING_VELOCITY_THRESHOLD;
    final bool isAtRest =
        hipVelocity.abs() < GluteBridgeConfig.REST_VELOCITY_THRESHOLD;
    final bool isElevated = hipY < (baseline - hipElevatedThreshold);
    final bool isAtBottom = hipY >= (baseline - bottomTolerance);

    switch (gluteState) {
      case GluteBridgeState.bottom:
        if (_ascendDebouncer.update(isAscending)) {
          _peakHipY = hipY;
          _transitionState(GluteBridgeState.ascending, timestampMs);
        }
        break;

      case GluteBridgeState.ascending:
        // Normal path: reach top.
        if (_topHoldDebouncer.update(isAtRest && isElevated)) {
          _transitionState(GluteBridgeState.topHold, timestampMs);
        }
        // Fast-path: start descending immediately without holding.
        else if (_descendDebouncer.update(isDescending && isElevated)) {
          _transitionState(GluteBridgeState.descending, timestampMs);
        }
        // Abort: hip never got high enough and stopped moving.
        else if (_bottomDebouncer.update(isAtRest && isAtBottom)) {
          _transitionState(GluteBridgeState.bottom, timestampMs);
        }
        break;

      case GluteBridgeState.topHold:
        if (_descendDebouncer.update(isDescending)) {
          _transitionState(GluteBridgeState.descending, timestampMs);
        }
        break;

      case GluteBridgeState.descending:
        // Rep counted here when returning to bottom.
        if (_bottomDebouncer.update(isAtRest && isAtBottom)) {
          _onRepCompleted(timestampMs);
          _transitionState(GluteBridgeState.bottom, timestampMs);
        }
        // Fallback: If user goes right back into another rep without stopping at bottom.
        else if (_ascendDebouncer.update(isAscending)) {
          _onRepCompleted(timestampMs);
          _transitionState(GluteBridgeState.ascending, timestampMs);
        }
        break;
    }
  }

  /* -----------------------------------------------------------------------
     REP COMPLETION — Evaluate metrics and record set feedback.
     Called just before completing the descent phase.
     ----------------------------------------------------------------------- */
  void _onRepCompleted(int timestampMs) {
    repCount += 1;

    // Let HipExtensionMetric evaluate the peak angle and deviation.
    hipExtensionMetric.checkRepCompletion(
        _peakShoulderHipKneeAngle, _peakNormalizedDeviation);

    // Let KneeAngleMetric evaluate foot placement at top hold.
    kneeAngleMetric.checkRepCompletion(_peakKneeAngle);

    // Evaluate speed control (eccentric vs concentric ratio).
    speedControlMetric.checkRepCompletion(timestampMs);

    // Collect faults from all metrics.
    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      allFaults.addAll(metric.faults);
    }

    correctForm = !allFaults.any((f) => f.affectsForm);
    resultIssues.feedback
        .removeWhere((key, _) => key != 'System' && key != 'progress');
    resultIssues.feedback['Result'] = correctForm ? 'Tốt!' : 'Chỉnh tư thế';
    if (!correctForm) {
      final formFaults = allFaults.where((fault) => fault.affectsForm).toList()
        ..sort((a, b) {
          final priorityCompare = a.priority.compareTo(b.priority);
          if (priorityCompare != 0) return priorityCompare;
          return a.type.compareTo(b.type);
        });
      if (formFaults.isNotEmpty) {
        final topFault = formFaults.first;
        resultIssues.feedback[topFault.type] =
            topFault.voiceMessage ?? topFault.message;
      }
    }

    // Build fault map for set history.
    final faultMap = <String, Map<String, String>>{};
    for (final fault in allFaults) {
      faultMap.putIfAbsent(fault.phase, () => {})[fault.type] = fault.message;
    }
    setFeedback.add({correctForm: faultMap});

    // Merge metric debug data BEFORE reset.
    if (isDebugModeActive) {
      for (final metric in _metrics) {
        debugData.addAll(metric.debugData);
      }
    }

    logger.addRepLog(RepLog(
      correctForm: correctForm,
      repNumber: repCount,
      data: {
        "peak_hip_extension_angle": _peakShoulderHipKneeAngle ?? 0.0,
        "peak_normalized_hip_deviation": _peakNormalizedDeviation ?? 0.0,
        "peak_knee_angle": _peakKneeAngle ?? 0.0,
        "fault_types": allFaults.map((f) => f.type).toSet().toList(),
      },
    ));

    // Reset for next rep.
    correctForm = true;
    _peakHipY = null;
    _peakShoulderHipKneeAngle = null;
    _peakNormalizedDeviation = null;
    _peakKneeAngle = null;
    for (final metric in _metrics) {
      metric.resetAndCountFault();
    }
  }

  /* -----------------------------------------------------------------------
     STATE TRANSITION HELPER
     ----------------------------------------------------------------------- */
  void _transitionState(GluteBridgeState newState, int timestampMs) {
    previousGluteState = gluteState;
    gluteState = newState;
    _topHoldStartMs = newState == GluteBridgeState.topHold ? timestampMs : null;

    // Clear coaching instructions at the start of a new rep.
    if (newState == GluteBridgeState.ascending) {
      resultIssues.instructions.clear();
    }

    // Reset all debouncers to ensure a clean slate for the new state.
    _ascendDebouncer.reset();
    _topHoldDebouncer.reset();
    _descendDebouncer.reset();
    _bottomDebouncer.reset();

    for (final metric in _metrics) {
      metric.onStateTransition(previousGluteState, newState, timestampMs);
    }
  }
}
