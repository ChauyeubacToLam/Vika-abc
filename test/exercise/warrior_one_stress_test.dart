import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/warrior_1/warrior_one.dart';
import 'package:vika/models/exercise_lookup.dart';

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

({double x, double y}) _pointAtClock({
  required double x,
  required double y,
  required double clockAngle,
  required double length,
}) {
  final radians = (clockAngle - 90.0) * math.pi / 180.0;
  return (
    x: x + math.cos(radians) * length,
    y: y + math.sin(radians) * length,
  );
}

Map<PoseLandmarkType, PoseLandmark> _warriorOnePose({
  double trunkLeanDegrees = 15.0,
  bool armsLow = false,
  bool backKneeBent = false,
}) {
  const hipX = 200.0;
  const hipY = 300.0;
  const torsoLength = 100.0;

  final trunkClock =
      trunkLeanDegrees >= 0 ? 360.0 - trunkLeanDegrees : -trunkLeanDegrees;
  final shoulder = _pointAtClock(
    x: hipX,
    y: hipY,
    clockAngle: trunkClock,
    length: torsoLength,
  );
  final torsoDx = shoulder.x - hipX;
  final torsoDy = shoulder.y - hipY;
  final ear = (
    x: shoulder.x + torsoDx * 0.5,
    y: shoulder.y + torsoDy * 0.5,
  );

  final armClock = armsLow ? 65.0 : 0.0;
  final elbow = _pointAtClock(
    x: shoulder.x,
    y: shoulder.y,
    clockAngle: armClock,
    length: 45.0,
  );
  final wrist = _pointAtClock(
    x: shoulder.x,
    y: shoulder.y,
    clockAngle: armClock,
    length: 90.0,
  );

  final rightAnkle = backKneeBent ? (x: 250.0, y: 430.0) : (x: 330.0, y: 420.0);

  return {
    PoseLandmarkType.leftEar: _landmark(
      PoseLandmarkType.leftEar,
      ear.x,
      ear.y,
      z: -0.45,
    ),
    PoseLandmarkType.rightEar: _landmark(
      PoseLandmarkType.rightEar,
      ear.x + 8,
      ear.y + 4,
      z: 0.35,
    ),
    PoseLandmarkType.leftShoulder: _landmark(
      PoseLandmarkType.leftShoulder,
      shoulder.x,
      shoulder.y,
      z: -0.50,
    ),
    PoseLandmarkType.rightShoulder: _landmark(
      PoseLandmarkType.rightShoulder,
      shoulder.x + 8,
      shoulder.y + 4,
      z: 0.38,
    ),
    PoseLandmarkType.leftElbow: _landmark(
      PoseLandmarkType.leftElbow,
      elbow.x,
      elbow.y,
      z: -0.46,
    ),
    PoseLandmarkType.rightElbow: _landmark(
      PoseLandmarkType.rightElbow,
      elbow.x + 8,
      elbow.y + 4,
      z: 0.34,
    ),
    PoseLandmarkType.leftWrist: _landmark(
      PoseLandmarkType.leftWrist,
      wrist.x,
      wrist.y,
      z: -0.43,
    ),
    PoseLandmarkType.rightWrist: _landmark(
      PoseLandmarkType.rightWrist,
      wrist.x + 8,
      wrist.y + 4,
      z: 0.31,
    ),
    PoseLandmarkType.leftHip: _landmark(
      PoseLandmarkType.leftHip,
      hipX,
      hipY,
      z: -0.48,
    ),
    PoseLandmarkType.rightHip: _landmark(
      PoseLandmarkType.rightHip,
      210,
      305,
      z: 0.36,
    ),
    PoseLandmarkType.leftKnee: _landmark(
      PoseLandmarkType.leftKnee,
      135,
      360,
      z: -0.42,
    ),
    PoseLandmarkType.rightKnee: _landmark(
      PoseLandmarkType.rightKnee,
      265,
      360,
      z: 0.30,
    ),
    PoseLandmarkType.leftAnkle: _landmark(
      PoseLandmarkType.leftAnkle,
      125,
      440,
      z: -0.37,
    ),
    PoseLandmarkType.rightAnkle: _landmark(
      PoseLandmarkType.rightAnkle,
      rightAnkle.x,
      rightAnkle.y,
      z: 0.24,
    ),
  };
}

int _pumpFrames(
  WarriorOne exercise,
  Map<PoseLandmarkType, PoseLandmark> pose, {
  required int startMs,
  required int count,
  int stepMs = 33,
}) {
  var timestamp = startMs;
  for (var i = 0; i < count; i++) {
    exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestamp);
    exercise.checkingPose(pose);
    timestamp += stepMs;
  }
  return timestamp;
}

int _enterHold(
  WarriorOne exercise,
  Map<PoseLandmarkType, PoseLandmark> pose, {
  int startMs = 0,
}) {
  final nextMs = _pumpFrames(
    exercise,
    pose,
    startMs: startMs,
    count: WarriorOneConfig.STILL_FRAMES + 2,
  );
  expect(exercise.holdState, WarriorOneState.hold);
  return nextMs;
}

void _completeHold(
  WarriorOne exercise,
  Map<PoseLandmarkType, PoseLandmark> pose, {
  required int completionMs,
}) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(completionMs);
  exercise.checkingPose(pose);
  expect(exercise.repCount, 1);
  expect(exercise.holdState, WarriorOneState.exit);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registry resolves Warrior I launch names', () {
    final byName = lookupExerciseDefinition('Warrior I');
    final byId = lookupExerciseDefinition('warrior_one');
    final byLegacyId = lookupExerciseDefinition('warrior_i');

    expect(byName, isNotNull);
    expect(byId, same(byName));
    expect(byLegacyId, same(byName));
    expect(byName!.createExercise(), isA<WarriorOne>());
  });

  test('safety and start gates reject bad framing before activation', () {
    final exercise = WarriorOne()
      ..cameraFacing = CameraFacing.left
      ..scaleFactor = 100;
    final pose = _warriorOnePose();

    expect(exercise.checkSafety(pose), isNull);
    expect(exercise.isInStartPosition(pose), isTrue);

    exercise.cameraFacing = CameraFacing.front;
    expect(exercise.checkSafety(pose), isNotNull);

    exercise.cameraFacing = CameraFacing.left;
    final missingAnkle = Map<PoseLandmarkType, PoseLandmark>.of(pose)
      ..remove(PoseLandmarkType.rightAnkle);
    expect(exercise.checkSafety(missingAnkle), isNotNull);

    final lowConfidence = Map<PoseLandmarkType, PoseLandmark>.of(pose);
    lowConfidence[PoseLandmarkType.leftHip] = _landmark(
      PoseLandmarkType.leftHip,
      200,
      300,
      z: -0.48,
      likelihood: 0.1,
    );
    expect(exercise.checkSafety(lowConfidence), isNotNull);
  });

  test('stable good hold completes one side without form faults', () {
    final exercise = WarriorOne(maxHolds: 1)
      ..cameraFacing = CameraFacing.left
      ..scaleFactor = 100;
    final pose = _warriorOnePose();

    final nextMs = _enterHold(exercise, pose);
    _pumpFrames(exercise, pose, startMs: nextMs, count: 5);
    _completeHold(exercise, pose, completionMs: 32000);

    expect(exercise.requestStop(), isTrue);
    expect(exercise.correctForm, isTrue);
    expect(exercise.setFeedback.single[true], isEmpty);
  });

  test('sustained trunk collapse fails the hold', () {
    final exercise = WarriorOne(maxHolds: 1)
      ..cameraFacing = CameraFacing.left
      ..scaleFactor = 100;
    final goodPose = _warriorOnePose();
    final trunkCollapsePose = _warriorOnePose(trunkLeanDegrees: 40);

    final nextMs = _enterHold(exercise, goodPose);
    _pumpFrames(exercise, trunkCollapsePose, startMs: nextMs, count: 10);
    _completeHold(exercise, trunkCollapsePose, completionMs: 32000);

    final faultMap = exercise.setFeedback.single[false]!;
    expect(exercise.correctForm, isFalse);
    expect(faultMap['HOLD'], containsPair('trunk_lean', contains('>30')));
  });

  test('coaching-only arm and back-knee faults do not fail the hold', () {
    final exercise = WarriorOne(maxHolds: 1)
      ..cameraFacing = CameraFacing.left
      ..scaleFactor = 100;
    final goodPose = _warriorOnePose();
    final coachingPose = _warriorOnePose(
      armsLow: true,
      backKneeBent: true,
    );

    final nextMs = _enterHold(exercise, goodPose);
    _pumpFrames(exercise, coachingPose, startMs: nextMs, count: 12);
    _completeHold(exercise, coachingPose, completionMs: 32000);

    final faultMap = exercise.setFeedback.single[true]!;
    expect(exercise.correctForm, isTrue);
    expect(faultMap['HOLD'], containsPair('Arms', contains('Arms hanging')));
    expect(faultMap['HOLD'], containsPair('back_knee', contains('Back knee')));
  });
}
