import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/russian_twist/russian_twist.dart';

PoseLandmark _landmark(
  PoseLandmarkType type,
  double x,
  double y, {
  double z = 0,
  double likelihood = 0.99,
}) {
  return PoseLandmark(
    type: type,
    x: x,
    y: y,
    z: z,
    likelihood: likelihood,
  );
}

/// Front-view Russian Twist pose.
///
/// The upper body leans back diagonally: shoulder midpoint sits at
/// (300, 200) while the hip midpoint sits at (400, 300). That dx=100 / dy=100
/// offset yields a ~45° trunk angle (inside the 32–72° valid range). The
/// shoulder midpoint (midShoulderX = 300) is the body midline that the wrist
/// lateral offset is measured against.
Map<PoseLandmarkType, PoseLandmark> _frontPose({
  double wristX = 300,
  double wristY = 240,
}) {
  const shoulderY = 200.0;
  const hipY = 300.0;
  const kneeY = 330.0;
  const shoulderSpread = 110.0; // left/right shoulder separation
  const hipSpread = 60.0;
  const kneeSpread = 80.0;

  // Shoulders centered on x=300; hips centered on x=400 (leaned back).
  const midShoulderX = 300.0;
  const midHipX = 400.0;

  PoseLandmark mark(PoseLandmarkType type, double x, double y) =>
      _landmark(type, x, y);

  return {
    PoseLandmarkType.leftShoulder: mark(
        PoseLandmarkType.leftShoulder, midShoulderX - shoulderSpread / 2, shoulderY),
    PoseLandmarkType.rightShoulder: mark(
        PoseLandmarkType.rightShoulder, midShoulderX + shoulderSpread / 2, shoulderY),
    PoseLandmarkType.leftHip: mark(
        PoseLandmarkType.leftHip, midHipX - hipSpread / 2, hipY),
    PoseLandmarkType.rightHip: mark(
        PoseLandmarkType.rightHip, midHipX + hipSpread / 2, hipY),
    PoseLandmarkType.leftKnee: mark(
        PoseLandmarkType.leftKnee, midHipX - kneeSpread / 2, kneeY),
    PoseLandmarkType.rightKnee: mark(
        PoseLandmarkType.rightKnee, midHipX + kneeSpread / 2, kneeY),
    PoseLandmarkType.leftWrist:
        mark(PoseLandmarkType.leftWrist, wristX, wristY),
    PoseLandmarkType.rightWrist:
        mark(PoseLandmarkType.rightWrist, wristX, wristY),
  };
}

void _pump(
  RussianTwist exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

RussianTwist _activatedRussianTwist() {
  return RussianTwist(maxRep: 4)
    ..cameraFacing = CameraFacing.front
    ..exerciseState = ExerciseState.activated;
}

/// Centered setup frame. midShoulderX = 300; shoulderWidth = 110.
const double _midShoulderX = 300.0;
// GOOD_ROM_DELTA (0.28) * 110 = 30.8 -> twist to x~331 reaches full ROM.
const double _forwardTargetX = 332.0;
const double _backwardTargetX = 268.0;

void _completeForwardHalf(RussianTwist exercise, int startMs) {
  _pump(exercise, _frontPose(wristX: _midShoulderX), startMs);
  _pump(exercise, _frontPose(wristX: _midShoulderX + 20), startMs + 100);
  _pump(exercise, _frontPose(wristX: _forwardTargetX), startMs + 200);
  _pump(exercise, _frontPose(wristX: _midShoulderX + 20), startMs + 300);
  _pump(exercise, _frontPose(wristX: _midShoulderX), startMs + 400);
}

void _completeBackwardHalf(RussianTwist exercise, int startMs) {
  _pump(exercise, _frontPose(wristX: _midShoulderX - 20), startMs);
  _pump(exercise, _frontPose(wristX: _backwardTargetX), startMs + 100);
  _pump(exercise, _frontPose(wristX: _midShoulderX - 20), startMs + 200);
  _pump(exercise, _frontPose(wristX: _midShoulderX), startMs + 300);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('safety requires front camera instead of side or angled', () {
    final exercise = RussianTwist();

    exercise.cameraFacing = CameraFacing.front;
    expect(exercise.checkSafety(_frontPose()), isNull);

    exercise.cameraFacing = CameraFacing.right;
    expect(exercise.checkSafety(_frontPose()), isNotNull);

    exercise.cameraFacing = CameraFacing.angled;
    expect(exercise.checkSafety(_frontPose()), isNotNull);
  });

  test('start position requires leaned-back torso and centered hands', () {
    final exercise = RussianTwist()..cameraFacing = CameraFacing.front;

    expect(exercise.isInStartPosition(_frontPose()), isTrue);
    // Hands off-center -> not ready.
    expect(
      exercise.isInStartPosition(_frontPose(wristX: _forwardTargetX)),
      isFalse,
    );
  });

  test('counts one rep when user twists to both sides', () {
    final exercise = _activatedRussianTwist();

    _completeForwardHalf(exercise, 0);
    expect(exercise.repCount, 0);

    _completeBackwardHalf(exercise, 1000);
    expect(exercise.repCount, 1);
  });

  test('counts consecutive reps across alternating twists', () {
    final exercise = _activatedRussianTwist();

    _completeForwardHalf(exercise, 0);
    _completeBackwardHalf(exercise, 1000);
    _completeForwardHalf(exercise, 2000);
    _completeBackwardHalf(exercise, 3000);

    expect(exercise.repCount, 2);
  });

  test('does not count shallow twists that do not reach ROM', () {
    final exercise = _activatedRussianTwist();

    // Twist only slightly to each side (well below GOOD_ROM_DELTA).
    _pump(exercise, _frontPose(wristX: _midShoulderX), 0);
    _pump(exercise, _frontPose(wristX: _midShoulderX + 16), 100);
    _pump(exercise, _frontPose(wristX: _midShoulderX + 16), 200);
    _pump(exercise, _frontPose(wristX: _midShoulderX), 300);
    _pump(exercise, _frontPose(wristX: _midShoulderX - 16), 400);
    _pump(exercise, _frontPose(wristX: _midShoulderX - 16), 500);
    _pump(exercise, _frontPose(wristX: _midShoulderX), 600);

    expect(exercise.repCount, 0);
  });
}
