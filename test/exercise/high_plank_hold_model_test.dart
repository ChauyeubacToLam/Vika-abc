import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/3.High Plank/high_plank.dart';
import 'package:vika/exercise/3.High Plank/metrics/high_plank_metric_base.dart';
import 'package:vika/exercise/3.High Plank/metrics/timer_metric.dart';
import 'package:vika/exercise/exercise_base.dart';

PoseLandmark _landmark(PoseLandmarkType type, double x, double y) =>
    PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 0.99);

Map<PoseLandmarkType, PoseLandmark> _pose({double hipY = 243.333}) {
  const shoulderX = 400.0;
  const shoulderY = 200.0;
  const hipX = 300.0;
  const kneeX = 200.0;
  const kneeY = 286.667;
  const ankleX = 100.0;
  const ankleY = 330.0;
  const wristY = 330.0;
  const elbowY = (shoulderY + wristY) / 2;
  return {
    PoseLandmarkType.rightShoulder:
        _landmark(PoseLandmarkType.rightShoulder, shoulderX, shoulderY),
    PoseLandmarkType.rightElbow:
        _landmark(PoseLandmarkType.rightElbow, shoulderX, elbowY),
    PoseLandmarkType.rightWrist:
        _landmark(PoseLandmarkType.rightWrist, shoulderX, wristY),
    PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, hipX, hipY),
    PoseLandmarkType.rightKnee:
        _landmark(PoseLandmarkType.rightKnee, kneeX, kneeY),
    PoseLandmarkType.rightAnkle:
        _landmark(PoseLandmarkType.rightAnkle, ankleX, ankleY),
  };
}

Map<PoseLandmarkType, PoseLandmark> _uprightPose() {
  return {
    PoseLandmarkType.rightShoulder:
        _landmark(PoseLandmarkType.rightShoulder, 400, 200),
    PoseLandmarkType.rightElbow:
        _landmark(PoseLandmarkType.rightElbow, 400, 350),
    PoseLandmarkType.rightWrist:
        _landmark(PoseLandmarkType.rightWrist, 400, 500),
    PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, 390, 300),
    PoseLandmarkType.rightKnee: _landmark(PoseLandmarkType.rightKnee, 380, 400),
    PoseLandmarkType.rightAnkle:
        _landmark(PoseLandmarkType.rightAnkle, 370, 500),
  };
}

void _pump(HighPlank exercise, Map<PoseLandmarkType, PoseLandmark> pose,
    int timestampMs) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('outer-ring break pauses and resumes the same hold', () {
    final exercise = HighPlank(maxHolds: 1, holdSeconds: 2)
      ..cameraFacing = CameraFacing.right
      ..exerciseState = ExerciseState.activated;
    exercise.onExerciseActivated();

    final clean = _pose();
    final collapsed = _pose(hipY: 315);
    for (var ms = 0; ms <= 1250; ms += 250) {
      _pump(exercise, clean, ms);
    }
    final earnedBeforeBreak = exercise.liveHoldSeconds!;
    expect(earnedBeforeBreak, greaterThan(0));

    _pump(exercise, collapsed, 1500);
    _pump(exercise, collapsed, 1750);
    expect(exercise.state, HighPlankState.dropping);
    expect(exercise.liveFaults.single.type, 'wall_guard');
    final pausedAt = exercise.liveHoldSeconds!;

    for (var ms = 2000; ms <= 2750; ms += 250) {
      _pump(exercise, clean, ms);
    }
    expect(exercise.state, HighPlankState.holding);
    expect(exercise.liveHoldSeconds, pausedAt);

    var ms = 3000;
    while (exercise.repCount == 0 && ms < 6000) {
      _pump(exercise, clean, ms);
      ms += 250;
    }
    expect(exercise.repCount, 1);
    expect(exercise.logger.repLogs, hasLength(1));
  });

  test('pause reactivation discards the partial hold and paused span', () {
    final exercise = HighPlank(maxHolds: 1, holdSeconds: 2)
      ..cameraFacing = CameraFacing.right
      ..exerciseState = ExerciseState.activated;
    exercise.onExerciseActivated();
    final clean = _pose();

    for (var ms = 0; ms <= 1250; ms += 250) {
      _pump(exercise, clean, ms);
    }
    expect(exercise.state, HighPlankState.holding);
    expect(exercise.timerMetric.totalHoldingTimeMs, 500);

    exercise
      ..exerciseState = ExerciseState.notActivated
      ..frameTimestamp = DateTime.fromMillisecondsSinceEpoch(10000);
    exercise.onPauseReactivationStarted();

    expect(exercise.state, HighPlankState.setup);
    expect(exercise.timerMetric.totalHoldingTimeMs, 0);
    expect(exercise.repCount, 0);
    expect(exercise.logger.repLogs, isEmpty);

    exercise.exerciseState = ExerciseState.activated;
    exercise.onExerciseReactivatedAfterPause();
    for (var ms = 13000; ms <= 13750; ms += 250) {
      _pump(exercise, clean, ms);
    }
    _pump(exercise, clean, 14000);

    expect(exercise.state, HighPlankState.holding);
    expect(exercise.timerMetric.totalHoldingTimeMs, 250);
    expect(exercise.repCount, 0);
  });

  test('hold timer drops frame gaps outside the shared accumulator gate', () {
    final timer = TimerMetric();
    final issues = ResultIssues();
    HighPlankRepContext contextAt(int timestampMs) => HighPlankRepContext(
          shoulderHipAnkleAngle: 180,
          shoulderElbowWristAngle: 180,
          hipDeviation: 0,
          scaleFactor: 100,
          state: HighPlankState.holding,
          frameTimestampMs: timestampMs,
          resultIssues: issues,
        );

    timer.onStateTransition(HighPlankState.setup, HighPlankState.holding, 0);
    timer.update(contextAt(1000));
    expect(timer.totalHoldingTimeMs, 0);

    timer.update(contextAt(1250));
    expect(timer.totalHoldingTimeMs, 250);
  });

  test('inner sag is coached without pausing earned time', () {
    final exercise = HighPlank(maxHolds: 1, holdSeconds: 2)
      ..cameraFacing = CameraFacing.right
      ..exerciseState = ExerciseState.activated;
    exercise.onExerciseActivated();

    final clean = _pose();
    final sagging = _pose(hipY: 275);
    for (var ms = 0; ms <= 750; ms += 250) {
      _pump(exercise, clean, ms);
    }
    _pump(exercise, sagging, 1000);
    _pump(exercise, sagging, 1250);

    expect(exercise.state, HighPlankState.holding);
    expect(exercise.liveHoldSeconds, greaterThan(0));
    expect(exercise.liveFaults.map((fault) => fault.type), contains('sagging'));
  });

  test('outer horizontal gate admits deep sag but drops an upright body', () {
    final saggingExercise = HighPlank(maxHolds: 1, holdSeconds: 10)
      ..cameraFacing = CameraFacing.right
      ..exerciseState = ExerciseState.activated;
    saggingExercise.onExerciseActivated();

    final deepSag = _pose(hipY: 275);
    for (var ms = 0; ms <= 750; ms += 250) {
      _pump(saggingExercise, deepSag, ms);
    }
    expect(
      saggingExercise.state,
      HighPlankState.holding,
      reason: 'a ~37° sag stays below the 40° outer-entry ceiling',
    );

    final upright = _uprightPose();
    _pump(saggingExercise, upright, 1000);
    _pump(saggingExercise, upright, 1250);
    expect(saggingExercise.state, HighPlankState.dropping);
  });

  test('completed holds become reps with the internal rest between them', () {
    final exercise = HighPlank(maxHolds: 2, holdSeconds: 1)
      ..cameraFacing = CameraFacing.right
      ..exerciseState = ExerciseState.activated;
    exercise.onExerciseActivated();
    final clean = _pose();

    var ms = 0;
    while (exercise.repCount < 1 && ms < 5000) {
      _pump(exercise, clean, ms);
      ms += 250;
    }
    expect(exercise.state, HighPlankState.resting);
    expect(exercise.requestStop(), isFalse);

    while (exercise.state != HighPlankState.holding && ms < 10000) {
      _pump(exercise, clean, ms);
      ms += 250;
    }
    while (exercise.repCount < 2 && ms < 14000) {
      _pump(exercise, clean, ms);
      ms += 250;
    }

    expect(exercise.repCount, 2);
    expect(exercise.requestStop(), isTrue);
    expect(exercise.logger.repLogs.map((log) => log.repNumber), [1, 2]);
  });

  test('timed rest drains before a break-resettable 3s re-arm', () {
    final exercise = HighPlank(maxHolds: 2, holdSeconds: 1)
      ..cameraFacing = CameraFacing.right
      ..exerciseState = ExerciseState.activated;
    exercise.onExerciseActivated();
    final clean = _pose();
    final collapsed = _pose(hipY: 315);

    var ms = 0;
    while (exercise.state != HighPlankState.resting && ms < 5000) {
      _pump(exercise, clean, ms);
      ms += 250;
    }
    expect(exercise.liveRestTargetSeconds, 5);
    expect(exercise.liveRestSeconds, closeTo(5, 0.01));

    final restStartedAt = ms - 250;
    _pump(exercise, clean, restStartedAt + 4750);
    expect(exercise.state, HighPlankState.resting);
    expect(exercise.liveRestSeconds, closeTo(0.25, 0.01));
    _pump(exercise, clean, restStartedAt + 5000);
    expect(exercise.state, HighPlankState.reArming);
    expect(exercise.guidanceSignal?.kind, GuidanceClass.setupPosition);
    expect(exercise.currentPhaseKey, 'reArming');
    expect(exercise.liveRestSeconds, isNull);
    expect(exercise.holdStillElapsedMs, isNull);

    // Four clean frames confirm the existing outer-pose debounce, then the
    // shared activation surfaces begin at zero.
    for (var offset = 5250; offset <= 6000; offset += 250) {
      _pump(exercise, clean, restStartedAt + offset);
    }
    expect(exercise.holdStillElapsedMs, 0);
    expect(exercise.activationProgress, 0);
    // Once posed, re-arm is lineless (mirrors set-start's hold-still): NO
    // guidance banner, so the _CenterOverlay activation countdown RING renders
    // instead of a 'Giữ yên' banner suppressing it.
    expect(exercise.guidanceSignal, isNull);

    _pump(exercise, clean, restStartedAt + 7000);
    expect(exercise.holdStillElapsedMs, 1000);
    _pump(exercise, collapsed, restStartedAt + 7250);
    expect(exercise.state, HighPlankState.reArming);
    expect(exercise.holdStillElapsedMs, isNull);
    expect(exercise.guidanceSignal?.kind, GuidanceClass.setupPosition);

    for (var offset = 7500; offset <= 8250; offset += 250) {
      _pump(exercise, clean, restStartedAt + offset);
    }
    expect(exercise.holdStillElapsedMs, 0);
    _pump(exercise, clean, restStartedAt + 11250);
    expect(exercise.state, HighPlankState.holding);
    expect(exercise.liveHoldSeconds, 0);
  });

  test('rest wall clock advances to re-arm without a pose frame', () {
    final exercise = HighPlank(maxHolds: 2, holdSeconds: 1)
      ..cameraFacing = CameraFacing.right
      ..exerciseState = ExerciseState.activated;
    exercise.onExerciseActivated();
    final clean = _pose();

    var ms = 0;
    while (exercise.state != HighPlankState.resting && ms < 5000) {
      _pump(exercise, clean, ms);
      ms += 250;
    }
    expect(exercise.state, HighPlankState.resting);

    exercise.processNoPoseFrame();

    expect(exercise.state, HighPlankState.reArming);
    expect(exercise.liveRestSeconds, isNull);
  });
}
