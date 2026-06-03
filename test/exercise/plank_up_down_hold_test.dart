import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/13.Plank Up-Down/metrics/plank_up_down_metric_base.dart';
import 'package:vika/exercise/13.Plank Up-Down/plank_up_down.dart';
import 'package:vika/exercise/exercise_base.dart';

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

Map<PoseLandmarkType, PoseLandmark> _plankPose({
  required double elbowX,
  required double elbowY,
  required double wristX,
  required double wristY,
}) {
  const shoulderX = 400.0;
  const hipX = 300.0;
  const kneeX = 200.0;
  const ankleX = 100.0;
  const bodyY = 220.0;

  PoseLandmark mark(PoseLandmarkType type, double x, double y) =>
      _landmark(type, x, y);

  return {
    PoseLandmarkType.leftShoulder:
        mark(PoseLandmarkType.leftShoulder, shoulderX, bodyY),
    PoseLandmarkType.leftElbow:
        mark(PoseLandmarkType.leftElbow, elbowX, elbowY),
    PoseLandmarkType.leftWrist:
        mark(PoseLandmarkType.leftWrist, wristX, wristY),
    PoseLandmarkType.leftHip: mark(PoseLandmarkType.leftHip, hipX, bodyY),
    PoseLandmarkType.leftKnee: mark(PoseLandmarkType.leftKnee, kneeX, bodyY),
    PoseLandmarkType.leftAnkle: mark(PoseLandmarkType.leftAnkle, ankleX, bodyY),
    PoseLandmarkType.rightShoulder:
        mark(PoseLandmarkType.rightShoulder, shoulderX, bodyY),
    PoseLandmarkType.rightElbow:
        mark(PoseLandmarkType.rightElbow, elbowX, elbowY),
    PoseLandmarkType.rightWrist:
        mark(PoseLandmarkType.rightWrist, wristX, wristY),
    PoseLandmarkType.rightHip: mark(PoseLandmarkType.rightHip, hipX, bodyY),
    PoseLandmarkType.rightKnee: mark(PoseLandmarkType.rightKnee, kneeX, bodyY),
    PoseLandmarkType.rightAnkle:
        mark(PoseLandmarkType.rightAnkle, ankleX, bodyY),
  };
}

Map<PoseLandmarkType, PoseLandmark> _forearmPose() => _plankPose(
      elbowX: 400,
      elbowY: 320,
      wristX: 320,
      wristY: 320,
    );

Map<PoseLandmarkType, PoseLandmark> _pushingPose() => _plankPose(
      elbowX: 400,
      elbowY: 290,
      wristX: 360,
      wristY: 340,
    );

Map<PoseLandmarkType, PoseLandmark> _highPose() => _plankPose(
      elbowX: 400,
      elbowY: 280,
      wristX: 400,
      wristY: 340,
    );

void _pump(
  PlankUpDown exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('requires 3 second holds at high and forearm plank before counting rep',
      () {
    final exercise = PlankUpDown()
      ..cameraFacing = CameraFacing.left
      ..exerciseState = ExerciseState.activated;

    expect(exercise.isInStartPosition(_forearmPose()), isTrue);

    _pump(exercise, _forearmPose(), 0);
    expect(exercise.debugData['holdRemaining'], closeTo(3.0, 0.01));

    _pump(exercise, _forearmPose(), 3000);
    expect(exercise.plankState, PlankState.forearm_plank);
    expect(exercise.debugData.containsKey('holdRemaining'), isFalse);

    _pump(exercise, _pushingPose(), 3100);
    _pump(exercise, _pushingPose(), 3200);
    expect(exercise.plankState, PlankState.pushing_up);

    _pump(exercise, _highPose(), 3300);
    _pump(exercise, _highPose(), 3400);
    expect(exercise.plankState, PlankState.high_plank);

    _pump(exercise, _pushingPose(), 3500);
    _pump(exercise, _pushingPose(), 3600);
    expect(exercise.plankState, PlankState.high_plank);
    expect(exercise.repCount, 0);
    expect(exercise.debugData['holdRemaining'], closeTo(3.0, 0.01));

    _pump(exercise, _highPose(), 3700);
    _pump(exercise, _highPose(), 6700);
    expect(exercise.debugData.containsKey('holdRemaining'), isFalse);

    _pump(exercise, _pushingPose(), 6800);
    _pump(exercise, _pushingPose(), 6900);
    expect(exercise.plankState, PlankState.lowering);

    _pump(exercise, _forearmPose(), 7000);
    _pump(exercise, _forearmPose(), 7100);
    expect(exercise.plankState, PlankState.forearm_plank);
    expect(exercise.repCount, 0);

    _pump(exercise, _forearmPose(), 10000);
    expect(exercise.repCount, 0);

    _pump(exercise, _forearmPose(), 10100);
    expect(exercise.repCount, 1);
  });
}
