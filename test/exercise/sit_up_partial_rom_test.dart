import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/2.Sit-Up/sit_up.dart';
import 'package:vika/exercise/2.Sit-Up/metrics/sit_up_metric_base.dart';
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

Map<PoseLandmarkType, PoseLandmark> _sitUpPose({
  required double shoulderX,
  required double shoulderY,
}) {
  return {
    PoseLandmarkType.leftShoulder:
        _landmark(PoseLandmarkType.leftShoulder, shoulderX, shoulderY),
    PoseLandmarkType.rightShoulder:
        _landmark(PoseLandmarkType.rightShoulder, shoulderX, shoulderY),
    PoseLandmarkType.leftHip: _landmark(PoseLandmarkType.leftHip, 300, 300),
    PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, 300, 300),
    PoseLandmarkType.leftKnee: _landmark(PoseLandmarkType.leftKnee, 420, 300),
    PoseLandmarkType.rightKnee: _landmark(PoseLandmarkType.rightKnee, 420, 300),
    PoseLandmarkType.leftAnkle: _landmark(PoseLandmarkType.leftAnkle, 420, 180),
    PoseLandmarkType.rightAnkle:
        _landmark(PoseLandmarkType.rightAnkle, 420, 180),
  };
}

void _pump(
  SitUp exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

SitUp _activatedSitUp() {
  return SitUp(maxRep: 15)
    ..cameraFacing = CameraFacing.left
    ..exerciseState = ExerciseState.activated;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('counts a controlled partial sit-up without requiring upright torso',
      () {
    final sitUp = _activatedSitUp();
    final lying = _sitUpPose(shoulderX: 180, shoulderY: 300);
    final halfway = _sitUpPose(shoulderX: 250, shoulderY: 240);

    expect(sitUp.isInStartPosition(lying), isTrue);

    _pump(sitUp, lying, 0);
    _pump(sitUp, lying, 100);
    _pump(sitUp, halfway, 300);
    _pump(sitUp, halfway, 400);
    _pump(sitUp, halfway, 500);
    _pump(sitUp, lying, 900);
    _pump(sitUp, lying, 1000);

    expect(sitUp.repCount, 1);
    expect(sitUp.logger.repLogs.single.correctForm, isTrue);
    expect(sitUp.logger.repLogs.single.data['fault_types'], isEmpty);
  });

  test('leaves upright hold state and counts after lowering to the floor', () {
    final sitUp = _activatedSitUp();
    final lying = _sitUpPose(shoulderX: 180, shoulderY: 300);
    final upright = _sitUpPose(shoulderX: 300, shoulderY: 180);
    final lowering = _sitUpPose(shoulderX: 240, shoulderY: 220);

    _pump(sitUp, lying, 0);
    _pump(sitUp, upright, 100);
    _pump(sitUp, upright, 200);
    _pump(sitUp, upright, 300);
    _pump(sitUp, upright, 400);
    expect(sitUp.state, SitUpState.upright);

    _pump(sitUp, lowering, 500);
    _pump(sitUp, lowering, 600);
    expect(sitUp.state, SitUpState.lowering);

    _pump(sitUp, lying, 700);
    _pump(sitUp, lying, 800);

    expect(sitUp.state, SitUpState.lying);
    expect(sitUp.repCount, 1);
  });
}
