import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../exercise_base.dart';

enum AshwaSanchalanasanaState { setup, holding }

class AshwaSanchalanasana extends ExerciseBase {
  AshwaSanchalanasanaState state = AshwaSanchalanasanaState.setup;

  double _holdStartTimeMs = 0.0;
  double _currentHoldTime = 0.0;
  static const double targetHoldTime = 15.0;

  PoseLandmark? _previousFrontKnee;
  PoseLandmark? _previousHip;
  PoseLandmark? _previousAnkle;

  @override
  String get exerciseName => 'Ashwa Sanchalanasana';

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

    final req = [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftEar,
      PoseLandmarkType.rightEar,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.leftFootIndex,
      PoseLandmarkType.rightFootIndex,
    ];

    for (final type in req) {
      if (landmarks[type] == null ||
          !ExerciseBase.isLandmarkConfident(landmarks[type]!)) {
        // We will do custom confidence checks for the knee during execution due to occlusion
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

    // In Ashwa Sanchalanasana, one leg steps back. The front leg has the knee bent ~90 deg.
    // The back leg is almost straight >130 deg.
    // Which leg is front? The one with X coordinate closer to the chest/nose?
    // Or we can just calculate both knees and see which one has X closer to Nose X.
    final leftAnkle = smoothedLandmarks[PoseLandmarkType.leftAnkle]!;
    final rightAnkle = smoothedLandmarks[PoseLandmarkType.rightAnkle]!;

    final nose = smoothedLandmarks[PoseLandmarkType.nose]!;
    final ear = isLeft
        ? smoothedLandmarks[PoseLandmarkType.leftEar]!
        : smoothedLandmarks[PoseLandmarkType.rightEar]!;

    bool isFacingRight = nose.x > ear.x;

    // Front leg is the one further forward in the facing direction
    bool leftIsFront =
        isFacingRight ? leftAnkle.x > rightAnkle.x : leftAnkle.x < rightAnkle.x;

    final frontHip = leftIsFront
        ? smoothedLandmarks[PoseLandmarkType.leftHip]!
        : smoothedLandmarks[PoseLandmarkType.rightHip]!;
    final backHip = leftIsFront
        ? smoothedLandmarks[PoseLandmarkType.rightHip]!
        : smoothedLandmarks[PoseLandmarkType.leftHip]!;

    PoseLandmark frontKneeRaw = leftIsFront
        ? smoothedLandmarks[PoseLandmarkType.leftKnee]!
        : smoothedLandmarks[PoseLandmarkType.rightKnee]!;
    final backKnee = leftIsFront
        ? smoothedLandmarks[PoseLandmarkType.rightKnee]!
        : smoothedLandmarks[PoseLandmarkType.leftKnee]!;

    final frontAnkle = leftIsFront
        ? smoothedLandmarks[PoseLandmarkType.leftAnkle]!
        : smoothedLandmarks[PoseLandmarkType.rightAnkle]!;
    final backAnkle = leftIsFront
        ? smoothedLandmarks[PoseLandmarkType.rightAnkle]!
        : smoothedLandmarks[PoseLandmarkType.leftAnkle]!;

    final frontFootIndex = leftIsFront
        ? smoothedLandmarks[PoseLandmarkType.leftFootIndex]!
        : smoothedLandmarks[PoseLandmarkType.rightFootIndex]!;

    final shoulder = isLeft
        ? smoothedLandmarks[PoseLandmarkType.leftShoulder]!
        : smoothedLandmarks[PoseLandmarkType.rightShoulder]!;

    // 6. Noise Processing (Interpolation)
    // If the arms occlude the front knee, its position might jump or become inaccurate.
    PoseLandmark frontKnee = frontKneeRaw;
    if (_previousFrontKnee != null &&
        _previousHip != null &&
        _previousAnkle != null) {
      double hipMovement = calculateDistance(frontHip, _previousHip!);
      double ankleMovement = calculateDistance(frontAnkle, _previousAnkle!);
      double kneeMovement =
          calculateDistance(frontKneeRaw, _previousFrontKnee!);

      // If hip and ankle are relatively still but knee moves a lot, lock it.
      // We assume body size roughly from shoulder to hip
      double bodyScale = calculateDistance(shoulder, frontHip);
      if (bodyScale == 0) bodyScale = 1;

      if (hipMovement < 0.1 * bodyScale &&
          ankleMovement < 0.1 * bodyScale &&
          kneeMovement > 0.15 * bodyScale) {
        frontKnee = _previousFrontKnee!; // Lock knee
      } else {
        _previousFrontKnee = frontKneeRaw;
      }
    } else {
      _previousFrontKnee = frontKneeRaw;
    }

    _previousHip = frontHip;
    _previousAnkle = frontAnkle;

    // 2. Trigger (Start step)
    double deltaX = (leftAnkle.x - rightAnkle.x).abs();
    double bodyHeight = calculateDistance(nose, frontAnkle);
    if (bodyHeight == 0) bodyHeight = 1;

    bool isStepped = deltaX > 0.3 * bodyHeight; // Threshold for stepping
    bool isBackKneeLowering = backKnee.y > backHip.y; // Y increases downwards

    if (!isStepped || !isBackKneeLowering) {
      // Not in trigger state yet
      _resetState();
      return;
    }

    // 3. Validation (Confirm form)
    bool isVerified = false;

    // Hip lowered
    double hipToKneeY = (frontHip.y - frontKnee.y).abs();
    bool isHipLowered = hipToKneeY < 0.3 * bodyHeight;

    // Front knee angle
    double frontKneeAngle = calculateAngle(
        firstPoint: frontHip, midPoint: frontKnee, lastPoint: frontAnkle);
    bool isFrontKneeValid = frontKneeAngle >= 90 && frontKneeAngle <= 110;

    // Back knee angle
    double backKneeAngle = calculateAngle(
        firstPoint: backHip, midPoint: backKnee, lastPoint: backAnkle);
    bool isBackKneeValid = backKneeAngle > 130;

    // Chest lifted
    bool isChestLifted = shoulder.y < frontHip.y;

    // 4. Metric P4 - Shear Force
    bool isKneeOverToe = false;
    if (isFacingRight) {
      if (frontKnee.x > frontFootIndex.x) {
        isKneeOverToe = true;
      }
    } else {
      if (frontKnee.x < frontFootIndex.x) {
        isKneeOverToe = true;
      }
    }

    if (isKneeOverToe) {
      resultIssues.addInstruction(currentPhaseKey, 'Pose',
          "Bước chân sau dài ra, giữ đầu gối trước vuông góc với mắt cá!");
      _resetState();
      return; // Hard Block
    }

    if (isHipLowered && isFrontKneeValid && isBackKneeValid && isChestLifted) {
      isVerified = true;
    } else {
      if (!isChestLifted) {
        resultIssues.addInstruction(
            currentPhaseKey, 'Pose', "Vươn ngực lên, để vai cao hơn hông.");
      } else if (!isHipLowered) {
        resultIssues.addInstruction(
            currentPhaseKey, 'Pose', "Hạ thấp hông xuống một chút nữa.");
      } else if (!isFrontKneeValid) {
        resultIssues.addInstruction(currentPhaseKey, 'Pose',
            "Điều chỉnh đầu gối trước vuông góc (khoảng 90 độ).");
      } else if (!isBackKneeValid) {
        resultIssues.addInstruction(
            currentPhaseKey, 'Pose', "Duỗi thẳng chân sau ra sau hơn.");
      }
      _resetState();
      return;
    }

    if (isVerified) {
      if (state == AshwaSanchalanasanaState.setup) {
        state = AshwaSanchalanasanaState.holding;
        _holdStartTimeMs = frameTimestampMs.toDouble();
        resultIssues.addInstruction(
            currentPhaseKey, 'Status', "Form chuẩn. Giữ tĩnh...");
      } else if (state == AshwaSanchalanasanaState.holding) {
        _currentHoldTime = (frameTimestampMs - _holdStartTimeMs) / 1000.0;
        resultIssues.addInstruction(currentPhaseKey, 'Status',
            "Giữ tĩnh: ${_currentHoldTime.toStringAsFixed(1)}s / ${targetHoldTime}s");

        if (_currentHoldTime >= targetHoldTime) {
          repCount += 1;
          _currentHoldTime = 0;
          state = AshwaSanchalanasanaState.setup;
          resultIssues.addInstruction(
              currentPhaseKey, 'Status', "Hoàn thành Ashwa Sanchalanasana");
        }
      }
    }

    debugData['currentHoldTime'] = _currentHoldTime;
    debugData['holdProgress'] =
        (_currentHoldTime / targetHoldTime).clamp(0.0, 1.0);
  }

  void _resetState() {
    state = AshwaSanchalanasanaState.setup;
    _currentHoldTime = 0;
  }

  @override
  String get currentPhaseKey => state.name;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case AshwaSanchalanasanaState.setup:
        return 'Chuẩn bị';
      case AshwaSanchalanasanaState.holding:
        return 'Giữ tĩnh';
    }
  }

  @override
  void onSetComplete() {}
}
