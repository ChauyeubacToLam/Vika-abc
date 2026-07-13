import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/seated_forward_fold/seated_forward_fold.dart';
import 'package:vika/exercise/seated_forward_fold/seated_forward_report_builder.dart';

PoseLandmark _landmark(
  PoseLandmarkType type,
  double x,
  double y,
) {
  return PoseLandmark(
    type: type,
    x: x,
    y: y,
    z: 0,
    likelihood: 0.99,
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
  return <PoseLandmarkType, PoseLandmark>{
    PoseLandmarkType.rightEar: _landmark(PoseLandmarkType.rightEar, earX, earY),
    PoseLandmarkType.rightShoulder:
        _landmark(PoseLandmarkType.rightShoulder, shoulderX, shoulderY),
    PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, 200, 300),
    PoseLandmarkType.rightKnee: _landmark(PoseLandmarkType.rightKnee, 400, 300),
    PoseLandmarkType.rightHeel:
        _landmark(PoseLandmarkType.rightHeel, heelX, heelY),
    PoseLandmarkType.rightFootIndex:
        _landmark(PoseLandmarkType.rightFootIndex, toeX, toeY),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('full engine hold logs snake fault and preserves report keys', () {
    final exercise = SeatedForwardFold(maxHolds: 1, holdSeconds: 2)
      ..cameraFacing = CameraFacing.right
      ..exerciseState = ExerciseState.activated;
    final start = _seatedForwardPose(
      shoulderX: 200,
      shoulderY: 200,
      earX: 200,
      earY: 150,
    );
    final cleanHold = _seatedForwardPose();
    final kneeFault = _seatedForwardPose(
      heelX: 480,
      heelY: 440,
      toeX: 500,
      toeY: 390,
    );

    expect(exercise.isInStartPosition(start), isTrue);
    exercise.onExerciseActivated();

    var timestampMs = 0;
    while (exercise.phase != HoldPhase.holding && timestampMs < 3000) {
      _pump(exercise, cleanHold, timestampMs);
      timestampMs += 100;
    }
    expect(exercise.phase, HoldPhase.holding);

    for (var i = 0; i < 6; i += 1) {
      _pump(exercise, kneeFault, timestampMs);
      timestampMs += 100;
    }
    expect(exercise.liveFaults.map((fault) => fault.type), contains('knee'));

    while (exercise.repCount == 0 && timestampMs < 7000) {
      _pump(exercise, cleanHold, timestampMs);
      timestampMs += 100;
    }

    expect(exercise.repCount, 1);
    expect(exercise.requestStop(), isTrue);
    expect(exercise.logger.repLogs, hasLength(1));
    final repData = exercise.logger.repLogs.single.data;
    expect(repData['hold_time'], 2.0);
    expect(repData['max_depth_angle'], isA<num>());
    expect(repData['fault_types'], contains('knee'));

    exercise.onSetComplete();
    final setLogs = exercise.logger.setLogs;
    expect(setLogs['total_seconds'], 2.0);
    expect(setLogs['good_seconds'], isA<num>());
    expect(setLogs['knee_bent_seconds'], isA<num>());
    expect(setLogs['spine_round_seconds'], isA<num>());
    expect(setLogs.containsKey('max_rep'), isFalse);
    expect(setLogs.containsKey('good_rep_count'), isFalse);

    final report = SeatedForwardReportBuilder().buildReport(
      setLoggers: [exercise.logger],
      exerciseName: 'Seated Forward Fold',
      metValue: 2.5,
    );
    expect(report.formScore, inInclusiveRange(0, 100));
  });
}
