import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/push up/push_up.dart';

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

Map<PoseLandmarkType, PoseLandmark> _pushUpPose({
  required double bodyY,
  required double elbowX,
  required double elbowY,
  double wristY = 300,
  double heelY = 300,
  double footY = 300,
  double kneeYOffset = 0,
  double ankleYOffset = 0,
}) {
  const shoulderX = 400.0;
  const hipX = 300.0;
  const kneeX = 200.0;
  const ankleX = 120.0;
  const footX = 95.0;

  final kneeY = bodyY + kneeYOffset;
  final ankleY = bodyY + ankleYOffset;

  return {
    PoseLandmarkType.rightShoulder: _landmark(
      PoseLandmarkType.rightShoulder,
      shoulderX,
      bodyY,
    ),
    PoseLandmarkType.rightElbow: _landmark(
      PoseLandmarkType.rightElbow,
      elbowX,
      elbowY,
    ),
    PoseLandmarkType.rightWrist: _landmark(
      PoseLandmarkType.rightWrist,
      shoulderX,
      wristY,
    ),
    PoseLandmarkType.rightHip: _landmark(
      PoseLandmarkType.rightHip,
      hipX,
      bodyY,
    ),
    PoseLandmarkType.rightKnee: _landmark(
      PoseLandmarkType.rightKnee,
      kneeX,
      kneeY,
    ),
    PoseLandmarkType.rightAnkle: _landmark(
      PoseLandmarkType.rightAnkle,
      ankleX,
      ankleY,
    ),
    PoseLandmarkType.rightHeel: _landmark(
      PoseLandmarkType.rightHeel,
      footX,
      heelY,
    ),
    PoseLandmarkType.rightFootIndex: _landmark(
      PoseLandmarkType.rightFootIndex,
      footX,
      footY,
    ),
  };
}

void _pump(
  PushUp exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('start position requires a full high plank with knees off the floor',
      () {
    final pushUp = PushUp()..cameraFacing = CameraFacing.left;

    final highPlank = _pushUpPose(
      bodyY: 220,
      elbowX: 400,
      elbowY: 260,
    );

    final kneePushUp = _pushUpPose(
      bodyY: 235,
      elbowX: 400,
      elbowY: 265,
      kneeYOffset: 65,
      ankleYOffset: 65,
    );

    final lyingFlat = _pushUpPose(
      bodyY: 300,
      elbowX: 400,
      elbowY: 300,
    );

    expect(pushUp.isInStartPosition(highPlank), isTrue);
    expect(pushUp.isInStartPosition(kneePushUp), isFalse);
    expect(pushUp.isInStartPosition(lyingFlat), isFalse);
  });

  test('counts a full-body push-up with elbow ROM and knee travel', () {
    final pushUp = PushUp()
      ..cameraFacing = CameraFacing.left
      ..exerciseState = ExerciseState.activated;

    final top = _pushUpPose(bodyY: 220, elbowX: 400, elbowY: 260);
    final down1 = _pushUpPose(bodyY: 235, elbowX: 408, elbowY: 272);
    final down2 = _pushUpPose(bodyY: 245, elbowX: 412, elbowY: 278);
    final bottom = _pushUpPose(bodyY: 270, elbowX: 415, elbowY: 285);
    final up1 = _pushUpPose(bodyY: 245, elbowX: 412, elbowY: 278);

    expect(pushUp.isInStartPosition(top), isTrue);

    _pump(pushUp, top, 0);
    _pump(pushUp, down1, 100);
    _pump(pushUp, down2, 200);
    _pump(pushUp, bottom, 900);
    _pump(pushUp, bottom, 1300);
    _pump(pushUp, up1, 1700);
    _pump(pushUp, top, 2200);
    _pump(pushUp, top, 2600);

    expect(pushUp.repCount, 1);
    expect(pushUp.logger.repLogs.single.correctForm, isTrue);
  });

  test('rejects elbow-only motion while body stays pinned', () {
    final pushUp = PushUp()
      ..cameraFacing = CameraFacing.left
      ..exerciseState = ExerciseState.activated;

    final top = _pushUpPose(bodyY: 220, elbowX: 400, elbowY: 260);
    final down1 = _pushUpPose(bodyY: 220, elbowX: 412, elbowY: 260);
    final down2 = _pushUpPose(bodyY: 220, elbowX: 425, elbowY: 260);
    final bottom = _pushUpPose(bodyY: 220, elbowX: 440, elbowY: 260);
    final up1 = _pushUpPose(bodyY: 220, elbowX: 425, elbowY: 260);

    expect(pushUp.isInStartPosition(top), isTrue);

    _pump(pushUp, top, 0);
    _pump(pushUp, down1, 100);
    _pump(pushUp, down2, 200);
    _pump(pushUp, bottom, 900);
    _pump(pushUp, bottom, 1300);
    _pump(pushUp, up1, 1700);
    _pump(pushUp, top, 2200);
    _pump(pushUp, top, 2600);

    expect(pushUp.repCount, 0);
    expect(pushUp.logger.repLogs, isEmpty);
  });

  test('rejects a rep when wrist height drifts from the start baseline', () {
    final pushUp = PushUp()
      ..cameraFacing = CameraFacing.left
      ..exerciseState = ExerciseState.activated;

    final top = _pushUpPose(bodyY: 220, elbowX: 400, elbowY: 260);
    final down1 = _pushUpPose(bodyY: 235, elbowX: 408, elbowY: 272);
    final down2 = _pushUpPose(bodyY: 245, elbowX: 412, elbowY: 278);
    final bottom = _pushUpPose(
      bodyY: 270,
      elbowX: 435,
      elbowY: 305,
      wristY: 340,
    );
    final up1 = _pushUpPose(
      bodyY: 245,
      elbowX: 430,
      elbowY: 292,
      wristY: 340,
    );
    final up2 = _pushUpPose(
      bodyY: 235,
      elbowX: 420,
      elbowY: 287,
      wristY: 340,
    );
    final up3 = _pushUpPose(
      bodyY: 225,
      elbowX: 410,
      elbowY: 282,
      wristY: 340,
    );

    expect(pushUp.isInStartPosition(top), isTrue);

    _pump(pushUp, top, 0);
    _pump(pushUp, down1, 100);
    _pump(pushUp, down2, 200);
    _pump(pushUp, bottom, 900);
    _pump(pushUp, bottom, 1300);
    _pump(pushUp, up1, 1700);
    _pump(pushUp, up2, 1900);
    _pump(pushUp, up3, 2100);
    _pump(pushUp, top, 2400);
    _pump(pushUp, top, 2700);

    expect(pushUp.repCount, 0);
    expect(pushUp.logger.repLogs, isEmpty);
  });

  test('rejects a rep when heel height drifts from the start baseline', () {
    final pushUp = PushUp()
      ..cameraFacing = CameraFacing.left
      ..exerciseState = ExerciseState.activated;

    final top = _pushUpPose(bodyY: 220, elbowX: 400, elbowY: 260);
    final down1 = _pushUpPose(bodyY: 235, elbowX: 408, elbowY: 272);
    final down2 = _pushUpPose(bodyY: 245, elbowX: 412, elbowY: 278);
    final bottom = _pushUpPose(
      bodyY: 270,
      elbowX: 415,
      elbowY: 285,
      heelY: 360,
    );
    final up1 = _pushUpPose(
      bodyY: 245,
      elbowX: 412,
      elbowY: 278,
      heelY: 360,
    );
    final up2 = _pushUpPose(
      bodyY: 235,
      elbowX: 408,
      elbowY: 272,
      heelY: 360,
    );
    final up3 = _pushUpPose(
      bodyY: 225,
      elbowX: 404,
      elbowY: 266,
      heelY: 360,
    );

    expect(pushUp.isInStartPosition(top), isTrue);

    _pump(pushUp, top, 0);
    _pump(pushUp, down1, 100);
    _pump(pushUp, down2, 200);
    _pump(pushUp, bottom, 900);
    _pump(pushUp, bottom, 1300);
    _pump(pushUp, up1, 1700);
    _pump(pushUp, up2, 1900);
    _pump(pushUp, up3, 2100);
    _pump(pushUp, top, 2400);
    _pump(pushUp, top, 2700);

    expect(pushUp.repCount, 0);
    expect(pushUp.logger.repLogs, isEmpty);
  });
}
