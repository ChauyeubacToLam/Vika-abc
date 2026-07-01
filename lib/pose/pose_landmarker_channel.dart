import 'package:flutter/services.dart';
import 'package:vika/exercise/exercise_base.dart';

class PoseLandmarkerChannel {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.vikavn.app/pose_landmarker',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.vikavn.app/pose_landmarker_stream',
  );

  Stream<Map<String, dynamic>> get landmarkStream {
    return _eventChannel.receiveBroadcastStream().map(
          (event) => Map<String, dynamic>.from(event as Map),
        );
  }

  Future<int> initialize({
    bool useFrontCamera = true,
    VikaImageOrientation initialOrientation = VikaImageOrientation.portrait,
    bool? isFrontCamera,
  }) async {
    final arguments = <String, dynamic>{'useFrontCamera': useFrontCamera};
    if (ExerciseBase.kLandscapeRotationEnabled) {
      arguments.addAll(<String, dynamic>{
        'initialOrientation': initialOrientation.channelCode,
        'isFrontCamera': isFrontCamera ?? useFrontCamera,
      });
    }

    final textureId = await _methodChannel.invokeMethod<int>(
      'initialize',
      arguments,
    );
    if (textureId == null) {
      throw PlatformException(
        code: 'pose_landmarker_init',
        message: 'Native pose preview did not return a texture id.',
      );
    }
    return textureId;
  }

  Future<void> setOrientation({
    required VikaImageOrientation orientation,
    required bool isFrontCamera,
  }) async {
    if (!ExerciseBase.kLandscapeRotationEnabled) return;
    await _methodChannel.invokeMethod<void>('setOrientation', <String, dynamic>{
      'orientation': orientation.channelCode,
      'isFrontCamera': isFrontCamera,
    });
  }

  Future<void> dispose() => _methodChannel.invokeMethod<void>('dispose');

  Future<void> startDetection() =>
      _methodChannel.invokeMethod<void>('startDetection');

  Future<void> stopDetection() =>
      _methodChannel.invokeMethod<void>('stopDetection');

  Future<void> switchCamera() =>
      _methodChannel.invokeMethod<void>('switchCamera');
}
