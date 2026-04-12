// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'package:vinafit_mobile/utils/debouncer.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../exercise_base.dart';
import '../../utils/pose_math_helpers.dart';
import 'metrics/curl_up_metric_base.dart';
import 'metrics/curl_up_trunk_elevation.dart';
import 'metrics/curl_up_neck_pulling.dart';
import 'metrics/curl_up_knee_extension.dart';

// --- Config ---

class CurlUpConfig {
  static const int MAX_REP = 15;

  // Trunk angle from horizontal (0° = flat, increases as shoulders rise)
  static const double RESTING_ANGLE_THRESHOLD = 12.0;
  static const double ASCENDING_ANGLE_THRESHOLD = 20.0;

  // Apex detected by kinematic reversal, not fixed threshold
  static const double MIN_APEX_ANGLE = 22.0;
  static const int REVERSAL_FRAMES = 3;

  // Bent knee elevation (fraction of torso length) for McGill setup
  static const double BENT_KNEE_ELEVATION = 0.15;
}

enum CurlUpState { resting, ascending, apex, descending }

// --- Curl Up ---

class CurlUp extends ExerciseBase {
  final int maxRep;

  CurlUp({this.maxRep = CurlUpConfig.MAX_REP});

  CurlUpState curlUpState = CurlUpState.resting;
  CurlUpState previousCurlUpState = CurlUpState.resting;

  final Debouncer _entryDebouncer = Debouncer(requiredFrames: 2);

  // Baselines captured during hold-still activation
  double? _holdStillEarShoulderHip;
  double? _holdStillShoulderHipKnee;

  // Kinematic reversal detection
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

  // --- UI Bridge ---

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

  // --- Start Position ---

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

    // Camera-side knee must be bent (McGill setup)
    double torsoLength = (shoulder.y - hip.y).abs();
    if (torsoLength < 1) return false;
    double kneeElevation = (hip.y - knee.y) / torsoLength;
    if (kneeElevation < CurlUpConfig.BENT_KNEE_ELEVATION) return false;

    // Capture baselines during hold-still
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

  // --- Stop Condition ---

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {}

  // --- Safety Checks ---

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return "⚠️ Quay nghiêng để AI theo dõi Curl Up tốt hơn";
    }
    if (cameraFacing == CameraFacing.angled) {
      return "⚠️ Quay nghiêng hẳn 90° — camera chưa đủ nghiêng";
    }
    if (cameraFacing == CameraFacing.undefined) {
      return "⚠️ Không xác định được góc camera";
    }

    // Ankle is optional — KneeExtensionMetric runs opportunistically
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

  // --- Main Loop (called every frame when activated) ---

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    // 1. Get landmarks
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

    PoseLandmark? ankle = getSideLandmark(
      landmarks: smoothedLandmarks,
      rightType: PoseLandmarkType.rightAnkle,
      leftType: PoseLandmarkType.leftAnkle,
    );
    bool ankleVisible =
        ankle != null && ankle.likelihood >= ExerciseBase.MIN_CONFIDENCE;

    if (shoulder == null || hip == null || knee == null || ear == null) return;

    // 2. Calculate geometry
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
    int now = frameTimestampMs;

    // 3. Build RepContext
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

    // 4. Rep completion (back to resting)
    if (curlUpState == CurlUpState.resting &&
        previousCurlUpState == CurlUpState.descending) {
      repCount += 1;

      previousCurlUpState = CurlUpState.resting;
      trunkElevationMetric.checkRepCompletion(ctx);

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

    // 5. Update state machine
    _updateCurlUpState(trunkAngle, shoulder.y, now);

    // 6. Run all metrics
    if (curlUpState == CurlUpState.resting) {
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

    if (curlUpState == CurlUpState.ascending) {
      resultIssues.addInstruction('ascending', 'Status', 'Cuộn lên...');
    } else if (curlUpState == CurlUpState.apex) {
      resultIssues.addInstruction('apex', 'Status', 'Đỉnh!');
    } else if (curlUpState == CurlUpState.descending) {
      resultIssues.addInstruction('descending', 'Status', 'Hạ từ từ...');
    }
  }

  // --- State Machine ---

  void _updateCurlUpState(
      double trunkAngle, double shoulderY, int timestampMs) {
    // Resting → Ascending
    bool isEnteringRep = trunkAngle >= CurlUpConfig.ASCENDING_ANGLE_THRESHOLD;
    bool confirmedEntry = _entryDebouncer.update(isEnteringRep);

    if (confirmedEntry && curlUpState == CurlUpState.resting) {
      _prevShoulderY = shoulderY;
      _reversalCount = 0;
      _transitionState(CurlUpState.ascending, timestampMs);
      return;
    }

    // Descending/Ascending → Resting
    if (trunkAngle < CurlUpConfig.RESTING_ANGLE_THRESHOLD &&
        (curlUpState == CurlUpState.descending ||
            curlUpState == CurlUpState.ascending)) {
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

    // Ascending → Apex (kinematic reversal: shoulder.y increases = user descending)
    if (curlUpState == CurlUpState.ascending) {
      if (_prevShoulderY != null &&
          shoulderY > _prevShoulderY! &&
          trunkAngle >= CurlUpConfig.MIN_APEX_ANGLE) {
        _reversalCount++;
        if (_reversalCount >= CurlUpConfig.REVERSAL_FRAMES) {
          _transitionState(CurlUpState.apex, timestampMs);
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
    if (newState == CurlUpState.ascending &&
        previousCurlUpState == CurlUpState.resting) {
      resultIssues.instructions.clear();
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousCurlUpState, newState, timestampMs);
    }
  }
}
