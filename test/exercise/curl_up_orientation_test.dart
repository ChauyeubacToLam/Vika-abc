import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/curl_up/curl_up.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/utils/pose_math_helpers.dart';

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

void _pumpCurlUp(
  CurlUp exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

double _trunkAngle(Map<PoseLandmarkType, PoseLandmark> pose) {
  final shoulder = pose[PoseLandmarkType.rightShoulder]!;
  final hip = pose[PoseLandmarkType.rightHip]!;
  final dy = (hip.y - shoulder.y).abs();
  final dx = (shoulder.x - hip.x).abs();
  if (dx == 0 && dy == 0) return 0.0;
  return (math.atan2(dy, dx) * (180.0 / math.pi)).clamp(0.0, 90.0).toDouble();
}

double _earShoulderHipAngle(Map<PoseLandmarkType, PoseLandmark> pose) {
  return calculateAngleNormalized(
    firstPoint: pose[PoseLandmarkType.rightEar]!,
    midPoint: pose[PoseLandmarkType.rightShoulder]!,
    lastPoint: pose[PoseLandmarkType.rightHip]!,
  );
}

double _hipKneeAnkleAngle(Map<PoseLandmarkType, PoseLandmark> pose) {
  return calculateAngleNormalized(
    firstPoint: pose[PoseLandmarkType.rightHip]!,
    midPoint: pose[PoseLandmarkType.rightKnee]!,
    lastPoint: pose[PoseLandmarkType.rightAnkle]!,
  );
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

    test('fixed rep logs peak telemetry from running scalars', () {
      final curlUp = CurlUp()
        ..cameraFacing = CameraFacing.right
        ..exerciseState = ExerciseState.activated;

      final startPose = _curlUpLandmarks(shoulderY: 100, kneeY: 50);
      final up1 = _curlUpLandmarks(shoulderY: 90, kneeY: 50);
      final up2 = _curlUpLandmarks(shoulderY: 80, kneeY: 50);
      final down1 = _curlUpLandmarks(shoulderY: 90, kneeY: 50);
      final down2 = _curlUpLandmarks(shoulderY: 100, kneeY: 50);
      final down3 = _curlUpLandmarks(shoulderY: 100, kneeY: 50);

      expect(curlUp.isInStartPosition(startPose), isTrue);

      final activeFrames = [up1, up2, down1, down2];
      var timestamp = 100;
      for (final frame in activeFrames) {
        curlUp
          ..curlUpState = CurlUpState.ascending
          ..previousCurlUpState = CurlUpState.resting;
        _pumpCurlUp(curlUp, frame, timestamp);
        timestamp += 100;
      }

      curlUp
        ..curlUpState = CurlUpState.resting
        ..previousCurlUpState = CurlUpState.descending;
      _pumpCurlUp(curlUp, down3, timestamp);

      expect(curlUp.repCount, 1);
      final data = curlUp.logger.repLogs.single.data;
      final baseTrunk = _trunkAngle(startPose);
      final baseNeck = _earShoulderHipAngle(startPose);
      expect(
        data['peak_trunk_elevation'] as num,
        closeTo(
          (activeFrames.map(_trunkAngle).reduce((a, b) => a > b ? a : b) -
                  baseTrunk)
              .clamp(0.0, 90.0),
          1e-9,
        ),
      );
      expect(
        data['peak_neck_deviation'] as num,
        closeTo(
          (baseNeck -
                  activeFrames
                      .map(_earShoulderHipAngle)
                      .reduce((a, b) => a < b ? a : b))
              .clamp(0.0, 90.0),
          1e-9,
        ),
      );
      expect(
        data['max_knee_angle'] as num,
        closeTo(
          activeFrames.map(_hipKneeAnkleAngle).reduce((a, b) => a > b ? a : b),
          1e-9,
        ),
      );
    });
  });
}
