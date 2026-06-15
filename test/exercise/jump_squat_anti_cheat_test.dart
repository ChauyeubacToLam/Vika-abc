import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/Jump_Squat/jump_squat.dart';
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

Map<PoseLandmarkType, PoseLandmark> _jumpSquatPose({
  required double kneeAngle,
  required double hipY,
  double supportY = 400,
}) {
  const hipX = 180.0;
  final kneeY = hipY + 100;
  final ankle = _pointAt(
    x: hipX,
    y: kneeY,
    angleDegrees: -90 + kneeAngle,
    length: 100,
  );
  final ankleY = math.min(ankle.y, supportY);

  return {
    PoseLandmarkType.nose: _landmark(PoseLandmarkType.nose, hipX, hipY - 170),
    PoseLandmarkType.leftShoulder:
        _landmark(PoseLandmarkType.leftShoulder, hipX, hipY - 120),
    PoseLandmarkType.leftHip: _landmark(PoseLandmarkType.leftHip, hipX, hipY),
    PoseLandmarkType.leftKnee:
        _landmark(PoseLandmarkType.leftKnee, hipX, kneeY),
    PoseLandmarkType.leftAnkle:
        _landmark(PoseLandmarkType.leftAnkle, ankle.x, ankleY),
    PoseLandmarkType.leftHeel:
        _landmark(PoseLandmarkType.leftHeel, ankle.x - 12, supportY),
    PoseLandmarkType.leftFootIndex:
        _landmark(PoseLandmarkType.leftFootIndex, ankle.x + 24, supportY),
  };
}

void _pump(
  JumpSquat exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

JumpSquat _activatedJumpSquat() {
  return JumpSquat(maxRep: 4)
    ..cameraFacing = CameraFacing.left
    ..exerciseState = ExerciseState.activated;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('start position captures a standing floor and hip baseline', () {
    final exercise = JumpSquat()..cameraFacing = CameraFacing.left;

    expect(
      exercise.isInStartPosition(_jumpSquatPose(kneeAngle: 175, hipY: 200)),
      isTrue,
    );
  });

  test('does not count calf raise or foot flick as airborne', () {
    final exercise = _activatedJumpSquat();
    final standing = _jumpSquatPose(kneeAngle: 175, hipY: 200);
    final squat = _jumpSquatPose(kneeAngle: 115, hipY: 225);
    final footFlick = _jumpSquatPose(
      kneeAngle: 105,
      hipY: 200,
      supportY: 335,
    );

    expect(exercise.isInStartPosition(standing), isTrue);

    _pump(exercise, standing, 0);
    _pump(exercise, standing, 100);
    _pump(exercise, squat, 200);
    _pump(exercise, squat, 300);
    _pump(exercise, footFlick, 400);
    _pump(exercise, footFlick, 500);
    _pump(exercise, standing, 700);
    _pump(exercise, standing, 800);

    expect(exercise.repCount, 0);
    expect(exercise.logger.repLogs, isEmpty);
  });

  test('counts a clear jump squat with hip lift and controlled landing', () {
    final exercise = _activatedJumpSquat();
    final standing = _jumpSquatPose(kneeAngle: 175, hipY: 200);
    final deepSquat = _jumpSquatPose(kneeAngle: 85, hipY: 260);
    final launch1 = _jumpSquatPose(kneeAngle: 110, hipY: 245);
    final launch2 = _jumpSquatPose(kneeAngle: 130, hipY: 225);
    final airborne = _jumpSquatPose(
      kneeAngle: 165,
      hipY: 160,
      supportY: 340,
    );
    final landing = _jumpSquatPose(kneeAngle: 110, hipY: 220);

    expect(exercise.isInStartPosition(standing), isTrue);

    _pump(exercise, standing, 0);
    _pump(exercise, standing, 100);
    _pump(exercise, deepSquat, 200);
    _pump(exercise, deepSquat, 300);
    _pump(exercise, launch1, 400);
    _pump(exercise, launch2, 500);
    _pump(exercise, airborne, 600);
    _pump(exercise, airborne, 700);
    _pump(exercise, landing, 800);
    _pump(exercise, landing, 900);
    _pump(exercise, standing, 1100);
    _pump(exercise, standing, 1200);
    _pump(exercise, standing, 1300);

    expect(exercise.repCount, 1);
    expect(exercise.logger.repLogs.single.correctForm, isTrue);
  });

  test('counts and faults a jump launched from a shallow dip', () {
    final exercise = _activatedJumpSquat();
    final standing = _jumpSquatPose(kneeAngle: 175, hipY: 200);
    final shallowDip = _jumpSquatPose(kneeAngle: 140, hipY: 225);
    final launch1 = _jumpSquatPose(kneeAngle: 155, hipY: 210);
    final launch2 = _jumpSquatPose(kneeAngle: 165, hipY: 190);
    final airborne = _jumpSquatPose(
      kneeAngle: 170,
      hipY: 155,
      supportY: 335,
    );
    final landing = _jumpSquatPose(kneeAngle: 115, hipY: 220);

    expect(exercise.isInStartPosition(standing), isTrue);

    _pump(exercise, standing, 0);
    _pump(exercise, standing, 100);
    _pump(exercise, shallowDip, 200);
    _pump(exercise, shallowDip, 300);
    _pump(exercise, launch1, 400);
    _pump(exercise, launch2, 500);
    _pump(exercise, airborne, 600);
    _pump(exercise, airborne, 700);
    _pump(exercise, landing, 800);
    _pump(exercise, landing, 900);
    _pump(exercise, standing, 1100);
    _pump(exercise, standing, 1200);
    _pump(exercise, standing, 1300);

    // Count-vs-reject for shallow-dip is intentionally deferred
    // (keep-counted decision, 2026-06-14); revisit if we add a real
    // anti-cheat later.
    expect(exercise.repCount, 1);
    expect(exercise.logger.repLogs, hasLength(1));
    expect(exercise.logger.repLogs.single.correctForm, isFalse);
    expect(
      exercise.logger.repLogs.single.data['fault_types'],
      contains('Power'),
    );

    exercise.onSetComplete();
    expect(exercise.logger.setLogs['shallow_dip_fails_count'], 1);
  });
}
