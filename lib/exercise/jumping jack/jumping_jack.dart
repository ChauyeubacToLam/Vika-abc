// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'dart:math' as math;

import 'package:vika/utils/debouncer.dart';

import '../../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../exercise_base.dart';
import 'metrics/jumping_jack_metric_base.dart';
import 'metrics/arm_extension_metric.dart';
import 'metrics/leg_spread_metric.dart';
import 'metrics/tempo_metric.dart';

// --- Config ---

class JumpingJackConfig {
  static const int MAX_REP = 30;

  // All normalized to shoulder width for body-size independence
  static const double OPEN_ANKLE_SPREAD_THRESHOLD = 1.2;
  static const double CLOSED_ANKLE_SPREAD_THRESHOLD = 0.5;
  static const double OPEN_ARM_ELEVATION_MIN = 105.0;
  static const double CLOSED_ARM_ELEVATION_MAX = 100.0;
}

enum JJState { closed, open }

// --- Jumping Jack (front-view exercise) ---

class JumpingJack extends ExerciseBase {
  final int maxRep;

  JumpingJack({this.maxRep = JumpingJackConfig.MAX_REP});

  JJState jjState = JJState.closed;
  JJState previousJJState = JJState.closed;

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

  // Shoulder width as scale factor for front view
  double? _shoulderWidth;

  // --- UI Bridge ---

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

  // --- Start Position ---

  @override
  void onExerciseActivated() {
    super.onExerciseActivated();
    ttsService.speak("Sẵn sàng, mở");
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
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

    // Trunk must be roughly vertical
    double trunkClockAngle =
        calculateVerticalAngle(pivot: hip, point: shoulder);
    double deviationFromVertical = trunkClockAngle;
    if (deviationFromVertical > 180)
      deviationFromVertical = 360 - deviationFromVertical;
    if (deviationFromVertical > 25.0) return false;

    // Legs must be straight (knee angle > 155°)
    double kneeAngle = calculateAngleNormalized(
      firstPoint: hip,
      midPoint: knee,
      lastPoint: ankle,
    );
    if (kneeAngle < 155.0) return false;

    return true;
  }

  // --- Stop Condition ---

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {}

  // --- Safety Checks (requires front view) ---

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.left ||
        cameraFacing == CameraFacing.right) {
      return "⚠️ Xin hãy quay mặt về phía camera để theo dõi Nhảy Dạng";
    }

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

  // --- Main Loop (called every frame when activated, front view) ---

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    // 1. Get all bilateral landmarks
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
    scaleFactor = _shoulderWidth ?? 1.0;
    if (_shoulderWidth == null || _shoulderWidth! <= 1.0) return;

    // 2. Calculate geometry
    final leftArmAngle = calculateAngle(
        firstPoint: leftShoulder, midPoint: leftElbow, lastPoint: leftWrist);
    final rightArmAngle = calculateAngle(
        firstPoint: rightShoulder, midPoint: rightElbow, lastPoint: rightWrist);

    final leftArmElevation = calculateAngleNormalized(
        firstPoint: leftHip, midPoint: leftShoulder, lastPoint: leftWrist);
    final rightArmElevation = calculateAngleNormalized(
        firstPoint: rightHip, midPoint: rightShoulder, lastPoint: rightWrist);

    final ankleDistance = calculateDistance(leftAnkle, rightAnkle);
    final ankleSpreadNorm = ankleDistance / _shoulderWidth!;

    final wristAboveHead = leftWrist.y < nose.y && rightWrist.y < nose.y;
    final wristBelowShoulders =
        leftWrist.y > leftShoulder.y && rightWrist.y > rightShoulder.y;

    final avgArmElevation = (leftArmElevation + rightArmElevation) / 2.0;

    int now = frameTimestampMs;

    // 3. Build RepContext
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

    // 4. Debug data
    debugData['jjState'] = jjState.toString().split('.').last;
    debugData['ankleSpread'] = ankleSpreadNorm.toStringAsFixed(2);
    debugData['leftElev'] = leftArmElevation.toStringAsFixed(1);
    debugData['rightElev'] = rightArmElevation.toStringAsFixed(1);
    debugData['wristAbove'] = wristAboveHead.toString();
    debugData['correctForm'] = correctForm.toString();

    // 5. Rep completion (return to closed)
    if (jjState == JJState.closed && previousJJState == JJState.open) {
      repCount += 1;
      previousJJState = jjState;

      armExtensionMetric.evaluateRep(ctx);
      legSpreadMetric.evaluateRep(ctx);
      tempoMetric.evaluateRep(ctx, now);

      final allFaults = <FaultRecord>[];
      for (final metric in _metrics) {
        allFaults.addAll(metric.faults);
      }

      correctForm = !allFaults.any((f) => f.affectsForm);
      resultIssues.feedback['Result'] = correctForm ? 'Tốt lắm!' : 'Sửa tư thế';

      final faultMap = <String, Map<String, String>>{};
      for (final fault in allFaults) {
        if (!faultMap.containsKey(fault.phase)) {
          faultMap[fault.phase] = {};
        }
        faultMap[fault.phase]![fault.type] = fault.message;
      }
      setFeedback.add({correctForm: faultMap});

      speakRepCompletion(
        nextPhaseVoice: "Mở",
        correctForm: correctForm,
      );

      for (final metric in _metrics) {
        debugData.addAll(metric.debugData);
      }

      if (tempoMetric.lastRepDuration != null) {
        resultIssues.feedback['Tempo'] =
            '${tempoMetric.lastRepDuration!.toStringAsFixed(1)}s';
      }

      correctForm = true;
      for (final metric in _metrics) {
        metric.reset();
      }
      return;
    }

    // 6. Update state machine
    _updateJJState(ankleSpreadNorm, avgArmElevation, wristAboveHead,
        wristBelowShoulders, now);

    // 7. Run all metrics
    for (final metric in _metrics) {
      metric.update(ctx);
    }

    // 8. Merge metric debug data
    for (final metric in _metrics) {
      debugData.addAll(metric.debugData);
    }

    if (jjState == JJState.closed) {
      resultIssues.addInstruction('closed', 'Status', 'Vào');
    } else if (jjState == JJState.open) {
      resultIssues.addInstruction('open', 'Status', 'Mở rộng!');
    }
  }

  // --- State Machine (2-state, fast transitions) ---

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

    if (newState == JJState.open && previousJJState == JJState.closed) {
      ttsService.clearQueue();
      resultIssues.instructions.clear();
      ttsService.speak("Đóng");
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousJJState, newState, timestampMs);
    }
  }
}
