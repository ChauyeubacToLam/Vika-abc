import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../exercise_base.dart';
import '../side_tracked_exercise_mixin.dart';

enum AshtangaNamaskaraState { setup, holding }

class AshtangaNamaskara extends ExerciseBase with SideTrackedExerciseMixin {
  @override
  String get exerciseName => 'Ashtanga Namaskara';

  @override
  String get currentPhaseKey => state.name;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case AshtangaNamaskaraState.setup:
        return 'Chuẩn bị';
      case AshtangaNamaskaraState.holding:
        return 'Giữ tư thế';
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

  AshtangaNamaskaraState state = AshtangaNamaskaraState.setup;
  double targetHoldTime = 1.5;
  double _holdStartTimeMs = 0;
  double _currentHoldTime = 0;

  @override
  bool requestStop() => repCount >= 1;

  void _resetState() {
    state = AshtangaNamaskaraState.setup;
    _currentHoldTime = 0;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    return true; // Always return true for static sequence
  }

  @override
  void onSetComplete() {
    // No logging needed for this simple static pose
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
    
    // 1. Lấy tọa độ (chọn bên cơ thể dựa trên hướng quay)
    final lm = getSideTrackedLandmarks(smoothedLandmarks);
    if (lm == null) {
      _resetState();
      return;
    }

    final shoulder = lm['shoulder']!;
    final hip = lm['hip']!;
    final knee = lm['knee']!;
    final wrist = lm['wrist']!;
    final elbow = lm['elbow']!;

    // Chống nhiễu: Tọa độ X của Đầu gối luôn phải nằm phía sau Tọa độ X của Vai.
    // Dựa trên trackedSide, Right side => facing right => shoulder.x > knee.x
    bool isFacingRight = trackedSide == TrackedSide.right;
    if (isFacingRight) {
       if (knee.x > shoulder.x) return; // Nhiễu
    } else {
       if (knee.x < shoulder.x) return; // Nhiễu
    }

    // 2. Trigger & Validation (Xác nhận form 8 điểm)
    // Trọng tâm: Hông tạo thành "đỉnh đồi" nhô lên so với Ngực (Vai) và Đầu gối
    bool isHipHigherThanShoulder = hip.y < shoulder.y;
    bool isHipHigherThanKnee = hip.y < knee.y;

    // Khuỷu tay khép: Góc Cổ tay - Khuỷu tay - Vai <= 100
    final armAngle = calculateAngleNormalized(firstPoint: wrist, midPoint: elbow, lastPoint: shoulder);

    // 4. Bắt lỗi riêng (Metric P6) - Lỗi sập hông / Nằm bẹp
    // Tolerance = 5% chiều cao cơ thể (khoảng cách vai - hông)
    final bodyHeight = calculateDistance(shoulder, hip);
    final tolerance = bodyHeight * 0.05; 
    
    // Nếu Tọa độ Y của Hông lớn hơn hoặc xấp xỉ Tọa độ Y của Vai (Hông ngang bằng hoặc thấp hơn ngực)
    bool isFlat = hip.y >= (shoulder.y - tolerance);

    if (isFlat) {
        resultIssues.addInstruction(currentPhaseKey, 'Pose', "Nhô mông lên! Khép chặt khuỷu tay vào sườn, không để bụng chạm thảm!");
        _resetState();
        return;
    }

    // Kiểm tra các điều kiện còn lại
    if (!isHipHigherThanShoulder || !isHipHigherThanKnee) {
        resultIssues.addInstruction(currentPhaseKey, 'Pose', "Đẩy hông lên cao để tạo thành đỉnh đồi.");
        _resetState();
        return;
    }

    if (armAngle > 100) {
        resultIssues.addInstruction(currentPhaseKey, 'Pose', "Khép chặt khuỷu tay vào sườn (co tay lại).");
        _resetState();
        return;
    }

    // 6. Log AI & Chuyển trạng thái
    if (state == AshtangaNamaskaraState.setup) {
      state = AshtangaNamaskaraState.holding;
      _holdStartTimeMs = frameTimestampMs.toDouble();
      resultIssues.addInstruction(currentPhaseKey, 'Status', "Hông nhô cao chuẩn. Giữ tĩnh...");
    } else if (state == AshtangaNamaskaraState.holding) {
      _currentHoldTime = (frameTimestampMs - _holdStartTimeMs) / 1000.0;
      resultIssues.addInstruction(currentPhaseKey, 'Status', "Giữ tĩnh: ${_currentHoldTime.toStringAsFixed(1)}s / ${targetHoldTime}s");

      if (_currentHoldTime >= targetHoldTime) {
        repCount += 1;
        _currentHoldTime = 0;
        state = AshtangaNamaskaraState.setup;
        resultIssues.addInstruction(currentPhaseKey, 'Status', "Hoàn thành Ashtanga Namaskara");
      }
    }
    
    debugData['currentHoldTime'] = _currentHoldTime;
    debugData['isHipHigherThanShoulder'] = isHipHigherThanShoulder;
    debugData['isHipHigherThanKnee'] = isHipHigherThanKnee;
    debugData['armAngle'] = armAngle;
    debugData['isFlat'] = isFlat;
  }
}
