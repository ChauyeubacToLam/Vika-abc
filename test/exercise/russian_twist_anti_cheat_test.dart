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

Map<PoseLandmarkType, PoseLandmark> _russianPose({
  double shoulderX = 245,
  double shoulderY = 220,
  double hipX = 300,
  double hipY = 300,
  double kneeX = 420,
  double kneeY = 320,
  double wristX = 350,
  double wristY = 245,
}) {
  PoseLandmark mark(PoseLandmarkType type, double x, double y) =>
      _landmark(type, x, y);

  return {
    PoseLandmarkType.leftShoulder:
        mark(PoseLandmarkType.leftShoulder, shoulderX, shoulderY),
    PoseLandmarkType.rightShoulder:
        mark(PoseLandmarkType.rightShoulder, shoulderX, shoulderY),
    PoseLandmarkType.leftHip: mark(PoseLandmarkType.leftHip, hipX, hipY),
    PoseLandmarkType.rightHip: mark(PoseLandmarkType.rightHip, hipX, hipY),
    PoseLandmarkType.leftKnee: mark(PoseLandmarkType.leftKnee, kneeX, kneeY),
    PoseLandmarkType.rightKnee: mark(PoseLandmarkType.rightKnee, kneeX, kneeY),
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
    ..cameraFacing = CameraFacing.right
    ..exerciseState = ExerciseState.activated;
}

void _completeForwardHalf(RussianTwist exercise, int startMs) {
  _pump(exercise, _russianPose(), startMs);
  _pump(exercise, _russianPose(), startMs + 100);
  _pump(
    exercise,
    _russianPose(shoulderX: 255, wristX: 365),
    startMs + 200,
  );
  _pump(
    exercise,
    _russianPose(shoulderX: 265, wristX: 385),
    startMs + 300,
  );
  _pump(
    exercise,
    _russianPose(shoulderX: 255, wristX: 370),
    startMs + 400,
  );
  _pump(exercise, _russianPose(), startMs + 500);
}

void _completeBackwardHalf(RussianTwist exercise, int startMs) {
  _pump(
    exercise,
    _russianPose(shoulderX: 235, wristX: 330),
    startMs,
  );
  _pump(
    exercise,
    _russianPose(shoulderX: 225, wristX: 315),
    startMs + 100,
  );
  _pump(
    exercise,
    _russianPose(shoulderX: 235, wristX: 330),
    startMs + 200,
  );
  _pump(exercise, _russianPose(), startMs + 300);
}

void _completeArmOnlyForwardHalf(RussianTwist exercise, int startMs) {
  _pump(exercise, _russianPose(), startMs);
  _pump(exercise, _russianPose(), startMs + 100);
  _pump(exercise, _russianPose(wristX: 365), startMs + 200);
  _pump(exercise, _russianPose(wristX: 385), startMs + 300);
  _pump(exercise, _russianPose(wristX: 370), startMs + 400);
  _pump(exercise, _russianPose(), startMs + 500);
}

void _completeArmOnlyBackwardHalf(RussianTwist exercise, int startMs) {
  _pump(exercise, _russianPose(wristX: 330), startMs);
  _pump(exercise, _russianPose(wristX: 315), startMs + 100);
  _pump(exercise, _russianPose(wristX: 330), startMs + 200);
  _pump(exercise, _russianPose(), startMs + 300);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('safety requires side camera instead of front or angled', () {
    final exercise = RussianTwist(maxRep: 20);

    exercise.cameraFacing = CameraFacing.front;
    expect(exercise.checkSafety(_russianPose()), isNotNull);

    exercise.cameraFacing = CameraFacing.right;
    expect(exercise.checkSafety(_russianPose()), isNull);

    exercise.cameraFacing = CameraFacing.angled;
    expect(exercise.checkSafety(_russianPose()), isNotNull);
  });

  test('start position requires lean-back torso and centered hands', () {
    final exercise = RussianTwist(maxRep: 20)..cameraFacing = CameraFacing.right;

    expect(exercise.isInStartPosition(_russianPose()), isTrue);
    expect(
      exercise.isInStartPosition(_russianPose(shoulderX: 300, shoulderY: 200)),
      isFalse,
    );
    expect(exercise.isInStartPosition(_russianPose(wristX: 385)), isFalse);
  });

  test('counts one rep when user twists to both sides with torso rotation', () {
    final exercise = _activatedRussianTwist();

    _completeForwardHalf(exercise, 0);
    expect(exercise.repCount, 0);

    _completeBackwardHalf(exercise, 1000);
    expect(exercise.repCount, 1);
    expect(exercise.logger.repLogs.single.correctForm, isTrue);
  });

  test('does not count arm-only swings without shoulder rotation', () {
    final exercise = _activatedRussianTwist();

    _completeArmOnlyForwardHalf(exercise, 0);
    _completeArmOnlyBackwardHalf(exercise, 1000);

    expect(exercise.repCount, 0);
    expect(exercise.logger.repLogs, isEmpty);
  });

  test('does not count twists performed with an upright torso', () {
    final exercise = _activatedRussianTwist();

    _completeArmOnlyForwardHalf(exercise, 0);
    _pump(
      exercise,
      _russianPose(shoulderX: 300, shoulderY: 200, wristX: 330),
      1000,
    );
    _pump(
      exercise,
      _russianPose(shoulderX: 300, shoulderY: 200, wristX: 315),
      1100,
    );
    _pump(
      exercise,
      _russianPose(shoulderX: 300, shoulderY: 200, wristX: 330),
      1200,
    );
    _pump(
      exercise,
      _russianPose(shoulderX: 300, shoulderY: 200),
      1300,
    );

    expect(exercise.repCount, 0);
    expect(exercise.logger.repLogs, isEmpty);
  });
}
