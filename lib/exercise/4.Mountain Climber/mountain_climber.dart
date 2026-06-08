// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../utils/exercise_logger.dart';
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
      case ClimberState.high_plank_base:
        return 'Chuẩn bị';
      case ClimberState.knee_driving_in:
        return 'Kéo gối lên';
      case ClimberState.max_flexion:
        return 'Chạm đỉnh';
      case ClimberState.knee_driving_out:
        return 'Duỗi chân về';
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
  int _doubleKneeRejects = 0;
  bool _doubleKneeActive = false;

  // ---------------------------------------------------------------------------
  // Safety check
  // ---------------------------------------------------------------------------

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return 'Vui lòng quay ngang người 100% với camera!';
    }
    if (_extractLandmarks(smoothedLandmarks) == null) {
      return 'Giữ vai, tay, hông, gối và cổ chân rõ trong khung hình.';
    }
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
    final leftKneeDist = (lm.leftKnee.x - lm.shoulder.x).abs() / scaleFactor;
    final rightKneeDist = (lm.rightKnee.x - lm.shoulder.x).abs() / scaleFactor;
    final supportAnkle =
        leftKneeDist > rightKneeDist ? lm.leftAnkle : lm.rightAnkle;

    final double trunkAngle = calculateAngleNormalized(
      firstPoint: lm.shoulder,
      midPoint: lm.hip,
      lastPoint: supportAnkle,
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
    final double scale = calculateDistance(lm.shoulder, lm.hip);
    if (scale > 0) {
      final double distL = (lm.leftKnee.x - lm.shoulder.x).abs() / scale;
      final double distR = (lm.rightKnee.x - lm.shoulder.x).abs() / scale;

      // Lấy trung bình 3 frame để ổn định (đơn giản: gán thẳng khi form đạt)
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
    if (!scaleFactor.isFinite || scaleFactor <= 1e-6) return;

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

    // --- Peak counter phải ---
    final int rightRep = _rightCounter.update(
      kneeX: lm.rightKnee.x,
      shoulderX: lm.shoulder.x,
      scaleFactor: scaleFactor,
      nowMs: now,
    );
    final bothKneesInZone = _leftCounter.isInZone && _rightCounter.isInZone;
    _doubleKneeActive = _doubleKneeActive || bothKneesInZone;
    final rejectsDoubleKneeRep =
        _doubleKneeActive && (leftRep > 0 || rightRep > 0 || bothKneesInZone);

    if ((leftRep > 0 && rightRep > 0) || rejectsDoubleKneeRep) {
      _doubleKneeRejects++;
      resultIssues.feedback['Result'] = 'Không tính rep';
      resultIssues.feedback['ROM'] = 'Luân phiên từng gối';
      resultIssues.addInstruction(
          'high_plank_base', 'ROM', 'Kéo từng gối một, không co cả hai gối');
      trunkMetric.resetAndCountFault();
      romMetric.reset();
      _leftCounter.reset();
      _rightCounter.reset();
      _doubleKneeActive = false;
    } else if (leftRep > 0) {
      _onRepCompleted(ctx, KneeSide.left);
    } else if (rightRep > 0) {
      _onRepCompleted(ctx, KneeSide.right);
    }

    // --- Cập nhật display state dựa trên zone của 2 counter ---
    _updateDisplayState();

    // --- Diagnostic table ---
    debugData['Diag'] = {
      'state': _displayState.name,
      'repCount': repCount,
      'elapsed_s': ((now - _exerciseStartTimeMs!) / 1000).toStringAsFixed(1),
      'armAngle': armAngle.toStringAsFixed(1),
      'trunkAngle': trunkAngle.toStringAsFixed(1),
      'L_dist': _leftCounter.smoothedDist.toStringAsFixed(2),
      'R_dist': _rightCounter.smoothedDist.toStringAsFixed(2),
      'L_inZone': _leftCounter.isInZone,
      'R_inZone': _rightCounter.isInZone,
      'doubleKneeActive': _doubleKneeActive,
      'L_threshold': _leftCounter.zoneThreshold.toStringAsFixed(2),
      'R_threshold': _rightCounter.zoneThreshold.toStringAsFixed(2),
      'scaleFactor': scaleFactor.toStringAsFixed(1),
    };
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _onRepCompleted(RepContext ctx, KneeSide side) {
    // Lấy peakDist từ counter tương ứng
    final double peakDist = side == KneeSide.left
        ? (_leftCounter.lastCompletedPeakDist ?? _leftCounter.minDistInZone)
        : (_rightCounter.lastCompletedPeakDist ?? _rightCounter.minDistInZone);

    final double threshold = side == KneeSide.left
        ? _leftCounter.zoneThreshold
        : _rightCounter.zoneThreshold;

    romMetric.evaluateRepEnd(ctx, side, peakDist, threshold);

    final allFaults = <FaultRecord>[
      ...trunkMetric.faults,
      ...romMetric.faults,
    ];
    correctForm = !allFaults.any((f) => f.affectsForm);
    repCount++;
    if (!correctForm) resultIssues.feedback['Result'] = 'Chỉnh form';

    logger.addRepLog(RepLog(
      correctForm: correctForm,
      repNumber: repCount,
      data: {
        'side': side.name,
        'peak_dist': peakDist,
        'zone_threshold': threshold,
        'fault_types': allFaults.map((f) => f.type).toSet().toList(),
      },
    ));

    trunkMetric.resetAndCountFault();
    romMetric.resetAndCountFault();
  }

  void _updateDisplayState() {
    final bool anyInZone = _leftCounter.isInZone || _rightCounter.isInZone;

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

  _LandmarkSet? _extractLandmarks(Map<PoseLandmarkType, PoseLandmark> lm) {
    final useRight = cameraFacing == CameraFacing.right;
    final PoseLandmark? shoulder = lm[useRight
        ? PoseLandmarkType.rightShoulder
        : PoseLandmarkType.leftShoulder];
    final PoseLandmark? elbow =
        lm[useRight ? PoseLandmarkType.rightElbow : PoseLandmarkType.leftElbow];
    final PoseLandmark? wrist =
        lm[useRight ? PoseLandmarkType.rightWrist : PoseLandmarkType.leftWrist];
    final PoseLandmark? hip =
        lm[useRight ? PoseLandmarkType.rightHip : PoseLandmarkType.leftHip];
    final PoseLandmark? ankle =
        lm[useRight ? PoseLandmarkType.rightAnkle : PoseLandmarkType.leftAnkle];
    final PoseLandmark? leftAnkle = lm[PoseLandmarkType.leftAnkle];
    final PoseLandmark? rightAnkle = lm[PoseLandmarkType.rightAnkle];
    final PoseLandmark? leftKnee = lm[PoseLandmarkType.leftKnee];
    final PoseLandmark? rightKnee = lm[PoseLandmarkType.rightKnee];

    if (shoulder == null ||
        elbow == null ||
        wrist == null ||
        hip == null ||
        ankle == null ||
        leftAnkle == null ||
        rightAnkle == null ||
        leftKnee == null ||
        rightKnee == null) {
      return null;
    }
    if (![
      shoulder,
      elbow,
      wrist,
      hip,
      ankle,
      leftAnkle,
      rightAnkle,
      leftKnee,
      rightKnee
    ].every(ExerciseBase.isLandmarkConfident)) {
      return null;
    }

    return _LandmarkSet(
      shoulder: shoulder,
      elbow: elbow,
      wrist: wrist,
      hip: hip,
      ankle: ankle,
      leftAnkle: leftAnkle,
      rightAnkle: rightAnkle,
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
    logger.pushKey('target_rep', ClimberConfig.MAX_REP);
    logger.pushKey('max_rep', repCount);
    logger.pushKey('trunk_fails_count', trunkMetric.faultsCount);
    logger.pushKey('rom_fails_count', romMetric.faultsCount);
    logger.pushKey('double_knee_rejects_count', _doubleKneeRejects);
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
    _doubleKneeRejects = 0;
    _doubleKneeActive = false;
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
    required this.leftAnkle,
    required this.rightAnkle,
    required this.leftKnee,
    required this.rightKnee,
  });

  final PoseLandmark shoulder;
  final PoseLandmark elbow;
  final PoseLandmark wrist;
  final PoseLandmark hip;
  final PoseLandmark ankle;
  final PoseLandmark leftAnkle;
  final PoseLandmark rightAnkle;
  final PoseLandmark leftKnee;
  final PoseLandmark rightKnee;
}
