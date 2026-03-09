// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'dart:math' as math;

import 'package:vinafit_mobile/utils/debouncer.dart';

import '../../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../exercise_base.dart';
import 'metrics/jumping_jack_metric_base.dart';
import 'metrics/arm_extension_metric.dart';
import 'metrics/leg_spread_metric.dart';
import 'metrics/tempo_metric.dart';

/* =========================================================================
   CONFIGURATION & THRESHOLDS
   ========================================================================= */
class JumpingJackConfig {
  /// Max reps per set — office workers doing quick cardio bursts
  static const int MAX_REP = 30;

  // -- State transition thresholds --
  // All normalized to shoulder width for body-size independence.

  /// Ankle spread (÷ shoulder width) to enter OPEN state
  static const double OPEN_ANKLE_SPREAD_THRESHOLD = 1.2;

  /// Ankle spread (÷ shoulder width) to return to CLOSED state
  static const double CLOSED_ANKLE_SPREAD_THRESHOLD = 0.5;

  /// Minimum arm elevation (degrees from horizontal) for OPEN state
  /// Combined with ankle spread for robust OPEN detection
  static const double OPEN_ARM_ELEVATION_MIN = 105.0;

  /// Maximum arm elevation for CLOSED state (arms at sides)
  static const double CLOSED_ARM_ELEVATION_MAX = 100.0;
}

/* =========================================================================
   STATE ENUM
   ========================================================================= */
enum JJState {
  closed,
  open,
}

/* =========================================================================
   JUMPING JACK LOGIC — FRONT VIEW EXERCISE
   
   First front-facing exercise in VinaFit. Key differences from squat/plank:
   - REQUIRES front view (rejects side view)
   - Uses BOTH left + right landmarks simultaneously
   - Scale factor = shoulder width (not back length)
   - 2-state machine (closed/open) — simpler but FASTER (~1 rep/sec)
   
   Vietnamese context:
   - Universal familiarity from school PE (Bài tập nhảy dạng)
   - Minimal floor impact — apartment-friendly
   - ~1m² floor space needed
   - Land on balls of feet to reduce noise
   ========================================================================= */

class JumpingJack extends ExerciseBase {
  JJState jjState = JJState.closed;
  JJState previousJJState = JJState.closed;

  // -- Metrics --
  final ArmExtensionMetric armExtensionMetric = ArmExtensionMetric();
  final LegSpreadMetric legSpreadMetric = LegSpreadMetric();
  final TempoMetric tempoMetric = TempoMetric();

  final Debouncer _openDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _closedDebouncer = Debouncer(requiredFrames: 2);

  late final List<JJMetricBase> _metrics = [
    armExtensionMetric,
    legSpreadMetric,
    tempoMetric,
  ];

  // -- Shoulder width as scale factor for front view --
  double? _shoulderWidth;

  /* -----------------------------------------------------------------------
     UI BRIDGE
     ----------------------------------------------------------------------- */
  @override
  String get exerciseName => 'Nhảy Dạng';

  @override
  String get currentPhaseKey => jjState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (jjState) {
      case JJState.closed:
        return 'Đóng';
      case JJState.open:
        return 'Mở';
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
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return false;
    }

    final shoulder = PoseLandmark(
      type: PoseLandmarkType.leftShoulder,
      x: (leftShoulder.x + rightShoulder.x) / 2,
      y: (leftShoulder.y + rightShoulder.y) / 2,
      z: (leftShoulder.z + rightShoulder.z) / 2,
      likelihood: math.min(leftShoulder.likelihood, rightShoulder.likelihood),
    );
    final hip = PoseLandmark(
      type: PoseLandmarkType.leftHip,
      x: (leftHip.x + rightHip.x) / 2,
      y: (leftHip.y + rightHip.y) / 2,
      z: (leftHip.z + rightHip.z) / 2,
      likelihood: math.min(leftHip.likelihood, rightHip.likelihood),
    );
    final knee = PoseLandmark(
      type: PoseLandmarkType.leftKnee,
      x: (leftKnee.x + rightKnee.x) / 2,
      y: (leftKnee.y + rightKnee.y) / 2,
      z: (leftKnee.z + rightKnee.z) / 2,
      likelihood: math.min(leftKnee.likelihood, rightKnee.likelihood),
    );
    final ankle = PoseLandmark(
      type: PoseLandmarkType.leftAnkle,
      x: (leftAnkle.x + rightAnkle.x) / 2,
      y: (leftAnkle.y + rightAnkle.y) / 2,
      z: (leftAnkle.z + rightAnkle.z) / 2,
      likelihood: math.min(leftAnkle.likelihood, rightAnkle.likelihood),
    );

    // 1. Trunk must be roughly vertical (clock angle near 0°/360°)
    double trunkClockAngle =
        calculateVerticalAngle(pivot: hip, point: shoulder);
    // Near vertical: clock angle close to 0° (or 360°)
    double deviationFromVertical = trunkClockAngle;
    if (deviationFromVertical > 180)
      deviationFromVertical = 360 - deviationFromVertical;
    if (deviationFromVertical > 25.0) return false;

    // 2. Legs must be straight (knee angle > 155° = standing)
    double kneeAngle = calculateAngleNormalized(
      firstPoint: hip,
      midPoint: knee,
      lastPoint: ankle,
    );
    if (kneeAngle < 155.0) return false;

    return true;
  }

  /* -----------------------------------------------------------------------
     STOP CONDITION
     ----------------------------------------------------------------------- */
  @override
  bool requestStop() {
    return repCount >= JumpingJackConfig.MAX_REP;
  }

  /* -----------------------------------------------------------------------
     SAFETY CHECKS — REQUIRE FRONT VIEW
     ----------------------------------------------------------------------- */
  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks,
      CameraFacing cameraFacing) {
    // Jumping jacks REQUIRE front view — the opposite of squat/plank
    if (cameraFacing == CameraFacing.left ||
        cameraFacing == CameraFacing.right) {
      return "⚠️ Xin hãy quay mặt về phía camera để theo dõi Nhảy Dạng";
    }

    // Check visibility of ALL bilateral landmarks
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null ||
        leftWrist == null ||
        rightWrist == null ||
        leftHip == null ||
        rightHip == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return "⚠️ Đảm bảo toàn thân trong khung hình";
    }

    // Confidence check on critical landmarks
    if (leftShoulder.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        rightShoulder.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        leftWrist.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        rightWrist.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        leftAnkle.likelihood < ExerciseBase.MIN_CONFIDENCE ||
        rightAnkle.likelihood < ExerciseBase.MIN_CONFIDENCE) {
      return "⚠️ Hình ảnh không rõ. Điều chỉnh ánh sáng hoặc vị trí";
    }

    return null;
  }

  /* -----------------------------------------------------------------------
     MAIN PHYSICS LOOP — Called every frame when activated.
     
     FRONT VIEW: Uses BOTH left + right landmarks directly.
     Does NOT use getSideLandmark() — that's for side-view exercises.
     ----------------------------------------------------------------------- */
  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks,
      CameraFacing cameraFacing, double? scaleFactor) {
    // ---------- 1. Get ALL Bilateral Landmarks ----------
    final leftShoulder = smoothedLandmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = smoothedLandmarks[PoseLandmarkType.rightShoulder];
    final leftElbow = smoothedLandmarks[PoseLandmarkType.leftElbow];
    final rightElbow = smoothedLandmarks[PoseLandmarkType.rightElbow];
    final leftWrist = smoothedLandmarks[PoseLandmarkType.leftWrist];
    final rightWrist = smoothedLandmarks[PoseLandmarkType.rightWrist];
    final leftHip = smoothedLandmarks[PoseLandmarkType.leftHip];
    final rightHip = smoothedLandmarks[PoseLandmarkType.rightHip];
    final leftAnkle = smoothedLandmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = smoothedLandmarks[PoseLandmarkType.rightAnkle];
    final nose = smoothedLandmarks[PoseLandmarkType.nose];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null ||
        leftWrist == null ||
        rightWrist == null ||
        leftHip == null ||
        rightHip == null ||
        leftAnkle == null ||
        rightAnkle == null ||
        nose == null) return;

    _shoulderWidth = calculateDistance(leftShoulder, rightShoulder);
    distanceScaleFactor = _shoulderWidth;
    if (_shoulderWidth == null || _shoulderWidth! <= 1.0) return;

    // ---------- 3. Calculate Geometry ----------

    // Arm angles (shoulder→elbow→wrist), unsigned 0–180°
    final leftArmAngle = calculateAngle(
        firstPoint: leftShoulder, midPoint: leftElbow, lastPoint: leftWrist);
    final rightArmAngle = calculateAngle(
        firstPoint: rightShoulder, midPoint: rightElbow, lastPoint: rightWrist);

    // Arm elevation: angle of shoulder→wrist vector from horizontal
    // 90° = horizontal (arms to side), 180° = straight up
    final leftArmElevation = calculateAngleNormalized(
        firstPoint: leftHip, midPoint: leftShoulder, lastPoint: leftWrist);
    final rightArmElevation = calculateAngleNormalized(
        firstPoint: rightHip, midPoint: rightShoulder, lastPoint: rightWrist);

    // Ankle spread normalized to shoulder width
    final ankleDistance = calculateDistance(leftAnkle, rightAnkle);
    final ankleSpreadNorm = ankleDistance / _shoulderWidth!;

    // Wrist positions relative to body
    final wristAboveHead = leftWrist.y < nose.y && rightWrist.y < nose.y;
    final wristBelowShoulders =
        leftWrist.y > leftShoulder.y && rightWrist.y > rightShoulder.y;

    // Average arm elevation for state machine
    final avgArmElevation = (leftArmElevation + rightArmElevation) / 2.0;

    int now = DateTime.now().millisecondsSinceEpoch;

    // ---------- 4. Build RepContext ----------
    final ctx = RepContext(
      leftArmAngle: leftArmAngle,
      rightArmAngle: rightArmAngle,
      leftArmElevation: leftArmElevation,
      rightArmElevation: rightArmElevation,
      ankleSpreadNorm: ankleSpreadNorm,
      wristAboveHead: wristAboveHead,
      wristBelowShoulders: wristBelowShoulders,
      jjState: jjState,
      frameTimestamp: now,
      scaleFactor: scaleFactor,
      resultIssues: resultIssues,
    );

    // ---------- 5. Populate Debug Data ----------
    debugData['jjState'] = jjState.toString().split('.').last;
    debugData['ankleSpread'] = ankleSpreadNorm.toStringAsFixed(2);
    debugData['leftElev'] = leftArmElevation.toStringAsFixed(1);
    debugData['rightElev'] = rightArmElevation.toStringAsFixed(1);
    debugData['wristAbove'] = wristAboveHead.toString();
    debugData['correctForm'] = correctForm.toString();

    // ---------- 6. Rep Completion (Return to CLOSED) ----------

    if (jjState == JJState.closed && previousJJState == JJState.open) {
      repCount += 1;
      previousJJState = jjState; // Update previous state for next cycle

      // Evaluate rep quality via metrics
      armExtensionMetric.evaluateRep(ctx);
      legSpreadMetric.evaluateRep(ctx);
      tempoMetric.evaluateRep(ctx, now);

      // Collect faults from all metrics
      final allFaults = <FaultRecord>[];
      for (final metric in _metrics) {
        allFaults.addAll(metric.faults);
      }

      // Determine correctForm: true if no faults with affectsForm=true
      correctForm = !allFaults.any((f) => f.affectsForm);

      // UI feedback
      resultIssues.feedback['Result'] = correctForm ? 'Tốt lắm!' : 'Sửa tư thế';

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

      // Add tempo summary
      if (tempoMetric.lastRepDuration != null) {
        resultIssues.feedback['Tempo'] =
            '${tempoMetric.lastRepDuration!.toStringAsFixed(1)}s';
      }

      // Reset metrics for next rep (instructions survive during closed phase)
      correctForm = true;
      for (final metric in _metrics) {
        metric.reset();
      }
      return;
    }

    // ---------- 7. Update State Machine ----------
    _updateJJState(ankleSpreadNorm, avgArmElevation, wristAboveHead,
        wristBelowShoulders, now);

    // ---------- 8. Run All Metrics ----------
    for (final metric in _metrics) {
      metric.update(ctx);
    }

    // ---------- 9. Merge Metric Debug Data ----------
    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }

    // Status instructions
    if (jjState == JJState.closed) {
      resultIssues.addInstruction('closed', 'Status', 'Vào');
    } else if (jjState == JJState.open) {
      resultIssues.addInstruction('open', 'Status', 'Mở rộng!');
    }
  }

  /* -----------------------------------------------------------------------
     STATE MACHINE — 2 states, fast transitions
     
     CLOSED → OPEN:  ankleSpread > threshold AND arms elevated
     OPEN → CLOSED:  ankleSpread < threshold AND arms down
     ----------------------------------------------------------------------- */
  void _updateJJState(double ankleSpreadNorm, double avgArmElevation,
      bool wristAboveHead, bool wristBelowShoulders, int timestampMs) {
    final isOpenCandidate =
        ankleSpreadNorm > JumpingJackConfig.OPEN_ANKLE_SPREAD_THRESHOLD &&
            avgArmElevation > JumpingJackConfig.OPEN_ARM_ELEVATION_MIN &&
            wristAboveHead;
    final isClosedCandidate =
        ankleSpreadNorm < JumpingJackConfig.CLOSED_ANKLE_SPREAD_THRESHOLD &&
            avgArmElevation < JumpingJackConfig.CLOSED_ARM_ELEVATION_MAX &&
            wristBelowShoulders;

    final debouncedOpen = _openDebouncer.update(isOpenCandidate);
    final debouncedClosed = _closedDebouncer.update(isClosedCandidate);

    if (debouncedOpen && jjState == JJState.closed) {
      _transitionState(JJState.open, timestampMs);
    } else if (debouncedClosed && jjState == JJState.open) {
      _transitionState(JJState.closed, timestampMs);
    }
  }

  void _transitionState(JJState newState, int timestampMs) {
    previousJJState = jjState;
    jjState = newState;

    // Clear coaching instructions when starting a new rep cycle
    if (newState == JJState.open && previousJJState == JJState.closed) {
      resultIssues.instructions.clear();
    }

    // Notify all metrics
    for (final metric in _metrics) {
      metric.onStateTransition(previousJJState, newState, timestampMs);
    }
  }
}
