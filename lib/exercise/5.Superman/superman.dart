// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/debouncer.dart';
import '../../utils/exercise_logger.dart';
import '../exercise_base.dart';
import 'metrics/superman_metric_base.dart';
import 'metrics/limb_elevation_metric.dart';
import 'metrics/hip_grounding_metric.dart';
import 'metrics/hold_time_metric.dart';
import 'metrics/lumbar_extension_metric.dart';

class Superman extends ExerciseBase {
  Superman({required this.maxRep});

  final int maxRep;

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'Superman';

  SupermanState superState = SupermanState.setup;
  SupermanState previousState = SupermanState.setup;
  int? _startTimeMs;
  bool _isTimeout = false;
  int _rejectedAttempts = 0;
  double?
      _baselineHipY; // Biến lưu vị trí hông ban đầu để so sánh khi nâng người

  final LimbElevationMetric elevationMetric = LimbElevationMetric();
  final HipGroundingMetric hipMetric = HipGroundingMetric();
  final HoldTimeMetric holdMetric = HoldTimeMetric();
  final LumbarExtensionMetric lumbarMetric = LumbarExtensionMetric();

  late final List<SupermanMetricBase> _metrics = [
    elevationMetric,
    hipMetric,
    holdMetric,
    lumbarMetric
  ];

  final Debouncer _liftDebouncer = Debouncer(requiredFrames: 3);
  final Debouncer _topDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _lowerDebouncer = Debouncer(requiredFrames: 3);
  final Debouncer _loweredDebouncer = Debouncer(requiredFrames: 2);

  @override
  String get currentPhaseKey => superState.name;

  @override
  String get currentPhaseLabel {
    switch (superState) {
      case SupermanState.setup:
        return 'Nằm sấp';
      case SupermanState.lifting:
        return 'Nâng lên';
      case SupermanState.hold:
        return 'Giữ';
      case SupermanState.lowering:
        return 'Hạ xuống';
    }
  }

  @override
  double? get liveHoldSeconds => superState == SupermanState.hold
      ? holdMetric.currentHoldSeconds(frameTimestampMs)
      : null;

  @override
  double? get liveHoldTargetSeconds => SupermanConfig.HOLD_MIN_MS / 1000.0;

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return const GuidanceSignal.turnSide();
    }
    if (_getLandmarks(landmarks) == null) {
      return const GuidanceSignal.bodyInFrame();
    }
    return null;
  }

  // Ràng buộc BẮT BUỘC nằm sấp (Prone)
  bool _isProne(
      Map<PoseLandmarkType, PoseLandmark> landmarks, double scaleFactor) {
    final nose = landmarks[PoseLandmarkType.nose];
    final leftEar = landmarks[PoseLandmarkType.leftEar];
    final rightEar = landmarks[PoseLandmarkType.rightEar];

    PoseLandmark? ear;
    if (leftEar != null && rightEar != null) {
      ear = leftEar.likelihood > rightEar.likelihood ? leftEar : rightEar;
    } else {
      ear = leftEar ?? rightEar;
    }

    if (nose != null && ear != null && scaleFactor > 0) {
      // Trục Y hướng xuống.
      // Nằm sấp: Mũi úp xuống đất (Y lớn) hoặc ngang tai (nếu ngẩng đầu nhìn tới).
      // Nằm ngửa: Mũi chỉ lên trần (Y nhỏ), tai gần đất (Y lớn).
      double faceVerticalDiff = (nose.y - ear.y) / scaleFactor;
      // Nằm ngửa thì mũi cao hơn tai rất nhiều (faceVerticalDiff âm lớn)
      if (faceVerticalDiff < -0.2) return false;
    }

    // Kiểm tra bằng hướng của bàn chân (nếu nhìn thấy)
    final leftHeel = landmarks[PoseLandmarkType.leftHeel];
    final leftFootIndex = landmarks[PoseLandmarkType.leftFootIndex];
    final rightHeel = landmarks[PoseLandmarkType.rightHeel];
    final rightFootIndex = landmarks[PoseLandmarkType.rightFootIndex];

    PoseLandmark? heel;
    PoseLandmark? footIndex;

    if (leftHeel != null &&
        leftFootIndex != null &&
        rightHeel != null &&
        rightFootIndex != null) {
      if (leftHeel.likelihood + leftFootIndex.likelihood >
          rightHeel.likelihood + rightFootIndex.likelihood) {
        heel = leftHeel;
        footIndex = leftFootIndex;
      } else {
        heel = rightHeel;
        footIndex = rightFootIndex;
      }
    } else {
      heel = leftHeel ?? rightHeel;
      footIndex = leftFootIndex ?? rightFootIndex;
    }

    if (heel != null &&
        footIndex != null &&
        scaleFactor > 0 &&
        heel.likelihood > 0.3 &&
        footIndex.likelihood > 0.3) {
      // Nằm ngửa (supine): ngón chân (footIndex) hướng lên trần nhà (Y nhỏ hơn gót chân)
      // Nằm sấp (prone): ngón chân úp xuống sàn (Y lớn hơn hoặc bằng gót chân)
      double footVerticalDiff = (heel.y - footIndex.y) / scaleFactor;
      // Nếu ngón chân cao hơn gót chân một khoảng rõ rệt (footVerticalDiff dương), chắc chắn đang nằm ngửa
      if (footVerticalDiff > 0.15) return false;
    }

    return true;
  }

  // Chống gian lận: Nằm nghiêng
  bool _isNotOnSide(
      Map<PoseLandmarkType, PoseLandmark> landmarks, double scaleFactor) {
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];

    if (leftShoulder != null && rightShoulder != null && scaleFactor > 0) {
      double shoulderDiffY =
          (leftShoulder.y - rightShoulder.y).abs() / scaleFactor;
      // Nằm nghiêng thì 1 vai ở trên trần, 1 vai dưới đất -> chênh lệch Y rất lớn
      // Nằm sấp/ngửa thì 2 vai gần bằng nhau về trục Y.
      if (shoulderDiffY > 0.35) return false;
    }
    return true;
  }

  // Lấy độ cao THẤP NHẤT giữa bên trái và bên phải (Bắt buộc nhấc cả 2 bên)
  double _getStrictLimbElevation(
      PoseLandmark? leftJoint,
      PoseLandmark? rightJoint,
      PoseLandmark? leftBase,
      PoseLandmark? rightBase,
      double scaleFactor) {
    if (leftJoint == null ||
        rightJoint == null ||
        leftBase == null ||
        rightBase == null ||
        !ExerciseBase.isLandmarkConfident(leftJoint) ||
        !ExerciseBase.isLandmarkConfident(rightJoint) ||
        !ExerciseBase.isLandmarkConfident(leftBase) ||
        !ExerciseBase.isLandmarkConfident(rightBase)) {
      return 0.0;
    }

    final elevations = <double>[
      (leftBase.y - leftJoint.y) / scaleFactor,
      (rightBase.y - rightJoint.y) / scaleFactor,
    ];

    // Trả về mức nâng thấp nhất để ép người dùng phải nhấc cả hai bên
    return elevations.reduce((a, b) => a < b ? a : b);
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = _getLandmarks(landmarks);
    if (lm == null) return false;

    final torso = calculateDistance(lm['shoulder']!, lm['hip']!);
    if (torso == 0) return false;

    // Chặn trường hợp nằm ngửa gập bụng hoặc nằm nghiêng
    if (!_isProne(landmarks, torso) || !_isNotOnSide(landmarks, torso))
      return false;

    final shoulderHipDiff = (lm['shoulder']!.y - lm['hip']!.y).abs();

    bool isHorizontal = torso > 0 && shoulderHipDiff / torso < 0.25;

    // Lưu lại vị trí hông lúc thả lỏng làm mốc
    if (isHorizontal) {
      _baselineHipY = lm['hip']!.y;
    }

    return isHorizontal;
  }

  @override
  bool requestStop() {
    if (_startTimeMs != null &&
        (frameTimestampMs - _startTimeMs!) > SupermanConfig.MAX_DURATION_MS) {
      _isTimeout = true;
      return true;
    }
    return repCount >= maxRep;
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    _startTimeMs ??= frameTimestampMs;
    final now = frameTimestampMs;

    final lm = _getLandmarks(landmarks);
    if (lm == null) return;

    scaleFactor = calculateDistance(lm['shoulder']!, lm['hip']!);
    if (!scaleFactor.isFinite || scaleFactor <= 1e-6) return;

    // CHỐNG GIAN LẬN: Xử lý ngay trong lúc tập nếu người dùng lật ngửa hoặc nằm nghiêng
    if (!_isProne(landmarks, scaleFactor) ||
        !_isNotOnSide(landmarks, scaleFactor)) {
      if (superState != SupermanState.setup) {
        _transition(SupermanState.setup, now);
        for (final m in _metrics) m.reset(); // Reset số liệu của rep lỗi này
      }
      return;
    }

    // Tính toán khắt khe: Bắt buộc nhấc cả 2 tay và 2 chân
    final armElevation = _getStrictLimbElevation(
        landmarks[PoseLandmarkType.leftWrist],
        landmarks[PoseLandmarkType.rightWrist],
        landmarks[PoseLandmarkType.leftShoulder],
        landmarks[PoseLandmarkType.rightShoulder],
        scaleFactor);

    final legElevation = _getStrictLimbElevation(
        landmarks[PoseLandmarkType.leftAnkle],
        landmarks[PoseLandmarkType.rightAnkle],
        landmarks[PoseLandmarkType.leftHip],
        landmarks[PoseLandmarkType.rightHip],
        scaleFactor);

    // Tính toán độ nâng hông (Chống hít đất/plank)
    double hipElevation = 0.0;
    if (_baselineHipY != null) {
      hipElevation = (_baselineHipY! - lm['hip']!.y) / scaleFactor;
      if (hipElevation < 0) hipElevation = 0.0;
    }

    final spineAngle = calculateAbsoluteHorizontalAngle(
        point1: lm['shoulder']!, point2: lm['hip']!);

    debugData['arm_elev'] = armElevation.toStringAsFixed(3);
    debugData['leg_elev'] = legElevation.toStringAsFixed(3);
    debugData['hip_elev'] = hipElevation.toStringAsFixed(3);
    debugData['state'] = superState.name;

    final ctx = SupermanRepContext(
      armElevation: armElevation,
      legElevation: legElevation,
      hipElevation: hipElevation,
      spineAngle: spineAngle,
      scaleFactor: scaleFactor,
      currentState: superState,
      frameTimestampMs: now,
      resultIssues: resultIssues,
    );

    _updateStateMachine(ctx);

    for (final m in _metrics) {
      m.update(ctx);
      debugData.addAll(m.debugData);
    }

    if (superState == SupermanState.setup) {
      resultIssues.setPhaseStatus('setup', 'Nằm sấp, duỗi tay chân');
    } else if (superState == SupermanState.lifting) {
      resultIssues.setPhaseStatus('lifting', 'Nâng tay chân lên');
    } else if (superState == SupermanState.hold) {
      final holdSeconds = holdMetric.currentHoldSeconds(now);
      resultIssues.setPhaseStatus(
          'hold', 'Giữ ${holdSeconds.toStringAsFixed(1)}s');
    } else if (superState == SupermanState.lowering) {
      resultIssues.setPhaseStatus('lowering', 'Hạ chậm xuống');
    }
  }

  void _updateStateMachine(SupermanRepContext ctx) {
    bool isLifted = ctx.armElevation > SupermanConfig.LIFT_THRESHOLD &&
        ctx.legElevation > SupermanConfig.LIFT_THRESHOLD;
    bool hasFullRom = ctx.armElevation > SupermanConfig.ROM_THRESHOLD &&
        ctx.legElevation > SupermanConfig.ROM_THRESHOLD;
    bool isLowered = ctx.armElevation <= SupermanConfig.LOWERED_THRESHOLD &&
        ctx.legElevation <= SupermanConfig.LOWERED_THRESHOLD;

    switch (superState) {
      case SupermanState.setup:
        if (_liftDebouncer.update(isLifted))
          _transition(SupermanState.lifting, ctx.frameTimestampMs);
        break;
      case SupermanState.lifting:
        if (_topDebouncer.update(hasFullRom)) {
          _transition(SupermanState.hold, ctx.frameTimestampMs);
        } else if (isLowered) {
          _transition(SupermanState.setup, ctx.frameTimestampMs);
          for (final m in _metrics) m.reset();
        }
        break;
      case SupermanState.hold:
        if (_lowerDebouncer.update(!isLifted))
          _transition(SupermanState.lowering, ctx.frameTimestampMs);
        break;
      case SupermanState.lowering:
        if (_loweredDebouncer.update(isLowered)) _completeRep(ctx);
        break;
    }
  }

  void _transition(SupermanState to, int ts) {
    if (to == superState) return;
    final from = superState;
    superState = to;
    _resetPhaseDebouncers();
    for (final m in _metrics) m.onStateTransition(from, to, ts);
  }

  void _resetPhaseDebouncers() {
    _liftDebouncer.reset();
    _topDebouncer.reset();
    _lowerDebouncer.reset();
    _loweredDebouncer.reset();
  }

  void _completeRep(SupermanRepContext ctx) {
    for (final m in _metrics) m.evaluateRepEnd(ctx);

    final faults = <FaultRecord>[];
    for (final m in _metrics) faults.addAll(m.faults);
    correctForm = !faults.any((f) => f.affectsForm);

    final faultMap = <String, Map<String, String>>{};
    for (final fault in faults) {
      faultMap.putIfAbsent(fault.phase, () => {});
      faultMap[fault.phase]![fault.type] = fault.message;
    }
    setFeedback.add({correctForm: faultMap});

    repCount++;
    if (!correctForm) resultIssues.feedback['Result'] = 'Fix Form';

    logger.addRepLog(RepLog(
      correctForm: correctForm,
      repNumber: repCount,
      data: {
        'hold_time': holdMetric.lastHoldDurationMs / 1000.0,
        'fault_types': faults.map((e) => e.type).toSet().toList(),
      },
    ));

    _transition(SupermanState.setup, ctx.frameTimestampMs);
    for (final m in _metrics) m.resetAndCountFault();
    correctForm = true;
  }

  @override
  void onSetComplete() {
    logger.pushKey("max_rep", maxRep);
    logger.pushKey("timeout", _isTimeout);
    logger.pushKey("elevation_fails_count", elevationMetric.faultsCount);
    logger.pushKey("hip_fails_count", hipMetric.faultsCount);
    logger.pushKey("hold_fails_count", holdMetric.faultsCount);
    logger.pushKey("lumbar_fails_count", lumbarMetric.faultsCount);
    logger.pushKey("rejected_attempts_count", _rejectedAttempts);
    logger.pushGoodRepCount();
    _rejectedAttempts = 0;
  }

  Map<String, PoseLandmark>? _getLandmarks(
      Map<PoseLandmarkType, PoseLandmark> lm) {
    final useRight = cameraFacing == CameraFacing.right;
    final shoulder = lm[useRight
        ? PoseLandmarkType.rightShoulder
        : PoseLandmarkType.leftShoulder];
    final hip =
        lm[useRight ? PoseLandmarkType.rightHip : PoseLandmarkType.leftHip];
    final wrist =
        lm[useRight ? PoseLandmarkType.rightWrist : PoseLandmarkType.leftWrist];
    final ankle =
        lm[useRight ? PoseLandmarkType.rightAnkle : PoseLandmarkType.leftAnkle];

    if (shoulder == null || hip == null || wrist == null || ankle == null)
      return null;
    if (![shoulder, hip, wrist, ankle].every(ExerciseBase.isLandmarkConfident))
      return null;
    return {'shoulder': shoulder, 'hip': hip, 'wrist': wrist, 'ankle': ankle};
  }
}
