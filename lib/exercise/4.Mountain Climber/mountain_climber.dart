// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../exercise_base.dart';
import 'metrics/mountain_climber_metric_base.dart';
import 'metrics/trunk_stability_metric.dart';
import 'metrics/knee_drive_rom_metric.dart';

class MountainClimber extends ExerciseBase {
  // ---------------------------------------------------------------------------
  // Config
  // ---------------------------------------------------------------------------

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'Mountain Climber';

  // ---------------------------------------------------------------------------
  // State — chỉ dùng để hiển thị UI label, KHÔNG dùng để đếm rep
  // ---------------------------------------------------------------------------

  ClimberState _displayState = ClimberState.high_plank_base;

  @override
  String get currentPhaseKey => _displayState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (_displayState) {
      case ClimberState.high_plank_base:    return 'Chuẩn bị';
      case ClimberState.knee_driving_in:    return 'Kéo gối lên';
      case ClimberState.max_flexion:        return 'Chạm đỉnh';
      case ClimberState.knee_driving_out:   return 'Duỗi chân về';
    }
  }

  // ---------------------------------------------------------------------------
  // Core tracking objects
  // ---------------------------------------------------------------------------

  /// Counter độc lập cho từng chân
  final KneePeakRepCounter _leftCounter =
      KneePeakRepCounter(side: KneeSide.left);
  final KneePeakRepCounter _rightCounter =
      KneePeakRepCounter(side: KneeSide.right);

  final TrunkStabilityMetric trunkMetric = TrunkStabilityMetric();
  final KneeDriveRomMetric romMetric = KneeDriveRomMetric();

  // ---------------------------------------------------------------------------
  // Session state
  // ---------------------------------------------------------------------------

  int? _exerciseStartTimeMs;
  bool _isTimeout = false;

  /// Khoảng cách nghỉ chuẩn hóa của 2 chân, đo ở Setup
  double? _restDistLeft;
  double? _restDistRight;

  // ---------------------------------------------------------------------------
  // Safety check
  // ---------------------------------------------------------------------------

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    // Safety gate hiển thị popup hỏi chấn thương được xử lý ở tầng UI/UX.
    // Tầng AI không block — chỉ trả về null ở đây.
    return null;
  }

  // ---------------------------------------------------------------------------
  // isInStartPosition
  // ---------------------------------------------------------------------------

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = _extractLandmarks(landmarks);
    if (lm == null) return false;

    // Tính góc trên bên có thể nhìn rõ hơn (ưu tiên trái nếu cả 2 đều ok)
    final double armAngle = calculateAngleNormalized(
      firstPoint: lm.shoulder,
      midPoint: lm.elbow,
      lastPoint: lm.wrist,
    );
    final double trunkAngle = calculateAngleNormalized(
      firstPoint: lm.shoulder,
      midPoint: lm.hip,
      lastPoint: lm.ankle,
    );

    debugData['Setup'] = {
      'armAngle': armAngle.toStringAsFixed(1),
      'trunkAngle': trunkAngle.toStringAsFixed(1),
      'armOk': armAngle > ClimberConfig.ARM_STRAIGHT_THRESHOLD,
      'trunkOk': trunkAngle >= ClimberConfig.TRUNK_STRAIGHT_RANGE[0] &&
          trunkAngle <= ClimberConfig.TRUNK_STRAIGHT_RANGE[1],
    };

    if (armAngle <= ClimberConfig.ARM_STRAIGHT_THRESHOLD) return false;
    if (trunkAngle < ClimberConfig.TRUNK_STRAIGHT_RANGE[0] ||
        trunkAngle > ClimberConfig.TRUNK_STRAIGHT_RANGE[1]) return false;

    // --- Calibrate ngưỡng zone theo tư thế thực tế của người dùng ---
    final double scale =
        calculateDistance(lm.shoulder, lm.hip);
    if (scale > 0) {
      final double distL =
          (lm.leftKnee.x - lm.shoulder.x).abs() / scale;
      final double distR =
          (lm.rightKnee.x - lm.shoulder.x).abs() / scale;

      // Lấy trung bình 3 frame để ổn định (đơn giản: gán thẳng khi form đạt)
      _restDistLeft  = distL;
      _restDistRight = distR;
      _leftCounter.calibrate(distL);
      _rightCounter.calibrate(distR);

      debugData['Setup']['calibratedThresholdL'] =
          _leftCounter.zoneThreshold.toStringAsFixed(2);
      debugData['Setup']['calibratedThresholdR'] =
          _rightCounter.zoneThreshold.toStringAsFixed(2);
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // Stop condition
  // ---------------------------------------------------------------------------

  @override
  bool requestStop() {
    if (_exerciseStartTimeMs != null &&
        (frameTimestampMs - _exerciseStartTimeMs!) >
            ClimberConfig.MAX_DURATION_MS) {
      _isTimeout = true;
      return true;
    }
    return repCount >= ClimberConfig.MAX_REP;
  }

  // ---------------------------------------------------------------------------
  // Main loop
  // ---------------------------------------------------------------------------

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    _exerciseStartTimeMs ??= frameTimestampMs;
    final int now = frameTimestampMs;

    final lm = _extractLandmarks(landmarks);
    if (lm == null) return;

    scaleFactor = calculateDistance(lm.shoulder, lm.hip);

    final double armAngle = calculateAngleNormalized(
      firstPoint: lm.shoulder,
      midPoint: lm.elbow,
      lastPoint: lm.wrist,
    );
    final double trunkAngle = calculateAngleNormalized(
      firstPoint: lm.shoulder,
      midPoint: lm.hip,
      lastPoint: lm.ankle,
    );

    // --- Build context ---
    final ctx = RepContext(
      state: _displayState,
      frameTimestamp: now,
      scaleFactor: scaleFactor,
      armAngle: armAngle,
      trunkAngle: trunkAngle,
      hipY: lm.hip.y,
      shoulderX: lm.shoulder.x,
      hipX: lm.hip.x,
      leftKneeX: lm.leftKnee.x,
      rightKneeX: lm.rightKnee.x,
      resultIssues: resultIssues,
    );

    // --- Trunk metric (chạy mỗi frame, độc lập) ---
    trunkMetric.update(ctx);
    debugData.addAll(trunkMetric.debugData);

    // --- ROM metric (cập nhật min dist mỗi frame) ---
    romMetric.update(ctx);
    debugData.addAll(romMetric.debugData);

    // --- Peak counter trái ---
    final int leftRep = _leftCounter.update(
      kneeX: lm.leftKnee.x,
      shoulderX: lm.shoulder.x,
      scaleFactor: scaleFactor,
      nowMs: now,
    );
    if (leftRep > 0) _onRepCompleted(ctx, KneeSide.left);

    // --- Peak counter phải ---
    final int rightRep = _rightCounter.update(
      kneeX: lm.rightKnee.x,
      shoulderX: lm.shoulder.x,
      scaleFactor: scaleFactor,
      nowMs: now,
    );
    if (rightRep > 0) _onRepCompleted(ctx, KneeSide.right);

    // --- Cập nhật display state dựa trên zone của 2 counter ---
    _updateDisplayState();

    // --- Diagnostic table ---
    debugData['Diag'] = {
      'state': _displayState.name,
      'repCount': repCount,
      'elapsed_s':
          ((now - _exerciseStartTimeMs!) / 1000).toStringAsFixed(1),
      'armAngle': armAngle.toStringAsFixed(1),
      'trunkAngle': trunkAngle.toStringAsFixed(1),
      'L_dist': _leftCounter.smoothedDist.toStringAsFixed(2),
      'R_dist': _rightCounter.smoothedDist.toStringAsFixed(2),
      'L_inZone': _leftCounter.isInZone,
      'R_inZone': _rightCounter.isInZone,
      'L_threshold': _leftCounter.zoneThreshold.toStringAsFixed(2),
      'R_threshold': _rightCounter.zoneThreshold.toStringAsFixed(2),
      'scaleFactor': scaleFactor.toStringAsFixed(1),
    };
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _onRepCompleted(RepContext ctx, KneeSide side) {
    repCount++;

    // Lấy peakDist từ counter tương ứng
    final double peakDist = side == KneeSide.left
        ? _leftCounter.minDistInZone
        : _rightCounter.minDistInZone;

    final double threshold = side == KneeSide.left
        ? _leftCounter.zoneThreshold
        : _rightCounter.zoneThreshold;

    romMetric.evaluateRepEnd(ctx, side, peakDist, threshold);

    // Đánh dấu form của rep này dựa trên lỗi trunk hiện tại
    correctForm = trunkMetric.faults.isEmpty;

    // Sau mỗi rep, reset fault list của trunk (đếm fault theo rep)
    trunkMetric.resetAndCountFault();
  }

  void _updateDisplayState() {
    final bool anyInZone =
        _leftCounter.isInZone || _rightCounter.isInZone;

    if (anyInZone) {
      // Đơn giản: nếu đang trong zone thì hiển thị knee_driving_in hoặc max_flexion
      // Dùng dist để phân biệt: đang tiến vào hay đã qua đỉnh
      final double dist = _leftCounter.isInZone
          ? _leftCounter.smoothedDist
          : _rightCounter.smoothedDist;
      final double threshold = _leftCounter.isInZone
          ? _leftCounter.zoneThreshold
          : _rightCounter.zoneThreshold;
      _displayState = dist < threshold * 0.7
          ? ClimberState.max_flexion
          : ClimberState.knee_driving_in;
    } else {
      _displayState = ClimberState.high_plank_base;
    }
  }

  // ---------------------------------------------------------------------------
  // Landmark extraction
  // ---------------------------------------------------------------------------

  _LandmarkSet? _extractLandmarks(
      Map<PoseLandmarkType, PoseLandmark> lm) {
    // Xác định side nhìn rõ hơn dựa trên likelihood (nếu API cung cấp),
    // fallback: dùng bên trái làm reference cho shoulder/elbow/wrist/hip/ankle.
    // Cả 2 đầu gối luôn được lấy để track độc lập.
    final PoseLandmark? shoulder = lm[PoseLandmarkType.leftShoulder];
    final PoseLandmark? elbow    = lm[PoseLandmarkType.leftElbow];
    final PoseLandmark? wrist    = lm[PoseLandmarkType.leftWrist];
    final PoseLandmark? hip      = lm[PoseLandmarkType.leftHip];
    final PoseLandmark? ankle    = lm[PoseLandmarkType.leftAnkle];
    final PoseLandmark? leftKnee  = lm[PoseLandmarkType.leftKnee];
    final PoseLandmark? rightKnee = lm[PoseLandmarkType.rightKnee];

    if (shoulder == null || elbow == null || wrist == null ||
        hip == null || ankle == null ||
        leftKnee == null || rightKnee == null) {
      return null;
    }

    return _LandmarkSet(
      shoulder: shoulder,
      elbow: elbow,
      wrist: wrist,
      hip: hip,
      ankle: ankle,
      leftKnee: leftKnee,
      rightKnee: rightKnee,
    );
  }

  // ---------------------------------------------------------------------------
  // Set complete
  // ---------------------------------------------------------------------------

  @override
  void onSetComplete() {
    logger.pushKey('timeout_triggered', _isTimeout);
    logger.pushKey('trunk_fails_count', trunkMetric.faultsCount);
    logger.pushKey('rom_fails_count', romMetric.faultsCount);
    logger.pushKey('rom_good_count', romMetric.goodRomCount);
    logger.pushKey('rom_short_count', romMetric.shortRomCount);
    logger.pushKey('core_stability_ratio',
        trunkMetric.coreStabilityRatio.toStringAsFixed(2));
    logger.pushGoodRepCount();

    // Full reset cho set tiếp theo
    trunkMetric.fullReset();
    romMetric.fullReset();
    _leftCounter.reset();
    _rightCounter.reset();
    _exerciseStartTimeMs = null;
    _isTimeout = false;
  }
}

// ---------------------------------------------------------------------------
// Internal data class — gom landmarks đã validate
// ---------------------------------------------------------------------------

class _LandmarkSet {
  const _LandmarkSet({
    required this.shoulder,
    required this.elbow,
    required this.wrist,
    required this.hip,
    required this.ankle,
    required this.leftKnee,
    required this.rightKnee,
  });

  final PoseLandmark shoulder;
  final PoseLandmark elbow;
  final PoseLandmark wrist;
  final PoseLandmark hip;
  final PoseLandmark ankle;
  final PoseLandmark leftKnee;
  final PoseLandmark rightKnee;
}