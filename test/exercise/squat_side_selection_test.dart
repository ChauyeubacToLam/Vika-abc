import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/squat/squat.dart';

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

Map<PoseLandmarkType, PoseLandmark> _buildSquatLandmarks({
  required bool rightSideVisible,
}) {
  final visibleLikelihood = 0.99;
  final hiddenLikelihood = 0.25;

  final visibleX = rightSideVisible ? 220.0 : 140.0;
  final hiddenX = rightSideVisible ? 140.0 : 220.0;

  final visibleSide = <PoseLandmarkType, PoseLandmark>{
    if (rightSideVisible) ...{
      PoseLandmarkType.rightShoulder: _landmark(
        PoseLandmarkType.rightShoulder,
        visibleX,
        110,
        likelihood: visibleLikelihood,
      ),
      PoseLandmarkType.rightHip: _landmark(
        PoseLandmarkType.rightHip,
        visibleX,
        200,
        likelihood: visibleLikelihood,
      ),
      PoseLandmarkType.rightKnee: _landmark(
        PoseLandmarkType.rightKnee,
        visibleX,
        290,
        likelihood: visibleLikelihood,
      ),
      PoseLandmarkType.rightAnkle: _landmark(
        PoseLandmarkType.rightAnkle,
        visibleX,
        380,
        likelihood: visibleLikelihood,
      ),
      PoseLandmarkType.rightHeel: _landmark(
        PoseLandmarkType.rightHeel,
        visibleX - 5,
        390,
        likelihood: visibleLikelihood,
      ),
      PoseLandmarkType.rightFootIndex: _landmark(
        PoseLandmarkType.rightFootIndex,
        visibleX + 18,
        390,
        likelihood: visibleLikelihood,
      ),
    } else ...{
      PoseLandmarkType.leftShoulder: _landmark(
        PoseLandmarkType.leftShoulder,
        visibleX,
        110,
        likelihood: visibleLikelihood,
      ),
      PoseLandmarkType.leftHip: _landmark(
        PoseLandmarkType.leftHip,
        visibleX,
        200,
        likelihood: visibleLikelihood,
      ),
      PoseLandmarkType.leftKnee: _landmark(
        PoseLandmarkType.leftKnee,
        visibleX,
        290,
        likelihood: visibleLikelihood,
      ),
      PoseLandmarkType.leftAnkle: _landmark(
        PoseLandmarkType.leftAnkle,
        visibleX,
        380,
        likelihood: visibleLikelihood,
      ),
      PoseLandmarkType.leftHeel: _landmark(
        PoseLandmarkType.leftHeel,
        visibleX - 5,
        390,
        likelihood: visibleLikelihood,
      ),
      PoseLandmarkType.leftFootIndex: _landmark(
        PoseLandmarkType.leftFootIndex,
        visibleX + 18,
        390,
        likelihood: visibleLikelihood,
      ),
    },
  };

  final hiddenSide = <PoseLandmarkType, PoseLandmark>{
    if (rightSideVisible) ...{
      PoseLandmarkType.leftShoulder: _landmark(
        PoseLandmarkType.leftShoulder,
        hiddenX + 20,
        150,
        likelihood: hiddenLikelihood,
      ),
      PoseLandmarkType.leftHip: _landmark(
        PoseLandmarkType.leftHip,
        hiddenX - 10,
        230,
        likelihood: hiddenLikelihood,
      ),
      PoseLandmarkType.leftKnee: _landmark(
        PoseLandmarkType.leftKnee,
        hiddenX + 35,
        300,
        likelihood: hiddenLikelihood,
      ),
      PoseLandmarkType.leftAnkle: _landmark(
        PoseLandmarkType.leftAnkle,
        hiddenX + 10,
        345,
        likelihood: hiddenLikelihood,
      ),
      PoseLandmarkType.leftHeel: _landmark(
        PoseLandmarkType.leftHeel,
        hiddenX - 5,
        350,
        likelihood: hiddenLikelihood,
      ),
      PoseLandmarkType.leftFootIndex: _landmark(
        PoseLandmarkType.leftFootIndex,
        hiddenX + 28,
        345,
        likelihood: hiddenLikelihood,
      ),
    } else ...{
      PoseLandmarkType.rightShoulder: _landmark(
        PoseLandmarkType.rightShoulder,
        hiddenX - 20,
        150,
        likelihood: hiddenLikelihood,
      ),
      PoseLandmarkType.rightHip: _landmark(
        PoseLandmarkType.rightHip,
        hiddenX + 10,
        230,
        likelihood: hiddenLikelihood,
      ),
      PoseLandmarkType.rightKnee: _landmark(
        PoseLandmarkType.rightKnee,
        hiddenX - 35,
        300,
        likelihood: hiddenLikelihood,
      ),
      PoseLandmarkType.rightAnkle: _landmark(
        PoseLandmarkType.rightAnkle,
        hiddenX - 10,
        345,
        likelihood: hiddenLikelihood,
      ),
      PoseLandmarkType.rightHeel: _landmark(
        PoseLandmarkType.rightHeel,
        hiddenX + 5,
        350,
        likelihood: hiddenLikelihood,
      ),
      PoseLandmarkType.rightFootIndex: _landmark(
        PoseLandmarkType.rightFootIndex,
        hiddenX - 28,
        345,
        likelihood: hiddenLikelihood,
      ),
    },
  };

  return {
    ...visibleSide,
    ...hiddenSide,
  };
}

void main() {
  test(
      'squat stays valid when the right side is visible but orientation is only angled',
      () {
    final squat = Squat()..cameraFacing = CameraFacing.angled;
    final landmarks = _buildSquatLandmarks(rightSideVisible: true);

    expect(squat.checkSafety(landmarks), isNull);
    expect(squat.isInStartPosition(landmarks), isTrue);
  });

  test(
      'squat stays valid when the left side is visible but orientation is undefined',
      () {
    final squat = Squat()..cameraFacing = CameraFacing.undefined;
    final landmarks = _buildSquatLandmarks(rightSideVisible: false);

    expect(squat.checkSafety(landmarks), isNull);
    expect(squat.isInStartPosition(landmarks), isTrue);
  });

  test('tracked squat side can switch when the opposite side becomes clearer',
      () {
    final squat = Squat()..cameraFacing = CameraFacing.angled;

    expect(
      squat.checkSafety(_buildSquatLandmarks(rightSideVisible: true)),
      isNull,
    );
    expect(
      squat.checkSafety(_buildSquatLandmarks(rightSideVisible: false)),
      isNull,
    );
    expect(
      squat.isInStartPosition(_buildSquatLandmarks(rightSideVisible: false)),
      isTrue,
    );
  });
}
