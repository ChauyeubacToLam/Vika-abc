import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../exercise_base.dart';

enum HastaUttanasanaState { setup, holding }

class HastaUttanasana extends ExerciseBase {
  HastaUttanasanaState state = HastaUttanasanaState.setup;
  
  double _holdStartTimeMs = 0.0;
  double _currentHoldTime = 0.0;
  static const double targetHoldTime = 3.0;

  double? _hipXT1;
  double? _shoulderXT1;

  @override
  String get exerciseName => 'Hasta Uttanasana';

  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
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
    int direction = isLeft ? -1 : 1;
    
    // Select landmarks (Ưu tiên bên hiển thị rõ hơn, ở đây ta lấy theo cameraFacing)
    final shoulder = isLeft ? smoothedLandmarks[PoseLandmarkType.leftShoulder]! : smoothedLandmarks[PoseLandmarkType.rightShoulder]!;
    final hip = isLeft ? smoothedLandmarks[PoseLandmarkType.leftHip]! : smoothedLandmarks[PoseLandmarkType.rightHip]!;
    final knee = isLeft ? smoothedLandmarks[PoseLandmarkType.leftKnee]! : smoothedLandmarks[PoseLandmarkType.rightKnee]!;
    final ankle = isLeft ? smoothedLandmarks[PoseLandmarkType.leftAnkle]! : smoothedLandmarks[PoseLandmarkType.rightAnkle]!;
    
    final wrist = isLeft ? smoothedLandmarks[PoseLandmarkType.leftWrist]! : smoothedLandmarks[PoseLandmarkType.rightWrist]!;
    final elbow = isLeft ? smoothedLandmarks[PoseLandmarkType.leftElbow]! : smoothedLandmarks[PoseLandmarkType.rightElbow]!;
    final nose = smoothedLandmarks[PoseLandmarkType.nose]!;

    // Capture T1 (Trạm 1) khi cơ thể đang đứng thẳng (Góc > 170 độ)
    final khsAngle = calculateAngle(firstPoint: knee, midPoint: hip, lastPoint: shoulder);
    if (khsAngle > 170 && _hipXT1 == null) {
      _hipXT1 = hip.x;
      _shoulderXT1 = shoulder.x;
    }

    bool isVerified = false;
    
    // 2. Trigger: Cổ tay di chuyển lên trên (Y_Wrist < Y_Nose)
    if (wrist.y < nose.y) {
      
      // 3. Validation: Độ thẳng của tay (Shoulder - Elbow - Wrist)
      final armAngle = calculateAngle(firstPoint: shoulder, midPoint: elbow, lastPoint: wrist);
      if (armAngle >= 150 && armAngle <= 180) {
        
        // Validation: Hông đẩy về trước, Vai ngả ra sau
        // direction = 1 (mặt quay phải): hip.x > ankle.x -> (hip.x - ankle.x) * 1 > 0
        // direction = -1 (mặt quay trái): hip.x < ankle.x -> (hip.x - ankle.x) * -1 > 0
        bool hipForward = (hip.x - ankle.x) * direction > 0;
        bool shoulderBack = (shoulder.x - ankle.x) * direction < 0;
        
        if (hipForward && shoulderBack) {
          
          // 4. Bắt lỗi riêng (Metric P2) - Bẻ gập thắt lưng
          double bodyHeight = calculateDistance(nose, ankle);
          if (bodyHeight == 0) bodyHeight = 1;
          
          if (_hipXT1 != null && _shoulderXT1 != null) {
            double deltaHip = (hip.x - _hipXT1!).abs();
            double deltaShoulder = (shoulder.x - _shoulderXT1!).abs();
            
            if (deltaShoulder > 0.15 * bodyHeight && deltaHip < 0.05 * bodyHeight) {
              resultIssues.addInstruction(currentPhaseKey, 'Pose', "Đẩy hông về trước, siết bụng lại! Không bẻ gãy thắt lưng!");
              _resetState();
              return;
            }
          }
          
          // 5. Đo lường biên độ (Extension Angle)
          if (khsAngle >= 136 && khsAngle <= 170) {
            isVerified = true; // Form chuẩn
          } else if (khsAngle < 130) {
            resultIssues.addInstruction(currentPhaseKey, 'Pose', "Ngả quá sâu, có thể gây chấn thương thắt lưng!");
            _resetState();
            return;
          } else if (khsAngle > 170) {
             resultIssues.addInstruction(currentPhaseKey, 'Pose', "Tiếp tục ngả vai ra sau và đẩy hông về trước.");
             _resetState();
             return;
          }
        } else {
           if (!hipForward) {
             resultIssues.addInstruction(currentPhaseKey, 'Pose', "Đẩy hông về phía trước.");
           } else {
             resultIssues.addInstruction(currentPhaseKey, 'Pose', "Ngả vai ra sau.");
           }
           _resetState();
           return;
        }
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
