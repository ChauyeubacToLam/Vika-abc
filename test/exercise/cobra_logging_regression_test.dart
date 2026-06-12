import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/Cobra/cobra.dart';
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

Map<PoseLandmarkType, PoseLandmark> _cobraSetupPose() {
  return {
    PoseLandmarkType.rightShoulder: _landmark(
      PoseLandmarkType.rightShoulder,
      200,
      300,
    ),
    PoseLandmarkType.rightHip: _landmark(
      PoseLandmarkType.rightHip,
      100,
      300,
    ),
    PoseLandmarkType.rightElbow: _landmark(
      PoseLandmarkType.rightElbow,
      300,
      300,
    ),
    PoseLandmarkType.rightWrist: _landmark(
      PoseLandmarkType.rightWrist,
      400,
      300,
    ),
    PoseLandmarkType.rightEar: _landmark(
      PoseLandmarkType.rightEar,
      250,
      250,
    ),
    PoseLandmarkType.rightKnee: _landmark(
      PoseLandmarkType.rightKnee,
      250,
      310,
    ),
    PoseLandmarkType.rightHeel: _landmark(
      PoseLandmarkType.rightHeel,
      300,
      310,
    ),
    PoseLandmarkType.rightFootIndex: _landmark(
      PoseLandmarkType.rightFootIndex,
      310,
      310,
    ),
  };
}

Map<PoseLandmarkType, PoseLandmark> _faultingCobraHoldPose({
  double shoulderY = 200,
}) {
  return {
    PoseLandmarkType.rightShoulder: _landmark(
      PoseLandmarkType.rightShoulder,
      200,
      shoulderY,
    ),
    PoseLandmarkType.rightHip: _landmark(
      PoseLandmarkType.rightHip,
      100,
      250,
    ),
    PoseLandmarkType.rightElbow: _landmark(
      PoseLandmarkType.rightElbow,
      300,
      shoulderY,
    ),
    PoseLandmarkType.rightWrist: _landmark(
      PoseLandmarkType.rightWrist,
      400,
      shoulderY,
    ),
    PoseLandmarkType.rightEar: _landmark(
      PoseLandmarkType.rightEar,
      300,
      shoulderY + 100,
    ),
    PoseLandmarkType.rightKnee: _landmark(
      PoseLandmarkType.rightKnee,
      250,
      260,
    ),
    PoseLandmarkType.rightHeel: _landmark(
      PoseLandmarkType.rightHeel,
      300,
      260,
    ),
    PoseLandmarkType.rightFootIndex: _landmark(
      PoseLandmarkType.rightFootIndex,
      310,
      260,
    ),
  };
}

void _pump(
  Cobra exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Cobra pushes per-metric fail counts after metric faults', () {
    final cobra = Cobra(maxRep: 2)
      ..cameraFacing = CameraFacing.right
      ..scaleFactor = 100;
    final setup = _cobraSetupPose();
    final faultingHold = _faultingCobraHoldPose();

    for (var i = 0; i < CobraConfig.CALIBRATION_FRAMES; i += 1) {
      expect(cobra.isInStartPosition(setup), isTrue);
    }

    cobra.exerciseState = ExerciseState.activated;

    _pump(cobra, faultingHold, 0);
    _pump(cobra, faultingHold, 1000);
    _pump(cobra, faultingHold, 2000);
    _pump(cobra, faultingHold, 4000);
    _pump(cobra, faultingHold, 8000);
    _pump(cobra, faultingHold, 12000);
    _pump(cobra, faultingHold, 16000);

    expect(cobra.repCount, 1);

    cobra.onSetComplete();

    expect(cobra.logger.setLogs['max_rep'], 2);
    expect(cobra.logger.setLogs['elbow_flexion_fails_count'], 1);
    expect(cobra.logger.setLogs['hand_placement_fails_count'], 1);
    expect(cobra.logger.setLogs['cervical_neutrality_fails_count'], 1);
    expect(cobra.logger.setLogs['pelvic_grounding_fails_count'], 1);
    expect(
      cobra.logger.setLogs.containsKey('descent_velocity_fails_count'),
      isFalse,
    );
    expect(
      cobra.logger.setLogs.keys,
      contains('hold_stability_fails_count'),
    );
  });

  test('Cobra hold stability fail count increments under real hold wobble', () {
    final cobra = Cobra(maxRep: 2)
      ..cameraFacing = CameraFacing.right
      ..scaleFactor = 100;
    final setup = _cobraSetupPose();

    for (var i = 0; i < CobraConfig.CALIBRATION_FRAMES; i += 1) {
      expect(cobra.isInStartPosition(setup), isTrue);
    }

    cobra.exerciseState = ExerciseState.activated;

    _pump(cobra, _faultingCobraHoldPose(shoulderY: 100), 0);
    for (var t = 1000; t <= 16000; t += 1000) {
      _pump(
        cobra,
        _faultingCobraHoldPose(shoulderY: (t ~/ 1000).isEven ? 100 : 200),
        t,
      );
    }

    expect(cobra.repCount, 1);

    cobra.onSetComplete();

    expect(cobra.logger.setLogs['hold_stability_fails_count'], 1);
  });
}
