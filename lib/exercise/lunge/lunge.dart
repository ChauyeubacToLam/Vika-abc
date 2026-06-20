// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/debug/tracked_metric.dart';
import '../../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/exercise_logger.dart';
import 'metrics/lunge_metric_base.dart';
import 'metrics/lunge_depth_metric.dart';
import 'metrics/lunge_trunk_lean_metric.dart';
import 'metrics/lunge_heel_lift_metric.dart';
import 'metrics/lunge_lumbar_proxy_metric.dart';
import '../../utils/debouncer.dart';

// --- Config ---

class LungeConfig {
  static const int MAX_REP = 15;
  static const int LUNGE_STAND_ANGLE_THRESHOLD = 155;
  static const int LUNGE_DESCEND_ANGLE_THRESHOLD = 145;
  static const List<int> LUNGE_BOTTOM_ANGLE_THRESHOLD = [55, 125];
  static const int LUNGE_ASCEND_ANGLE_THRESHOLD = 125;
  static const double CLEAN_REP_LEAD_KNEE_ANGLE = 178.6;
  static const double CLEAN_REP_LEAD_KNEE_TOLERANCE = 8.0;
  static const double CLEAN_REP_TRAIL_KNEE_ANGLE = 178.3;
  static const double CLEAN_REP_TRAIL_KNEE_TOLERANCE = 8.0;
  static const double CLEAN_REP_BACK_CLOCK_ANGLE = 358.0;
  static const double CLEAN_REP_BACK_CLOCK_TOLERANCE = 8.0;
  static const double CLEAN_REP_TRUNK_LEAN = -2.0;
  static const double CLEAN_REP_TRUNK_LEAN_TOLERANCE = 8.0;
  static const double CLEAN_REP_SH_TRAIL_KNEE_ANGLE = 203.1;
  static const double CLEAN_REP_SH_TRAIL_KNEE_TOLERANCE = 18.0;
  static const double CLEAN_REP_MIN_LEAD_KNEE_ANGLE = 58.6;
  static const double CLEAN_REP_MIN_LEAD_KNEE_TOLERANCE = 12.0;
  static const double CLEAN_REP_MAX_TRUNK_LEAN = 19.6;
  static const double CLEAN_REP_MAX_TRUNK_LEAN_TOLERANCE = 10.0;
  static const double CLEAN_REP_HEEL_NORM = 0.200;
  static const double CLEAN_REP_HEEL_NORM_TOLERANCE = 0.08;
}

enum LungeState { standing, descending, bottom, ascending }

// --- Lunge ---

class Lunge extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.portrait,
      };

  final int maxRep;

  Lunge({this.maxRep = LungeConfig.MAX_REP});

  LungeState lungeState = LungeState.standing;
  LungeState previousLungeState = LungeState.standing;
  bool _reachedBottomThisRep = false;
  int _rejectedShallowAttempts = 0;

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

  // --- Lead Leg Detection ---
  //
  // In side view, the lead (front) leg is the ankle closest to the
  // camera-facing edge. Debounced (5 frames) and locked per rep.

  bool? _isLeftLegLead;
  bool _leadLegLocked = false;
  final StickyDebouncer _leadLegDebouncer =
      StickyDebouncer(requiredFrames: 5, currentState: true);

  bool? _detectLeadLeg(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    if (leftAnkle == null || rightAnkle == null) return _isLeftLegLead;

    bool leftIsLead;
    if (cameraFacing == CameraFacing.left) {
      leftIsLead = leftAnkle.x < rightAnkle.x;
    } else if (cameraFacing == CameraFacing.right) {
      leftIsLead = leftAnkle.x > rightAnkle.x;
    } else {
      return _isLeftLegLead;
    }

    return _leadLegDebouncer.update(leftIsLead);
  }

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
    return (
      knee: landmarks[
          isLeft ? PoseLandmarkType.rightKnee : PoseLandmarkType.leftKnee],
      hip: landmarks[
          isLeft ? PoseLandmarkType.rightHip : PoseLandmarkType.leftHip],
      ankle: landmarks[
          isLeft ? PoseLandmarkType.rightAnkle : PoseLandmarkType.leftAnkle],
    );
  }

  // --- UI Bridge ---

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

  // --- Stop Condition ---

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey("depth_fails_count", depthMetric.faultsCount);
    logger.pushKey("trunk_lean_fails_count", trunkLeanMetric.faultsCount);
    logger.pushKey("heel_lift_fails_count", heelLiftMetric.faultsCount);
    logger.pushKey("lumbar_proxy_fails_count", lumbarProxyMetric.faultsCount);
    logger.pushKey("rejected_shallow_attempts_count", _rejectedShallowAttempts);

    logger.pushMin("min_lead_knee_angle", "min_lead_knee_angle");
    logger.pushMax("max_trunk_lean", "max_trunk_lean");

    logger.pushGoodRepCount();
    logger.pushKey("max_rep", maxRep);
  }

  // --- Safety Checks ---

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return "⚠️ Hãy quay sang bên để theo dõi Lunge tốt hơn";
    }

    // Lunge needs BOTH sides (unlike squat which uses getSideLandmark)
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

    if (allLandmarks.any((l) => !ExerciseBase.isLandmarkConfident(l))) {
      return "⚠️ Điều chỉnh ánh sáng/vị trí.";
    }

    return null;
  }

  // --- Start Position ---

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    // Require side view
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return false;
    }

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
    final knee = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightKnee,
      leftType: PoseLandmarkType.leftKnee,
    );

    if (shoulder == null || hip == null || knee == null) return false;

    // Trunk roughly vertical
    double trunkAngle = calculateVerticalAngle(pivot: hip, point: shoulder);
    double deviation = trunkAngle > 180 ? 360 - trunkAngle : trunkAngle;
    if (deviation > 25) return false;

    // Legs roughly straight
    final hipKneeAngle =
        calculateAngle(firstPoint: shoulder, midPoint: hip, lastPoint: knee);
    if (hipKneeAngle < LungeConfig.LUNGE_STAND_ANGLE_THRESHOLD) return false;

    return true;
  }

  // --- Main Loop (called every frame when activated) ---

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    // 1. Detect lead leg (before locking)
    if (!_leadLegLocked) {
      _isLeftLegLead = _detectLeadLeg(smoothedLandmarks);
    }

    // 2. Get landmarks (lead + trail)
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

    // 3. Calculate geometry
    double leadKneeAngle = calculateAngleNormalized(
        firstPoint: lead.hip!, midPoint: lead.knee!, lastPoint: lead.ankle!);

    double trailKneeAngle = calculateAngleNormalized(
        firstPoint: trail.hip!, midPoint: trail.knee!, lastPoint: trail.ankle!);

    double backAngle =
        calculateVerticalAngle(pivot: lead.hip!, point: lead.shoulder!);
    double trunkLean = convertClockAngleToTrunkLean(backAngle, cameraFacing);

    final leadFoot = smoothedLandmarks[(_isLeftLegLead ?? true)
        ? PoseLandmarkType.leftFootIndex
        : PoseLandmarkType.rightFootIndex];
    final leadHeel = smoothedLandmarks[(_isLeftLegLead ?? true)
        ? PoseLandmarkType.leftHeel
        : PoseLandmarkType.rightHeel];
    double heelDistance =
        (leadFoot != null && leadHeel != null) ? leadFoot.y - leadHeel.y : 0.0;

    double shoulderHipTrailKneeAngle = calculateAngle(
        firstPoint: lead.shoulder!,
        midPoint: lead.hip!,
        lastPoint: trail.knee!);

    int now = frameTimestampMs;

    // 4. Build LungeRepContext
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

    final debugEnabled = isDebugModeActive;
    // 5. Debug data
    debugData['lungeState'] = lungeState.toString().split('.').last;
    debugData['reachedBottomThisRep'] = _reachedBottomThisRep;
    debugData['rejectedShallowAttempts'] = _rejectedShallowAttempts;
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

    // 6. Rep completion (standing up)
    if (lungeState == LungeState.standing &&
        previousLungeState != LungeState.standing) {
      if (!_reachedBottomThisRep) {
        _rejectedShallowAttempts++;
        resultIssues.feedback['Result'] = 'Không tính';
        previousLungeState = LungeState.standing;
        _reachedBottomThisRep = false;
        _leadLegLocked = false;
        for (final metric in _metrics) {
          metric.reset();
        }
        return;
      }

      repCount += 1;

      depthMetric.checkRepCompletion(lungeState, ctx);
      _transitionState(LungeState.standing, now);

      final allFaults = <FaultRecord>[];
      for (final metric in _metrics) {
        allFaults.addAll(metric.faults);
      }

      _matchesCalibratedCleanRep(
        ctx,
        backClockAngle: backAngle,
      );

      correctForm = !allFaults.any((f) => f.affectsForm);
      resultIssues.feedback['Result'] = correctForm ? 'Good Rep!' : 'Fix Form';
      if (!correctForm) {
        final topFault = allFaults.firstWhere((fault) => fault.affectsForm);
        resultIssues.feedback[topFault.type] =
            topFault.voiceMessage ?? topFault.message;
      }

      final faultMap = <String, Map<String, String>>{};
      for (final fault in allFaults) {
        if (!faultMap.containsKey(fault.phase)) {
          faultMap[fault.phase] = {};
        }
        faultMap[fault.phase]![fault.type] = fault.message;
      }
      setFeedback.add({correctForm: faultMap});

      if (debugEnabled) {
        for (final metric in _metrics) {
          debugData.addAll(metric.debugData);
        }
      }

      logger.addRepLog(RepLog(
        correctForm: correctForm,
        repNumber: repCount,
        data: {
          "min_lead_knee_angle": depthMetric.minKneeAngle ?? leadKneeAngle,
          "max_trunk_lean": trunkLeanMetric.maxTrunkLean ?? trunkLean,
          "fault_types": allFaults.map((f) => f.type).toSet().toList(),
        },
      ));

      correctForm = true;
      for (final metric in _metrics) {
        metric.resetAndCountFault();
      }
      _reachedBottomThisRep = false;
      return;
    }

    // 7. Update state machine
    _updateLungeState(leadKneeAngle, now);

    // 8. Run all metrics
    if (lungeState != LungeState.standing) {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
    }

    if (debugEnabled) {
      for (final metric in _metrics) {
        debugData.addAll(metric.debugData);
      }
    }

    if (lungeState == LungeState.descending) {
      resultIssues.addInstruction('descending', 'Status', 'Đang xuống...');
    } else if (lungeState == LungeState.bottom) {
      resultIssues.addInstruction('bottom', 'Status', 'Đứng lên!');
    } else if (lungeState == LungeState.ascending) {
      resultIssues.addInstruction('ascending', 'Status', 'Đẩy lên!');
    }
  }

  bool _matchesCalibratedCleanRep(
    LungeRepContext ctx, {
    required double backClockAngle,
  }) {
    final safeScaleFactor = ctx.scaleFactor == null || ctx.scaleFactor == 0
        ? 1.0
        : ctx.scaleFactor!;
    final heelNorm = ctx.heelDistance / safeScaleFactor;
    final minLeadKneeAngle = depthMetric.minKneeAngle ?? ctx.leadKneeAngle;
    final maxTrunkLean = trunkLeanMetric.maxTrunkLean ?? ctx.trunkLean;

    final isMatch = _reachedBottomThisRep &&
        _within(
          ctx.leadKneeAngle,
          LungeConfig.CLEAN_REP_LEAD_KNEE_ANGLE,
          LungeConfig.CLEAN_REP_LEAD_KNEE_TOLERANCE,
        ) &&
        _within(
          ctx.trailKneeAngle,
          LungeConfig.CLEAN_REP_TRAIL_KNEE_ANGLE,
          LungeConfig.CLEAN_REP_TRAIL_KNEE_TOLERANCE,
        ) &&
        _withinCircularDegrees(
          backClockAngle,
          LungeConfig.CLEAN_REP_BACK_CLOCK_ANGLE,
          LungeConfig.CLEAN_REP_BACK_CLOCK_TOLERANCE,
        ) &&
        _within(
          ctx.trunkLean,
          LungeConfig.CLEAN_REP_TRUNK_LEAN,
          LungeConfig.CLEAN_REP_TRUNK_LEAN_TOLERANCE,
        ) &&
        _within(
          ctx.shoulderHipTrailKneeAngle,
          LungeConfig.CLEAN_REP_SH_TRAIL_KNEE_ANGLE,
          LungeConfig.CLEAN_REP_SH_TRAIL_KNEE_TOLERANCE,
        ) &&
        _within(
          minLeadKneeAngle,
          LungeConfig.CLEAN_REP_MIN_LEAD_KNEE_ANGLE,
          LungeConfig.CLEAN_REP_MIN_LEAD_KNEE_TOLERANCE,
        ) &&
        _within(
          maxTrunkLean,
          LungeConfig.CLEAN_REP_MAX_TRUNK_LEAN,
          LungeConfig.CLEAN_REP_MAX_TRUNK_LEAN_TOLERANCE,
        ) &&
        _within(
          heelNorm,
          LungeConfig.CLEAN_REP_HEEL_NORM,
          LungeConfig.CLEAN_REP_HEEL_NORM_TOLERANCE,
        );

    debugData['calibratedCleanRep'] = isMatch;
    debugData['calibratedLeadKneeDelta'] =
        ctx.leadKneeAngle - LungeConfig.CLEAN_REP_LEAD_KNEE_ANGLE;
    debugData['calibratedTrailKneeDelta'] =
        ctx.trailKneeAngle - LungeConfig.CLEAN_REP_TRAIL_KNEE_ANGLE;
    debugData['calibratedBackClockDelta'] = _circularDegreeDelta(
      backClockAngle,
      LungeConfig.CLEAN_REP_BACK_CLOCK_ANGLE,
    );
    debugData['calibratedTrunkDelta'] =
        ctx.trunkLean - LungeConfig.CLEAN_REP_TRUNK_LEAN;
    debugData['calibratedShTrailKneeDelta'] = ctx.shoulderHipTrailKneeAngle -
        LungeConfig.CLEAN_REP_SH_TRAIL_KNEE_ANGLE;
    debugData['calibratedMinLeadKneeDelta'] =
        minLeadKneeAngle - LungeConfig.CLEAN_REP_MIN_LEAD_KNEE_ANGLE;
    debugData['calibratedMaxTrunkDelta'] =
        maxTrunkLean - LungeConfig.CLEAN_REP_MAX_TRUNK_LEAN;
    debugData['calibratedHeelNormDelta'] =
        heelNorm - LungeConfig.CLEAN_REP_HEEL_NORM;

    return isMatch;
  }

  static bool _within(double value, double target, double tolerance) {
    return (value - target).abs() <= tolerance;
  }

  static bool _withinCircularDegrees(
    double value,
    double target,
    double tolerance,
  ) {
    return _circularDegreeDelta(value, target).abs() <= tolerance;
  }

  static double _circularDegreeDelta(double value, double target) {
    final normalized = ((value - target + 180) % 360) - 180;
    return normalized == -180 ? 180 : normalized;
  }

  // --- State Machine ---

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

    // Lock lead leg at rep start, unlock on return to standing
    if (newState == LungeState.descending &&
        previousLungeState == LungeState.standing) {
      _leadLegLocked = true;
      _reachedBottomThisRep = false;
      resultIssues.instructions.clear();
    } else if (newState == LungeState.bottom) {
      _reachedBottomThisRep = true;
    } else if (newState == LungeState.standing) {
      _leadLegLocked = false;
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousLungeState, newState, timestampMs);
    }
  }
}
