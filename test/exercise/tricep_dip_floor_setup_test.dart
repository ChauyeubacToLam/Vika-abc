import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/tricep_dip/tricep_dip.dart';

PoseLandmark _landmark(PoseLandmarkType type, double x, double y) {
  return PoseLandmark(
    type: type,
    x: x,
    y: y,
    z: 0,
    likelihood: 0.99,
  );
}

Map<PoseLandmarkType, PoseLandmark> _dipPose({required double hipY}) {
  return {
    PoseLandmarkType.leftEar: _landmark(PoseLandmarkType.leftEar, 180, 160),
    PoseLandmarkType.leftShoulder:
        _landmark(PoseLandmarkType.leftShoulder, 200, 200),
    PoseLandmarkType.leftElbow: _landmark(PoseLandmarkType.leftElbow, 250, 300),
    PoseLandmarkType.leftWrist: _landmark(PoseLandmarkType.leftWrist, 300, 400),
    PoseLandmarkType.leftHip: _landmark(PoseLandmarkType.leftHip, 400, hipY),
    PoseLandmarkType.leftAnkle: _landmark(PoseLandmarkType.leftAnkle, 600, 400),
  };
}

void _pump(TricepDip exercise, double hipY, int timestampMs) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(_dipPose(hipY: hipY));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts seated on the floor and counts when the hip is lifted', () {
    final exercise = TricepDip(maxRep: 10)
      ..cameraFacing = CameraFacing.left
      ..exerciseState = ExerciseState.activated;

    expect(exercise.isInStartPosition(_dipPose(hipY: 350)), isTrue);

    _pump(exercise, 280, 100);
    _pump(exercise, 280, 200);
    _pump(exercise, 280, 300);
    _pump(exercise, 280, 400);

    expect(exercise.repCount, 1);
    expect(exercise.tricepState, TricepDipState.bottom);

    _pump(exercise, 280, 500);
    _pump(exercise, 280, 600);
    expect(exercise.repCount, 1, reason: 'a held lift must not repeat-count');
  });

  test('requires a return to the seated setup before another lift', () {
    final exercise = TricepDip(maxRep: 10)
      ..cameraFacing = CameraFacing.left
      ..exerciseState = ExerciseState.activated;
    expect(exercise.isInStartPosition(_dipPose(hipY: 350)), isTrue);

    for (var i = 0; i < 4; i++) {
      _pump(exercise, 280, 100 + i * 100);
    }
    for (var i = 0; i < 4; i++) {
      _pump(exercise, 350, 500 + i * 100);
    }
    for (var i = 0; i < 4; i++) {
      _pump(exercise, 280, 900 + i * 100);
    }

    expect(exercise.repCount, 2);
  });
}
