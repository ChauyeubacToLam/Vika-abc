// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names

import 'package:vika/utils/debouncer.dart';
import '../../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../exercise_base.dart';
import 'metrics/jump_squat_metric_base.dart';
import 'metrics/landing_knee_flexion_metric.dart';
import 'metrics/take_off_depth_metric.dart';
import 'metrics/landing_trunk_alignment_metric.dart';

// --- Config ---
class JumpSquatConfig {
  static const int MAX_REP = 12; // Advanced plyometric mức thấp để giữ form
  
  // Góc chuyển trạng thái cơ bản
  static const double STANDING_KNEE_THRESHOLD = 160.0;
  static const double SQUATTING_KNEE_THRESHOLD = 150.0;
  
  // Khoảng cách lơ lửng (Airborne): Tọa độ Y nhỏ hơn mức sàn bao nhiêu thì tính là bay
  // Tùy thuộc vào độ phân giải, tạm dùng mức chênh lệch tương đối
  static const double AIRBORNE_LIFT_OFFSET = 30.0; 
}

// --- Jump Squat ---
class JumpSquat extends ExerciseBase {
  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.portrait,
      };

  final int maxRep;
  JumpSquat({this.maxRep = JumpSquatConfig.MAX_REP});

  JumpSquatState jumpSquatState = JumpSquatState.standing;
  JumpSquatState previousJumpSquatState = JumpSquatState.standing;

  // Dữ liệu tham chiếu sàn động
  double? _baselineFloorY;
  double? _previousHipY;
  
  final Debouncer _entryDebouncer = Debouncer(requiredFrames: 2);

  // Metrics
  final LandingKneeFlexionMetric landingFlexionMetric = LandingKneeFlexionMetric();
  final TakeOffDepthMetric takeOffDepthMetric = TakeOffDepthMetric();
  final LandingTrunkAlignmentMetric landingTrunkMetric = LandingTrunkAlignmentMetric();

  late final List<JumpSquatMetricBase> _metrics = [
    landingFlexionMetric,
    takeOffDepthMetric,
    landingTrunkMetric,
  ];

  @override
  String get exerciseName => 'Jump Squat';

  @override
  String get currentPhaseKey => jumpSquatState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (jumpSquatState) {
      case JumpSquatState.standing: return 'Chuẩn bị';
      case JumpSquatState.squatting: return 'Lấy đà';
      case JumpSquatState.launching: return 'Bật lên';
      case JumpSquatState.airborne: return 'Lơ lửng';
      case JumpSquatState.landing: return 'Tiếp đất';
    }
  }

  // --- Start Position & Setup ---
  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final nose = landmarks[PoseLandmarkType.nose];
    final shoulder = getSideLandmark(landmarks: landmarks, rightType: PoseLandmarkType.rightShoulder, leftType: PoseLandmarkType.leftShoulder);
    final hip = getSideLandmark(landmarks: landmarks, rightType: PoseLandmarkType.rightHip, leftType: PoseLandmarkType.leftHip);
    final knee = getSideLandmark(landmarks: landmarks, rightType: PoseLandmarkType.rightKnee, leftType: PoseLandmarkType.leftKnee);
    final ankle = getSideLandmark(landmarks: landmarks, rightType: PoseLandmarkType.rightAnkle, leftType: PoseLandmarkType.leftAnkle);
    final footIndex = getSideLandmark(landmarks: landmarks, rightType: PoseLandmarkType.rightFootIndex, leftType: PoseLandmarkType.leftFootIndex);

    if (nose == null || shoulder == null || hip == null || knee == null || ankle == null || footIndex == null) return false;

    // Phải nhìn thấy đủ các bộ phận trên cơ thể mới vào tư thế sẵn sàng
    if (!ExerciseBase.isLandmarkConfident(nose) ||
        !ExerciseBase.isLandmarkConfident(shoulder) ||
        !ExerciseBase.isLandmarkConfident(hip) ||
        !ExerciseBase.isLandmarkConfident(knee) ||
        !ExerciseBase.isLandmarkConfident(ankle) ||
        !ExerciseBase.isLandmarkConfident(footIndex)) {
      resultIssues.feedback['System'] = 'Hãy đứng xa ra để AI nhìn thấy toàn thân (từ đầu đến chân)';
      return false;
    }

    double kneeAngle = calculateAngle(firstPoint: hip, midPoint: knee, lastPoint: ankle);
    
    // Đứng thẳng (Hip-Knee-Ankle > 170)
    if (kneeAngle < 170.0) return false;

    // Set baseline sàn lúc bắt đầu
    _baselineFloorY = footIndex.y;
    return true;
  }

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {}

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return "⚠️ Hãy quay ngang người để AI đánh giá độ cong của lưng!";
    }
    return null;
  }

  // --- Main Loop ---
  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    PoseLandmark? shoulder = getSideLandmark(landmarks: smoothedLandmarks, rightType: PoseLandmarkType.rightShoulder, leftType: PoseLandmarkType.leftShoulder);
    PoseLandmark? hip = getSideLandmark(landmarks: smoothedLandmarks, rightType: PoseLandmarkType.rightHip, leftType: PoseLandmarkType.leftHip);
    PoseLandmark? knee = getSideLandmark(landmarks: smoothedLandmarks, rightType: PoseLandmarkType.rightKnee, leftType: PoseLandmarkType.leftKnee);
    PoseLandmark? ankle = getSideLandmark(landmarks: smoothedLandmarks, rightType: PoseLandmarkType.rightAnkle, leftType: PoseLandmarkType.leftAnkle);
    PoseLandmark? footIndex = getSideLandmark(landmarks: smoothedLandmarks, rightType: PoseLandmarkType.rightFootIndex, leftType: PoseLandmarkType.leftFootIndex);

    if (shoulder == null || hip == null || knee == null || ankle == null || footIndex == null) return;

    // 1. Tính toán Geometry
    double kneeAngle = calculateAngle(firstPoint: hip, midPoint: knee, lastPoint: ankle);
    double trunkVerticalAngle = calculateVerticalAngle(pivot: hip, point: shoulder);
    double footY = footIndex.y;
    double hipY = hip.y;
    int now = frameTimestampMs;

    // Cập nhật lại baseline floor khi đứng yên liên tục để bù trừ rung lắc camera
    if (jumpSquatState == JumpSquatState.standing && kneeAngle > 170) {
      _baselineFloorY = (_baselineFloorY! * 0.9) + (footY * 0.1); 
    }

    final ctx = RepContext(
      kneeAngle: kneeAngle,
      trunkVerticalAngle: trunkVerticalAngle,
      footY: footY,
      hipY: hipY,
      jumpSquatState: jumpSquatState,
      frameTimestamp: now,
      resultIssues: resultIssues,
    );

    debugData['State'] = jumpSquatState.toString().split('.').last;
    debugData['KneeAngle'] = kneeAngle.toStringAsFixed(1);
    debugData['TrunkAng'] = trunkVerticalAngle.toStringAsFixed(1);

    // 2. State Machine Update
    _updateState(kneeAngle, footY, hipY, now);
    _previousHipY = hipY;

    // 3. Metric Updates
    for (final metric in _metrics) {
      metric.update(ctx);
      debugData.addAll(metric.debugData);
    }

    // 4. Hoàn thành 1 Rep (từ landing -> standing)
    if (jumpSquatState == JumpSquatState.standing && previousJumpSquatState == JumpSquatState.landing) {
      // Xử lý Report và Faults
      final allFaults = <FaultRecord>[];
      for (final metric in _metrics) {
        allFaults.addAll(metric.faults);
      }

      final backFaults = allFaults.where((f) => f.type == 'Back').toList();
      bool hasBackFault = backFaults.isNotEmpty;

      if (!hasBackFault) {
        repCount += 1;
      } else {
        final voiceMsg = backFaults.first.voiceMessage;
        if (voiceMsg != null && voiceMsg.isNotEmpty) {
          ttsService.speak(voiceMsg);
        }
      }

      correctForm = !allFaults.any((f) => f.affectsForm);
      if (hasBackFault) {
        resultIssues.feedback['Result'] = 'Không tính rep (Cong lưng)';
      } else {
        resultIssues.feedback['Result'] = correctForm ? 'Hoàn hảo! 🔥' : 'Cần chú ý an toàn!';
      }

      final faultMap = <String, Map<String, String>>{};
      for (final fault in allFaults) {
        if (!faultMap.containsKey(fault.phase)) faultMap[fault.phase] = {};
        faultMap[fault.phase]![fault.type] = fault.message;
      }
      setFeedback.add({correctForm: faultMap});

      correctForm = true;
      for (final metric in _metrics) metric.reset();
      
      // Khóa cờ chuyển rep
      previousJumpSquatState = JumpSquatState.standing; 
    }

    // UI Status Instructions
    if (jumpSquatState == JumpSquatState.squatting) resultIssues.addInstruction('squatting', 'Status', 'Gồng nén lấy đà!');
    if (jumpSquatState == JumpSquatState.airborne) resultIssues.addInstruction('airborne', 'Status', 'Bay lên!');
    if (jumpSquatState == JumpSquatState.landing) resultIssues.addInstruction('landing', 'Status', 'Trùng gối ngay!');
  }

  // --- High-Speed State Machine ---
  void _updateState(double kneeAngle, double footY, double hipY, int timestampMs) {
    if (_baselineFloorY == null || _previousHipY == null) return;

    bool isMovingUp = hipY < _previousHipY! - 2.0; // Y giảm là đi lên
    bool isAirborne = footY < (_baselineFloorY! - JumpSquatConfig.AIRBORNE_LIFT_OFFSET);
    bool isFeetOnGround = footY >= (_baselineFloorY! - JumpSquatConfig.AIRBORNE_LIFT_OFFSET / 2);

    if (jumpSquatState == JumpSquatState.standing && kneeAngle < JumpSquatConfig.SQUATTING_KNEE_THRESHOLD) {
      _transitionState(JumpSquatState.squatting, timestampMs);
    } 
    else if (jumpSquatState == JumpSquatState.squatting && isMovingUp && kneeAngle > 90) {
      // Đang squat mà hông đột ngột bật lên
      _transitionState(JumpSquatState.launching, timestampMs);
    } 
    else if (jumpSquatState == JumpSquatState.launching && isAirborne) {
      // Rời khỏi mặt sàn
      _transitionState(JumpSquatState.airborne, timestampMs);
    } 
    else if (jumpSquatState == JumpSquatState.airborne && isFeetOnGround) {
      // Chạm đất trở lại -> Bắt đầu quá trình shock absorption
      _transitionState(JumpSquatState.landing, timestampMs);
    } 
    else if (jumpSquatState == JumpSquatState.landing && kneeAngle > JumpSquatConfig.STANDING_KNEE_THRESHOLD && !isMovingUp) {
      // Sau khi nhún tiếp đất, đứng thẳng lại hoàn toàn
      _transitionState(JumpSquatState.standing, timestampMs);
    }
    // Fallback phòng khi nhảy quá nhanh bỏ lỡ khung hình launching
    else if (jumpSquatState == JumpSquatState.squatting && isAirborne) {
      _transitionState(JumpSquatState.airborne, timestampMs);
    }
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