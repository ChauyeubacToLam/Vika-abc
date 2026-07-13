import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/14.Bear Plank/bear_plank.dart';
import 'package:vika/exercise/Sphinx_Pose/sphinx_stretch.dart';
import 'package:vika/exercise/exercise_base.dart';

PoseLandmark _landmark(PoseLandmarkType type, double x, double y) {
  return PoseLandmark(
    type: type,
    x: x,
    y: y,
    z: 0,
    likelihood: 0.99,
  );
}

Map<PoseLandmarkType, PoseLandmark> _bearPose({
  double shoulderX = 400,
  double shoulderY = 200,
  double kneeY = 270,
}) {
  return <PoseLandmarkType, PoseLandmark>{
    PoseLandmarkType.rightShoulder:
        _landmark(PoseLandmarkType.rightShoulder, shoulderX, shoulderY),
    PoseLandmarkType.rightWrist:
        _landmark(PoseLandmarkType.rightWrist, 400, 300),
    PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, 300, 200),
    PoseLandmarkType.rightKnee:
        _landmark(PoseLandmarkType.rightKnee, 300, kneeY),
    PoseLandmarkType.rightAnkle:
        _landmark(PoseLandmarkType.rightAnkle, 240, 300),
  };
}

enum _SphinxArmFault { none, straight, forearm, upperArm }

Map<PoseLandmarkType, PoseLandmark> _sphinxPose({
  _SphinxArmFault armFault = _SphinxArmFault.none,
}) {
  final elbow = armFault == _SphinxArmFault.upperArm
      ? _landmark(PoseLandmarkType.rightElbow, 400, 250)
      : _landmark(PoseLandmarkType.rightElbow, 300, 300);
  final wrist = switch (armFault) {
    _SphinxArmFault.none => _landmark(PoseLandmarkType.rightWrist, 400, 300),
    _SphinxArmFault.straight =>
      _landmark(PoseLandmarkType.rightWrist, 334.2, 394),
    _SphinxArmFault.forearm => _landmark(PoseLandmarkType.rightWrist, 400, 500),
    _SphinxArmFault.upperArm =>
      _landmark(PoseLandmarkType.rightWrist, 500, 250),
  };
  return <PoseLandmarkType, PoseLandmark>{
    PoseLandmarkType.rightEar: _landmark(PoseLandmarkType.rightEar, 350, 150),
    PoseLandmarkType.rightShoulder:
        _landmark(PoseLandmarkType.rightShoulder, 300, 200),
    PoseLandmarkType.rightElbow: elbow,
    PoseLandmarkType.rightWrist: wrist,
    PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, 200, 300),
    PoseLandmarkType.rightKnee: _landmark(PoseLandmarkType.rightKnee, 140, 385),
    PoseLandmarkType.rightAnkle:
        _landmark(PoseLandmarkType.rightAnkle, 100, 400),
  };
}

void _pumpBear(
  BearPlank exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

void _pumpSphinx(
  SphinxStretch exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Bear reuses hover gate, logs snake faults, and preserves report keys',
      () {
    final exercise = BearPlank(maxHolds: 1, holdSeconds: 2)
      ..cameraFacing = CameraFacing.right
      ..exerciseState = ExerciseState.activated;
    final clean = _bearPose();
    final backFault = _bearPose(shoulderY: 225);
    final kneeDrop = _bearPose(kneeY: 300);

    expect(exercise.isInStartPosition(clean), isTrue);
    exercise.onExerciseActivated();

    _pumpBear(exercise, clean, 0);
    _pumpBear(exercise, clean, 250);
    _pumpBear(exercise, clean, 500);
    expect(exercise.phase, HoldPhase.holding);

    _pumpBear(exercise, backFault, 750);
    expect(exercise.phase, HoldPhase.holding);
    expect(
      exercise.liveFaults.map((fault) => fault.type),
      contains('back_sag'),
    );

    for (var timestampMs = 1000; timestampMs <= 2000; timestampMs += 250) {
      _pumpBear(exercise, kneeDrop, timestampMs);
    }
    expect(exercise.phase, HoldPhase.dropping);
    expect(
      exercise.liveFaults.map((fault) => fault.type),
      contains('knee_hover'),
    );

    var timestampMs = 2250;
    while (exercise.repCount == 0 && timestampMs < 7000) {
      _pumpBear(exercise, clean, timestampMs);
      timestampMs += 250;
    }

    expect(exercise.repCount, 1);
    final repData = exercise.logger.repLogs.single.data;
    expect(repData['hold_time'], 2.0);
    expect(repData['perfect_hold_time'], 2.0);
    expect(repData['fault_types'],
        containsAll(<String>['back_sag', 'knee_hover']));

    exercise.onSetComplete();
    final setLogs = exercise.logger.setLogs;
    expect(setLogs['total_seconds'], 2.0);
    expect(setLogs['good_seconds'], isA<num>());
    expect(setLogs['max_rep'], 1);
    expect(setLogs['total_hover_time_ms'], 2000);
    expect(setLogs['timeout_triggered'], isFalse);
    expect(setLogs['knee_seconds'], isA<num>());
    expect(setLogs['back_seconds'], isA<num>());
    expect(setLogs['weight_seconds'], isA<num>());
    expect(setLogs['good_rep_count'], 0);
  });

  test('Sphinx engine timer logs straight_arm and preserves report keys', () {
    final exercise = SphinxStretch(maxHolds: 1, holdSeconds: 2)
      ..cameraFacing = CameraFacing.right
      ..exerciseState = ExerciseState.activated;
    final clean = _sphinxPose();
    final straightArm = _sphinxPose(armFault: _SphinxArmFault.straight);

    expect(exercise.isInStartPosition(clean), isTrue);
    exercise.onExerciseActivated();
    _pumpSphinx(exercise, clean, 0);
    expect(exercise.phase, HoldPhase.holding);

    for (var timestampMs = 100; timestampMs <= 400; timestampMs += 100) {
      _pumpSphinx(exercise, straightArm, timestampMs);
    }
    expect(exercise.phase, HoldPhase.holding);
    expect(
      exercise.liveFaults.map((fault) => fault.type),
      contains('straight_arm'),
    );

    var timestampMs = 500;
    while (exercise.repCount == 0 && timestampMs < 5000) {
      _pumpSphinx(exercise, clean, timestampMs);
      timestampMs += 100;
    }

    expect(exercise.repCount, 1);
    final repData = exercise.logger.repLogs.single.data;
    expect(repData['hold_time'], 2.0);
    expect(repData['active_hold_time'], 2.0);
    expect(repData['stability_score'], isA<num>());
    expect(repData['fault_types'], contains('straight_arm'));

    exercise.onSetComplete();
    final setLogs = exercise.logger.setLogs;
    expect(setLogs['active_hold_time'], 2.0);
    expect(setLogs['stability_score'], isA<num>());
    expect(setLogs['total_seconds'], 2.0);
    expect(setLogs['good_seconds'], isA<num>());
    expect(setLogs['hip_seconds'], 0.0);
    expect(setLogs['straight_arm_seconds'], isA<num>());
    expect(setLogs['shrug_neck_seconds'], isA<num>());
    expect(setLogs['max_rep'], 1);
    expect(setLogs['good_rep_count'], 0);
  });

  test('Sphinx keeps the three measured arm branches voice-distinct', () {
    final cases = <(_SphinxArmFault, String)>[
      (_SphinxArmFault.forearm, 'forearm'),
      (_SphinxArmFault.upperArm, 'upper_arm'),
    ];

    for (final (armFault, expectedType) in cases) {
      final exercise = SphinxStretch(maxHolds: 1, holdSeconds: 2)
        ..cameraFacing = CameraFacing.right
        ..exerciseState = ExerciseState.activated;
      exercise.onExerciseActivated();
      _pumpSphinx(exercise, _sphinxPose(), 0);

      for (var timestampMs = 100; timestampMs <= 400; timestampMs += 100) {
        _pumpSphinx(
          exercise,
          _sphinxPose(armFault: armFault),
          timestampMs,
        );
      }

      final liveTypes = exercise.liveFaults.map((fault) => fault.type).toSet();
      expect(liveTypes, contains(expectedType), reason: armFault.name);
      expect(liveTypes, isNot(contains('straight_arm')), reason: armFault.name);
    }
  });
}
