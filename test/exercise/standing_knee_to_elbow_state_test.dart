import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/standing_knee_to_elbow/standing_knee_to_elbow.dart';

PoseLandmark _landmark(PoseLandmarkType type, double x, double y) {
  return PoseLandmark(
    type: type,
    x: x,
    y: y,
    z: 0,
    likelihood: 0.99,
  );
}

Map<PoseLandmarkType, PoseLandmark> _pose({
  double leftKneeY = 500,
  double rightElbowX = 440,
  double rightElbowY = 120,
}) {
  return {
    PoseLandmarkType.leftShoulder:
        _landmark(PoseLandmarkType.leftShoulder, 200, 100),
    PoseLandmarkType.rightShoulder:
        _landmark(PoseLandmarkType.rightShoulder, 400, 100),
    PoseLandmarkType.leftElbow: _landmark(PoseLandmarkType.leftElbow, 160, 120),
    PoseLandmarkType.rightElbow:
        _landmark(PoseLandmarkType.rightElbow, rightElbowX, rightElbowY),
    PoseLandmarkType.leftHip: _landmark(PoseLandmarkType.leftHip, 220, 300),
    PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, 380, 300),
    PoseLandmarkType.leftKnee:
        _landmark(PoseLandmarkType.leftKnee, 220, leftKneeY),
    PoseLandmarkType.rightKnee: _landmark(PoseLandmarkType.rightKnee, 380, 500),
    PoseLandmarkType.leftAnkle: _landmark(PoseLandmarkType.leftAnkle, 220, 700),
    PoseLandmarkType.rightAnkle:
        _landmark(PoseLandmarkType.rightAnkle, 380, 700),
  };
}

void _pump(
  StandingKneeToElbow exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('counts only a complete lift, cross-touch, and controlled return', () {
    final exercise = StandingKneeToElbow(maxRep: 16)
      ..cameraFacing = CameraFacing.front
      ..exerciseState = ExerciseState.activated;

    final approach = _pose(leftKneeY: 440);
    final touch = _pose(
      leftKneeY: 330,
      rightElbowX: 225,
      rightElbowY: 330,
    );
    final base = _pose();

    _pump(exercise, approach, 100);
    _pump(exercise, approach, 200);
    expect(exercise.kteState, KteState.approaching);
    _pump(exercise, touch, 400);
    _pump(exercise, touch, 500);
    expect(exercise.kteState, KteState.touch);
    _pump(exercise, base, 700);
    expect(exercise.kteState, KteState.returning);
    _pump(exercise, base, 800);
    _pump(exercise, base, 900);
    _pump(exercise, base, 1000);

    expect(exercise.kteState, KteState.standing_base);
    expect(exercise.repCount, 1);
  });

  test('camera-cover-like landmark jumps cannot create reps', () {
    final exercise = StandingKneeToElbow(maxRep: 16)
      ..cameraFacing = CameraFacing.front
      ..exerciseState = ExerciseState.activated;
    final baseWithCloseElbow = _pose(
      rightElbowX: 225,
      rightElbowY: 500,
    );
    final oneFrameTeleport = _pose(
      leftKneeY: 330,
      rightElbowX: 225,
      rightElbowY: 330,
    );

    for (var i = 0; i < 8; i++) {
      _pump(exercise, baseWithCloseElbow, i * 100);
    }
    _pump(exercise, oneFrameTeleport, 900);
    _pump(exercise, baseWithCloseElbow, 1000);

    expect(exercise.kteState, KteState.standing_base);
    expect(exercise.repCount, 0);
  });

  test('an early return exposes a no-count coaching correction', () {
    final exercise = StandingKneeToElbow(maxRep: 16)
      ..cameraFacing = CameraFacing.front
      ..exerciseState = ExerciseState.activated;
    final approach = _pose(leftKneeY: 440);
    final base = _pose();

    _pump(exercise, approach, 100);
    _pump(exercise, approach, 200);
    _pump(exercise, base, 300);

    expect(exercise.repCount, 0);
    expect(exercise.resultIssues.feedback['Result'], 'Không tính rep');
    expect(exercise.resultIssues.feedback['CrossRom'], contains('chạm'));
  });
}
