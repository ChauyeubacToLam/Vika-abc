import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/curl_up/curl_up.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/pose/vika_image_orientation.dart';

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

Map<PoseLandmarkType, PoseLandmark> _curlUpLandmarks({
  required double shoulderY,
  required double kneeY,
}) {
  return <PoseLandmarkType, PoseLandmark>{
    PoseLandmarkType.rightEar: _landmark(
      PoseLandmarkType.rightEar,
      80,
      100,
    ),
    PoseLandmarkType.rightShoulder: _landmark(
      PoseLandmarkType.rightShoulder,
      100,
      shoulderY,
    ),
    PoseLandmarkType.rightHip: _landmark(
      PoseLandmarkType.rightHip,
      200,
      100,
    ),
    PoseLandmarkType.rightKnee: _landmark(
      PoseLandmarkType.rightKnee,
      200,
      kneeY,
    ),
    PoseLandmarkType.rightAnkle: _landmark(
      PoseLandmarkType.rightAnkle,
      240,
      kneeY,
    ),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const segmentationChannel = MethodChannel('com.vikavn.app/segmentation');
  const segmentationEventChannel =
      MethodChannel('com.vikavn.app/segmentation_stream');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    segmentationChannel,
    (call) async => <String, dynamic>{'success': true},
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    segmentationEventChannel,
    (call) async => null,
  );

  group('VikaImageOrientation surface resolution', () {
    test('uses Flutter landscape surface to unblock stale portrait sensor', () {
      expect(
        VikaImageOrientation.portrait.resolveForSurface(
          const Size(844, 390),
          fallbackLandscape: VikaImageOrientation.landscapeRight,
        ),
        VikaImageOrientation.landscapeRight,
      );
    });

    test('uses Flutter portrait surface to avoid premature landscape logic',
        () {
      expect(
        VikaImageOrientation.landscapeLeft.resolveForSurface(
          const Size(390, 844),
          fallbackLandscape: VikaImageOrientation.landscapeLeft,
        ),
        VikaImageOrientation.portrait,
      );
    });
  });

  group('VikaImageOrientation Android surface rotation', () {
    test('matches CameraX targetRotation constants', () {
      expect(VikaImageOrientation.portrait.androidSurfaceRotationDegrees, 0);
      expect(
        VikaImageOrientation.landscapeLeft.androidSurfaceRotationDegrees,
        90,
      );
      expect(
        VikaImageOrientation.landscapeRight.androidSurfaceRotationDegrees,
        270,
      );
      expect(
        VikaImageOrientation.portraitUpsideDown.androidSurfaceRotationDegrees,
        180,
      );
    });

    test('corrects native Android landscape camera scene presentation', () {
      expect(
        VikaImageOrientation.portrait.androidNativeCameraSceneQuarterTurns,
        0,
      );
      expect(
        VikaImageOrientation.landscapeLeft.androidNativeCameraSceneQuarterTurns,
        3,
      );
      expect(
        VikaImageOrientation
            .landscapeRight.androidNativeCameraSceneQuarterTurns,
        1,
      );
      expect(
        VikaImageOrientation
            .portraitUpsideDown.androidNativeCameraSceneQuarterTurns,
        0,
      );
    });
  });

  group('CurlUp landscape orientation tolerance', () {
    test('start position accepts bent knee above or below hip', () {
      final kneeAbove = CurlUp()..cameraFacing = CameraFacing.right;
      final kneeBelow = CurlUp()..cameraFacing = CameraFacing.right;

      expect(
        kneeAbove.isInStartPosition(
          _curlUpLandmarks(shoulderY: 100, kneeY: 50),
        ),
        isTrue,
      );
      expect(
        kneeBelow.isInStartPosition(
          _curlUpLandmarks(shoulderY: 100, kneeY: 150),
        ),
        isTrue,
      );
    });

    test('first ascent starts when shoulder lift appears in either direction',
        () {
      final shoulderMovesUp = CurlUp()..cameraFacing = CameraFacing.right;
      final shoulderMovesDown = CurlUp()..cameraFacing = CameraFacing.right;

      final startPose = _curlUpLandmarks(shoulderY: 100, kneeY: 50);
      expect(shoulderMovesUp.isInStartPosition(startPose), isTrue);
      shoulderMovesUp.exerciseState = ExerciseState.activated;
      shoulderMovesUp.checkingPose(startPose);
      shoulderMovesUp.checkingPose(
        _curlUpLandmarks(shoulderY: 90, kneeY: 50),
      );
      shoulderMovesUp.checkingPose(
        _curlUpLandmarks(shoulderY: 80, kneeY: 50),
      );
      expect(shoulderMovesUp.currentPhaseKey, 'ascending');

      expect(shoulderMovesDown.isInStartPosition(startPose), isTrue);
      shoulderMovesDown.exerciseState = ExerciseState.activated;
      shoulderMovesDown.checkingPose(startPose);
      shoulderMovesDown.checkingPose(
        _curlUpLandmarks(shoulderY: 110, kneeY: 50),
      );
      shoulderMovesDown.checkingPose(
        _curlUpLandmarks(shoulderY: 120, kneeY: 50),
      );
      expect(shoulderMovesDown.currentPhaseKey, 'ascending');
    });
  });
}
