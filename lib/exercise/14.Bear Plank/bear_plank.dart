// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/debug/tracked_metric.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
import '../../utils/debouncer.dart';
import '../exercise_base.dart';
import 'metrics/bear_plank_metric_base.dart';
import 'metrics/knee_hover_metric.dart';
import 'metrics/flat_back_metric.dart';
import 'metrics/weight_distribution_metric.dart';

class BearPlank extends ExerciseBase {
  BearPlank({
    this.maxSeconds = BearConfig.TARGET_HOVER_MS ~/ 1000,
  });

  final int maxSeconds;

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  BearState bearState = BearState.setup;
  BearState previousBearState = BearState.setup;

  int? _exerciseStartTimeMs;
  int _totalHoverTimeMs = 0; // Tổng thời gian giữ form chuẩn
  int? _lastFrameTimeMs;
  bool _isTimeout = false;
  bool _setCompletionLogged = false;

  final HoldSecondsAccumulator _holdSeconds = HoldSecondsAccumulator(const [
    'knee_seconds',
    'back_seconds',
    'weight_seconds',
  ]);

  // Telemetry Log
  final List<Map<String, dynamic>> _telemetryLog = [];

  // Metrics
  final KneeHoverMetric kneeMetric = KneeHoverMetric();
  final FlatBackMetric backMetric = FlatBackMetric();
  final WeightDistributionMetric weightMetric = WeightDistributionMetric();
  late final List<BearMetricBase> _metrics = [
    kneeMetric,
    backMetric,
    weightMetric
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

  // Debouncers
  final Debouncer _hoverDebouncer = Debouncer(requiredFrames: 3);
  final Debouncer _fatigueDebouncer = Debouncer(requiredFrames: 5);

  @override
  String get exerciseName => 'Bear Plank';

  @override
  String get currentPhaseKey => bearState.name;

  @override
  String get currentPhaseLabel {
    switch (bearState) {
      case BearState.setup:
        return 'Setup (Vào vị trí)';
      case BearState.hovering:
        return 'Giữ tĩnh (Hold!)';
      case BearState.fatiguing:
        return 'Mất form/Hạ gối';
    }
  }

  @override
  double? get liveHoldSeconds =>
      bearState == BearState.hovering || bearState == BearState.fatiguing
          ? _totalHoverTimeMs / 1000.0
          : null;

  @override
  double? get liveHoldTargetSeconds => maxSeconds.toDouble();

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return "Yêu cầu quay ngang để đo độ phẳng của lưng và độ cao đầu gối.";
    }
    if (_getLandmarks(landmarks) == null) {
      return 'Giữ vai, hông, gối, cổ tay và cổ chân rõ trong khung hình.';
    }
    return null;
  }

  // Điều kiện Setup chuẩn: Tay thẳng, đùi vuông góc, gối chạm hoặc sát đất
  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = _getLandmarks(landmarks);
    if (lm == null) return false;

    final kneeAngle = calculateAngleNormalized(
        firstPoint: lm['hip']!, midPoint: lm['knee']!, lastPoint: lm['ankle']!);
    // Đầu gối vuông góc 60-120 độ. Nếu lưng thẳng nữa thì mới cho bắt đầu.
    return kneeAngle >= BearConfig.KNEE_ANGLE_SETUP_MIN &&
        kneeAngle <= BearConfig.KNEE_ANGLE_SETUP_MAX;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    final now = frameTimestampMs;
    _exerciseStartTimeMs ??= now;
    final int dt = _lastFrameTimeMs != null ? (now - _lastFrameTimeMs!) : 0;
    _lastFrameTimeMs = now;

    if (now - _exerciseStartTimeMs! > BearConfig.MAX_SESSION_MS ||
        _totalHoverTimeMs >= _targetHoverMs) {
      _isTimeout = (now - _exerciseStartTimeMs! > BearConfig.MAX_SESSION_MS);
      return;
    }

    final lm = _getLandmarks(smoothedLandmarks);
    if (lm == null) {
      _lastFrameTimeMs = null;
      _holdSeconds.resetTick();
      return;
    }

    final shoulder = lm['shoulder']!;
    final hip = lm['hip']!;
    final knee = lm['knee']!;
    final wrist = lm['wrist']!;

    final ankle = lm['ankle']!;

    scaleFactor = calculateDistance(shoulder, hip);
    if (!scaleFactor.isFinite || scaleFactor <= 1e-6) {
      _lastFrameTimeMs = null;
      _holdSeconds.resetTick();
      return;
    }

    // Tính toán hình học
    // Sàn là đường thẳng nối cổ tay (wrist) và cổ chân (ankle)
    double floorY;
    if ((ankle.x - wrist.x).abs() > 0.001) {
      double t = (knee.x - wrist.x) / (ankle.x - wrist.x);
      floorY = wrist.y + t * (ankle.y - wrist.y);
    } else {
      floorY = wrist.y > ankle.y ? wrist.y : ankle.y;
    }

    final kneeHeightOffset = floorY - knee.y; // Dương khi gối nhấc lên khỏi sàn
    final kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);

    // Signed: dương = shoulder thấp hơn hip (Y hướng xuống) → võng lưng
    final backYOffset = (shoulder.y - hip.y) / scaleFactor;

    // Abs distance: vai chúi trước cổ tay
    final shoulderWristXOffset = (shoulder.x - wrist.x).abs() / scaleFactor;

    // Chuẩn hóa knee height
    final normKneeHeight = kneeHeightOffset / scaleFactor;

    if (isDebugModeActive) {
      // GHI LOG TELEMETRY
      _telemetryLog.add({
        'timestamp': now,
        'state': bearState.name,
        'normKneeHeight': double.parse(normKneeHeight.toStringAsFixed(3)),
        'kneeAngle': double.parse(kneeAngle.toStringAsFixed(1)),
        'backYOffset': double.parse(backYOffset.toStringAsFixed(3)),
        'shoulderWristXOffset':
            double.parse(shoulderWristXOffset.toStringAsFixed(3)),
      });
    }

    final ctx = BearRepContext(
      kneeHeightOffset: normKneeHeight,
      kneeAngle: kneeAngle,
      backYOffset: backYOffset,
      shoulderWristXOffset: shoulderWristXOffset,
      scaleFactor: scaleFactor,
      currentState: bearState,
      frameTimestampMs: now,
      resultIssues: resultIssues,
    );

    // Cập nhật State Machine
    _updateStateMachine(ctx, now, dt);

    repCount = _totalHoverTimeMs ~/ 1000;

    // Cập nhật Metrics (chỉ khi đang hovering)
    for (var metric in _metrics) {
      metric.update(ctx);
      debugData.addAll(metric.debugData);
    }

    if (bearState == BearState.hovering) {
      _holdSeconds.accumulate(
        elapsedMs: elapsedMs,
        faultingByKey: {
          'knee_seconds': kneeMetric.isFaultingNow,
          'back_seconds': backMetric.isFaultingNow,
          'weight_seconds': weightMetric.isFaultingNow,
        },
      );
    } else {
      _holdSeconds.resetTick();
    }

    // UI Data
    debugData['State'] = bearState.name;
    debugData['Hover_Time'] =
        '${(_totalHoverTimeMs / 1000).toStringAsFixed(1)}s / ${maxSeconds}s';
  }

  void _updateStateMachine(BearRepContext ctx, int now, int dt) {
    bool isHoveringForm = ctx.kneeHeightOffset > BearConfig.KNEE_HOVER_MIN &&
        ctx.kneeHeightOffset <= BearConfig.KNEE_HOVER_MAX &&
        ctx.kneeAngle < BearConfig.KNEE_ANGLE_BUTT_UP;

    final hasCleanBack = ctx.backYOffset <= BearConfig.BACK_SAG_THRESHOLD &&
        ctx.backYOffset >= -BearConfig.BACK_ARCH_THRESHOLD;
    final hasCleanWeight =
        ctx.shoulderWristXOffset <= BearConfig.WEIGHT_SHIFT_THRESHOLD;
    final isFullyCleanHold = isHoveringForm && hasCleanBack && hasCleanWeight;
    bool isFatiguedForm = !isFullyCleanHold;

    switch (bearState) {
      case BearState.setup:
        if (_hoverDebouncer.update(isHoveringForm)) {
          _transitionState(BearState.hovering, now);
        }
        break;
      case BearState.hovering:
        // Chỉ cộng thời gian khi form thực sự chuẩn (chưa bị fatigue)
        if (isFullyCleanHold) {
          _totalHoverTimeMs += dt;
        }

        if (_fatigueDebouncer.update(isFatiguedForm)) {
          // Reset metrics khi kết thúc hold cycle
          for (var metric in _metrics) {
            metric.resetAndCountFault();
          }
          _transitionState(BearState.fatiguing, now);
        }
        break;
      case BearState.fatiguing:
        if (_hoverDebouncer.update(isHoveringForm)) {
          _transitionState(BearState.hovering, now);
        }
        break;
    }
  }

  void _transitionState(BearState newState, int now) {
    previousBearState = bearState;
    bearState = newState;
    _hoverDebouncer.reset();
    _fatigueDebouncer.reset();
    for (var metric in _metrics) {
      metric.onStateTransition(previousBearState, newState, now);
    }
  }

  @override
  bool requestStop() => _totalHoverTimeMs >= _targetHoverMs || _isTimeout;

  @override
  Map<String, String> processNoPoseFrame() {
    _lastFrameTimeMs = null;
    _holdSeconds.resetTick();
    return super.processNoPoseFrame();
  }

  @override
  void onExerciseActivated() {
    super.onExerciseActivated();
    _resetSetState();
  }

  @override
  void onSetComplete() {
    final allFaults = <FaultRecord>[
      ...kneeMetric.faults,
      ...backMetric.faults,
      ...weightMetric.faults,
    ];
    final holdCorrect = _totalHoverTimeMs >= _targetHoverMs &&
        !allFaults.any((f) => f.affectsForm);

    // Đẩy dữ liệu tổng kết
    final targetSeconds = maxSeconds.toDouble();
    final goodSeconds = _holdSeconds.goodSeconds.clamp(0.0, targetSeconds);
    // Target denominator for scoring, not elapsed hold time.
    logger.pushKey("total_seconds", targetSeconds);
    logger.pushKey("good_seconds", goodSeconds);
    logger.pushKey("max_rep", 1);
    logger.pushKey("total_hover_time_ms", _totalHoverTimeMs);
    logger.pushKey("timeout_triggered", _isTimeout);
    logger.pushKey(
        "knee_seconds", _holdSeconds.faultSecondsFor('knee_seconds'));
    logger.pushKey(
        "back_seconds", _holdSeconds.faultSecondsFor('back_seconds'));
    logger.pushKey(
        "weight_seconds", _holdSeconds.faultSecondsFor('weight_seconds'));

    if (isDebugModeActive) {
      logger.pushKey("telemetry_data", _telemetryLog); // Chìa khóa debug
    }

    // Set kết quả (Form tốt nếu giữ trên 80% thời gian mục tiêu)
    if (!_setCompletionLogged) {
      logger.addRepLog(RepLog(
        correctForm: holdCorrect,
        repNumber: 1,
        data: {
          "perfect_hold_time": _totalHoverTimeMs / 1000.0,
          "fault_types": allFaults.map((f) => f.type).toSet().toList(),
        },
      ));
      _setCompletionLogged = true;
    }

    correctForm = holdCorrect;
    logger.pushGoodRepCount();
  }

  int get _targetHoverMs => maxSeconds * 1000;

  void _resetSetState() {
    bearState = BearState.setup;
    previousBearState = BearState.setup;
    _exerciseStartTimeMs = null;
    _totalHoverTimeMs = 0;
    _lastFrameTimeMs = null;
    _isTimeout = false;
    _setCompletionLogged = false;
    _holdSeconds.reset();
    _telemetryLog.clear();
    repCount = 0;
    correctForm = true;
    logger.clear();
    _hoverDebouncer.reset();
    _fatigueDebouncer.reset();
    for (final metric in _metrics) {
      metric.reset();
    }
  }

  Map<String, PoseLandmark>? _getLandmarks(
      Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final lHip = landmarks[PoseLandmarkType.leftHip];
    final lKnee = landmarks[PoseLandmarkType.leftKnee];
    final lAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final lWrist = landmarks[PoseLandmarkType.leftWrist];

    final rShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final rHip = landmarks[PoseLandmarkType.rightHip];
    final rKnee = landmarks[PoseLandmarkType.rightKnee];
    final rAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final rWrist = landmarks[PoseLandmarkType.rightWrist];

    // Chọn bên có likelihood hông cao hơn, fallback nếu 1 bên null
    if (lShoulder != null &&
        lHip != null &&
        lKnee != null &&
        lAnkle != null &&
        lWrist != null &&
        [lShoulder, lHip, lKnee, lAnkle, lWrist]
            .every(ExerciseBase.isLandmarkConfident)) {
      if (rHip == null || lHip.likelihood >= rHip.likelihood) {
        return {
          'shoulder': lShoulder,
          'hip': lHip,
          'knee': lKnee,
          'ankle': lAnkle,
          'wrist': lWrist
        };
      }
    }
    if (rShoulder != null &&
        rHip != null &&
        rKnee != null &&
        rAnkle != null &&
        rWrist != null &&
        [rShoulder, rHip, rKnee, rAnkle, rWrist]
            .every(ExerciseBase.isLandmarkConfident)) {
      return {
        'shoulder': rShoulder,
        'hip': rHip,
        'knee': rKnee,
        'ankle': rAnkle,
        'wrist': rWrist
      };
    }
    // Fallback to left if right failed but left was available
    if (lShoulder != null &&
        lHip != null &&
        lKnee != null &&
        lAnkle != null &&
        lWrist != null &&
        [lShoulder, lHip, lKnee, lAnkle, lWrist]
            .every(ExerciseBase.isLandmarkConfident)) {
      return {
        'shoulder': lShoulder,
        'hip': lHip,
        'knee': lKnee,
        'ankle': lAnkle,
        'wrist': lWrist
      };
    }
    return null;
  }
}
