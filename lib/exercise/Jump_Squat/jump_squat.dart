// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names

import 'dart:math' as math;

import 'package:vika/debug/tracked_metric.dart';
import '../../utils/debouncer.dart';
import '../../utils/exercise_logger.dart';
import '../../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../exercise_base.dart';
import 'metrics/jump_squat_metric_base.dart';
import 'metrics/landing_knee_flexion_metric.dart';
import 'metrics/take_off_depth_metric.dart';
import 'metrics/landing_trunk_alignment_metric.dart';

// --- Config ---
class JumpSquatConfig {
  // Góc chuyển trạng thái cơ bản
  static const double STANDING_KNEE_THRESHOLD = 150.0;
  static const double SQUATTING_KNEE_THRESHOLD = 140.0;

  // Khoảng cách lơ lửng (Airborne): Tọa độ Y nhỏ hơn mức sàn bao nhiêu thì tính là bay
  // Tùy thuộc vào độ phân giải, tạm dùng mức chênh lệch tương đối
  static const double AIRBORNE_FOOT_LIFT_LOWER_LEG_RATIO = 0.07;
  static const double AIRBORNE_FOOT_LIFT_TORSO_RATIO = 0.04;
  static const double AIRBORNE_HIP_LIFT_TORSO_RATIO = 0.05;
  static const double GROUND_CONTACT_LIFT_RATIO = 0.55;
  static const int MIN_REP_DURATION_MS = 350;
}

// --- Jump Squat ---
class JumpSquat extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.portrait,
      };

  final int maxRep;
  JumpSquat({required this.maxRep});

  JumpSquatState jumpSquatState = JumpSquatState.standing;
  JumpSquatState previousJumpSquatState = JumpSquatState.standing;

  // Dữ liệu tham chiếu sàn động
  double? _baselineFloorY;
  double? _baselineStandingHipY;
  double? _previousHipY;
  int? _repStartedAtMs;

  final Debouncer _squattingDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _launchingDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _airborneDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _landingDebouncer = Debouncer(requiredFrames: 2);
  final Debouncer _standingDebouncer = Debouncer(requiredFrames: 2);

  // Metrics
  final LandingKneeFlexionMetric landingFlexionMetric =
      LandingKneeFlexionMetric();
  final TakeOffDepthMetric takeOffDepthMetric = TakeOffDepthMetric();
  final LandingTrunkAlignmentMetric landingTrunkMetric =
      LandingTrunkAlignmentMetric();

  late final List<JumpSquatMetricBase> _metrics = [
    landingFlexionMetric,
    takeOffDepthMetric,
    landingTrunkMetric,
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

  @override
  String get exerciseName => 'Jump Squat';

  @override
  String get currentPhaseKey => jumpSquatState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (jumpSquatState) {
      case JumpSquatState.standing:
        return 'Chuẩn bị';
      case JumpSquatState.squatting:
        return 'Lấy đà';
      case JumpSquatState.launching:
        return 'Bật lên';
      case JumpSquatState.airborne:
        return 'Lơ lửng';
      case JumpSquatState.landing:
        return 'Tiếp đất';
    }
  }

  // --- Start Position & Setup ---
  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final nose = landmarks[PoseLandmarkType.nose];
    final shoulder = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    final hip = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);
    final knee = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightKnee,
        leftType: PoseLandmarkType.leftKnee);
    final ankle = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle);
    final footIndex = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightFootIndex,
        leftType: PoseLandmarkType.leftFootIndex);
    final heel = getSideLandmark(
        landmarks: landmarks,
        rightType: PoseLandmarkType.rightHeel,
        leftType: PoseLandmarkType.leftHeel);

    if (nose == null ||
        shoulder == null ||
        hip == null ||
        knee == null ||
        ankle == null ||
        footIndex == null) return false;

    // Phải nhìn thấy đủ các bộ phận trên cơ thể mới vào tư thế sẵn sàng
    if (!ExerciseBase.isLandmarkConfident(nose) ||
        !ExerciseBase.isLandmarkConfident(shoulder) ||
        !ExerciseBase.isLandmarkConfident(hip) ||
        !ExerciseBase.isLandmarkConfident(knee) ||
        !ExerciseBase.isLandmarkConfident(ankle) ||
        !ExerciseBase.isLandmarkConfident(footIndex)) {
      resultIssues.feedback['System'] =
          'Hãy đứng xa ra để AI nhìn thấy toàn thân (từ đầu đến chân)';
      return false;
    }

    double kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);

    // Đứng thẳng (Hip-Knee-Ankle > 170)
    if (kneeAngle < 170.0) return false;

    // Set baseline sàn lúc bắt đầu
    _baselineFloorY = _supportY(ankle: ankle, heel: heel, footIndex: footIndex);
    _baselineStandingHipY = hip.y;
    return true;
  }

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey(
        "stiff_landing_fails_count", landingFlexionMetric.faultsCount);
    logger.pushKey("shallow_dip_fails_count", takeOffDepthMetric.faultsCount);
    logger.pushKey("trunk_lean_fails_count", landingTrunkMetric.faultsCount);
    logger.pushGoodRepCount();
    logger.pushKey('max_rep', maxRep);
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return "⚠️ Hãy quay ngang người để AI đánh giá độ cong của lưng!";
    }
    return null;
  }

  // --- Main Loop ---
  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    PoseLandmark? shoulder = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightShoulder,
        leftType: PoseLandmarkType.leftShoulder);
    PoseLandmark? hip = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightHip,
        leftType: PoseLandmarkType.leftHip);
    PoseLandmark? knee = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightKnee,
        leftType: PoseLandmarkType.leftKnee);
    PoseLandmark? ankle = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightAnkle,
        leftType: PoseLandmarkType.leftAnkle);
    PoseLandmark? footIndex = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightFootIndex,
        leftType: PoseLandmarkType.leftFootIndex);
    PoseLandmark? heel = getSideLandmark(
        landmarks: smoothedLandmarks,
        rightType: PoseLandmarkType.rightHeel,
        leftType: PoseLandmarkType.leftHeel);

    if (shoulder == null ||
        hip == null ||
        knee == null ||
        ankle == null ||
        footIndex == null) return;
    if (![shoulder, hip, knee, ankle, footIndex]
        .every(ExerciseBase.isLandmarkConfident)) {
      return;
    }

    // 1. Tính toán Geometry
    double kneeAngle = calculateAngleNormalized(
        firstPoint: hip, midPoint: knee, lastPoint: ankle);
    double backAngle = calculateVerticalAngle(pivot: hip, point: shoulder);
    double trunkVerticalAngle =
        convertClockAngleToTrunkLean(backAngle, cameraFacing).abs();
    scaleFactor = calculateDistance(shoulder, hip);
    final lowerLegLength = calculateDistance(knee, ankle);
    final supportY = _supportY(ankle: ankle, heel: heel, footIndex: footIndex);
    double hipY = hip.y;
    int now = frameTimestampMs;

    // Cập nhật lại baseline floor khi đứng yên liên tục để bù trừ rung lắc camera
    _refreshStandingBaselines(kneeAngle, supportY, hipY, lowerLegLength);

    debugData['State'] = jumpSquatState.toString().split('.').last;
    debugData['KneeAngle'] = kneeAngle.toStringAsFixed(1);
    debugData['TrunkAng'] = trunkVerticalAngle.toStringAsFixed(1);
    debugData['SupportLift'] = _baselineFloorY == null
        ? '-'
        : (_baselineFloorY! - supportY).toStringAsFixed(1);
    debugData['HipLift'] = _baselineStandingHipY == null
        ? '-'
        : (_baselineStandingHipY! - hipY).toStringAsFixed(1);

    // 2. State Machine Update
    _updateState(kneeAngle, supportY, hipY, lowerLegLength, now);
    _previousHipY = hipY;

    final ctx = RepContext(
      kneeAngle: kneeAngle,
      trunkVerticalAngle: trunkVerticalAngle,
      footY: supportY,
      hipY: hipY,
      jumpSquatState: jumpSquatState,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    // 3. Metric Updates
    for (final metric in _metrics) {
      metric.update(ctx);
      debugData.addAll(metric.debugData);
    }
    _publishFaultFeedback(_metrics.expand((metric) => metric.faults));

    // 4. Hoàn thành 1 Rep (từ landing -> standing)
    if (jumpSquatState == JumpSquatState.standing &&
        previousJumpSquatState == JumpSquatState.landing) {
      // Xử lý Report và Faults
      final allFaults = <FaultRecord>[];
      for (final metric in _metrics) {
        allFaults.addAll(metric.faults);
      }

      final isAntiCheatReject = _isRepTooFast(now);
      correctForm = !allFaults.any((f) => f.affectsForm);

      if (!isAntiCheatReject) {
        repCount += 1;
        logger.addRepLog(RepLog(
          correctForm: correctForm,
          repNumber: repCount,
          data: {
            'fault_types': allFaults.map((e) => e.type).toSet().toList(),
          },
        ));

        resultIssues.feedback['Result'] =
            correctForm ? 'Hoàn hảo! 🔥' : 'Cần chú ý an toàn!';
        _publishFaultFeedback(allFaults);

        final faultMap = <String, Map<String, String>>{};
        for (final fault in allFaults) {
          if (!faultMap.containsKey(fault.phase)) faultMap[fault.phase] = {};
          faultMap[fault.phase]![fault.type] = fault.message;
        }
        setFeedback.add({correctForm: faultMap});

        for (final metric in _metrics) metric.resetAndCountFault();
      } else {
        resultIssues.feedback['Result'] = 'Không tính rep';
        resultIssues.feedback['too_fast'] =
            'Chuyển động quá nhanh, AI không xác nhận được rep.';
        resultIssues.addInstruction(
            currentPhaseKey, 'too_fast', 'Làm chậm lại và nhảy rõ hơn');
        for (final metric in _metrics) metric.reset();
      }

      correctForm = true;
      _repStartedAtMs = null;
      _resetDebouncers();

      // Khóa cờ chuyển rep
      previousJumpSquatState = JumpSquatState.standing;
    }

    // UI Status Instructions
    if (jumpSquatState == JumpSquatState.squatting)
      resultIssues.addInstruction('squatting', 'Status', 'Gồng nén lấy đà!');
    if (jumpSquatState == JumpSquatState.airborne)
      resultIssues.addInstruction('airborne', 'Status', 'Bay lên!');
    if (jumpSquatState == JumpSquatState.landing)
      resultIssues.addInstruction('landing', 'Status', 'Trùng gối ngay!');
  }

  // --- High-Speed State Machine ---
  void _updateState(
    double kneeAngle,
    double supportY,
    double hipY,
    double lowerLegLength,
    int timestampMs,
  ) {
    if (_baselineFloorY == null ||
        _baselineStandingHipY == null ||
        _previousHipY == null) {
      return;
    }

    bool isMovingUp = hipY < _previousHipY! - 2.0; // Y giảm là đi lên
    final footLiftThreshold = _airborneFootLiftThreshold(lowerLegLength);
    final hipLiftThreshold =
        scaleFactor * JumpSquatConfig.AIRBORNE_HIP_LIFT_TORSO_RATIO;
    final supportLift = _baselineFloorY! - supportY;
    final hipLift = _baselineStandingHipY! - hipY;
    final isAirborne =
        supportLift > footLiftThreshold && hipLift > hipLiftThreshold;
    final isFeetOnGround = supportLift <=
        footLiftThreshold * JumpSquatConfig.GROUND_CONTACT_LIFT_RATIO;

    if (_squattingDebouncer.update(jumpSquatState == JumpSquatState.standing &&
        kneeAngle < JumpSquatConfig.SQUATTING_KNEE_THRESHOLD)) {
      _repStartedAtMs = timestampMs;
      _transitionState(JumpSquatState.squatting, timestampMs);
    } else if (_launchingDebouncer.update(
        jumpSquatState == JumpSquatState.squatting &&
            isMovingUp &&
            kneeAngle > 90)) {
      // Đang squat mà hông đột ngột bật lên
      _transitionState(JumpSquatState.launching, timestampMs);
    } else if (_airborneDebouncer.update(
        (jumpSquatState == JumpSquatState.launching ||
                jumpSquatState == JumpSquatState.squatting) &&
            isAirborne)) {
      // Rời khỏi mặt sàn
      _transitionState(JumpSquatState.airborne, timestampMs);
    } else if (_landingDebouncer
        .update(jumpSquatState == JumpSquatState.airborne && isFeetOnGround)) {
      // Chạm đất trở lại -> Bắt đầu quá trình shock absorption
      _transitionState(JumpSquatState.landing, timestampMs);
    } else if (_standingDebouncer.update(
        jumpSquatState == JumpSquatState.landing &&
            kneeAngle > JumpSquatConfig.STANDING_KNEE_THRESHOLD &&
            !isMovingUp &&
            isFeetOnGround)) {
      // Sau khi nhún tiếp đất, đứng thẳng lại hoàn toàn
      _transitionState(JumpSquatState.standing, timestampMs);
    }
  }

  double _supportY({
    required PoseLandmark ankle,
    PoseLandmark? heel,
    required PoseLandmark footIndex,
  }) {
    final values = <double>[ankle.y, footIndex.y];
    if (heel != null && ExerciseBase.isLandmarkConfident(heel)) {
      values.add(heel.y);
    }
    return values.reduce(math.max);
  }

  void _refreshStandingBaselines(
    double kneeAngle,
    double supportY,
    double hipY,
    double lowerLegLength,
  ) {
    if (jumpSquatState != JumpSquatState.standing || kneeAngle < 170) return;

    final currentFloor = _baselineFloorY;
    if (currentFloor == null) {
      _baselineFloorY = supportY;
      _baselineStandingHipY = hipY;
      return;
    }

    final floorThreshold = _airborneFootLiftThreshold(lowerLegLength);
    final supportIsGrounded = currentFloor - supportY <= floorThreshold * 0.5;
    if (!supportIsGrounded) return;

    _baselineFloorY = (currentFloor * 0.92) + (supportY * 0.08);
    final currentHip = _baselineStandingHipY;
    _baselineStandingHipY =
        currentHip == null ? hipY : (currentHip * 0.92) + (hipY * 0.08);
  }

  double _airborneFootLiftThreshold(double lowerLegLength) {
    return math.max(
      lowerLegLength * JumpSquatConfig.AIRBORNE_FOOT_LIFT_LOWER_LEG_RATIO,
      scaleFactor * JumpSquatConfig.AIRBORNE_FOOT_LIFT_TORSO_RATIO,
    );
  }

  bool _isRepTooFast(int now) {
    final start = _repStartedAtMs;
    if (start == null) return true;
    return now - start < JumpSquatConfig.MIN_REP_DURATION_MS;
  }

  void _publishFaultFeedback(Iterable<FaultRecord> faults) {
    final sorted = faults.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    for (final fault in sorted) {
      final key = _feedbackKeyForFault(fault);
      final message = fault.voiceMessage ?? fault.message;
      final phase =
          fault.phase == 'REP_COMPLETE' ? currentPhaseKey : fault.phase;
      resultIssues.feedback[key] = message;
      resultIssues.addInstruction(phase, key, fault.message);
    }
  }

  String _feedbackKeyForFault(FaultRecord fault) {
    switch (fault.type) {
      case 'Power':
        return 'takeoff_depth';
      case 'Back':
        return 'trunk';
      case 'Knee':
        return fault.affectsForm ? 'landing_stiff' : 'landing_depth';
      default:
        return fault.type;
    }
  }

  void _resetDebouncers() {
    _squattingDebouncer.reset();
    _launchingDebouncer.reset();
    _airborneDebouncer.reset();
    _landingDebouncer.reset();
    _standingDebouncer.reset();
  }

  void _transitionState(JumpSquatState newState, int timestampMs) {
    previousJumpSquatState = jumpSquatState;
    jumpSquatState = newState;

    if (newState == JumpSquatState.squatting) {
      resultIssues.instructions.clear();
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousJumpSquatState, newState, timestampMs);
    }
  }
}
