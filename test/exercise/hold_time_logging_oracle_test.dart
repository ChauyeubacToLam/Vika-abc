import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/14.Bear Plank/bear_plank.dart';
import 'package:vika/exercise/3.High Plank/high_plank.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/seated_forward_fold/seated_forward_fold.dart';

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

Map<PoseLandmarkType, PoseLandmark> _highPlankPose({
  double elbowX = 400,
}) {
  const shoulderX = 400.0;
  const shoulderY = 200.0;
  const hipX = 300.0;
  const hipY = 243.3333333333;
  const kneeX = 200.0;
  const kneeY = 286.6666666667;
  const ankleX = 100.0;
  const ankleY = 330.0;
  const wristY = 330.0;
  const elbowY = (shoulderY + wristY) / 2;

  return {
    PoseLandmarkType.rightShoulder: _landmark(
      PoseLandmarkType.rightShoulder,
      shoulderX,
      shoulderY,
    ),
    PoseLandmarkType.rightElbow: _landmark(
      PoseLandmarkType.rightElbow,
      elbowX,
      elbowY,
    ),
    PoseLandmarkType.rightWrist: _landmark(
      PoseLandmarkType.rightWrist,
      shoulderX,
      wristY,
    ),
    PoseLandmarkType.rightHip: _landmark(
      PoseLandmarkType.rightHip,
      hipX,
      hipY,
    ),
    PoseLandmarkType.rightKnee: _landmark(
      PoseLandmarkType.rightKnee,
      kneeX,
      kneeY,
    ),
    PoseLandmarkType.rightAnkle: _landmark(
      PoseLandmarkType.rightAnkle,
      ankleX,
      ankleY,
    ),
  };
}

Map<PoseLandmarkType, PoseLandmark> _bearPlankPose({
  double shoulderX = 400,
  double shoulderY = 200,
}) {
  return {
    PoseLandmarkType.rightShoulder: _landmark(
      PoseLandmarkType.rightShoulder,
      shoulderX,
      shoulderY,
    ),
    PoseLandmarkType.rightWrist: _landmark(
      PoseLandmarkType.rightWrist,
      400,
      300,
    ),
    PoseLandmarkType.rightHip: _landmark(
      PoseLandmarkType.rightHip,
      300,
      200,
    ),
    PoseLandmarkType.rightKnee: _landmark(
      PoseLandmarkType.rightKnee,
      300,
      270,
    ),
    PoseLandmarkType.rightAnkle: _landmark(
      PoseLandmarkType.rightAnkle,
      240,
      300,
    ),
  };
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

void _activate(ExerciseBase exercise) {
  exercise
    ..exerciseState = ExerciseState.activated
    ..onExerciseActivated();
}

void _pump(
  ExerciseBase exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('hold time logging oracle', () {
    test('High Plank good_seconds excludes active elbow-fault frames', () {
      final exercise = HighPlank(maxHolds: 1, holdSeconds: 10)
        ..cameraFacing = CameraFacing.right;
      final clean = _highPlankPose();
      final elbowFault = _highPlankPose(elbowX: 420);

      expect(exercise.isInStartPosition(clean), isTrue);
      _activate(exercise);

      // Four clean frames enter holding at 750ms. Keep every later delta inside
      // the production frame-gap gate: 2s clean, then 2s with bent elbows.
      for (var ms = 0; ms <= 2750; ms += 250) {
        _pump(exercise, clean, ms);
      }
      for (var ms = 3000; ms <= 4750; ms += 250) {
        _pump(exercise, elbowFault, ms);
      }

      exercise.onSetComplete();

      expect(exercise.logger.setLogs['total_seconds'], 10.0);
      expect(exercise.logger.setLogs['total_perfect_time_ms'], 4000);
      // This direct metric fixture does not advance ExerciseBase's real-time
      // stopwatch, so the seconds accumulator remains at zero here.
      expect(exercise.logger.setLogs['good_seconds'], 0.0);
      expect(exercise.logger.setLogs['elbow_seconds'], isA<num>());
      expect(exercise.logger.setLogs['sagging_seconds'], isA<num>());
      expect(exercise.logger.setLogs['piked_seconds'], isA<num>());
    });

    test('Bear Plank good_seconds already uses fully clean hover frames', () {
      final exercise = BearPlank(maxSeconds: 10)
        ..cameraFacing = CameraFacing.right;
      final clean = _bearPlankPose();
      final backFault = _bearPlankPose(shoulderY: 225);
      final weightFault = _bearPlankPose(shoulderX: 450);

      expect(exercise.isInStartPosition(clean), isTrue);
      _activate(exercise);

      // Three clean frames enter hovering at 2000ms. From 2000->7000ms, only
      // the 3000, 5000, and 7000ms intervals are fully clean.
      _pump(exercise, clean, 0);
      _pump(exercise, clean, 1000);
      _pump(exercise, clean, 2000);
      _pump(exercise, clean, 3000);
      _pump(exercise, backFault, 4000);
      _pump(exercise, clean, 5000);
      _pump(exercise, weightFault, 6000);
      _pump(exercise, clean, 7000);

      exercise.onSetComplete();

      expect(exercise.logger.setLogs['total_seconds'], 10.0);
      expect(exercise.logger.setLogs['total_hover_time_ms'], 3000);
      expect(exercise.logger.setLogs['good_seconds'], 0.0);
      expect(exercise.logger.setLogs['knee_seconds'], isA<num>());
      expect(
        exercise.logger.setLogs['back_seconds'],
        isA<num>(),
      );
      expect(
        exercise.logger.setLogs['weight_seconds'],
        isA<num>(),
      );
    });

    test('Seated Forward Fold good_seconds excludes active form-fault frames',
        () {
      final exercise = SeatedForwardFold(maxSeconds: 10, maxHolds: 10)
        ..cameraFacing = CameraFacing.right;
      final start = _seatedForwardPose(
        shoulderX: 200,
        shoulderY: 200,
        earX: 200,
        earY: 150,
      );
      final cleanHold = _seatedForwardPose();
      final spineFault = _seatedForwardPose(
        earX: 250,
        earY: 150,
      );
      final kneeFault = _seatedForwardPose(
        heelX: 560,
        heelY: 240,
        toeX: 580,
        toeY: 190,
      );

      expect(exercise.isInStartPosition(start), isTrue);
      _activate(exercise);

      // The stable folded pose enters isometricHold at 2200ms. Good hold
      // accrues from actual frame deltas, ignores the 1500ms resume-like gap,
      // and excludes only debounced active fault frames.
      _pump(exercise, start, 0);
      for (var t = 100; t <= 2200; t += 100) {
        _pump(exercise, cleanHold, t);
      }
      _pump(exercise, cleanHold, 2300);
      _pump(exercise, cleanHold, 2400);
      _pump(exercise, spineFault, 2500);
      _pump(exercise, spineFault, 2600);
      _pump(exercise, spineFault, 2700);
      _pump(exercise, spineFault, 2800);
      _pump(exercise, cleanHold, 2900);
      _pump(exercise, cleanHold, 3000);
      _pump(exercise, kneeFault, 3100);
      _pump(exercise, kneeFault, 3200);
      _pump(exercise, kneeFault, 3300);
      _pump(exercise, cleanHold, 3400);
      _pump(exercise, cleanHold, 3500);
      _pump(exercise, cleanHold, 5000);
      _pump(exercise, cleanHold, 5100);

      expect(exercise.liveHoldSeconds, closeTo(3.9, 0.001));

      exercise.onSetComplete();

      expect(exercise.logger.setLogs['total_seconds'], 100.0);
      expect(exercise.logger.setLogs['good_seconds'], 0.0);
    });
  });
}
