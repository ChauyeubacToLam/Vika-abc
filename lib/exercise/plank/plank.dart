// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/utils/debouncer.dart';

import '../../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'metrics/plank_metric_base.dart';
import 'metrics/trunk_alignment_metric.dart';
import 'metrics/head_neck_metric.dart';
import 'metrics/knee_extension_metric.dart';

// --- Config (McGill Short-Hold Protocol: 3 holds × 10s, 5s rest) ---

class PlankConfig {
  static const int MAX_REP = 5;
  static const double HOLD_DURATION = 15.0;
  static const double REST_DURATION = 5.0;

  // Hip-to-floor ratio above which user is considered standing
  static const double STANDING_HIP_FLOOR_THRESHOLD = 0.5;

  // Trunk horizontal targets per facing direction
  static const double HORIZONTAL_CLOCK_LEFT = 270.0;
  static const double HORIZONTAL_CLOCK_RIGHT = 90.0;

  // Max deviation from horizontal to count as valid plank (degrees)
  static const double PLANK_POSITION_TOLERANCE = 25.0;

  // Trunk deviation thresholds for form assessment
  static const double SAG_GOOD_MAX = 4.5;
  static const double SAG_WARNING_MAX = 5.5;
  static const double PIKE_GOOD_MAX = 1.5;
  static const double PIKE_WARNING_MAX = 3.0;
}

enum PlankState { setup, holding, resting }

// --- Plank ---

class Plank extends ExerciseBase {
  final int maxRep;

  Plank({this.maxRep = PlankConfig.MAX_REP});

  PlankState plankState = PlankState.setup;
  PlankState previousPlankState = PlankState.setup;

  int? _holdStartMs;
  int? _restStartMs;
  bool _ankleAvailable = true;
  bool _spoken10 = false;
  bool _spoken5 = false;

  final Debouncer _positionDebouncer = Debouncer(requiredFrames: 2);

  final TrunkAlignmentMetric trunkAlignmentMetric = TrunkAlignmentMetric();
  final HeadNeckMetric headNeckMetric = HeadNeckMetric();
  final KneeExtensionMetric kneeExtensionMetric = KneeExtensionMetric();

  late final List<PlankMetricBase> _metrics = [
    trunkAlignmentMetric,
    headNeckMetric,
    kneeExtensionMetric,
  ];

  // --- UI Bridge ---

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

    if (shoulder == null || hip == null) return false;

    // Trunk must be roughly horizontal (within 25°)
    double trunkClockAngle =
        calculateVerticalAngle(pivot: hip, point: shoulder);
    double horizontalTarget = cameraFacing == CameraFacing.right
        ? PlankConfig.HORIZONTAL_CLOCK_RIGHT
        : PlankConfig.HORIZONTAL_CLOCK_LEFT;
    double diff = trunkClockAngle - horizontalTarget;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    if (diff.abs() > 25.0) return false;

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

    if (!ExerciseBase.isLandmarkConfident(shoulder) ||
        !ExerciseBase.isLandmarkConfident(hip) ||
        !ExerciseBase.isLandmarkConfident(ear)) {
      return "⚠️ Hình ảnh không rõ. Điều chỉnh ánh sáng hoặc vị trí";
    }

    // Ankle is optional — only for knee extension metric
    PoseLandmark? ankle = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle);

    _ankleAvailable = ankle != null &&
        ExerciseBase.isLandmarkConfident(ankle) &&
        ExerciseBase.isLandmarkConfident(knee);

    return null;
  }

  // --- Main Loop (called every frame when activated) ---

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    // 1. Get landmarks
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

    PoseLandmark? ankle = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle);

    // 2. Calculate geometry
    double trunkClockAngle =
        calculateVerticalAngle(pivot: hip, point: shoulder);

    double horizontalTarget = cameraFacing == CameraFacing.right
        ? PlankConfig.HORIZONTAL_CLOCK_RIGHT
        : PlankConfig.HORIZONTAL_CLOCK_LEFT;
    double trunkDeviation =
        clockAngleDeviation(trunkClockAngle, horizontalTarget);

    double neckAngle =
        calculateAngle(firstPoint: ear, midPoint: shoulder, lastPoint: hip);

    double? kneeAngle;
    if (_ankleAvailable && ankle != null) {
      kneeAngle =
          calculateAngle(firstPoint: hip, midPoint: knee, lastPoint: ankle);
    }

    PoseLandmark? foot = smoothedLandmarks[PoseLandmarkType.leftFootIndex] ??
        smoothedLandmarks[PoseLandmarkType.rightFootIndex];
    PoseLandmark? heel = smoothedLandmarks[PoseLandmarkType.leftHeel] ??
        smoothedLandmarks[PoseLandmarkType.rightHeel];

    double floorY = foot?.y ?? heel?.y ?? knee.y;
    double hipToFloor = (floorY - hip.y).abs() / scaleFactor;
    bool isStanding = hipToFloor > PlankConfig.STANDING_HIP_FLOOR_THRESHOLD;
    int now = frameTimestampMs;

    // 3. Build RepContext
    final ctx = RepContext(
      trunkDeviation: trunkDeviation,
      neckAngle: neckAngle,
      kneeAngle: kneeAngle,
      plankState: plankState,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    final debugEnabled = isDebugModeActive;
    // 4. Debug data
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

    // 5. Update plank state
    _updatePlankState(trunkDeviation, now, isStanding);

    // 6. Rest period feedback
    if (plankState == PlankState.resting && _restStartMs != null) {
      final restElapsed = (now - _restStartMs!) / 1000.0;
      final restRemaining = (PlankConfig.REST_DURATION - restElapsed)
          .clamp(0.0, PlankConfig.REST_DURATION);

      resultIssues.addInstruction(
          'resting', 'Status', 'Nghỉ ${restRemaining.toStringAsFixed(1)}s');
      debugData['restRemaining'] = restRemaining.toStringAsFixed(1);
    }

    // 7. Run metrics (only during holding)
    if (plankState == PlankState.holding) {
      for (final metric in _metrics) {
        if (metric == kneeExtensionMetric && !_ankleAvailable) continue;
        metric.update(ctx);
      }

      final holdSecs = _currentHoldSeconds();
      final remaining = (PlankConfig.HOLD_DURATION - holdSecs)
          .clamp(0.0, PlankConfig.HOLD_DURATION);

      if (remaining <= 10.0 && !_spoken10) {
        _spoken10 = true;
      }
      if (remaining <= 5.0 && !_spoken5) {
        _spoken5 = true;
      }

      resultIssues.addInstruction(
          'holding', 'Status', 'Giữ! ${remaining.toStringAsFixed(1)}s');
      debugData['holdProgress'] =
          (holdSecs / PlankConfig.HOLD_DURATION).clamp(0.0, 1.0);
    }

    // 8. Merge metric debug data
    if (debugEnabled) {
      for (final metric in _metrics) {
        debugData.addAll(metric.debugData);
      }
    }
  }

  // --- State Machine ---

  void _updatePlankState(
      double trunkDeviation, int timestampMs, bool isStanding) {
    bool isPlankPosition =
        trunkDeviation.abs() <= PlankConfig.PLANK_POSITION_TOLERANCE &&
            !isStanding;
    bool confirmedPlank = _positionDebouncer.update(isPlankPosition);

    debugData['isPlankPosition'] = confirmedPlank;

    switch (plankState) {
      case PlankState.setup:
        if (confirmedPlank) {
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
          if (restElapsed >= PlankConfig.REST_DURATION && confirmedPlank) {
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
        _spoken10 = false;
        _spoken5 = false;
        break;

      case PlankState.resting:
        _restStartMs = timestampMs;
        _onHoldComplete();
        break;

      case PlankState.setup:
        break;
    }
  }

  // --- Hold Complete ---

  void _onHoldComplete() {
    repCount += 1;

    final allFaults = <FaultRecord>[];
    for (final metric in _metrics) {
      metric.finalizeHold();
      allFaults.addAll(metric.faults);
    }

    correctForm = !allFaults.any((f) => f.affectsForm);

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

    final faultMap = <String, Map<String, String>>{};
    for (final fault in allFaults) {
      faultMap.putIfAbsent('HOLDING', () => {});
      faultMap['HOLDING']![fault.type] = fault.message;
    }
    setFeedback.add({correctForm: faultMap});

    if (isDebugModeActive) {
      for (final metric in _metrics) {
        debugData.addAll(metric.debugData);
      }
    }

    for (final metric in _metrics) {
      metric.reset();
    }
    correctForm = true;
  }

  // --- Helpers ---

  double _currentHoldSeconds() {
    if (_holdStartMs == null) return 0.0;
    return (frameTimestampMs - _holdStartMs!) / 1000.0;
  }
}
