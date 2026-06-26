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

Map<PoseLandmarkType, PoseLandmark> _buildDepthFacingLandmarks({
  required bool leftSideCloser,
}) {
  final leftNear = leftSideCloser;

  double leftDepth(double near, double far) => leftNear ? near : far;
  double rightDepth(double near, double far) => leftNear ? far : near;

  return {
    PoseLandmarkType.leftShoulder: _landmark(
      PoseLandmarkType.leftShoulder,
      154,
      110,
      z: leftDepth(-0.58, 0.41),
    ),
    PoseLandmarkType.rightShoulder: _landmark(
      PoseLandmarkType.rightShoulder,
      164,
      112,
      z: rightDepth(-0.54, 0.46),
    ),
    PoseLandmarkType.leftElbow: _landmark(
      PoseLandmarkType.leftElbow,
      150,
      170,
      z: leftDepth(-0.46, 0.30),
    ),
    PoseLandmarkType.rightElbow: _landmark(
      PoseLandmarkType.rightElbow,
      168,
      172,
      z: rightDepth(-0.43, 0.34),
    ),
    PoseLandmarkType.leftWrist: _landmark(
      PoseLandmarkType.leftWrist,
      147,
      220,
      z: leftDepth(-0.38, 0.22),
    ),
    PoseLandmarkType.rightWrist: _landmark(
      PoseLandmarkType.rightWrist,
      171,
      224,
      z: rightDepth(-0.34, 0.26),
    ),
    PoseLandmarkType.leftHip: _landmark(
      PoseLandmarkType.leftHip,
      156,
      200,
      z: leftDepth(-0.52, 0.36),
    ),
    PoseLandmarkType.rightHip: _landmark(
      PoseLandmarkType.rightHip,
      162,
      202,
      z: rightDepth(-0.48, 0.39),
    ),
    PoseLandmarkType.leftKnee: _landmark(
      PoseLandmarkType.leftKnee,
      156,
      290,
      z: leftDepth(-0.44, 0.28),
    ),
    PoseLandmarkType.rightKnee: _landmark(
      PoseLandmarkType.rightKnee,
      163,
      292,
      z: rightDepth(-0.40, 0.31),
    ),
    PoseLandmarkType.leftAnkle: _landmark(
      PoseLandmarkType.leftAnkle,
      157,
      380,
      z: leftDepth(-0.36, 0.18),
    ),
    PoseLandmarkType.rightAnkle: _landmark(
      PoseLandmarkType.rightAnkle,
      164,
      382,
      z: rightDepth(-0.33, 0.21),
    ),
    PoseLandmarkType.leftHeel: _landmark(
      PoseLandmarkType.leftHeel,
      152,
      390,
      z: leftDepth(-0.34, 0.16),
    ),
    PoseLandmarkType.rightHeel: _landmark(
      PoseLandmarkType.rightHeel,
      159,
      392,
      z: rightDepth(-0.30, 0.20),
    ),
    PoseLandmarkType.leftFootIndex: _landmark(
      PoseLandmarkType.leftFootIndex,
      171,
      390,
      z: leftDepth(-0.31, 0.13),
    ),
    PoseLandmarkType.rightFootIndex: _landmark(
      PoseLandmarkType.rightFootIndex,
      179,
      392,
      z: rightDepth(-0.27, 0.17),
    ),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'squat stays valid when the right side is visible but orientation is only angled',
      () {
    final squat = Squat(maxRep: 15)..cameraFacing = CameraFacing.angled;
    final landmarks = _buildSquatLandmarks(rightSideVisible: true);

    expect(squat.checkSafety(landmarks), isNull);
    expect(squat.isInStartPosition(landmarks), isTrue);
  });

  test(
      'squat stays valid when the left side is visible but orientation is undefined',
      () {
    final squat = Squat(maxRep: 15)..cameraFacing = CameraFacing.undefined;
    final landmarks = _buildSquatLandmarks(rightSideVisible: false);

    expect(squat.checkSafety(landmarks), isNull);
    expect(squat.isInStartPosition(landmarks), isTrue);
  });

  test('tracked squat side can switch when the opposite side becomes clearer',
      () {
    final squat = Squat(maxRep: 15)..cameraFacing = CameraFacing.angled;

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

  test('camera facing uses z-score depth to switch from right to left side',
      () {
    final squat = Squat(maxRep: 15);
    final rightFacingLandmarks =
        _buildDepthFacingLandmarks(leftSideCloser: false);
    final leftFacingLandmarks =
        _buildDepthFacingLandmarks(leftSideCloser: true);

    CameraFacing facing = CameraFacing.undefined;
    for (var i = 0; i < 5; i++) {
      facing = squat.detectCameraFacing(rightFacingLandmarks);
    }
    expect(facing, CameraFacing.right);

    squat.cameraFacing = facing;
    expect(squat.checkSafety(rightFacingLandmarks), isNull);

    for (var i = 0; i < 5; i++) {
      facing = squat.detectCameraFacing(leftFacingLandmarks);
    }
    expect(facing, CameraFacing.left);

    squat.cameraFacing = facing;
    expect(squat.checkSafety(leftFacingLandmarks), isNull);
    expect(squat.isInStartPosition(leftFacingLandmarks), isTrue);
  });
}
