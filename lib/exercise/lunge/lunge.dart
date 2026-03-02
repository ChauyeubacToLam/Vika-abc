import 'package:vinafit_mobile/exercise/exercise_base.dart';
import '../../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'metrics/lunge_metric_base.dart';
import 'metrics/lunge_depth_metric.dart';
import 'metrics/lunge_trunk_lean_metric.dart';
import 'metrics/lunge_heel_lift_metric.dart';
import 'metrics/lunge_lumbar_proxy_metric.dart';
import '../../utils/debouncer.dart';

/* =========================================================================
   CONFIGURATION & THRESHOLDS
   ========================================================================= */
class LungeConfig {
  static const int MAX_REP = 15;

  // Standing: lead knee angle > 160°
  static const int LUNGE_STAND_ANGLE_THRESHOLD = 160;

  // Descending: lead knee angle < 150° AND was standing
  static const int LUNGE_DESCEND_ANGLE_THRESHOLD = 150;

  // Bottom: lead knee angle in [70°, 110°]
  static const List<int> LUNGE_BOTTOM_ANGLE_THRESHOLD = [70, 110];

  // Ascending: lead knee angle > 115° AND was bottom
  static const int LUNGE_ASCEND_ANGLE_THRESHOLD = 115;
}

enum LungeState {
  standing, // start position
  descending, // lowering
  bottom, // maximum depth reached
  ascending // pushing back up
}

class Lunge extends ExerciseBase {
  LungeState lungeState = LungeState.standing;
  LungeState previousLungeState = LungeState.standing;

  final LungeDepthMetric depthMetric = LungeDepthMetric();
  final LungeTrunkLeanMetric trunkLeanMetric = LungeTrunkLeanMetric();
  final LungeHeelLiftMetric heelLiftMetric = LungeHeelLiftMetric();
  final LungeLumbarProxyMetric lumbarProxyMetric = LungeLumbarProxyMetric();

  late final List<LungeMetricBase> _metrics = [
    depthMetric,
    trunkLeanMetric,
    heelLiftMetric,
    lumbarProxyMetric,
  ];

  /* -----------------------------------------------------------------------
     LEAD LEG DETECTION
     
     In side view, the LEAD (front) leg is the ankle closest to the camera-
     facing edge of the screen:
       - CameraFacing.left  → lead ankle has LOWER x value  (closer to left edge)
       - CameraFacing.right → lead ankle has HIGHER x value (closer to right edge)
     
     A StickyDebouncer (5 frames) prevents flickering.
     The result is locked when transitioning from standing → descending
     and held for the entire rep.
  ----------------------------------------------------------------------- */

  /// true = left leg is lead, false = right leg is lead, null = not yet determined
  bool? _isLeftLegLead;

  /// Locked at the start of each rep (standing → descending). Remains constant
  /// until the rep completes (back to standing).
  bool _leadLegLocked = false;

  /// Debouncer to stabilise lead-leg detection before locking.
  final StickyDebouncer _leadLegDebouncer =
      StickyDebouncer(requiredFrames: 5, currentState: true);

  /// Determines which leg is the lead leg based on ankle x-coordinates
  /// and the current camera facing direction.
  ///
  /// Returns `true` if the left leg is the lead leg, `false` otherwise.
  /// Returns `null` if ankle landmarks are missing.
  bool? _detectLeadLeg(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    if (leftAnkle == null || rightAnkle == null) return _isLeftLegLead;

    // Determine which ankle is closer to the camera-facing edge.
    bool leftIsLead;
    if (cameraFacing == CameraFacing.left) {
      // Camera facing left → lead ankle has lower x (closer to left edge)
      leftIsLead = leftAnkle.x < rightAnkle.x;
    } else if (cameraFacing == CameraFacing.right) {
      // Camera facing right → lead ankle has higher x (closer to right edge)
      leftIsLead = leftAnkle.x > rightAnkle.x;
    } else {
      // Front / angled — cannot reliably determine lead leg in side view
      return _isLeftLegLead;
    }

    // Debounce to avoid flickering between frames
    final debouncedResult = _leadLegDebouncer.update(leftIsLead);
    return debouncedResult;
  }

  /// Returns the landmark references for the lead and trail legs.
  /// Uses left/right based on [_isLeftLegLead].
  ({
    PoseLandmark? knee,
    PoseLandmark? hip,
    PoseLandmark? ankle,
    PoseLandmark? shoulder,
  }) _getLeadLandmarks(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final isLeft = _isLeftLegLead ?? true;
    return (
      knee: landmarks[
          isLeft ? PoseLandmarkType.leftKnee : PoseLandmarkType.rightKnee],
      hip: landmarks[
          isLeft ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip],
      ankle: landmarks[
          isLeft ? PoseLandmarkType.leftAnkle : PoseLandmarkType.rightAnkle],
      shoulder: landmarks[isLeft
          ? PoseLandmarkType.leftShoulder
          : PoseLandmarkType.rightShoulder],
    );
  }

  ({
    PoseLandmark? knee,
    PoseLandmark? hip,
    PoseLandmark? ankle,
  }) _getTrailLandmarks(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final isLeft = _isLeftLegLead ?? true;
    // Trail is the opposite side of lead
    return (
      knee: landmarks[
          isLeft ? PoseLandmarkType.rightKnee : PoseLandmarkType.leftKnee],
      hip: landmarks[
          isLeft ? PoseLandmarkType.rightHip : PoseLandmarkType.leftHip],
      ankle: landmarks[
          isLeft ? PoseLandmarkType.rightAnkle : PoseLandmarkType.leftAnkle],
    );
  }

  /* -----------------------------------------------------------------------
     UI BRIDGE
  ----------------------------------------------------------------------- */
  @override
  String get exerciseName => 'Lunge';

  @override
  String get currentPhaseKey => lungeState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (lungeState) {
      case LungeState.standing:
        return 'Đứng thẳng';
      case LungeState.descending:
        return 'Xuống';
      case LungeState.bottom:
        return 'Giữ';
      case LungeState.ascending:
        return 'Đứng lên';
    }
  }

  /* -----------------------------------------------------------------------
     SAFETY CHECKS
  ----------------------------------------------------------------------- */
  @override
  bool requestStop() {
    return repCount >= LungeConfig.MAX_REP;
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks,
      CameraFacing cameraFacing) {
    // Only accept side view for lunge — front view cannot distinguish lead/trail legs.
    if (cameraFacing == CameraFacing.front) {
      return "⚠️ Hãy quay sang bên để theo dõi Lunge tốt hơn";
    }

    // Check visibility and confidence of critical landmarks on BOTH sides
    // (lunge needs both legs unlike squat which uses getSideLandmark)
    PoseLandmark? leftHip = landmarks[PoseLandmarkType.leftHip];
    PoseLandmark? rightHip = landmarks[PoseLandmarkType.rightHip];
    PoseLandmark? leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    PoseLandmark? rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    PoseLandmark? leftKnee = landmarks[PoseLandmarkType.leftKnee];
    PoseLandmark? rightKnee = landmarks[PoseLandmarkType.rightKnee];
    PoseLandmark? leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    PoseLandmark? rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    PoseLandmark? leftFoot = landmarks[PoseLandmarkType.leftFootIndex];
    PoseLandmark? rightFoot = landmarks[PoseLandmarkType.rightFootIndex];
    PoseLandmark? leftHeel = landmarks[PoseLandmarkType.leftHeel];
    PoseLandmark? rightHeel = landmarks[PoseLandmarkType.rightHeel];

    if (leftHip == null ||
        rightHip == null ||
        leftShoulder == null ||
        rightShoulder == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null ||
        leftFoot == null ||
        rightFoot == null ||
        leftHeel == null ||
        rightHeel == null) {
      return "⚠️ Không thấy toàn bộ cơ thể.";
    }

    final allLandmarks = [
      leftHip,
      rightHip,
      leftShoulder,
      rightShoulder,
      leftKnee,
      rightKnee,
      leftAnkle,
      rightAnkle,
      leftFoot,
      rightFoot,
      leftHeel,
      rightHeel,
    ];

    if (allLandmarks.any((l) => l.likelihood < ExerciseBase.MIN_CONFIDENCE)) {
      return "⚠️ Điều chỉnh ánh sáng/vị trí.";
    }

    return null;
  }

  /* -----------------------------------------------------------------------
     MAIN PHYSICS LOOP — Called every frame when activated.
  ----------------------------------------------------------------------- */
  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks,
      CameraFacing cameraFacing, double? scaleFactor) {
    // ---------- 1. Detect Lead Leg (before locking) ----------

    if (!_leadLegLocked) {
      _isLeftLegLead = _detectLeadLeg(smoothedLandmarks);
    }

    // ---------- 2. Get Landmarks (lead + trail) ----------

    final lead = _getLeadLandmarks(smoothedLandmarks);
    final trail = _getTrailLandmarks(smoothedLandmarks);

    if (lead.knee == null ||
        lead.hip == null ||
        lead.ankle == null ||
        lead.shoulder == null ||
        trail.knee == null ||
        trail.hip == null ||
        trail.ankle == null) {
      return;
    }

    // ---------- 3. Calculate Geometry ----------

    // Lead knee angle: Hip-Knee-Ankle on lead leg
    double leadKneeAngle = calculateAngleNormalized(
        firstPoint: lead.hip!, midPoint: lead.knee!, lastPoint: lead.ankle!);

    // Trail knee angle: Hip-Knee-Ankle on trail leg
    double trailKneeAngle = calculateAngleNormalized(
        firstPoint: trail.hip!, midPoint: trail.knee!, lastPoint: trail.ankle!);

    // Trunk lean: vertical angle of shoulder relative to hip
    double backAngle =
        calculateVerticalAngle(pivot: lead.hip!, point: lead.shoulder!);
    double trunkLean = convertClockAngleToTrunkLean(backAngle, cameraFacing);

    // Heel distance: foot.y - heel.y on lead leg
    final leadFoot = smoothedLandmarks[(_isLeftLegLead ?? true)
        ? PoseLandmarkType.leftFootIndex
        : PoseLandmarkType.rightFootIndex];
    final leadHeel = smoothedLandmarks[(_isLeftLegLead ?? true)
        ? PoseLandmarkType.leftHeel
        : PoseLandmarkType.rightHeel];
    double heelDistance =
        (leadFoot != null && leadHeel != null) ? leadFoot.y - leadHeel.y : 0.0;

    // Shoulder-Hip-TrailingKnee angle (for lumbar proxy)
    double shoulderHipTrailKneeAngle = calculateAngle(
        firstPoint: lead.shoulder!,
        midPoint: lead.hip!,
        lastPoint: trail.knee!);

    int now = DateTime.now().millisecondsSinceEpoch;

    // ---------- 4. Build LungeRepContext ----------

    final ctx = LungeRepContext(
      leadKneeAngle: leadKneeAngle,
      trailKneeAngle: trailKneeAngle,
      trunkLean: trunkLean,
      heelDistance: heelDistance,
      shoulderHipTrailKneeAngle: shoulderHipTrailKneeAngle,
      lungeState: lungeState,
      isLeftLegLead: _isLeftLegLead ?? true,
      frameTimestamp: now,
      scaleFactor: scaleFactor,
      leadKneeY: lead.knee!.y,
      leadHipY: lead.hip!.y,
      resultIssues: resultIssues,
    );

    // ---------- 5. Populate Debug Data ----------

    debugData['lungeState'] = lungeState.toString().split('.').last;
    debugData['leadLeg'] = (_isLeftLegLead ?? true) ? 'Left' : 'Right';
    debugData['leadKneeAngle'] = leadKneeAngle.toStringAsFixed(1);
    debugData['trailKneeAngle'] = trailKneeAngle.toStringAsFixed(1);
    debugData['backClockAngle'] = backAngle.toStringAsFixed(1);
    debugData['trunkLean'] =
        '${trunkLean >= 0 ? "+" : ""}${trunkLean.toStringAsFixed(1)}°';
    debugData['shTrailKneeAngle'] =
        shoulderHipTrailKneeAngle.toStringAsFixed(1);
    debugData['heelDist'] = heelDistance.toStringAsFixed(2);
    debugData['correctForm'] = correctForm.toString();

    // ---------- 6. Rep Completion (Standing Up) ----------

    if (lungeState == LungeState.standing &&
        previousLungeState != LungeState.standing) {
      repCount += 1;

      // Let depth check if rep was deep enough
      depthMetric.checkRepCompletion(lungeState, ctx);

      // Fire final state transition
      _transitionState(LungeState.standing, now);

      // Collect faults from all metrics
      final allFaults = <FaultRecord>[];
      for (final metric in _metrics) {
        allFaults.addAll(metric.faults);
      }

      // Determine correctForm: true if no faults with affectsForm=true
      correctForm = !allFaults.any((f) => f.affectsForm);

      // UI feedback
      resultIssues.feedback['Result'] = correctForm ? 'Good Rep!' : 'Fix Form';

      // Build fault map for set history
      final faultMap = <String, Map<String, String>>{};
      for (final fault in allFaults) {
        if (!faultMap.containsKey(fault.phase)) {
          faultMap[fault.phase] = {};
        }
        faultMap[fault.phase]![fault.type] = fault.message;
      }
      setFeedback.add({correctForm: faultMap});

      // Merge metric debug data BEFORE reset
      for (final metric in _metrics) {
        debugData.addAll(metric.debugData);
      }

      // Reset metrics for next rep (instructions survive — shown during standing)
      correctForm = true;
      for (final metric in _metrics) {
        metric.reset();
      }
      return;
    }

    // ---------- 7. Update State Machine ----------

    _updateLungeState(leadKneeAngle, now);

    // ---------- 8. Run All Metrics ----------

    if (lungeState != LungeState.standing) {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
    }

    // Merge metric debug data
    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }

    // Status instruction based on current lunge phase
    if (lungeState == LungeState.descending) {
      resultIssues.addInstruction('descending', 'Status', 'Đang xuống...');
    } else if (lungeState == LungeState.bottom) {
      resultIssues.addInstruction('bottom', 'Status', 'Đứng lên!');
    } else if (lungeState == LungeState.ascending) {
      resultIssues.addInstruction('ascending', 'Status', 'Đẩy lên!');
    }
  }

  /* -----------------------------------------------------------------------
     STATE MACHINE (with transition notifications)
     
     standing ──(leadKnee < 150°)──▶ descending
                                        │
                                 (leadKnee in [70°,110°])
                                        ▼
     standing ◀──(leadKnee > 160°)── ascending ◀──(leadKnee > 115°)── bottom
  ----------------------------------------------------------------------- */

  void _updateLungeState(double leadKneeAngle, int timestampMs) {
    if (leadKneeAngle < LungeConfig.LUNGE_DESCEND_ANGLE_THRESHOLD &&
        lungeState == LungeState.standing) {
      _transitionState(LungeState.descending, timestampMs);
    } else if (leadKneeAngle <= LungeConfig.LUNGE_BOTTOM_ANGLE_THRESHOLD[1] &&
        leadKneeAngle >= LungeConfig.LUNGE_BOTTOM_ANGLE_THRESHOLD[0] &&
        lungeState == LungeState.descending) {
      _transitionState(LungeState.bottom, timestampMs);
    } else if (leadKneeAngle > LungeConfig.LUNGE_ASCEND_ANGLE_THRESHOLD &&
        lungeState == LungeState.bottom) {
      _transitionState(LungeState.ascending, timestampMs);
    } else if (leadKneeAngle > LungeConfig.LUNGE_STAND_ANGLE_THRESHOLD &&
        (lungeState == LungeState.ascending ||
            lungeState == LungeState.descending)) {
      _transitionState(LungeState.standing, timestampMs);
    }
  }

  void _transitionState(LungeState newState, int timestampMs) {
    previousLungeState = lungeState;
    lungeState = newState;

    // Lock lead leg when starting a new rep (standing → descending).
    // Unlock when returning to standing.
    if (newState == LungeState.descending &&
        previousLungeState == LungeState.standing) {
      _leadLegLocked = true;
      // Clear coaching instructions for the new rep
      resultIssues.instructions.clear();
    } else if (newState == LungeState.standing) {
      _leadLegLocked = false;
    }

    // Notify all metrics of the state transition
    for (final metric in _metrics) {
      metric.onStateTransition(previousLungeState, newState, timestampMs);
    }
  }
}
