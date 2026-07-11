import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/glute bridge/glute_bridge.dart';

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

Map<PoseLandmarkType, PoseLandmark> _rightSideBridgePose({
  bool includeKnee = true,
  bool includeAnkle = true,
  double shoulderLikelihood = 0.99,
}) {
  return {
    PoseLandmarkType.rightShoulder: _landmark(
      PoseLandmarkType.rightShoulder,
      210,
      180,
      likelihood: shoulderLikelihood,
    ),
    PoseLandmarkType.rightHip: _landmark(
      PoseLandmarkType.rightHip,
      260,
      260,
    ),
    if (includeKnee)
      PoseLandmarkType.rightKnee: _landmark(
        PoseLandmarkType.rightKnee,
        330,
        270,
      ),
    if (includeAnkle)
      PoseLandmarkType.rightAnkle: _landmark(
        PoseLandmarkType.rightAnkle,
        390,
        310,
      ),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('glute bridge checkSafety emits orientation guidance when not side-on',
      () {
    final exercise = GluteBridge(maxRep: 3)..cameraFacing = CameraFacing.front;

    expect(
      exercise.checkSafety(_rightSideBridgePose())?.kind,
      GuidanceClass.turnSide,
    );
  });

  test('glute bridge checkSafety emits body guidance when core landmarks miss',
      () {
    final exercise = GluteBridge(maxRep: 3)..cameraFacing = CameraFacing.right;

    expect(
      exercise.checkSafety(_rightSideBridgePose(includeKnee: false))?.kind,
      GuidanceClass.bodyInFrame,
    );
  });

  test('glute bridge checkSafety emits lighting guidance on low confidence',
      () {
    final exercise = GluteBridge(maxRep: 3)..cameraFacing = CameraFacing.right;

    expect(
      exercise
          .checkSafety(_rightSideBridgePose(
            includeAnkle: false,
            shoulderLikelihood: 0.1,
          ))
          ?.kind,
      GuidanceClass.lighting,
    );
  });

  test('glute bridge side-view far-side occlusion still proceeds', () {
    final exercise = GluteBridge(maxRep: 3)..cameraFacing = CameraFacing.right;

    expect(exercise.checkSafety(_rightSideBridgePose()), isNull);
  });
}
