import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/seated_forward_fold/seated_forward_fold.dart';
import 'package:vika/exercise/seated_forward_fold/metrics/seated_forward_metric_base.dart';
import 'package:vika/exercise/seated_forward_fold/seated_forward_report_builder.dart';

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

Map<PoseLandmarkType, PoseLandmark> _seatedForwardPose({
  double shoulderX = 300,
  double shoulderY = 200,
  double earX = 350,
  double earY = 150,
  double heelX = 600,
  double heelY = 300,
  double toeX = 620,
  double toeY = 250,
}) {
  return {
    PoseLandmarkType.rightEar: _landmark(
      PoseLandmarkType.rightEar,
      earX,
      earY,
    ),
    PoseLandmarkType.rightShoulder: _landmark(
      PoseLandmarkType.rightShoulder,
      shoulderX,
      shoulderY,
    ),
    PoseLandmarkType.rightHip: _landmark(
      PoseLandmarkType.rightHip,
      200,
      300,
    ),
    PoseLandmarkType.rightKnee: _landmark(
      PoseLandmarkType.rightKnee,
      400,
      300,
    ),
    PoseLandmarkType.rightHeel: _landmark(
      PoseLandmarkType.rightHeel,
      heelX,
      heelY,
    ),
    PoseLandmarkType.rightFootIndex: _landmark(
      PoseLandmarkType.rightFootIndex,
      toeX,
      toeY,
    ),
  };
}

void _pump(
  SeatedForwardFold exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

Future<int> _completeShortHoldRep({
  required SeatedForwardFold exercise,
  required Map<PoseLandmarkType, PoseLandmark> start,
  required Map<PoseLandmarkType, PoseLandmark> cleanHold,
  required int timestampMs,
}) async {
  _pump(exercise, start, timestampMs);

  for (var offsetMs = 100; offsetMs <= 2200; offsetMs += 100) {
    _pump(exercise, cleanHold, timestampMs + offsetMs);
  }
  expect(exercise.state, SeatedForwardState.isometricHold);

  var currentTimestamp = timestampMs + 2200;
  for (var i = 0; i < 12; i += 1) {
    await Future<void>.delayed(const Duration(milliseconds: 70));
    currentTimestamp += 100;
    _pump(exercise, cleanHold, currentTimestamp);
  }
  expect(exercise.state, SeatedForwardState.ascending);

  currentTimestamp += 100;
  _pump(exercise, start, currentTimestamp);
  expect(exercise.state, SeatedForwardState.setup);

  return currentTimestamp + 100;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Seated Forward Fold scores partial clean time over all three holds',
      () async {
    final exercise = SeatedForwardFold(maxSeconds: 2, maxHolds: 3)
      ..cameraFacing = CameraFacing.right
      ..exerciseState = ExerciseState.activated;
    final start = _seatedForwardPose(
      shoulderX: 200,
      shoulderY: 200,
      earX: 200,
      earY: 150,
    );
    final cleanHold = _seatedForwardPose();

    expect(exercise.isInStartPosition(start), isTrue);
    exercise.onExerciseActivated();

    var timestampMs = 0;
    for (var rep = 0; rep < 3; rep += 1) {
      timestampMs = await _completeShortHoldRep(
        exercise: exercise,
        start: start,
        cleanHold: cleanHold,
        timestampMs: timestampMs,
      );
    }

    expect(exercise.requestStop(), isTrue);
    exercise.onSetComplete();

    final setLogs = exercise.logger.setLogs;
    final goodSeconds = setLogs['good_seconds'] as double;
    final report = SeatedForwardReportBuilder().buildReport(
      setLoggers: [exercise.logger],
      exerciseName: 'Seated Forward Fold',
      metValue: 2.5,
    );

    expect(setLogs['total_seconds'], 6.0);
    expect(goodSeconds, greaterThan(0.0));
    expect(goodSeconds, lessThan(6.0));
    expect(report.formScore, lessThan(100));
  });
}
