import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/plank/plank.dart';

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
  double kneeYOffset = 0,
}) {
  const shoulderX = 400.0;
  const hipX = 300.0;
  const kneeX = 200.0;
  const ankleX = 100.0;
  const earX = 430.0;
  const footX = 80.0;
  const bodyY = 220.0;
  final kneeY = bodyY + kneeYOffset;

  PoseLandmark mark(PoseLandmarkType type, double x, double y) =>
      _landmark(type, x, y);

  return {
    PoseLandmarkType.leftEar: mark(PoseLandmarkType.leftEar, earX, bodyY),
    PoseLandmarkType.leftShoulder:
        mark(PoseLandmarkType.leftShoulder, shoulderX, bodyY),
    PoseLandmarkType.leftElbow:
        mark(PoseLandmarkType.leftElbow, elbowX, elbowY),
    PoseLandmarkType.leftWrist:
        mark(PoseLandmarkType.leftWrist, wristX, wristY),
    PoseLandmarkType.leftHip: mark(PoseLandmarkType.leftHip, hipX, bodyY),
    PoseLandmarkType.leftKnee: mark(PoseLandmarkType.leftKnee, kneeX, kneeY),
    PoseLandmarkType.leftAnkle: mark(PoseLandmarkType.leftAnkle, ankleX, bodyY),
    PoseLandmarkType.leftHeel: mark(PoseLandmarkType.leftHeel, footX, bodyY),
    PoseLandmarkType.leftFootIndex:
        mark(PoseLandmarkType.leftFootIndex, footX, bodyY),
    PoseLandmarkType.rightEar: mark(PoseLandmarkType.rightEar, earX, bodyY),
    PoseLandmarkType.rightShoulder:
        mark(PoseLandmarkType.rightShoulder, shoulderX, bodyY),
    PoseLandmarkType.rightElbow:
        mark(PoseLandmarkType.rightElbow, elbowX, elbowY),
    PoseLandmarkType.rightWrist:
        mark(PoseLandmarkType.rightWrist, wristX, wristY),
    PoseLandmarkType.rightHip: mark(PoseLandmarkType.rightHip, hipX, bodyY),
    PoseLandmarkType.rightKnee: mark(PoseLandmarkType.rightKnee, kneeX, kneeY),
    PoseLandmarkType.rightAnkle:
        mark(PoseLandmarkType.rightAnkle, ankleX, bodyY),
    PoseLandmarkType.rightHeel: mark(PoseLandmarkType.rightHeel, footX, bodyY),
    PoseLandmarkType.rightFootIndex:
        mark(PoseLandmarkType.rightFootIndex, footX, bodyY),
  };
}

Map<PoseLandmarkType, PoseLandmark> _forearmPose() => _plankPose(
      elbowX: 400,
      elbowY: 320,
      wristX: 320,
      wristY: 320,
    );

Map<PoseLandmarkType, PoseLandmark> _highPlankPose() => _plankPose(
      elbowX: 400,
      elbowY: 280,
      wristX: 400,
      wristY: 340,
    );

Map<PoseLandmarkType, PoseLandmark> _bentKneePose() => _plankPose(
      elbowX: 400,
      elbowY: 320,
      wristX: 320,
      wristY: 320,
      kneeYOffset: 85,
    );

void _pump(
  Plank exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('start position requires forearm plank geometry', () {
    final exercise = Plank(maxRep: 5)..cameraFacing = CameraFacing.right;

    expect(exercise.liveHoldTargetSeconds, PlankConfig.HOLD_DURATION);
    expect(exercise.liveHoldTargetSeconds, 15.0);
    expect(exercise.isInStartPosition(_forearmPose()), isTrue);
    expect(exercise.isInStartPosition(_highPlankPose()), isFalse);
    expect(exercise.isInStartPosition(_bentKneePose()), isFalse);
  });

  test('hold timer resets when user leaves forearm plank', () {
    final exercise = Plank(maxRep: 5)
      ..cameraFacing = CameraFacing.right
      ..exerciseState = ExerciseState.activated;

    _pump(exercise, _forearmPose(), 0);
    _pump(exercise, _forearmPose(), 100);
    expect(exercise.plankState, PlankState.holding);

    _pump(exercise, _highPlankPose(), 200);
    expect(exercise.plankState, PlankState.setup);
    expect(exercise.liveHoldSeconds, isNull);

    _pump(exercise, _forearmPose(), 300);
    _pump(exercise, _forearmPose(), 400);
    expect(exercise.plankState, PlankState.holding);

    _pump(exercise, _forearmPose(), 15400);
    expect(exercise.repCount, 1);
    expect(exercise.plankState, PlankState.resting);
  });
}
