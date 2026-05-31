import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../exercise_base.dart';

enum HastapaadasanaState { setup, holding }

class Hastapaadasana extends ExerciseBase {
  HastapaadasanaState state = HastapaadasanaState.setup;

  double _holdStartTimeMs = 0.0;
  double _currentHoldTime = 0.0;
  static const double targetHoldTime = 15.0;

  double? _previousWristY;

  @override
  String get exerciseName => 'Hastapaadasana';

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.portrait,
      };

  @override
  bool requestStop() {
    return _currentHoldTime >= targetHoldTime;
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return "Vui lòng xoay người hoàn toàn sang ngang để máy quét được tư thế.";
    }

    // Không bắt buộc Wrist vì có fallback dùng Elbow
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
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightElbow,
    ];

    for (final type in req) {
      if (landmarks[type] == null ||
          !ExerciseBase.isLandmarkConfident(landmarks[type]!)) {
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
    final isLeft =
        cameraFacing == CameraFacing.left || cameraFacing == CameraFacing.front;

    // Select landmarks
    final shoulder = isLeft
        ? smoothedLandmarks[PoseLandmarkType.leftShoulder]!
        : smoothedLandmarks[PoseLandmarkType.rightShoulder]!;
    final hip = isLeft
        ? smoothedLandmarks[PoseLandmarkType.leftHip]!
        : smoothedLandmarks[PoseLandmarkType.rightHip]!;
    final knee = isLeft
        ? smoothedLandmarks[PoseLandmarkType.leftKnee]!
        : smoothedLandmarks[PoseLandmarkType.rightKnee]!;
    final ankle = isLeft
        ? smoothedLandmarks[PoseLandmarkType.leftAnkle]!
        : smoothedLandmarks[PoseLandmarkType.rightAnkle]!;
    final nose = smoothedLandmarks[PoseLandmarkType.nose]!;

    // Backup logic for missing wrist
    PoseLandmark? wrist = isLeft
        ? smoothedLandmarks[PoseLandmarkType.leftWrist]
        : smoothedLandmarks[PoseLandmarkType.rightWrist];
    final elbow = isLeft
        ? smoothedLandmarks[PoseLandmarkType.leftElbow]!
        : smoothedLandmarks[PoseLandmarkType.rightElbow]!;

    bool isWristConfident =
        wrist != null && ExerciseBase.isLandmarkConfident(wrist);
    double currentWristY = isWristConfident ? wrist.y : elbow.y;

    bool isVerified = false;

    // 2. Trigger (Bắt đầu chuyển động gập)
    if (_previousWristY != null && currentWristY > _previousWristY!) {
      // Đang di chuyển xuống (Y tăng lên)
    }
    _previousWristY = currentWristY;

    double bodyHeight = calculateDistance(nose, ankle);
    if (bodyHeight == 0) bodyHeight = 1;

    // 3. Validation (Xác nhận form gập người)
    // Vị trí đầu: Đầu phải thấp hơn hông (Y_Nose > Y_Hip)
    bool headLowerThanHip = nose.y > hip.y;

    // Góc gập hông: S-H-K <= 65 độ
    final shkAngle =
        calculateAngle(firstPoint: shoulder, midPoint: hip, lastPoint: knee);
    bool hipFlexed = shkAngle <= 65;

    // Vị trí tay
    bool armsValid = false;
    if (isWristConfident) {
      double wristAnkleDistY = (wrist.y - ankle.y).abs();
      if (wristAnkleDistY < 0.15 * bodyHeight) {
        armsValid = true;
      }
    } else {
      // Mẹo xử lý nhiễu: Nếu mất dấu Cổ tay, dùng Khuỷu tay sát Gối
      double elbowKneeDistY = (elbow.y - knee.y).abs();
      if (elbowKneeDistY < 0.15 * bodyHeight) {
        armsValid = true;
      }
    }

    if (headLowerThanHip && hipFlexed && armsValid) {
      isVerified = true;
    } else {
      if (!headLowerThanHip) {
        resultIssues.addInstruction(currentPhaseKey, 'Pose',
            "Gập sâu người xuống, để đầu thấp hơn hông.");
      } else if (!hipFlexed) {
        resultIssues.addInstruction(
            currentPhaseKey, 'Pose', "Gập hông sâu hơn nữa.");
      } else if (!armsValid) {
        resultIssues.addInstruction(
            currentPhaseKey, 'Pose', "Với tay chạm sát vào mũi chân/cổ chân.");
      }
      _resetState();
      return;
    }

    // 4. Bắt lỗi riêng (Metric P3) - Độ căng khoeo chân
    final hkaAngle =
        calculateAngle(firstPoint: hip, midPoint: knee, lastPoint: ankle);
    String warningMsg = "";
    if (hkaAngle < 140) {
      warningMsg =
          "Cố gắng đẩy đỉnh mông lên cao, duỗi thẳng chân hơn một chút để kéo giãn cơ khoeo nhé";
      resultIssues.addInstruction(currentPhaseKey, 'Pose', warningMsg);
    }

    // 5. Log AI & Chuyển trạng thái
    if (isVerified) {
      if (state == HastapaadasanaState.setup) {
        state = HastapaadasanaState.holding;
        _holdStartTimeMs = frameTimestampMs.toDouble();
        resultIssues.addInstruction(
            currentPhaseKey, 'Status', "Form chuẩn. Giữ tĩnh...");
      } else if (state == HastapaadasanaState.holding) {
        _currentHoldTime = (frameTimestampMs - _holdStartTimeMs) / 1000.0;
        resultIssues.addInstruction(currentPhaseKey, 'Status',
            "Giữ tĩnh: ${_currentHoldTime.toStringAsFixed(1)}s / ${targetHoldTime}s");

        if (_currentHoldTime >= targetHoldTime) {
          repCount += 1;
          _currentHoldTime = 0;
          state = HastapaadasanaState.setup;
          resultIssues.addInstruction(
              currentPhaseKey, 'Status', "Hoàn thành Hastapaadasana");
        }
      }
    }

    debugData['currentHoldTime'] = _currentHoldTime;
    debugData['holdProgress'] =
        (_currentHoldTime / targetHoldTime).clamp(0.0, 1.0);
  }

  void _resetState() {
    state = HastapaadasanaState.setup;
    _currentHoldTime = 0;
  }

  @override
  String get currentPhaseKey => state.name;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case HastapaadasanaState.setup:
        return 'Chuẩn bị';
      case HastapaadasanaState.holding:
        return 'Giữ tĩnh';
    }
  }

  @override
  void onSetComplete() {}
}
