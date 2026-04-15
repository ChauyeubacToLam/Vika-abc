import 'package:flutter/services.dart';

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

  Future<int> initialize({required bool useFrontCamera}) async {
    final textureId = await _methodChannel.invokeMethod<int>(
      'initialize',
      <String, dynamic>{'useFrontCamera': useFrontCamera},
    );
    if (textureId == null) {
      throw PlatformException(
        code: 'pose_landmarker_init',
        message: 'Native pose preview did not return a texture id.',
      );
    }
    return textureId;
  }

  Future<void> dispose() => _methodChannel.invokeMethod<void>('dispose');

  Future<void> startDetection() =>
      _methodChannel.invokeMethod<void>('startDetection');

  Future<void> stopDetection() =>
      _methodChannel.invokeMethod<void>('stopDetection');

  Future<void> switchCamera() =>
      _methodChannel.invokeMethod<void>('switchCamera');
}
