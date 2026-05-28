import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../pose/vika_image_orientation.dart';
import '../exercise_base.dart';
import '../side_tracked_exercise_mixin.dart';

enum ParvatasanaState { setup, holding }

class Parvatasana extends ExerciseBase with SideTrackedExerciseMixin {
  @override
  String get exerciseName => 'Parvatasana';

  @override
  String get currentPhaseKey => state.name;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case ParvatasanaState.setup:
        return 'Chuẩn bị';
      case ParvatasanaState.holding:
        return 'Giữ tư thế';
    }
  }

  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.portrait,
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

  ParvatasanaState state = ParvatasanaState.setup;
  double targetHoldTime = 15.0;
  double _holdStartTimeMs = 0;
  double _currentHoldTime = 0;

  @override
  bool requestStop() => repCount >= 1;

  void _resetState() {
    state = ParvatasanaState.setup;
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
    return null; // Return null (no safety error) by default
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

    // Tip tối ưu AI: Không dùng các điểm trên mặt, chỉ tập trung vào Vai, Hông, Gối và Cổ tay
    // Lấy 2 mắt cá chân để kiểm tra khoảng cách
    final rightAnkle = smoothedLandmarks[PoseLandmarkType.rightAnkle];
    final leftAnkle = smoothedLandmarks[PoseLandmarkType.leftAnkle];

    if (rightAnkle == null || leftAnkle == null) {
      _resetState();
      return;
    }

    // 2. Trigger check
    // Chân rút về: Khoảng cách trục X giữa hai Cổ chân giảm mạnh
    final deltaXAnkle = (rightAnkle.x - leftAnkle.x).abs();
    final bodyHeight = calculateDistance(shoulder, hip); // Scale tham chiếu
    if (deltaXAnkle > bodyHeight * 0.5) {
       resultIssues.addInstruction(currentPhaseKey, 'Pose', "Rút chân về sát nhau.");
       _resetState();
       return;
    }

    // 3. Validation (Xác nhận form Chữ V ngược)
    // Hông là đỉnh chữ V: Tọa độ Y của Hông phải nhỏ nhất (nằm cao nhất)
    bool isHipHighest = hip.y < shoulder.y && hip.y < knee.y;
    if (!isHipHighest) {
       resultIssues.addInstruction(currentPhaseKey, 'Pose', "Đẩy hông lên cao để tạo hình chữ V ngược.");
       _resetState();
       return;
    }

    // Tay thẳng: Góc Vai - Khuỷu tay - Cổ tay >= 160
    final armAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
    if (armAngle < 160) {
       resultIssues.addInstruction(currentPhaseKey, 'Pose', "Duỗi thẳng hai cánh tay.");
       _resetState();
       return;
    }

    // 4. Bắt lỗi riêng (Metric P5) - Trục Vai/Lưng bị gù
    // Góc Cổ tay - Vai - Hông >= 155 (Hạ từ 170 xuống 155 cho thân thiện)
    final backAngle = calculateAngleNormalized(firstPoint: wrist, midPoint: shoulder, lastPoint: hip);

    bool isVerified = false;

    if (backAngle >= 155 && backAngle <= 180) {
        isVerified = true;
    } else {
        if (backAngle < 155) {
            resultIssues.addInstruction(currentPhaseKey, 'Pose', "Đẩy mạnh hai tay xuống thảm, ép vai ra sau, vươn dài lưng lên đỉnh mông!");
            _resetState();
            return;
        } else {
            // Trường hợp > 180 (ngả quá lố ra sau, rất khó xảy ra, nhưng cứ coi là pass)
            isVerified = true;
        }
    }

    // 5. Bổ sung UX: Không bắt lỗi gập gối hay nhón gót.

    // 6. Log AI & Chuyển trạng thái
    if (isVerified) {
      if (state == ParvatasanaState.setup) {
        state = ParvatasanaState.holding;
        _holdStartTimeMs = frameTimestampMs.toDouble();
        resultIssues.addInstruction(currentPhaseKey, 'Status', "Lưng thẳng, Vai mở. Giữ tĩnh...");
      } else if (state == ParvatasanaState.holding) {
        _currentHoldTime = (frameTimestampMs - _holdStartTimeMs) / 1000.0;
        resultIssues.addInstruction(currentPhaseKey, 'Status', "Giữ tĩnh: ${_currentHoldTime.toStringAsFixed(1)}s / ${targetHoldTime}s");

        if (_currentHoldTime >= targetHoldTime) {
          repCount += 1;
          _currentHoldTime = 0;
          state = ParvatasanaState.setup;
          resultIssues.addInstruction(currentPhaseKey, 'Status', "Hoàn thành Parvatasana");
        }
      }
    }
    
    debugData['currentHoldTime'] = _currentHoldTime;
    debugData['holdProgress'] = (_currentHoldTime / targetHoldTime).clamp(0.0, 1.0);
    debugData['deltaXAnkle'] = deltaXAnkle;
    debugData['isHipHighest'] = isHipHighest;
    debugData['armAngle'] = armAngle;
    debugData['backAngle'] = backAngle;
  }
}
