import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/12.Dead Bug/dead_bug.dart';
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

({double x, double y}) _pointAt({
  required double x,
  required double y,
  required double angleDegrees,
  required double length,
}) {
  final radians = angleDegrees * math.pi / 180.0;
  return (
    x: x + math.cos(radians) * length,
    y: y + math.sin(radians) * length,
  );
}

({double x, double y}) _armPoint({
  required double shoulderX,
  required double shoulderY,
  required double angle,
}) {
  return _pointAt(
    x: shoulderX,
    y: shoulderY,
    angleDegrees: -angle,
    length: 100,
  );
}

({double x, double y}) _kneePoint({
  required double hipX,
  required double hipY,
  required double angle,
}) {
  final vectorAngle = angle <= 90 ? -90.0 : 180.0 - angle;
  return _pointAt(
    x: hipX,
    y: hipY,
    angleDegrees: vectorAngle,
    length: 100,
  );
}

Map<PoseLandmarkType, PoseLandmark> _deadBugPose({
  double leftArmAngle = 90,
  double rightArmAngle = 90,
  double leftLegAngle = 90,
  double rightLegAngle = 90,
}) {
  const leftShoulderX = 100.0;
  const leftShoulderY = 200.0;
  const rightShoulderX = 100.0;
  const rightShoulderY = 220.0;
  const leftHipX = 220.0;
  const leftHipY = 200.0;
  const rightHipX = 220.0;
  const rightHipY = 220.0;

  final leftWrist = _armPoint(
    shoulderX: leftShoulderX,
    shoulderY: leftShoulderY,
    angle: leftArmAngle,
  );
  final rightWrist = _armPoint(
    shoulderX: rightShoulderX,
    shoulderY: rightShoulderY,
    angle: rightArmAngle,
  );
  final leftKnee = _kneePoint(
    hipX: leftHipX,
    hipY: leftHipY,
    angle: leftLegAngle,
  );
  final rightKnee = _kneePoint(
    hipX: rightHipX,
    hipY: rightHipY,
    angle: rightLegAngle,
  );

  PoseLandmark mark(PoseLandmarkType type, double x, double y) =>
      _landmark(type, x, y);

  return {
    PoseLandmarkType.leftShoulder:
        mark(PoseLandmarkType.leftShoulder, leftShoulderX, leftShoulderY),
    PoseLandmarkType.rightShoulder:
        mark(PoseLandmarkType.rightShoulder, rightShoulderX, rightShoulderY),
    PoseLandmarkType.leftWrist:
        mark(PoseLandmarkType.leftWrist, leftWrist.x, leftWrist.y),
    PoseLandmarkType.rightWrist:
        mark(PoseLandmarkType.rightWrist, rightWrist.x, rightWrist.y),
    PoseLandmarkType.leftHip:
        mark(PoseLandmarkType.leftHip, leftHipX, leftHipY),
    PoseLandmarkType.rightHip:
        mark(PoseLandmarkType.rightHip, rightHipX, rightHipY),
    PoseLandmarkType.leftKnee:
        mark(PoseLandmarkType.leftKnee, leftKnee.x, leftKnee.y),
    PoseLandmarkType.rightKnee:
        mark(PoseLandmarkType.rightKnee, rightKnee.x, rightKnee.y),
    PoseLandmarkType.leftAnkle: mark(
      PoseLandmarkType.leftAnkle,
      leftKnee.x + (leftKnee.x - leftHipX) * 0.6,
      leftKnee.y + (leftKnee.y - leftHipY) * 0.6,
    ),
    PoseLandmarkType.rightAnkle: mark(
      PoseLandmarkType.rightAnkle,
      rightKnee.x + (rightKnee.x - rightHipX) * 0.6,
      rightKnee.y + (rightKnee.y - rightHipY) * 0.6,
    ),
  };
}

void _pump(
  DeadBug exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

void _completeDeadBugRep({
  required DeadBug exercise,
  required Map<PoseLandmarkType, PoseLandmark> topPose,
  required Map<PoseLandmarkType, PoseLandmark> returningPose,
  required int startMs,
}) {
  final setupPose = _deadBugPose();

  _pump(exercise, topPose, startMs);
  _pump(exercise, topPose, startMs + 100);
  _pump(exercise, topPose, startMs + 1700);
  _pump(exercise, topPose, startMs + 1800);
  _pump(exercise, returningPose, startMs + 2000);
  _pump(exercise, returningPose, startMs + 2100);
  _pump(exercise, setupPose, startMs + 2200);
  _pump(exercise, setupPose, startMs + 2300);
}

DeadBug _activatedDeadBug() {
  return DeadBug(maxRep: 4)
    ..cameraFacing = CameraFacing.left
    ..exerciseState = ExerciseState.activated;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('start position accepts tabletop arms and legs', () {
    final exercise = DeadBug()..cameraFacing = CameraFacing.left;

    expect(exercise.isInStartPosition(_deadBugPose()), isTrue);
  });

  test('counts two reps when opposite arm and leg alternate each rep', () {
    final exercise = _activatedDeadBug();
    final leftArmRightLegTop = _deadBugPose(
      leftArmAngle: 155,
      rightLegAngle: 155,
    );
    final leftArmRightLegReturn = _deadBugPose(
      leftArmAngle: 120,
      rightLegAngle: 120,
    );
    final rightArmLeftLegTop = _deadBugPose(
      rightArmAngle: 155,
      leftLegAngle: 155,
    );
    final rightArmLeftLegReturn = _deadBugPose(
      rightArmAngle: 120,
      leftLegAngle: 120,
    );

    _pump(exercise, _deadBugPose(), 0);
    _pump(exercise, _deadBugPose(), 50);

    _completeDeadBugRep(
      exercise: exercise,
      topPose: leftArmRightLegTop,
      returningPose: leftArmRightLegReturn,
      startMs: 100,
    );

    expect(exercise.repCount, 1);
    expect(exercise.logger.repLogs.single.correctForm, isTrue);

    _completeDeadBugRep(
      exercise: exercise,
      topPose: rightArmLeftLegTop,
      returningPose: rightArmLeftLegReturn,
      startMs: 3000,
    );

    expect(exercise.repCount, 2);
    expect(exercise.logger.repLogs, hasLength(2));
    expect(exercise.logger.repLogs.map((log) => log.correctForm),
        everyElement(isTrue));
  });

  test('counts a repeated side but marks the rep as form correction', () {
    final exercise = _activatedDeadBug();
    final repeatedTop = _deadBugPose(
      leftArmAngle: 155,
      rightLegAngle: 155,
    );
    final repeatedReturn = _deadBugPose(
      leftArmAngle: 120,
      rightLegAngle: 120,
    );

    _completeDeadBugRep(
      exercise: exercise,
      topPose: repeatedTop,
      returningPose: repeatedReturn,
      startMs: 100,
    );
    _completeDeadBugRep(
      exercise: exercise,
      topPose: repeatedTop,
      returningPose: repeatedReturn,
      startMs: 3000,
    );

    expect(exercise.repCount, 2);
    expect(exercise.logger.repLogs, hasLength(2));
    expect(exercise.logger.repLogs.last.correctForm, isFalse);
    expect(
      exercise.logger.repLogs.last.data['fault_types'],
      contains('NotAlternating'),
    );
  });

  test('counts floor contact but marks the rep as form correction', () {
    final exercise = _activatedDeadBug();
    final floorContactTop = _deadBugPose(
      leftArmAngle: 170,
      rightLegAngle: 170,
    );
    final returningPose = _deadBugPose(
      leftArmAngle: 120,
      rightLegAngle: 120,
    );

    _completeDeadBugRep(
      exercise: exercise,
      topPose: floorContactTop,
      returningPose: returningPose,
      startMs: 100,
    );

    expect(exercise.repCount, 1);
    expect(exercise.logger.repLogs.single.correctForm, isFalse);
    expect(
      exercise.logger.repLogs.single.data['fault_types'],
      contains('FloorContact'),
    );
  });
}
