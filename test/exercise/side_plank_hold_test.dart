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
  return <PoseLandmarkType, PoseLandmark>{
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

SidePlankDip _activeSidePlank({int holdSeconds = 1}) {
  final exercise = SidePlankDip(maxHolds: 1, holdSeconds: holdSeconds)
    ..cameraFacing = CameraFacing.left
    ..exerciseState = ExerciseState.activated;
  final pose = _sidePlankPose();
  expect(exercise.isInStartPosition(pose), isTrue);
  exercise.onExerciseActivated();
  return exercise;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('full static hold logs one engine rep', () {
    final exercise = _activeSidePlank();
    final pose = _sidePlankPose();

    var timestampMs = 0;
    while (exercise.repCount == 0 && timestampMs < 4000) {
      _pump(exercise, pose, timestampMs);
      timestampMs += 250;
    }

    expect(exercise.phase, HoldPhase.resting);
    expect(exercise.repCount, 1);
    expect(exercise.requestStop(), isTrue);
    expect(exercise.logger.repLogs.single.data['hold_time'], 1.0);
  });

  test('strict reused gate emits amplitude and preserves report keys', () {
    final exercise = _activeSidePlank();
    final good = _sidePlankPose();
    final dropped = _sidePlankPose(hipY: 410);

    _pump(exercise, good, 0);
    _pump(exercise, good, 250);
    _pump(exercise, dropped, 500);

    expect(exercise.phase, HoldPhase.dropping);
    expect(
      exercise.liveFaults.map((fault) => fault.type),
      contains('amplitude'),
    );

    var timestampMs = 750;
    while (exercise.repCount == 0 && timestampMs < 5000) {
      _pump(exercise, good, timestampMs);
      timestampMs += 250;
    }

    final repData = exercise.logger.repLogs.single.data;
    expect(repData['hold_time'], 1.0);
    expect(repData['fault_types'], contains('amplitude'));

    exercise.onSetComplete();
    final setLogs = exercise.logger.setLogs;
    expect(setLogs['shoulder_align_fails_count'], 0);
    expect(setLogs['rotation_fails_count'], 0);
    expect(setLogs['dip_depth_fails_count'], 1);
    expect(setLogs['total_seconds'], 1.0);
    expect(setLogs['good_seconds'], isA<num>());
    expect(setLogs['shoulder_seconds'], isA<num>());
    expect(setLogs['rotation_seconds'], isA<num>());
    expect(setLogs['body_line_seconds'], isA<num>());
    expect(setLogs['max_rep'], 1);
    expect(setLogs['good_rep_count'], 0);
  });
}
