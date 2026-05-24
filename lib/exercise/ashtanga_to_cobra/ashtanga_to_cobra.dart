import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../exercise_base.dart';
import '../side_tracked_exercise_mixin.dart';

enum AshtangaToCobraState {
  ashtangaSetup,
  ashtangaHolding,
  cobraTransition,
  cobraHolding
}

class AshtangaToCobra extends ExerciseBase with SideTrackedExerciseMixin {
  @override
  String get exerciseName => 'Ashtanga to Cobra';

  @override
  String get currentPhaseKey => state.name;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case AshtangaToCobraState.ashtangaSetup:
        return 'Cá sấu (Chuẩn bị)';
      case AshtangaToCobraState.ashtangaHolding:
        return 'Cá sấu (Giữ tĩnh)';
      case AshtangaToCobraState.cobraTransition:
        return 'Rắn hổ mang (Chuyển)';
      case AshtangaToCobraState.cobraHolding:
        return 'Rắn hổ mang (Giữ tĩnh)';
    }
  }

  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  Map<String, SideLandmarkPair> get requiredSideLandmarks => const {
        'shoulder': (right: PoseLandmarkType.rightShoulder, left: PoseLandmarkType.leftShoulder),
        'hip': (right: PoseLandmarkType.rightHip, left: PoseLandmarkType.leftHip),
        'knee': (right: PoseLandmarkType.rightKnee, left: PoseLandmarkType.leftKnee),
        'ankle': (right: PoseLandmarkType.rightAnkle, left: PoseLandmarkType.leftAnkle),
        'wrist': (right: PoseLandmarkType.rightWrist, left: PoseLandmarkType.leftWrist),
        'elbow': (right: PoseLandmarkType.rightElbow, left: PoseLandmarkType.leftElbow),
      };

  AshtangaToCobraState state = AshtangaToCobraState.ashtangaSetup;
  double targetAshtangaHoldTime = 1.5;
  double targetCobraHoldTime = 2.0;
  
  double _holdStartTimeMs = 0;
  double _currentHoldTime = 0;

  @override
  bool requestStop() => repCount >= 1;

  void _resetState() {
    state = AshtangaToCobraState.ashtangaSetup;
    _currentHoldTime = 0;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    return true; // Always return true for static sequence
  }

  @override
  void onSetComplete() {
    // No specific logging for this compound static pose
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left && cameraFacing != CameraFacing.right) {
      return "Vui lòng xoay người hoàn toàn sang ngang để máy quét được tư thế.";
    }
    return null; 
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    resultIssues.instructions.clear();
    
    // 1. Lấy tọa độ
    final lm = getSideTrackedLandmarks(smoothedLandmarks);
    if (lm == null) {
      if (state == AshtangaToCobraState.ashtangaHolding) {
        _resetState();
      } else if (state == AshtangaToCobraState.cobraHolding) {
        state = AshtangaToCobraState.cobraTransition;
      }
      return;
    }

    final shoulder = lm['shoulder']!;
    final hip = lm['hip']!;
    final knee = lm['knee']!;
    final wrist = lm['wrist']!;
    final elbow = lm['elbow']!;

    // Chống nhiễu: Tọa độ X của Đầu gối luôn phải nằm phía sau Tọa độ X của Vai.
    bool isFacingRight = trackedSide == TrackedSide.right;
    if (isFacingRight) {
       if (knee.x > shoulder.x) return; // Nhiễu
    } else {
       if (knee.x < shoulder.x) return; // Nhiễu
    }

    // --- Điều kiện Ashtanga ---
    bool isHipHigherThanShoulder = hip.y < shoulder.y;
    bool isHipHigherThanKnee = hip.y < knee.y;
    final armAngle = calculateAngleNormalized(firstPoint: wrist, midPoint: elbow, lastPoint: shoulder);
    
    final bodyHeight = calculateDistance(shoulder, hip);
    final tolerance = bodyHeight * 0.05; 
    bool isFlat = hip.y >= (shoulder.y - tolerance);

    // --- Điều kiện Cobra ---
    double trunkClockAngle = calculateVerticalAngle(pivot: hip, point: shoulder);
    bool isCobraPosition = false;
    
    // Hông chạm thảm: hông nên xấp xỉ mức của đầu gối (đang quỳ/nằm)
    bool isHipOnFloor = (hip.y - knee.y).abs() < bodyHeight * 0.4; 

    // Cobra: Góc thân trên nâng cao tối thiểu 25 độ
    if (isFacingRight) {
       isCobraPosition = trunkClockAngle < (90.0 - 25.0) && isHipOnFloor;
    } else {
       isCobraPosition = trunkClockAngle > (270.0 + 25.0) && isHipOnFloor;
    }

    // Xử lý State Machine
    switch(state) {
      case AshtangaToCobraState.ashtangaSetup:
        if (isFlat) {
            resultIssues.addInstruction(currentPhaseKey, 'Pose', "Tư thế Cá sấu: Nhô mông lên! Khép khuỷu tay, không để bụng chạm thảm!");
            return;
        }

        if (!isHipHigherThanShoulder || !isHipHigherThanKnee) {
            resultIssues.addInstruction(currentPhaseKey, 'Pose', "Tư thế Cá sấu: Đẩy hông lên cao để tạo thành đỉnh đồi.");
            return;
        }

        if (armAngle > 100) {
            resultIssues.addInstruction(currentPhaseKey, 'Pose', "Tư thế Cá sấu: Khép chặt khuỷu tay vào sườn.");
            return;
        }
        
        state = AshtangaToCobraState.ashtangaHolding;
        _holdStartTimeMs = frameTimestampMs.toDouble();
        resultIssues.addInstruction(currentPhaseKey, 'Status', "Đang ở Ashtanga (Cá sấu). Giữ tĩnh...");
        break;

      case AshtangaToCobraState.ashtangaHolding:
        if (isFlat || !isHipHigherThanShoulder || !isHipHigherThanKnee || armAngle > 100) {
            _resetState();
            return;
        }
        
        _currentHoldTime = (frameTimestampMs - _holdStartTimeMs) / 1000.0;
        resultIssues.addInstruction(currentPhaseKey, 'Status', "Đang ở Ashtanga: ${_currentHoldTime.toStringAsFixed(1)}s / ${targetAshtangaHoldTime}s");

        if (_currentHoldTime >= targetAshtangaHoldTime) {
          state = AshtangaToCobraState.cobraTransition;
          resultIssues.addInstruction(currentPhaseKey, 'Status', "Chuyển sang Rắn hổ mang (Cobra).");
        }
        break;

      case AshtangaToCobraState.cobraTransition:
        resultIssues.addInstruction(currentPhaseKey, 'Pose', "Hạ hông xuống sàn, trườn người lên Rắn hổ mang.");
        
        if (isCobraPosition) {
          state = AshtangaToCobraState.cobraHolding;
          _holdStartTimeMs = frameTimestampMs.toDouble();
          resultIssues.addInstruction(currentPhaseKey, 'Status', "Đang ở Rắn hổ mang. Giữ tĩnh...");
        }
        break;

      case AshtangaToCobraState.cobraHolding:
        if (!isCobraPosition) {
           state = AshtangaToCobraState.cobraTransition;
           return;
        }

        _currentHoldTime = (frameTimestampMs - _holdStartTimeMs) / 1000.0;
        resultIssues.addInstruction(currentPhaseKey, 'Status', "Đang ở Rắn hổ mang: ${_currentHoldTime.toStringAsFixed(1)}s / ${targetCobraHoldTime}s");

        if (_currentHoldTime >= targetCobraHoldTime) {
          repCount += 1;
          _currentHoldTime = 0;
          state = AshtangaToCobraState.ashtangaSetup;
          resultIssues.addInstruction(currentPhaseKey, 'Status', "Hoàn thành bài tập!");
        }
        break;
    }
    
    // Debug Data
    debugData['state'] = state.name;
    debugData['currentHoldTime'] = _currentHoldTime;
    debugData['trunkAngle'] = trunkClockAngle;
    debugData['isCobraPosition'] = isCobraPosition;
    debugData['isHipOnFloor'] = isHipOnFloor;
  }
}
