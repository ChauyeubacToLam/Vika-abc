import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../../pose/vika_image_orientation.dart';
import '../exercise_base.dart';

enum HastaUttanasanaState { setup, holding }

class HastaUttanasana extends ExerciseBase {
  HastaUttanasanaState state = HastaUttanasanaState.setup;
  
  double _holdStartTimeMs = 0.0;
  double _currentHoldTime = 0.0;
  static const double targetHoldTime = 15.0;

  @override
  String get exerciseName => 'Hasta Uttanasana';

  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.portrait,
      };

  @override
  bool requestStop() {
    return _currentHoldTime >= targetHoldTime;
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left && cameraFacing != CameraFacing.right) {
      return "Vui lòng xoay người hoàn toàn sang ngang để máy quét được tư thế.";
    }

    final req = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
    ];

    for (final type in req) {
      if (landmarks[type] == null || !ExerciseBase.isLandmarkConfident(landmarks[type]!)) {
        return "Cơ thể chưa nằm trọn trong khung hình hoặc ánh sáng yếu.";
      }
    }
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    return true; 
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    resultIssues.instructions.clear();
    // 1. Xác định hướng (Facing)
    final isLeft = cameraFacing == CameraFacing.left || cameraFacing == CameraFacing.front;
    
    // Select landmarks (Ưu tiên bên hiển thị rõ hơn, ở đây ta lấy theo cameraFacing)
    final shoulder = isLeft ? smoothedLandmarks[PoseLandmarkType.leftShoulder]! : smoothedLandmarks[PoseLandmarkType.rightShoulder]!;
    final elbow = isLeft ? smoothedLandmarks[PoseLandmarkType.leftElbow]! : smoothedLandmarks[PoseLandmarkType.rightElbow]!;
    final wrist = isLeft ? smoothedLandmarks[PoseLandmarkType.leftWrist]! : smoothedLandmarks[PoseLandmarkType.rightWrist]!;
    final nose = smoothedLandmarks[PoseLandmarkType.nose]!;

    bool isVerified = false;
    
    // 2. Trigger: Cổ tay di chuyển lên trên (Y_Wrist < Y_Nose)
    if (wrist.y < nose.y) {
      
      // 3. Validation: Độ thẳng của tay (Shoulder - Elbow - Wrist)
      final armAngle = calculateAngle(firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
      if (armAngle >= 150 && armAngle <= 180) {
        isVerified = true; // Form chuẩn đã được nới lỏng theo yêu cầu
      } else {
        resultIssues.addInstruction(currentPhaseKey, 'Pose', "Duỗi thẳng cánh tay (góc hiện tại: ${armAngle.toStringAsFixed(0)}°).");
        _resetState();
        return;
      }
    } else {
      resultIssues.addInstruction(currentPhaseKey, 'Pose', "Nâng hai tay cao qua đầu.");
      _resetState();
      return;
    }

    // 6. Log AI (Thành công)
    if (isVerified) {
      if (state == HastaUttanasanaState.setup) {
        state = HastaUttanasanaState.holding;
        _holdStartTimeMs = frameTimestampMs.toDouble();
        resultIssues.addInstruction(currentPhaseKey, 'Status', "Form chuẩn. Giữ tĩnh...");
      } else if (state == HastaUttanasanaState.holding) {
        _currentHoldTime = (frameTimestampMs - _holdStartTimeMs) / 1000.0;
        resultIssues.addInstruction(currentPhaseKey, 'Status', "Giữ tĩnh: ${_currentHoldTime.toStringAsFixed(1)}s / ${targetHoldTime}s");

        if (_currentHoldTime >= targetHoldTime) {
          repCount += 1;
          _currentHoldTime = 0;
          state = HastaUttanasanaState.setup;
          resultIssues.addInstruction(currentPhaseKey, 'Status', "Hoàn thành Hasta Uttanasana");
        }
      }
    }

    debugData['currentHoldTime'] = _currentHoldTime;
    debugData['holdProgress'] = (_currentHoldTime / targetHoldTime).clamp(0.0, 1.0);
  }

  void _resetState() {
    state = HastaUttanasanaState.setup;
    _currentHoldTime = 0;
  }

  @override
  String get currentPhaseKey => state.name;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case HastaUttanasanaState.setup: return 'Chuẩn bị';
      case HastaUttanasanaState.holding: return 'Giữ tĩnh';
    }
  }

  @override
  void onSetComplete() {
  }
}
