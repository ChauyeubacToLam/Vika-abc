import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/wall_push_up/wall_push_up.dart';

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

Map<PoseLandmarkType, PoseLandmark> _wallPose({
  required double shoulderX,
  required double shoulderY,
  required double hipX,
  required double hipY,
  required double elbowX,
  required double elbowY,
  double wristX = 420,
  double wristY = 200,
  double footX = 150,
  double footY = 500,
}) {
  return {
    PoseLandmarkType.rightShoulder: _landmark(
      PoseLandmarkType.rightShoulder,
      shoulderX,
      shoulderY,
    ),
    PoseLandmarkType.rightElbow: _landmark(
      PoseLandmarkType.rightElbow,
      elbowX,
      elbowY,
    ),
    PoseLandmarkType.rightWrist: _landmark(
      PoseLandmarkType.rightWrist,
      wristX,
      wristY,
    ),
    PoseLandmarkType.rightHip: _landmark(
      PoseLandmarkType.rightHip,
      hipX,
      hipY,
    ),
    PoseLandmarkType.rightAnkle: _landmark(
      PoseLandmarkType.rightAnkle,
      footX,
      footY,
    ),
    PoseLandmarkType.rightHeel: _landmark(
      PoseLandmarkType.rightHeel,
      footX,
      footY,
    ),
    PoseLandmarkType.rightFootIndex: _landmark(
      PoseLandmarkType.rightFootIndex,
      footX,
      footY,
    ),
  };
}

Map<PoseLandmarkType, PoseLandmark> _floorLikePose() {
  return _wallPose(
    shoulderX: 420,
    shoulderY: 280,
    hipX: 300,
    hipY: 300,
    elbowX: 480,
    elbowY: 280,
    wristX: 540,
    wristY: 280,
    footX: 100,
    footY: 330,
  );
}

void _activate(WallPushUp exercise, Map<PoseLandmarkType, PoseLandmark> pose) {
  expect(exercise.isInStartPosition(pose), isTrue);
  exercise
    ..exerciseState = ExerciseState.activated
    ..onExerciseActivated();
}

void _pump(
  WallPushUp exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('start position rejects floor-like push-ups', () {
    final wallPushUp = WallPushUp()..cameraFacing = CameraFacing.right;

    final top = _wallPose(
      shoulderX: 300,
      shoulderY: 200,
      hipX: 250,
      hipY: 300,
      elbowX: 360,
      elbowY: 200,
    );

    expect(wallPushUp.isInStartPosition(top), isTrue);
    expect(wallPushUp.isInStartPosition(_floorLikePose()), isFalse);
  });

  test('counts only after a full bottom-to-standing wall push-up', () {
    final wallPushUp = WallPushUp()
      ..cameraFacing = CameraFacing.right
      ..exerciseState = ExerciseState.activated;

    final top = _wallPose(
      shoulderX: 300,
      shoulderY: 200,
      hipX: 250,
      hipY: 300,
      elbowX: 360,
      elbowY: 200,
    );
    final down1 = _wallPose(
      shoulderX: 320,
      shoulderY: 220,
      hipX: 263.3,
      hipY: 313.3,
      elbowX: 360,
      elbowY: 230,
    );
    final down2 = _wallPose(
      shoulderX: 345,
      shoulderY: 245,
      hipX: 280,
      hipY: 330,
      elbowX: 380,
      elbowY: 240,
    );
    final bottom = _wallPose(
      shoulderX: 360,
      shoulderY: 260,
      hipX: 290,
      hipY: 340,
      elbowX: 400,
      elbowY: 260,
    );

    _activate(wallPushUp, top);

    _pump(wallPushUp, top, 0);
    _pump(wallPushUp, down1, 100);
    _pump(wallPushUp, down2, 200);
    _pump(wallPushUp, bottom, 900);
    _pump(wallPushUp, bottom, 1300);
    _pump(wallPushUp, down2, 1700);
    _pump(wallPushUp, top, 2200);

    expect(wallPushUp.repCount, 1);
    expect(double.parse(wallPushUp.debugData['peakElbow'] as String),
        greaterThanOrEqualTo(WallPushUpConfig.LOCKOUT_GOOD_MIN));

    _pump(wallPushUp, top, 2600);

    expect(wallPushUp.repCount, 1);
  });

  test('rejects a rep when the wall hand drifts by body-scale ratio', () {
    final wallPushUp = WallPushUp()
      ..cameraFacing = CameraFacing.right
      ..exerciseState = ExerciseState.activated;

    final top = _wallPose(
      shoulderX: 300,
      shoulderY: 200,
      hipX: 250,
      hipY: 300,
      elbowX: 360,
      elbowY: 200,
    );
    final down1 = _wallPose(
      shoulderX: 320,
      shoulderY: 220,
      hipX: 263.3,
      hipY: 313.3,
      elbowX: 360,
      elbowY: 230,
      wristX: 460,
    );
    final down2 = _wallPose(
      shoulderX: 345,
      shoulderY: 245,
      hipX: 280,
      hipY: 330,
      elbowX: 370,
      elbowY: 220,
      wristX: 460,
    );
    final bottom = _wallPose(
      shoulderX: 360,
      shoulderY: 260,
      hipX: 290,
      hipY: 340,
      elbowX: 440,
      elbowY: 260,
      wristX: 460,
    );

    _activate(wallPushUp, top);

    _pump(wallPushUp, top, 0);
    _pump(wallPushUp, down1, 100);
    _pump(wallPushUp, down2, 200);
    for (var i = 0; i < 8; i += 1) {
      _pump(wallPushUp, bottom, 500 + i * 100);
    }
    _pump(wallPushUp, down2, 1500);
    _pump(wallPushUp, top, 1900);
    _pump(wallPushUp, top, 2300);

    expect(wallPushUp.repCount, 0);
    expect(wallPushUp.getSetFeedback(), isNotEmpty);
  });
}
