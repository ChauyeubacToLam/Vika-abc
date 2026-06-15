import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/squat/squat.dart';
import 'package:vika/utils/pose_math_helpers.dart';

class _RepFrame {
  const _RepFrame({
    required this.kneeAngle,
    required this.trunkLean,
    required this.heelDistance,
  });

  final double kneeAngle;
  final double trunkLean;
  final double heelDistance;
}

class _MeasuredRepFrame {
  const _MeasuredRepFrame({
    required this.pose,
    required this.kneeAngle,
    required this.trunkLean,
    required this.heelDistance,
  });

  final Map<PoseLandmarkType, PoseLandmark> pose;
  final double kneeAngle;
  final double trunkLean;
  final double heelDistance;
}

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

double _radians(double degrees) => degrees * math.pi / 180.0;

Map<PoseLandmarkType, PoseLandmark> _poseFor(_RepFrame frame) {
  const kneeX = 220.0;
  const kneeY = 290.0;
  const thighLength = 100.0;
  const shinLength = 100.0;
  const torsoLength = 90.0;

  final kneeRadians = _radians(frame.kneeAngle);
  final hipX = kneeX + thighLength * math.sin(kneeRadians);
  final hipY = kneeY + thighLength * math.cos(kneeRadians);
  final ankleX = kneeX;
  final ankleY = kneeY + shinLength;

  final trunkRadians = _radians(frame.trunkLean);
  final shoulderX = hipX + torsoLength * math.sin(trunkRadians);
  final shoulderY = hipY - torsoLength * math.cos(trunkRadians);

  final footX = ankleX + 24.0;
  final footY = ankleY + 8.0;
  final heelX = footX - 20.0;
  final heelY = footY - frame.heelDistance;

  return {
    PoseLandmarkType.rightShoulder: _landmark(
      PoseLandmarkType.rightShoulder,
      shoulderX,
      shoulderY,
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
    PoseLandmarkType.rightHeel: _landmark(
      PoseLandmarkType.rightHeel,
      heelX,
      heelY,
    ),
    PoseLandmarkType.rightFootIndex: _landmark(
      PoseLandmarkType.rightFootIndex,
      footX,
      footY,
    ),
  };
}

_MeasuredRepFrame _measure(_RepFrame frame) {
  final pose = _poseFor(frame);
  final hip = pose[PoseLandmarkType.rightHip]!;
  final knee = pose[PoseLandmarkType.rightKnee]!;
  final ankle = pose[PoseLandmarkType.rightAnkle]!;
  final shoulder = pose[PoseLandmarkType.rightShoulder]!;
  final foot = pose[PoseLandmarkType.rightFootIndex]!;
  final heel = pose[PoseLandmarkType.rightHeel]!;
  final clockAngle = calculateVerticalAngle(pivot: hip, point: shoulder);

  return _MeasuredRepFrame(
    pose: pose,
    kneeAngle: calculateAngleNormalized(
      firstPoint: hip,
      midPoint: knee,
      lastPoint: ankle,
    ),
    trunkLean: convertClockAngleToTrunkLean(clockAngle, CameraFacing.right),
    heelDistance: foot.y - heel.y,
  );
}

void _pumpFrame(
  Squat squat,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  squat.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  squat.checkingPose(pose);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'squat running rep peaks match manual scan and keep trunk lean correlated',
      () {
    final squat = Squat(maxRep: 1)
      ..exerciseState = ExerciseState.activated
      ..cameraFacing = CameraFacing.right
      ..squatState = SquatState.descending
      ..previousSquatState = SquatState.standing;

    final activeFrames = const [
      _RepFrame(kneeAngle: 128, trunkLean: 8, heelDistance: 2),
      _RepFrame(kneeAngle: 116, trunkLean: 12, heelDistance: 6),
      _RepFrame(kneeAngle: 102, trunkLean: 17, heelDistance: 5),
      _RepFrame(kneeAngle: 94, trunkLean: 23, heelDistance: 9),
      _RepFrame(kneeAngle: 98, trunkLean: 31, heelDistance: 13),
      _RepFrame(kneeAngle: 112, trunkLean: 18, heelDistance: 7),
    ].map(_measure).toList();

    var timestampMs = 1000;
    for (final frame in activeFrames) {
      _pumpFrame(squat, frame.pose, timestampMs);
      timestampMs += 100;
    }

    final manualBottomFrame = activeFrames.reduce(
      (currentMin, frame) =>
          frame.kneeAngle < currentMin.kneeAngle ? frame : currentMin,
    );
    final manualMaxHeelDistance = activeFrames
        .map((frame) => frame.heelDistance)
        .reduce((a, b) => a > b ? a : b);
    final manualMaxTrunkLean = activeFrames
        .map((frame) => frame.trunkLean)
        .reduce((a, b) => a > b ? a : b);

    expect(manualMaxTrunkLean, greaterThan(manualBottomFrame.trunkLean));

    squat
      ..squatState = SquatState.standing
      ..previousSquatState = SquatState.bottom;
    _pumpFrame(
      squat,
      _poseFor(
        const _RepFrame(kneeAngle: 170, trunkLean: 5, heelDistance: 1),
      ),
      timestampMs,
    );

    final repData = squat.logger.repLogs.single.data;
    expect(
      repData['peak_knee_angle'] as num,
      closeTo(manualBottomFrame.kneeAngle, 1e-9),
    );
    expect(
      repData['trunk_lean_at_bottom'] as num,
      closeTo(manualBottomFrame.trunkLean, 1e-9),
    );
    expect(
      repData['peak_heel_distance'] as num,
      closeTo(manualMaxHeelDistance, 1e-9),
    );

    squat.onSetComplete();
    expect(
      squat.logger.setLogs['min_knee_angle'] as num,
      closeTo(manualBottomFrame.kneeAngle, 1e-9),
    );
    expect(
      squat.logger.setLogs['max_heel_distance'] as num,
      closeTo(manualMaxHeelDistance, 1e-9),
    );
  });
}
