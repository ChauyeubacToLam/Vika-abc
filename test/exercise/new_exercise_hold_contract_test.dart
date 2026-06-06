import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/ashtanga_namaskara/ashtanga_namaskara.dart';
import 'package:vika/exercise/downward_dog/downward_dog.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/low_lunge/low_lunge.dart';
import 'package:vika/exercise/raised_arms/raised_arms.dart';
import 'package:vika/exercise/surya_namaskar/pose_recognizers.dart';

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

Map<PoseLandmarkType, PoseLandmark> _downwardDogPose() {
  return {
    PoseLandmarkType.rightWrist:
        _landmark(PoseLandmarkType.rightWrist, 430, 430),
    PoseLandmarkType.rightElbow:
        _landmark(PoseLandmarkType.rightElbow, 380, 340),
    PoseLandmarkType.rightShoulder:
        _landmark(PoseLandmarkType.rightShoulder, 300, 250),
    PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, 250, 100),
    PoseLandmarkType.rightKnee: _landmark(PoseLandmarkType.rightKnee, 180, 250),
    PoseLandmarkType.rightAnkle:
        _landmark(PoseLandmarkType.rightAnkle, 100, 430),
    PoseLandmarkType.rightEar: _landmark(PoseLandmarkType.rightEar, 315, 238),
  };
}

Map<PoseLandmarkType, PoseLandmark> _lowLungePose({
  bool backKneeGrounded = true,
  bool frontKneeBent = true,
}) {
  return {
    PoseLandmarkType.leftShoulder:
        _landmark(PoseLandmarkType.leftShoulder, 380, 120),
    PoseLandmarkType.leftHip: _landmark(PoseLandmarkType.leftHip, 380, 230),
    PoseLandmarkType.leftKnee: _landmark(
      PoseLandmarkType.leftKnee,
      frontKneeBent ? 300 : 245,
      frontKneeBent ? 330 : 330,
    ),
    PoseLandmarkType.leftAnkle: _landmark(
      PoseLandmarkType.leftAnkle,
      frontKneeBent ? 270 : 270,
      430,
    ),
    PoseLandmarkType.rightShoulder:
        _landmark(PoseLandmarkType.rightShoulder, 360, 130),
    PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, 365, 250),
    PoseLandmarkType.rightKnee: _landmark(
      PoseLandmarkType.rightKnee,
      500,
      backKneeGrounded ? 430 : 280,
    ),
    PoseLandmarkType.rightAnkle:
        _landmark(PoseLandmarkType.rightAnkle, 560, 430),
  };
}

Map<PoseLandmarkType, PoseLandmark> _raisedArmsPose({
  bool armsUp = true,
  double hipY = 320,
}) {
  return {
    PoseLandmarkType.rightShoulder:
        _landmark(PoseLandmarkType.rightShoulder, 200, 150),
    PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, 200, hipY),
    PoseLandmarkType.rightElbow: _landmark(
      PoseLandmarkType.rightElbow,
      200,
      armsUp ? 80 : 230,
    ),
    PoseLandmarkType.rightWrist: _landmark(
      PoseLandmarkType.rightWrist,
      200,
      armsUp ? 20 : 300,
    ),
    PoseLandmarkType.rightEar: _landmark(PoseLandmarkType.rightEar, 205, 130),
  };
}

Map<PoseLandmarkType, PoseLandmark> _ashtangaPose({bool valid = true}) {
  return {
    PoseLandmarkType.rightShoulder:
        _landmark(PoseLandmarkType.rightShoulder, 300, valid ? 260 : 210),
    PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, 260, 220),
    PoseLandmarkType.rightKnee: _landmark(PoseLandmarkType.rightKnee, 430, 430),
    PoseLandmarkType.rightAnkle:
        _landmark(PoseLandmarkType.rightAnkle, 510, 430),
    PoseLandmarkType.rightEar: _landmark(PoseLandmarkType.rightEar, 320, 245),
  };
}

void _activate(
    ExerciseBase exercise, Map<PoseLandmarkType, PoseLandmark> pose) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(0);
  expect(exercise.isInStartPosition(pose), isTrue);
  exercise
    ..exerciseState = ExerciseState.activated
    ..onExerciseActivated();
}

void _pump(
  ExerciseBase exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Downward Dog counts only after full valid hold and writes logs', () {
    final exercise = DownwardDog()..cameraFacing = CameraFacing.right;
    final pose = _downwardDogPose();

    for (var i = 0; i < DownwardDogConfig.START_POSITION_FRAMES; i += 1) {
      exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(i * 33);
      exercise.isInStartPosition(pose);
    }

    exercise
      ..exerciseState = ExerciseState.activated
      ..frameTimestamp = DateTime.fromMillisecondsSinceEpoch(0)
      ..onExerciseActivated();

    _pump(exercise, pose, 0);
    _pump(exercise, pose, 31000);

    expect(exercise.repCount, 1);
    expect(exercise.logger.repLogs, hasLength(1));
    expect(exercise.getSetFeedback(), isNotEmpty);
  });

  test('Low Lunge start rejects lifted back knee', () {
    final exercise = LowLunge()..cameraFacing = CameraFacing.right;

    expect(exercise.isInStartPosition(_lowLungePose()), isTrue);
    expect(
      exercise.isInStartPosition(_lowLungePose(backKneeGrounded: false)),
      isFalse,
    );
  });

  test('Low Lunge does not count when hold breaks before target duration', () {
    final exercise = LowLunge()..cameraFacing = CameraFacing.right;
    final good = _lowLungePose();
    final bad = _lowLungePose(backKneeGrounded: false);

    _activate(exercise, good);

    for (var i = 0; i < 10; i += 1) {
      _pump(exercise, bad, 1000 + i * 100);
    }

    expect(exercise.repCount, 0);
    expect(exercise.getSetFeedback(), isNotEmpty);
  });

  test('Raised Arms does not count when arms drop before hold target', () {
    final exercise = RaisedArms()..cameraFacing = CameraFacing.right;
    final good = _raisedArmsPose();
    final bad = _raisedArmsPose(armsUp: false, hipY: 450);

    _activate(exercise, good);

    for (var i = 0; i < 10; i += 1) {
      _pump(exercise, bad, 1000 + i * 100);
    }

    expect(exercise.repCount, 0);
    expect(exercise.getSetFeedback(), isNotEmpty);
  });

  test('Ashtanga transient does not count a broken recognition window', () {
    final exercise = AshtangaNamaskara()..cameraFacing = CameraFacing.right;
    final good = _ashtangaPose();
    final bad = _ashtangaPose(valid: false);

    _activate(exercise, good);

    for (var i = 0; i < 8; i += 1) {
      _pump(exercise, bad, 50 + i * 50);
    }

    expect(exercise.repCount, 0);
    expect(exercise.getSetFeedback(), isNotEmpty);
  });

  test('Surya Namaskar recognizes High Plank instead of auto-passing it', () {
    final recognition = SuryaPoseRecognizers.recognize(
      poseId: SuryaPoseId.highPlankBlank,
      landmarks: _highPlankPose(),
      cameraFacing: CameraFacing.right,
    );

    expect(recognition.recognized, isTrue);
  });
}

Map<PoseLandmarkType, PoseLandmark> _highPlankPose() {
  return {
    PoseLandmarkType.rightWrist:
        _landmark(PoseLandmarkType.rightWrist, 300, 300),
    PoseLandmarkType.rightShoulder:
        _landmark(PoseLandmarkType.rightShoulder, 305, 180),
    PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, 470, 220),
    PoseLandmarkType.rightKnee: _landmark(PoseLandmarkType.rightKnee, 600, 250),
    PoseLandmarkType.rightAnkle:
        _landmark(PoseLandmarkType.rightAnkle, 735, 285),
  };
}
