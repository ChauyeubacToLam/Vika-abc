import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/butterfly_stretch/butterfly_stretch.dart';
import 'package:vika/exercise/butterfly_stretch/metrics/butterfly_metric_base.dart';
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

Map<PoseLandmarkType, PoseLandmark> _butterflyPose({
  bool feetFarFromHips = false,
  bool collapsedTorso = false,
  double leftHipLikelihood = 0.99,
  bool includeLeftHeel = true,
}) {
  final shoulderY = collapsedTorso ? 200.0 : 100.0;
  const hipY = 240.0;
  final heelY = feetFarFromHips ? 390.0 : 320.0;

  final pose = <PoseLandmarkType, PoseLandmark>{
    PoseLandmarkType.leftShoulder:
        _landmark(PoseLandmarkType.leftShoulder, 150, shoulderY),
    PoseLandmarkType.rightShoulder:
        _landmark(PoseLandmarkType.rightShoulder, 250, shoulderY),
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

int _pumpFrames(
  ButterflyStretch exercise,
  Map<PoseLandmarkType, PoseLandmark> pose, {
  required int startMs,
  required int count,
  int stepMs = 1000,
}) {
  var timestamp = startMs;
  for (var i = 0; i < count; i++) {
    exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestamp);
    exercise.checkingPose(pose);
    timestamp += stepMs;
  }
  return timestamp;
}

ButterflyStretch _activeButterfly() {
  return ButterflyStretch(maxSeconds: 30)
    ..cameraFacing = CameraFacing.front
    ..stretchState = ButterflyState.isometric_hold;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('good hold accumulates valid time and completes cleanly', () {
    final exercise = _activeButterfly();
    final pose = _butterflyPose();

    _pumpFrames(exercise, pose, startMs: 0, count: 32);

    expect(exercise.repCount, greaterThanOrEqualTo(30));
    expect(exercise.requestStop(), isTrue);

    exercise.onSetComplete();

    expect(exercise.correctForm, isTrue);
    expect(exercise.logger.repLogs.single.correctForm, isTrue);
    expect(exercise.logger.setLogs['foot_placement_seconds'], 0.0);
  });

  test('feet too far from hips freeze hold progress and fail form', () {
    final exercise = _activeButterfly();
    final goodPose = _butterflyPose();
    final farFeetPose = _butterflyPose(feetFarFromHips: true);

    final nextMs = _pumpFrames(exercise, goodPose, startMs: 0, count: 4);
    final holdSecondsBeforeFault = exercise.repCount;
    _pumpFrames(exercise, farFeetPose, startMs: nextMs, count: 10);

    expect(exercise.repCount, holdSecondsBeforeFault);
    expect(exercise.requestStop(), isFalse);

    exercise.onSetComplete();

    expect(exercise.correctForm, isFalse);
    expect(exercise.logger.setLogs['foot_placement_seconds'], 0.0);
    expect(
      exercise.logger.repLogs.single.data['fault_types'],
      contains('FootPlacement'),
    );
  });

  test('collapsed torso freezes hold progress and fails form', () {
    final exercise = _activeButterfly();
    final goodPose = _butterflyPose();
    final collapsedPose = _butterflyPose(collapsedTorso: true);

    final nextMs = _pumpFrames(exercise, goodPose, startMs: 0, count: 4);
    final holdSecondsBeforeFault = exercise.repCount;
    _pumpFrames(exercise, collapsedPose, startMs: nextMs, count: 10);

    expect(exercise.repCount, holdSecondsBeforeFault);

    exercise.onSetComplete();

    expect(exercise.correctForm, isFalse);
    expect(exercise.logger.setLogs['posture_seconds'], 0.0);
    expect(
      exercise.logger.repLogs.single.data['fault_types'],
      contains('PostureCollapse'),
    );
  });

  test('start position rejects far feet and collapsed posture', () {
    final exercise = ButterflyStretch(maxSeconds: 30)
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

  test('supports both upright and landscape phone orientations', () {
    final exercise = ButterflyStretch(maxSeconds: 30);

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
    final exercise = ButterflyStretch(maxSeconds: 30)
      ..cameraFacing = CameraFacing.front;

    expect(exercise.checkSafety(_butterflyPose()), isNull);
    expect(
      exercise.checkSafety(_butterflyPose(includeLeftHeel: false)),
      contains('khuất'),
    );
    expect(
      exercise.checkSafety(_butterflyPose(leftHipLikelihood: 0.1)),
      contains('khuất'),
    );
  });
}
