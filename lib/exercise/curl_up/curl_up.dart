// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'dart:math' as math;

import 'package:vinafit_mobile/utils/debouncer.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../exercise_base.dart';
import '../../utils/pose_math_helpers.dart';
import 'metrics/curl_up_metric_base.dart';
import 'metrics/curl_up_trunk_elevation.dart';
import 'metrics/curl_up_neck_pulling.dart';
import 'metrics/curl_up_knee_extension.dart';

/* =========================================================================
   CONFIGURATION & THRESHOLDS
   ========================================================================= */
class CurlUpConfig {
  static const int MAX_REP = 15;

  /// Trunk angle from horizontal (degrees).
  /// 0° = lying flat, increases as shoulders rise.
  static const double RESTING_ANGLE_THRESHOLD = 12.0;
  static const double ASCENDING_ANGLE_THRESHOLD = 20.0;

  /// Minimum angle to be considered "curling" before reversal detection.
  /// Apex is detected by kinematic reversal (shoulder.y starts rising),
  /// not a fixed threshold.
  static const double MIN_APEX_ANGLE = 22.0;

  /// Number of consecutive frames shoulder.y must increase to confirm
  /// kinematic reversal (ascending → apex).
  static const int REVERSAL_FRAMES = 3;

  /// Minimum knee elevation (as fraction of torso length) to confirm
  /// bent knee in McGill setup. Bent knee sticks up in side view;
  /// straight leg stays near hip height.
  static const double BENT_KNEE_ELEVATION = 0.15;
}

enum CurlUpState {
  resting, // start position (lying flat)
  ascending, // curling up
  apex, // maximum curl reached
  descending, // lowering back down
}

/* =========================================================================
   CURL UP LOGIC
   ========================================================================= */

class CurlUp extends ExerciseBase {
  CurlUpState curlUpState = CurlUpState.resting;
  CurlUpState previousCurlUpState = CurlUpState.resting;

  final Debouncer _entryDebouncer = Debouncer(requiredFrames: 2);

  /// Baselines captured during hold-still activation (3s motionless).
  double? _holdStillEarShoulderHip;
  double? _holdStillShoulderHipKnee;

  /// Tracks previous shoulder.y for kinematic reversal detection.
  double? _prevShoulderY;
  int _reversalCount = 0;
  final TrunkElevationMetric trunkElevationMetric = TrunkElevationMetric();
  final NeckPullingMetric neckPullingMetric = NeckPullingMetric();
  final KneeExtensionMetric kneeExtensionMetric = KneeExtensionMetric();

  late final List<CurlUpMetricBase> _metrics = [
    trunkElevationMetric,
    neckPullingMetric,
    kneeExtensionMetric,
  ];

  /* -----------------------------------------------------------------------
     UI BRIDGE
  ----------------------------------------------------------------------- */
  @override
  String get exerciseName => 'Curl Up';

  @override
  String get currentPhaseKey => curlUpState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (curlUpState) {
      case CurlUpState.resting:
        return 'Nằm';
      case CurlUpState.ascending:
        return 'Cuộn lên';
      case CurlUpState.apex:
        return 'Đỉnh';
      case CurlUpState.descending:
        return 'Hạ xuống';
    }
  }

  /* -----------------------------------------------------------------------
     INITIALIZATION
  ----------------------------------------------------------------------- */
  @override
  bool isInStartPosition(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing facing,
    double? scaleFactor,
  ) {
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
    final ear = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightEar,
      leftType: PoseLandmarkType.leftEar,
    );

    if (shoulder == null || hip == null || knee == null || ear == null)
      return false;

    // Trunk must be roughly horizontal (lying flat)
    double trunkAngle = calculateHorizontalAngle(point1: shoulder, point2: hip);
    if (trunkAngle > 15.0) return false;

    // McGill setup: camera-side knee must be bent.
    // Bent knee sticks up in side view (knee.y < hip.y in screen coords).
    // Normalized by torso length for body-size independence.
    // User instruction: "Quay đầu gối co về phía camera."
    double torsoLength = (shoulder.y - hip.y).abs();
    if (torsoLength < 1) return false;
    double kneeElevation = (hip.y - knee.y) / torsoLength;
    if (kneeElevation < CurlUpConfig.BENT_KNEE_ELEVATION) return false;

    // Capture baselines during hold-still. Last frame wins —
    // user is motionless so all frames are equivalent.
    _holdStillShoulderHipKnee = calculateAngleNormalized(
      firstPoint: shoulder,
      midPoint: hip,
      lastPoint: knee,
    );

    _holdStillEarShoulderHip = calculateAngleNormalized(
      firstPoint: ear,
      midPoint: shoulder,
      lastPoint: hip,
    );

    return true;
  }

  /* -----------------------------------------------------------------------
     STOP CONDITION
  ----------------------------------------------------------------------- */
  @override
  bool requestStop() {
    return repCount >= CurlUpConfig.MAX_REP;
  }

  /* -----------------------------------------------------------------------
     SAFETY CHECKS
  ----------------------------------------------------------------------- */
  @override
  String? checkSafety(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    CameraFacing cameraFacing,
  ) {
    // Side profile only — reject front, angled, and undefined views.
    if (cameraFacing == CameraFacing.front) {
      return "⚠️ Quay nghiêng để AI theo dõi Curl Up tốt hơn";
    }
    if (cameraFacing == CameraFacing.angled) {
      return "⚠️ Quay nghiêng hẳn 90° — camera chưa đủ nghiêng";
    }
    if (cameraFacing == CameraFacing.undefined) {
      return "⚠️ Không xác định được góc camera";
    }

    // Only require landmarks needed by critical metrics.
    // Ankle is optional — KneeExtensionMetric runs opportunistically.
    PoseLandmark? shoulder = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightShoulder,
      leftType: PoseLandmarkType.leftShoulder,
    );
    PoseLandmark? hip = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightHip,
      leftType: PoseLandmarkType.leftHip,
    );
    PoseLandmark? knee = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightKnee,
      leftType: PoseLandmarkType.leftKnee,
    );
    PoseLandmark? ear = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightEar,
      leftType: PoseLandmarkType.leftEar,
    );

    if (shoulder == null || hip == null || knee == null || ear == null) {
      return "⚠️ Không thấy đủ cơ thể.";
    }

    if (shoulder.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        hip.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        knee.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        ear.likelihood < ExerciseBase.MIN_CONFIDENCE) {
      return "⚠️ Điều chỉnh ánh sáng/vị trí.";
    }

    return null;
  }

  /* -----------------------------------------------------------------------
     MAIN PHYSICS LOOP
  ----------------------------------------------------------------------- */
  @override
  void checkingPose(
    Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks,
    CameraFacing cameraFacing,
    double? scaleFactor,
  ) {
    // ---------- 1. Get Landmarks ----------

    PoseLandmark? shoulder = getSideLandmark(
      landmarks: smoothedLandmarks,
      rightType: PoseLandmarkType.rightShoulder,
      leftType: PoseLandmarkType.leftShoulder,
    );
    PoseLandmark? hip = getSideLandmark(
      landmarks: smoothedLandmarks,
      rightType: PoseLandmarkType.rightHip,
      leftType: PoseLandmarkType.leftHip,
    );
    PoseLandmark? knee = getSideLandmark(
      landmarks: smoothedLandmarks,
      rightType: PoseLandmarkType.rightKnee,
      leftType: PoseLandmarkType.leftKnee,
    );
    PoseLandmark? ear = getSideLandmark(
      landmarks: smoothedLandmarks,
      rightType: PoseLandmarkType.rightEar,
      leftType: PoseLandmarkType.leftEar,
    );

    // Ankle is optional — only needed for KneeExtensionMetric.
    PoseLandmark? ankle = getSideLandmark(
      landmarks: smoothedLandmarks,
      rightType: PoseLandmarkType.rightAnkle,
      leftType: PoseLandmarkType.leftAnkle,
    );
    bool ankleVisible =
        ankle != null && ankle.likelihood >= ExerciseBase.MIN_CONFIDENCE;

    // Critical landmarks only. Ankle absence doesn't block processing.
    if (shoulder == null || hip == null || knee == null || ear == null) return;

    // ---------- 2. Calculate Geometry ----------

    double trunkAngle = calculateHorizontalAngle(point1: shoulder, point2: hip);
    double shoulderHipKneeAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: knee);
    double earShoulderHipAngle = calculateAngleNormalized(
        firstPoint: ear, midPoint: shoulder, lastPoint: hip);

    double? hipKneeAnkleAngle = ankleVisible
        ? calculateAngleNormalized(
            firstPoint: hip, midPoint: knee, lastPoint: ankle)
        : null;
    if (hipKneeAnkleAngle == 0.0) {}
    int now = DateTime.now().millisecondsSinceEpoch;

    // ---------- 3. Build RepContext ----------

    final ctx = RepContext(
      trunkAngle: trunkAngle,
      shoulderHipKneeAngle: shoulderHipKneeAngle,
      earShoulderHipAngle: earShoulderHipAngle,
      hipKneeAnkleAngle: hipKneeAnkleAngle,
      scaleFactor: scaleFactor,
      curlUpState: curlUpState,
      frameTimestamp: now,
      shoulderY: shoulder.y,
      hipY: hip.y,
      kneeY: knee.y,
      holdStillEarShoulderHip: _holdStillEarShoulderHip,
      holdStillShoulderHipKnee: _holdStillShoulderHipKnee,
      resultIssues: resultIssues,
    );

    // ---------- 4. Rep Completion (Back to Resting) ----------

    // Only count a rep if the user completed the full cycle (went through
    // descending). An aborted ascending that drops back to resting without
    // reaching the apex does NOT count.
    if (curlUpState == CurlUpState.resting &&
        previousCurlUpState == CurlUpState.descending) {
      repCount += 1;

      previousCurlUpState = CurlUpState.resting;

      // Let trunk elevation evaluate the completed rep
      trunkElevationMetric.checkRepCompletion(ctx);

      // Collect faults from all metrics
      final allFaults = <FaultRecord>[];
      for (final metric in _metrics) {
        allFaults.addAll(metric.faults);
      }

      final repCorrect = !allFaults.any((f) => f.affectsForm);

      resultIssues.feedback['Result'] = repCorrect ? 'Good Rep!' : 'Fix Form';

      final faultMap = <String, Map<String, String>>{};
      for (final fault in allFaults) {
        if (!faultMap.containsKey(fault.phase)) {
          faultMap[fault.phase] = {};
        }
        faultMap[fault.phase]![fault.type] = fault.message;
      }
      setFeedback.add({repCorrect: faultMap});

      for (final metric in _metrics) {
        debugData.addAll(metric.debugData);
      }

      correctForm = true;
      for (final metric in _metrics) {
        metric.reset();
      }
      return;
    }

    // ---------- 5. Update State Machine ----------

    _updateCurlUpState(trunkAngle, shoulder.y, now);

    // ---------- 6. Run All Metrics ----------

    if (curlUpState == CurlUpState.resting) {
      // Sample baselines from the actual lying position
      for (final metric in _metrics) {
        metric.onRestingFrame(ctx);
      }
    } else {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
    }

    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }

    // Status instruction based on current phase
    if (curlUpState == CurlUpState.ascending) {
      resultIssues.addInstruction('ascending', 'Status', 'Cuộn lên...');
    } else if (curlUpState == CurlUpState.apex) {
      resultIssues.addInstruction('apex', 'Status', 'Đỉnh!');
    } else if (curlUpState == CurlUpState.descending) {
      resultIssues.addInstruction('descending', 'Status', 'Hạ từ từ...');
    }
  }

  /* -----------------------------------------------------------------------
     STATE MACHINE
  ----------------------------------------------------------------------- */

  void _updateCurlUpState(
      double trunkAngle, double shoulderY, int timestampMs) {
    // --- Resting → Ascending: debounced entry ---
    bool isEnteringRep = trunkAngle >= CurlUpConfig.ASCENDING_ANGLE_THRESHOLD;
    bool confirmedEntry = _entryDebouncer.update(isEnteringRep);

    if (confirmedEntry && curlUpState == CurlUpState.resting) {
      _prevShoulderY = shoulderY;
      _reversalCount = 0;
      _transitionState(CurlUpState.ascending, timestampMs);
      return;
    }

    // --- Descending or Ascending → Resting: trunk returns to flat ---
    // NOTE: checked before reversal detection so an aborted ascending
    // (never reaches MIN_APEX_ANGLE) can still return to resting.
    if (trunkAngle < CurlUpConfig.RESTING_ANGLE_THRESHOLD &&
        (curlUpState == CurlUpState.descending ||
            curlUpState == CurlUpState.ascending)) {
      // If aborting from ascending, reset metrics (no rep counted,
      // but faults/state from the partial curl must be cleared).
      if (curlUpState == CurlUpState.ascending) {
        for (final metric in _metrics) {
          metric.reset();
        }
      }

      _transitionState(CurlUpState.resting, timestampMs);
      _prevShoulderY = null;
      _reversalCount = 0;
      return;
    }

    // --- Ascending → Apex: kinematic reversal detection ---
    // In screen coords, Y increases downward, so shoulder.y DECREASES
    // as user curls up. Reversal = shoulder.y starts INCREASING.
    if (curlUpState == CurlUpState.ascending) {
      if (_prevShoulderY != null &&
          shoulderY > _prevShoulderY! &&
          trunkAngle >= CurlUpConfig.MIN_APEX_ANGLE) {
        _reversalCount++;
        if (_reversalCount >= CurlUpConfig.REVERSAL_FRAMES) {
          _transitionState(CurlUpState.apex, timestampMs);
          // Immediately transition to descending — apex is instantaneous
          _transitionState(CurlUpState.descending, timestampMs);
          _reversalCount = 0;
        }
      } else {
        _reversalCount = 0;
      }
      _prevShoulderY = shoulderY;
    }
  }

  void _transitionState(CurlUpState newState, int timestampMs) {
    previousCurlUpState = curlUpState;
    curlUpState = newState;

    if (newState == CurlUpState.ascending) {
      resultIssues.instructions.clear();
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousCurlUpState, newState, timestampMs);
    }
  }
}
