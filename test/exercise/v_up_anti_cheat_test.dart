import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/10.Vup/v_up.dart';
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

Map<PoseLandmarkType, PoseLandmark> _vUpPose({
  required double shoulderX,
  required double shoulderY,
  required double wristX,
  required double wristY,
  required double hipX,
  required double hipY,
  required double kneeX,
  required double kneeY,
  required double ankleX,
  required double ankleY,
}) {
  return {
    PoseLandmarkType.leftShoulder:
        _landmark(PoseLandmarkType.leftShoulder, shoulderX, shoulderY),
    PoseLandmarkType.rightShoulder:
        _landmark(PoseLandmarkType.rightShoulder, shoulderX, shoulderY),
    PoseLandmarkType.leftWrist:
        _landmark(PoseLandmarkType.leftWrist, wristX, wristY),
    PoseLandmarkType.rightWrist:
        _landmark(PoseLandmarkType.rightWrist, wristX, wristY),
    PoseLandmarkType.leftHip: _landmark(PoseLandmarkType.leftHip, hipX, hipY),
    PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, hipX, hipY),
    PoseLandmarkType.leftKnee:
        _landmark(PoseLandmarkType.leftKnee, kneeX, kneeY),
    PoseLandmarkType.rightKnee:
        _landmark(PoseLandmarkType.rightKnee, kneeX, kneeY),
    PoseLandmarkType.leftAnkle:
        _landmark(PoseLandmarkType.leftAnkle, ankleX, ankleY),
    PoseLandmarkType.rightAnkle:
        _landmark(PoseLandmarkType.rightAnkle, ankleX, ankleY),
  };
}

Map<PoseLandmarkType, PoseLandmark> _flatStartPose() {
  return _vUpPose(
    shoulderX: 180,
    shoulderY: 300,
    wristX: 60,
    wristY: 300,
    hipX: 300,
    hipY: 300,
    kneeX: 420,
    kneeY: 300,
    ankleX: 540,
    ankleY: 300,
  );
}

Map<PoseLandmarkType, PoseLandmark> _risingPose() {
  return _vUpPose(
    shoulderX: 210,
    shoulderY: 250,
    wristX: 250,
    wristY: 245,
    hipX: 300,
    hipY: 300,
    kneeX: 400,
    kneeY: 275,
    ankleX: 500,
    ankleY: 250,
  );
}

Map<PoseLandmarkType, PoseLandmark> _strictTopPose() {
  return _vUpPose(
    shoulderX: 240,
    shoulderY: 170,
    wristX: 380,
    wristY: 170,
    hipX: 300,
    hipY: 300,
    kneeX: 340,
    kneeY: 235,
    ankleX: 380,
    ankleY: 170,
  );
}

Map<PoseLandmarkType, PoseLandmark> _moderateTopPose() {
  return _vUpPose(
    shoulderX: 230,
    shoulderY: 210,
    wristX: 350,
    wristY: 205,
    hipX: 300,
    hipY: 300,
    kneeX: 365,
    kneeY: 255,
    ankleX: 430,
    ankleY: 210,
  );
}

Map<PoseLandmarkType, PoseLandmark> _sitUpToeTouchPose() {
  return _vUpPose(
    shoulderX: 430,
    shoulderY: 180,
    wristX: 540,
    wristY: 300,
    hipX: 300,
    hipY: 300,
    kneeX: 420,
    kneeY: 300,
    ankleX: 540,
    ankleY: 300,
  );
}

Map<PoseLandmarkType, PoseLandmark> _bentKneeTopPose() {
  return _vUpPose(
    shoulderX: 240,
    shoulderY: 170,
    wristX: 380,
    wristY: 170,
    hipX: 300,
    hipY: 300,
    kneeX: 350,
    kneeY: 265,
    ankleX: 380,
    ankleY: 170,
  );
}

void _pump(
  VUp exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

VUp _activatedVUp() {
  return VUp(maxRep: 12)
    ..cameraFacing = CameraFacing.left
    ..exerciseState = ExerciseState.activated;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('start position requires flat full-body extension', () {
    final vUp = VUp(maxRep: 12)..cameraFacing = CameraFacing.left;

    expect(vUp.isInStartPosition(_flatStartPose()), isTrue);
    expect(vUp.isInStartPosition(_strictTopPose()), isFalse);
    expect(vUp.isInStartPosition(_sitUpToeTouchPose()), isFalse);
  });

  test('does not count when user starts already in a V and only lies down', () {
    final vUp = _activatedVUp();
    final top = _strictTopPose();
    final flat = _flatStartPose();

    _pump(vUp, top, 0);
    _pump(vUp, top, 100);
    _pump(vUp, flat, 300);
    _pump(vUp, flat, 400);
    _pump(vUp, flat, 500);

    expect(vUp.repCount, 0);
    expect(vUp.logger.repLogs, isEmpty);
  });

  test('does not count sit-up toe touch while legs stay pinned down', () {
    final vUp = _activatedVUp();
    final flat = _flatStartPose();
    final toeTouch = _sitUpToeTouchPose();

    _pump(vUp, flat, 0);
    _pump(vUp, flat, 100);
    _pump(vUp, flat, 200);
    _pump(vUp, toeTouch, 300);
    _pump(vUp, toeTouch, 400);
    _pump(vUp, flat, 600);
    _pump(vUp, flat, 700);

    expect(vUp.repCount, 0);
    expect(vUp.logger.repLogs, isEmpty);
  });

  test('does not count bent-knee tuck-up as a V-up', () {
    final vUp = _activatedVUp();
    final flat = _flatStartPose();
    final rising = _risingPose();
    final bentTop = _bentKneeTopPose();

    _pump(vUp, flat, 0);
    _pump(vUp, flat, 100);
    _pump(vUp, flat, 200);
    _pump(vUp, rising, 300);
    _pump(vUp, rising, 400);
    _pump(vUp, bentTop, 700);
    _pump(vUp, bentTop, 800);
    _pump(vUp, flat, 1100);
    _pump(vUp, flat, 1200);

    expect(vUp.repCount, 0);
    expect(vUp.logger.repLogs, isEmpty);
  });

  test('counts a complete controlled V-up from flat baseline', () {
    final vUp = _activatedVUp();
    final flat = _flatStartPose();
    final rising = _risingPose();
    final top = _strictTopPose();

    _pump(vUp, flat, 0);
    _pump(vUp, flat, 100);
    _pump(vUp, flat, 200);
    _pump(vUp, rising, 400);
    _pump(vUp, rising, 500);
    _pump(vUp, top, 900);
    _pump(vUp, top, 1000);
    _pump(vUp, rising, 1300);
    _pump(vUp, rising, 1400);
    _pump(vUp, flat, 2600);
    _pump(vUp, flat, 2700);

    expect(vUp.repCount, 1);
    expect(vUp.logger.repLogs.single.correctForm, isTrue);
  });

  test('counts a moderate V-up without requiring an extreme toe-touch angle',
      () {
    final vUp = _activatedVUp();
    final flat = _flatStartPose();
    final rising = _risingPose();
    final top = _moderateTopPose();

    _pump(vUp, flat, 0);
    _pump(vUp, flat, 100);
    _pump(vUp, flat, 200);
    _pump(vUp, rising, 400);
    _pump(vUp, rising, 500);
    _pump(vUp, top, 900);
    _pump(vUp, top, 1000);
    _pump(vUp, rising, 1300);
    _pump(vUp, rising, 1400);
    _pump(vUp, flat, 2600);
    _pump(vUp, flat, 2700);

    expect(vUp.repCount, 1);
    expect(vUp.logger.repLogs.single.correctForm, isTrue);
  });
}
