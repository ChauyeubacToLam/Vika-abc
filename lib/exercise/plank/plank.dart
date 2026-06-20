// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/debug/tracked_metric.dart';
import 'package:vika/utils/debouncer.dart';
import 'package:vika/utils/exercise_logger.dart';

import '../../utils/pose_math_helpers.dart';
import '../../services/plank_voice_coach.dart';
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
  static const double PLANK_POSITION_TOLERANCE = 35.0;

  // Forearm plank gates copied from Plank Up-Down.
  static const double BODY_ALIGNMENT_START_MIN = 160.0;
  static const double BODY_ALIGNMENT_HOLD_MIN = 150.0;
  static const double KNEE_EXTENSION_MIN = 140.0;
  static const double ELBOW_FOREARM_MAX = 125.0;

  // Trunk deviation thresholds for form assessment
  static const double SAG_GOOD_MAX = 8.0;
  static const double SAG_WARNING_MAX = 12.0;
  static const double PIKE_GOOD_MAX = 4.0;
  static const double PIKE_WARNING_MAX = 8.0;
}

enum PlankState { setup, holding, resting }

// --- Plank ---

class Plank extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  final int maxRep;

  Plank({this.maxRep = PlankConfig.MAX_REP});

  PlankState plankState = PlankState.setup;
  PlankState previousPlankState = PlankState.setup;
  String? lastHoldFaultVoiceMessage;

  int? _holdStartMs;
  int? _restStartMs;
  bool _ankleAvailable = true;
  bool _spoken10 = false;
  bool _spoken5 = false;
  final HoldSecondsAccumulator _holdSeconds = HoldSecondsAccumulator(const [
    'trunk_seconds',
    'neck_seconds',
    'knee_seconds',
  ]);

  final Debouncer _positionDebouncer = Debouncer(requiredFrames: 2);

  final TrunkAlignmentMetric trunkAlignmentMetric = TrunkAlignmentMetric();
  final HeadNeckMetric headNeckMetric = HeadNeckMetric();
  final KneeExtensionMetric kneeExtensionMetric = KneeExtensionMetric();

  late final List<PlankMetricBase> _metrics = [
    trunkAlignmentMetric,
    headNeckMetric,
    kneeExtensionMetric,
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

  // --- UI Bridge ---

  @override
  String get exerciseName => 'Plank';

  @override
  ExerciseVoiceCoach? createVoiceCoach() => PlankVoiceCoach();

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

  @override
  double? get liveHoldSeconds =>
      plankState == PlankState.holding ? _currentHoldSeconds() : null;

  @override
  double? get liveHoldTargetSeconds => PlankConfig.HOLD_DURATION;

  // --- Start Position ---

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final geometry = _buildForearmPlankGeometry(landmarks);
    return geometry?.isStartPose ?? false;
  }

  // --- Stop Condition ---

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onExerciseActivated() {
    super.onExerciseActivated();
    _holdSeconds.reset();
    lastHoldFaultVoiceMessage = null;
  }

  @override
  void onSetComplete() {
    logger.pushKey("max_rep", maxRep);
    logger.pushKey("total_seconds", maxRep * PlankConfig.HOLD_DURATION);
    logger.pushKey(
      "good_seconds",
      _holdSeconds.goodSeconds.clamp(0.0, maxRep * PlankConfig.HOLD_DURATION),
    );
    logger.pushKey(
        "trunk_seconds", _holdSeconds.faultSecondsFor('trunk_seconds'));
    logger.pushKey(
        "neck_seconds", _holdSeconds.faultSecondsFor('neck_seconds'));
    logger.pushKey(
        "knee_seconds", _holdSeconds.faultSecondsFor('knee_seconds'));
    logger.pushGoodRepCount();
  }

  // --- Safety Checks ---

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return "Xin hãy quay nghiêng để theo dõi tư thế Plank";
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

    PoseLandmark? ankle = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle);

    _ankleAvailable = ankle != null &&
        ExerciseBase.isLandmarkConfident(ankle) &&
        ExerciseBase.isLandmarkConfident(knee);
    if (!_ankleAvailable) {
      return "Giữ cả cổ chân trong khung hình để kiểm tra gối.";
    }

    return null;
  }

  // --- Main Loop (called every frame when activated) ---

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final geometry = _buildForearmPlankGeometry(smoothedLandmarks);

    if (geometry == null) {
      if (plankState == PlankState.holding) {
        _transitionState(PlankState.setup, frameTimestampMs);
      }
      _holdSeconds.resetTick();
      return;
    }
    _ankleAvailable = true;

    int now = frameTimestampMs;

    // 3. Build RepContext
    final ctx = RepContext(
      trunkDeviation: geometry.trunkDeviation,
      neckAngle: geometry.neckAngle,
      kneeAngle: geometry.kneeAngle,
      plankState: plankState,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    final debugEnabled = isDebugModeActive;
    // 4. Debug data
    debugData['plankState'] = plankState.toString().split('.').last;
    debugData['trunkClock'] = geometry.trunkClockAngle.toStringAsFixed(1);
    debugData['trunkDev'] =
        '${geometry.trunkDeviation >= 0 ? "+" : ""}${geometry.trunkDeviation.toStringAsFixed(1)}°';
    debugData['neckAngle'] = geometry.neckAngle.toStringAsFixed(1);
    debugData['bodyAngle'] = geometry.bodyAngle.toStringAsFixed(1);
    debugData['kneeAngle'] = geometry.kneeAngle.toStringAsFixed(1);
    debugData['elbowAngle'] = geometry.elbowAngle.toStringAsFixed(1);
    debugData['holdTime'] = _currentHoldSeconds().toStringAsFixed(1);
    debugData['repCount'] = repCount.toString();
    debugData['isStanding'] = geometry.isStanding;
    debugData['isForearmPlank'] = geometry.isForearmPlank;
    debugData['bodyAligned'] = geometry.isBodyAlignedForHold;
    debugData['kneeExtended'] = geometry.isKneeExtended;
    debugData['ankleAvail'] = true;

    // 5. Update plank state
    _updatePlankState(geometry, now);

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

      _holdSeconds.accumulate(
        elapsedMs: elapsedMs,
        faultingByKey: {
          'trunk_seconds': trunkAlignmentMetric.isFaultingNow,
          'neck_seconds': headNeckMetric.isFaultingNow,
          'knee_seconds': _ankleAvailable && kneeExtensionMetric.isFaultingNow,
        },
      );

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
    } else {
      _holdSeconds.resetTick();
    }

    // 8. Merge metric debug data
    if (debugEnabled) {
      for (final metric in _metrics) {
        debugData.addAll(metric.debugData);
      }
    }
  }

  // --- State Machine ---

  void _updatePlankState(_ForearmPlankGeometry geometry, int timestampMs) {
    bool isPlankPosition = geometry.isHoldPose;
    bool confirmedPlank = _positionDebouncer.update(isPlankPosition);

    debugData['isPlankPosition'] = confirmedPlank;

    if (!geometry.isForearmPlank) {
      resultIssues.feedback['Arms'] = 'Chống bằng cẳng tay để vào Plank';
    }
    if (!geometry.isBodyAlignedForHold) {
      resultIssues.feedback['Body'] = 'Giữ thân người thẳng như plank';
    }
    if (!geometry.isKneeExtended) {
      resultIssues.feedback['Knees'] = 'Thẳng đầu gối ra';
    }

    switch (plankState) {
      case PlankState.setup:
        if (confirmedPlank) {
          lastHoldFaultVoiceMessage = null;
          _transitionState(PlankState.holding, timestampMs);
        }
        break;

      case PlankState.holding:
        if (!isPlankPosition) {
          lastHoldFaultVoiceMessage = _voiceForHoldBreak(geometry);
          _transitionState(PlankState.setup, timestampMs);
        } else if (_currentHoldSeconds() >= PlankConfig.HOLD_DURATION) {
          lastHoldFaultVoiceMessage = null;
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
        _holdSeconds.resetTick();
        _holdStartMs = timestampMs;
        _restStartMs = null;
        resultIssues.instructions.clear();
        _spoken10 = false;
        _spoken5 = false;
        break;

      case PlankState.resting:
        _holdSeconds.resetTick();
        _restStartMs = timestampMs;
        _onHoldComplete();
        break;

      case PlankState.setup:
        _holdSeconds.resetTick();
        _holdStartMs = null;
        break;
    }
  }

  String _voiceForHoldBreak(_ForearmPlankGeometry geometry) {
    if (!geometry.isForearmPlank) {
      return 'Chống bằng cẳng tay';
    }
    if (!geometry.isKneeExtended) {
      return 'Thẳng đầu gối ra';
    }
    if (!geometry.isBodyAlignedForHold) {
      if (geometry.trunkDeviation < 0) {
        return 'Hạ hông xuống, giữ thân thẳng';
      }
      return 'Gồng cơ bụng, nâng hông lên';
    }
    if (!geometry.isTrunkHorizontal) {
      if (geometry.trunkDeviation < 0) {
        return 'Hạ hông xuống, giữ thân thẳng';
      }
      return 'Gồng cơ bụng, nâng hông lên';
    }
    if (geometry.isStanding) {
      return 'Chống bằng cẳng tay';
    }
    return 'Giữ thân người thẳng';
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
    logger.addRepLog(RepLog(
      correctForm: correctForm,
      repNumber: repCount,
      data: {
        'hold_time': PlankConfig.HOLD_DURATION,
        'fault_types': allFaults.map((f) => f.type).toSet().toList(),
      },
    ));

    for (final metric in _metrics) {
      metric.resetAndCountFault();
    }

    if (isDebugModeActive) {
      for (final metric in _metrics) {
        debugData.addAll(metric.debugData);
      }
    }
    correctForm = true;
  }

  @override
  Map<String, String> processNoPoseFrame() {
    if (plankState == PlankState.holding) {
      lastHoldFaultVoiceMessage = 'Giữ cả người trong khung hình';
      _transitionState(PlankState.setup, frameTimestampMs);
    }
    _holdSeconds.resetTick();
    return super.processNoPoseFrame();
  }

  // --- Helpers ---

  _ForearmPlankGeometry? _buildForearmPlankGeometry(
      Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final side = _selectForearmPlankSide(landmarks);
    if (side == null) return null;

    final trackingLandmarks = [
      side.shoulder,
      side.hip,
      side.ear,
      side.knee,
      side.ankle,
      side.elbow,
      side.wrist,
    ];
    if (!trackingLandmarks.every(ExerciseBase.isLandmarkConfident)) {
      return null;
    }

    final scale = calculateDistance(side.shoulder, side.hip);
    if (!scale.isFinite || scale <= 1e-6) return null;

    final trunkClockAngle =
        calculateVerticalAngle(pivot: side.hip, point: side.shoulder);
    final horizontalTarget = cameraFacing == CameraFacing.right
        ? PlankConfig.HORIZONTAL_CLOCK_RIGHT
        : PlankConfig.HORIZONTAL_CLOCK_LEFT;
    final trunkDeviation =
        clockAngleDeviation(trunkClockAngle, horizontalTarget);

    final neckAngle = calculateAngle(
      firstPoint: side.ear,
      midPoint: side.shoulder,
      lastPoint: side.hip,
    );
    final bodyAngle = calculateAngleNormalized(
      firstPoint: side.shoulder,
      midPoint: side.hip,
      lastPoint: side.ankle,
    );
    final kneeAngle = calculateAngleNormalized(
      firstPoint: side.hip,
      midPoint: side.knee,
      lastPoint: side.ankle,
    );
    final elbowAngle = calculateAngleNormalized(
      firstPoint: side.shoulder,
      midPoint: side.elbow,
      lastPoint: side.wrist,
    );

    final floorY = side.foot?.y ?? side.heel?.y ?? side.knee.y;
    final hipToFloor = (floorY - side.hip.y).abs() / scale;

    return _ForearmPlankGeometry(
      trunkClockAngle: trunkClockAngle,
      trunkDeviation: trunkDeviation,
      neckAngle: neckAngle,
      bodyAngle: bodyAngle,
      kneeAngle: kneeAngle,
      elbowAngle: elbowAngle,
      hipToFloor: hipToFloor,
    );
  }

  _ForearmPlankSide? _selectForearmPlankSide(
      Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final left = _buildForearmPlankSide(
      landmarks,
      shoulderType: PoseLandmarkType.leftShoulder,
      hipType: PoseLandmarkType.leftHip,
      earType: PoseLandmarkType.leftEar,
      kneeType: PoseLandmarkType.leftKnee,
      ankleType: PoseLandmarkType.leftAnkle,
      elbowType: PoseLandmarkType.leftElbow,
      wristType: PoseLandmarkType.leftWrist,
      heelType: PoseLandmarkType.leftHeel,
      footType: PoseLandmarkType.leftFootIndex,
    );
    final right = _buildForearmPlankSide(
      landmarks,
      shoulderType: PoseLandmarkType.rightShoulder,
      hipType: PoseLandmarkType.rightHip,
      earType: PoseLandmarkType.rightEar,
      kneeType: PoseLandmarkType.rightKnee,
      ankleType: PoseLandmarkType.rightAnkle,
      elbowType: PoseLandmarkType.rightElbow,
      wristType: PoseLandmarkType.rightWrist,
      heelType: PoseLandmarkType.rightHeel,
      footType: PoseLandmarkType.rightFootIndex,
    );

    if (cameraFacing == CameraFacing.right) return right ?? left;
    if (cameraFacing == CameraFacing.left) return left ?? right;
    if (left == null) return right;
    if (right == null) return left;
    return left.hip.likelihood >= right.hip.likelihood ? left : right;
  }

  _ForearmPlankSide? _buildForearmPlankSide(
    Map<PoseLandmarkType, PoseLandmark> landmarks, {
    required PoseLandmarkType shoulderType,
    required PoseLandmarkType hipType,
    required PoseLandmarkType earType,
    required PoseLandmarkType kneeType,
    required PoseLandmarkType ankleType,
    required PoseLandmarkType elbowType,
    required PoseLandmarkType wristType,
    required PoseLandmarkType heelType,
    required PoseLandmarkType footType,
  }) {
    final shoulder = landmarks[shoulderType];
    final hip = landmarks[hipType];
    final ear = landmarks[earType];
    final knee = landmarks[kneeType];
    final ankle = landmarks[ankleType];
    final elbow = landmarks[elbowType];
    final wrist = landmarks[wristType];

    if (shoulder == null ||
        hip == null ||
        ear == null ||
        knee == null ||
        ankle == null ||
        elbow == null ||
        wrist == null) {
      return null;
    }

    final heel = _confidentOptionalLandmark(landmarks[heelType]);
    final foot = _confidentOptionalLandmark(landmarks[footType]);

    return _ForearmPlankSide(
      shoulder: shoulder,
      hip: hip,
      ear: ear,
      knee: knee,
      ankle: ankle,
      elbow: elbow,
      wrist: wrist,
      heel: heel,
      foot: foot,
    );
  }

  PoseLandmark? _confidentOptionalLandmark(PoseLandmark? landmark) {
    if (landmark == null) return null;
    return ExerciseBase.isLandmarkConfident(landmark) ? landmark : null;
  }

  double _currentHoldSeconds() {
    if (_holdStartMs == null) return 0.0;
    return (frameTimestampMs - _holdStartMs!) / 1000.0;
  }
}

class _ForearmPlankSide {
  const _ForearmPlankSide({
    required this.shoulder,
    required this.hip,
    required this.ear,
    required this.knee,
    required this.ankle,
    required this.elbow,
    required this.wrist,
    required this.heel,
    required this.foot,
  });

  final PoseLandmark shoulder;
  final PoseLandmark hip;
  final PoseLandmark ear;
  final PoseLandmark knee;
  final PoseLandmark ankle;
  final PoseLandmark elbow;
  final PoseLandmark wrist;
  final PoseLandmark? heel;
  final PoseLandmark? foot;
}

class _ForearmPlankGeometry {
  const _ForearmPlankGeometry({
    required this.trunkClockAngle,
    required this.trunkDeviation,
    required this.neckAngle,
    required this.bodyAngle,
    required this.kneeAngle,
    required this.elbowAngle,
    required this.hipToFloor,
  });

  final double trunkClockAngle;
  final double trunkDeviation;
  final double neckAngle;
  final double bodyAngle;
  final double kneeAngle;
  final double elbowAngle;
  final double hipToFloor;

  bool get isTrunkHorizontal =>
      trunkDeviation.abs() <= PlankConfig.PLANK_POSITION_TOLERANCE;
  bool get isBodyAlignedForStart =>
      bodyAngle >= PlankConfig.BODY_ALIGNMENT_START_MIN;
  bool get isBodyAlignedForHold =>
      bodyAngle >= PlankConfig.BODY_ALIGNMENT_HOLD_MIN;
  bool get isKneeExtended => kneeAngle >= PlankConfig.KNEE_EXTENSION_MIN;
  bool get isForearmPlank => elbowAngle <= PlankConfig.ELBOW_FOREARM_MAX;
  bool get isStanding => hipToFloor > PlankConfig.STANDING_HIP_FLOOR_THRESHOLD;

  bool get isStartPose =>
      isTrunkHorizontal &&
      isBodyAlignedForStart &&
      isKneeExtended &&
      isForearmPlank &&
      !isStanding;

  bool get isHoldPose =>
      isTrunkHorizontal &&
      isBodyAlignedForHold &&
      isKneeExtended &&
      isForearmPlank &&
      !isStanding;
}
