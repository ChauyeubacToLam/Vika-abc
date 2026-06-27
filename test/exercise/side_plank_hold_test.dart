import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/side_plank_dip/side_plank_dip.dart';

PoseLandmark _landmark(PoseLandmarkType type, double x, double y) {
  return PoseLandmark(
    type: type,
    x: x,
    y: y,
    z: 0,
    likelihood: 0.99,
  );
}

Map<PoseLandmarkType, PoseLandmark> _sidePlankPose({
  double hipY = 300,
}) {
  return {
    PoseLandmarkType.leftShoulder:
        _landmark(PoseLandmarkType.leftShoulder, 200, 300),
    PoseLandmarkType.rightShoulder:
        _landmark(PoseLandmarkType.rightShoulder, 210, 295),
    PoseLandmarkType.leftElbow: _landmark(PoseLandmarkType.leftElbow, 200, 400),
    PoseLandmarkType.rightElbow:
        _landmark(PoseLandmarkType.rightElbow, 210, 300),
    PoseLandmarkType.leftHip: _landmark(PoseLandmarkType.leftHip, 400, hipY),
    PoseLandmarkType.rightHip:
        _landmark(PoseLandmarkType.rightHip, 410, hipY - 5),
    PoseLandmarkType.leftAnkle: _landmark(PoseLandmarkType.leftAnkle, 600, 300),
    PoseLandmarkType.rightAnkle:
        _landmark(PoseLandmarkType.rightAnkle, 610, 295),
  };
}

void _pump(
  SidePlankDip exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses a hold timer and completes one static hold', () {
    final exercise = SidePlankDip(maxSeconds: 2)
      ..cameraFacing = CameraFacing.left
      ..exerciseState = ExerciseState.activated;
    final pose = _sidePlankPose();

    expect(exercise.isInStartPosition(pose), isTrue);
    exercise.onExerciseActivated();
    for (var timestamp = 0; timestamp <= 2000; timestamp += 250) {
      _pump(exercise, pose, timestamp);
    }

    expect(exercise.liveHoldSeconds, 2.0);
    expect(exercise.requestStop(), isTrue);
    expect(exercise.repCount, 0);

    exercise.onSetComplete();
    expect(exercise.repCount, 1);
    expect(exercise.logger.repLogs.single.data['hold_time'], 2.0);
  });

  test('does not advance the timer while the hip drops', () {
    final exercise = SidePlankDip(maxSeconds: 2)
      ..cameraFacing = CameraFacing.left
      ..exerciseState = ExerciseState.activated;
    final good = _sidePlankPose();
    final dropped = _sidePlankPose(hipY: 410);

    expect(exercise.isInStartPosition(good), isTrue);
    exercise.onExerciseActivated();
    _pump(exercise, good, 0);
    _pump(exercise, good, 250);
    final beforeDrop = exercise.liveHoldSeconds;
    _pump(exercise, dropped, 500);
    _pump(exercise, dropped, 750);

    expect(exercise.liveHoldSeconds, beforeDrop);
    expect(exercise.repCount, 0);
    expect(exercise.resultIssues.feedback['Amplitude'], isNotNull);
  });
}
