import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/walking_lunge/metrics/front_knee_control_metric.dart';
import 'package:vika/exercise/walking_lunge/metrics/walking_metric_base.dart';
import 'package:vika/exercise/walking_lunge/walking_lunge.dart';

PoseLandmark _landmark(PoseLandmarkType type, double x, double y) {
  return PoseLandmark(
    type: type,
    x: x,
    y: y,
    z: 0,
    likelihood: 1,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('knee travel does not reject a short walking-lunge step', () {
    final metric = FrontKneeControlMetric();
    final context = WalkingRepContext(
      thighLength: 100,
      frontKnee: _landmark(PoseLandmarkType.leftKnee, 145, 100),
      frontAnkle: _landmark(PoseLandmarkType.leftAnkle, 100, 200),
      frontFoot: _landmark(PoseLandmarkType.leftFootIndex, 120, 200),
      rearKnee: _landmark(PoseLandmarkType.rightKnee, 20, 100),
      rearAnkle: _landmark(PoseLandmarkType.rightAnkle, 0, 200),
      hip: _landmark(PoseLandmarkType.leftHip, 80, 0),
      shoulder: _landmark(PoseLandmarkType.leftShoulder, 80, -100),
      frontKneeAngle: 90,
      rearKneeAngle: 90,
      torsoAngle: 0,
      stepLengthX: 100,
      state: WalkingState.bottom,
      frameTimestamp: 0,
      resultIssues: ResultIssues(),
    );

    metric.update(context);

    expect(metric.debugData['kneeOverToeX'], '0.25');
    expect(metric.faults, isEmpty);
  });
}
