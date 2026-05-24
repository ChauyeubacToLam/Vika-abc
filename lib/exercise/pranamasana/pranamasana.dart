import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/pose_math_helpers.dart';
import '../exercise_base.dart';

enum PranamasanaState { setup, holding }

class Pranamasana extends ExerciseBase {
  PranamasanaState state = PranamasanaState.setup;

  double _holdStartTimeMs = 0.0;
  double _currentHoldTime = 0.0;
  static const double targetHoldTime = 5.0; // 5 seconds

  @override
  String get exerciseName => 'Pranamasana';

  @override
  Set<VikaImageOrientation> get supportedOrientations => const <VikaImageOrientation>{
        VikaImageOrientation.portrait,
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  bool requestStop() {
    return _currentHoldTime >= targetHoldTime;
  }

  @override
  String? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    // Require upper body to knees
    final req = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
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
    return true; // Simple trigger, we rely on checkingPose for the actual start
  }

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    resultIssues.instructions.clear();
    bool isVerified = _verifyPose(smoothedLandmarks);

    if (isVerified) {
      if (state == PranamasanaState.setup) {
        state = PranamasanaState.holding;
        _holdStartTimeMs = frameTimestampMs.toDouble();
        resultIssues.addInstruction(currentPhaseKey, 'Status', "Form chuẩn. Giữ tĩnh...");
      } else if (state == PranamasanaState.holding) {
        _currentHoldTime = (frameTimestampMs - _holdStartTimeMs) / 1000.0;
        resultIssues.addInstruction(currentPhaseKey, 'Status', "Giữ tĩnh: ${_currentHoldTime.toStringAsFixed(1)}s / ${targetHoldTime}s");

        if (_currentHoldTime >= targetHoldTime) {
          // Rep completed
          repCount += 1;
          _currentHoldTime = 0; // reset for next rep or stop
          state = PranamasanaState.setup;
        }
      }
    } else {
      // If broken, reset timer
      state = PranamasanaState.setup;
      _currentHoldTime = 0;
      resultIssues.addInstruction(currentPhaseKey, 'Pose', "Chưa đúng tư thế. Hãy đứng thẳng và chắp tay trước ngực.");
    }
    
    debugData['currentHoldTime'] = _currentHoldTime;
  }

  bool _verifyPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final ls = landmarks[PoseLandmarkType.leftShoulder];
    final rs = landmarks[PoseLandmarkType.rightShoulder];
    final lh = landmarks[PoseLandmarkType.leftHip];
    final rh = landmarks[PoseLandmarkType.rightHip];
    final la = landmarks[PoseLandmarkType.leftAnkle] ?? landmarks[PoseLandmarkType.leftKnee];
    final ra = landmarks[PoseLandmarkType.rightAnkle] ?? landmarks[PoseLandmarkType.rightKnee];
    
    final lw = landmarks[PoseLandmarkType.leftWrist];
    final rw = landmarks[PoseLandmarkType.rightWrist];

    if (ls == null || rs == null || lh == null || rh == null || la == null || ra == null) {
      return false;
    }

    // Validation 1: Body Axis 170-180
    // Use the side that is more visible or just average
    final isLeft = cameraFacing == CameraFacing.left || cameraFacing == CameraFacing.front;
    final shoulder = isLeft ? ls : rs;
    final hip = isLeft ? lh : rh;
    final ankle = isLeft ? la : ra;

    final bodyAngle = calculateAngleNormalized(firstPoint: shoulder, midPoint: hip, lastPoint: ankle);
    if (bodyAngle < 165 || bodyAngle > 180) { // Slight tolerance for 165
      return false;
    }

    // Validation 3: Hands folded in front of chest
    if (lw == null && rw == null) return false;

    final shoulderY = (ls.y + rs.y) / 2;
    final hipY = (lh.y + rh.y) / 2;
    final chestX = (ls.x + rs.x) / 2;
    
    // Scale threshold based on shoulder width
    final shoulderWidth = (ls.x - rs.x).abs();
    final wristThreshold = shoulderWidth * 0.5; // very close

    bool handsValid = false;

    final lwConf = lw != null && ExerciseBase.isLandmarkConfident(lw);
    final rwConf = rw != null && ExerciseBase.isLandmarkConfident(rw);

    if (lwConf && rwConf) {
      // Both wrists detected
      final wristDist = calculateDistance(lw, rw);
      final avgWristY = (lw.y + rw.y) / 2;
      
      if (wristDist < wristThreshold && avgWristY > shoulderY && avgWristY < hipY) {
        handsValid = true;
      }
    } else if (lwConf || rwConf) {
      // Occlusion: 1 wrist detected
      final w = lwConf ? lw : rw!;
      
      // Check if it's in the middle of the chest
      final distToChestMidX = (w.x - chestX).abs();
      if (distToChestMidX < wristThreshold && w.y > shoulderY && w.y < hipY) {
        handsValid = true;
      }
    }

    if (!handsValid) return false;

    // Validation 2: Static state (v approx 0)
    // Implicitly handled by the 5s hold timer resetting if pose is broken.
    // We could add frameBuffer tracking, but keeping the pose validates it.

    return true;
  }

  @override
  String get currentPhaseKey => state.name;

  @override
  String get currentPhaseLabel {
    switch (state) {
      case PranamasanaState.setup: return 'Chuẩn bị';
      case PranamasanaState.holding: return 'Giữ tĩnh';
    }
  }

  @override
  void onSetComplete() {
    // End of exercise
  }
}
