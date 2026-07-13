import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/butterfly_stretch/butterfly_stretch.dart';
import 'package:vika/exercise/exercise_base.dart';

PoseLandmark _landmark(
  PoseLandmarkType type,
  double x,
  double y, {
  double likelihood = 0.99,
}) {
  return PoseLandmark(
    type: type,
    x: x,
    y: y,
    z: 0,
    likelihood: likelihood,
  );
}

Map<PoseLandmarkType, PoseLandmark> _butterflyPose({
  bool feetFarFromHips = false,
  bool collapsedTorso = false,
  double? rightShoulderY,
  double leftHipLikelihood = 0.99,
  bool includeLeftHeel = true,
}) {
  final shoulderY = collapsedTorso ? 200.0 : 100.0;
  const hipY = 240.0;
  final heelY = feetFarFromHips ? 390.0 : 320.0;

  final pose = <PoseLandmarkType, PoseLandmark>{
    PoseLandmarkType.leftShoulder:
        _landmark(PoseLandmarkType.leftShoulder, 150, shoulderY),
    PoseLandmarkType.rightShoulder: _landmark(
      PoseLandmarkType.rightShoulder,
      250,
      rightShoulderY ?? shoulderY,
    ),
    PoseLandmarkType.leftHip: _landmark(
      PoseLandmarkType.leftHip,
      160,
      hipY,
      likelihood: leftHipLikelihood,
    ),
    PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, 240, hipY),
    PoseLandmarkType.leftKnee: _landmark(PoseLandmarkType.leftKnee, 110, 360),
    PoseLandmarkType.rightKnee: _landmark(PoseLandmarkType.rightKnee, 290, 360),
    PoseLandmarkType.leftAnkle: _landmark(PoseLandmarkType.leftAnkle, 193, 380),
    PoseLandmarkType.rightAnkle:
        _landmark(PoseLandmarkType.rightAnkle, 207, 380),
    PoseLandmarkType.rightHeel:
        _landmark(PoseLandmarkType.rightHeel, 205, heelY),
  };

  if (includeLeftHeel) {
    pose[PoseLandmarkType.leftHeel] =
        _landmark(PoseLandmarkType.leftHeel, 195, heelY);
  }
  return pose;
}

void _pump(
  ButterflyStretch exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

ButterflyStretch _activeButterfly({int holdSeconds = 1}) {
  final exercise = ButterflyStretch(maxHolds: 1, holdSeconds: holdSeconds)
    ..cameraFacing = CameraFacing.front
    ..exerciseState = ExerciseState.activated;
  exercise.onExerciseActivated();
  return exercise;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('full hold logs one rep and preserves every report-builder key', () {
    final exercise = _activeButterfly();
    final pose = _butterflyPose();

    var timestampMs = 0;
    while (exercise.repCount == 0 && timestampMs < 4000) {
      _pump(exercise, pose, timestampMs);
      timestampMs += 100;
    }

    expect(exercise.phase, HoldPhase.resting);
    expect(exercise.repCount, 1);
    expect(exercise.requestStop(), isTrue);
    expect(exercise.logger.repLogs, hasLength(1));
    expect(exercise.logger.repLogs.single.data['hold_time'], 1.0);

    exercise.onSetComplete();
    final setLogs = exercise.logger.setLogs;
    expect(setLogs['max_rep'], 1);
    expect(setLogs['total_seconds'], 1.0);
    expect(setLogs['good_seconds'], isA<num>());
    expect(setLogs['total_hold_time'], 1.0);
    expect(setLogs['max_knee_separation'], greaterThan(0));
    expect(setLogs['knee_seconds'], isA<num>());
    expect(setLogs['posture_seconds'], isA<num>());
    expect(setLogs['foot_placement_seconds'], isA<num>());
    expect(setLogs['good_rep_count'], 1);
  });

  test('foot metric emits snake_case live fault without freezing hold time',
      () {
    final exercise = _activeButterfly(holdSeconds: 2);
    final clean = _butterflyPose();
    final farFeet = _butterflyPose(feetFarFromHips: true);

    var timestampMs = 0;
    while (exercise.phase != HoldPhase.holding && timestampMs < 3000) {
      _pump(exercise, clean, timestampMs);
      timestampMs += 100;
    }
    final beforeFault = exercise.timerMetric.totalHoldingTimeMs;
    for (var i = 0; i < 6; i += 1) {
      _pump(exercise, farFeet, timestampMs);
      timestampMs += 100;
    }

    expect(exercise.phase, HoldPhase.holding);
    expect(exercise.timerMetric.totalHoldingTimeMs, greaterThan(beforeFault));
    expect(exercise.liveFaults.map((fault) => fault.type), contains('foot'));

    while (exercise.repCount == 0 && timestampMs < 6000) {
      _pump(exercise, clean, timestampMs);
      timestampMs += 100;
    }
    expect(
      exercise.logger.repLogs.single.data['fault_types'],
      contains('foot'),
    );
  });

  test('measured shoulder tilt routes shoulder audio identity', () {
    final exercise = _activeButterfly(holdSeconds: 2);
    final clean = _butterflyPose();
    final tiltedShoulders = _butterflyPose(rightShoulderY: 150);

    var timestampMs = 0;
    while (exercise.phase != HoldPhase.holding && timestampMs < 3000) {
      _pump(exercise, clean, timestampMs);
      timestampMs += 100;
    }
    for (var i = 0; i < 7; i += 1) {
      _pump(exercise, tiltedShoulders, timestampMs);
      timestampMs += 100;
    }

    final liveTypes = exercise.liveFaults.map((fault) => fault.type).toSet();
    expect(liveTypes, contains('shoulder'));
    expect(liveTypes, isNot(contains('posture')));
  });

  test('start position rejects far feet and collapsed posture', () {
    final exercise = ButterflyStretch(maxHolds: 1, holdSeconds: 30)
      ..cameraFacing = CameraFacing.front;

    expect(exercise.isInStartPosition(_butterflyPose()), isTrue);
    expect(
      exercise.isInStartPosition(_butterflyPose(feetFarFromHips: true)),
      isFalse,
    );
    expect(
      exercise.isInStartPosition(_butterflyPose(collapsedTorso: true)),
      isFalse,
    );
  });

  test('supports upright and landscape phone orientations', () {
    final exercise = ButterflyStretch(maxHolds: 1, holdSeconds: 30);

    expect(
      exercise.supportedOrientations,
      containsAll(<VikaImageOrientation>{
        VikaImageOrientation.portrait,
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      }),
    );
    expect(exercise.setupOrientationIntroVoiceKey, 'common.thang_intro');
  });

  test('safety rejects missing or low-confidence hip and heel landmarks', () {
    final exercise = ButterflyStretch(maxHolds: 1, holdSeconds: 30)
      ..cameraFacing = CameraFacing.front;

    expect(exercise.checkSafety(_butterflyPose()), isNull);
    expect(
      exercise.checkSafety(_butterflyPose(includeLeftHeel: false))?.kind,
      GuidanceClass.bodyInFrame,
    );
    expect(
      exercise.checkSafety(_butterflyPose(leftHipLikelihood: 0.1))?.kind,
      GuidanceClass.bodyInFrame,
    );
  });
}
