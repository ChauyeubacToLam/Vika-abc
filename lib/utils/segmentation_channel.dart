import 'package:flutter/services.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/pose/vika_image_orientation.dart';

class SegmentationChannel {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.vikavn.app/segmentation',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.vikavn.app/segmentation_stream',
  );

  Stream<Map<String, dynamic>> get eventStream {
    return _eventChannel.receiveBroadcastStream().map(
          (event) => Map<String, dynamic>.from(event as Map),
        );
  }

  Future<Map<String, dynamic>> initialize({
    required double pixelConfidenceThreshold,
    required double softPixelConfidenceThreshold,
    required int minProcessIntervalMs,
    VikaImageOrientation initialOrientation = VikaImageOrientation.portrait,
    bool isFrontCamera = false,
  }) async {
    final arguments = <String, dynamic>{
      'pixelConfidenceThreshold': pixelConfidenceThreshold,
      'softPixelConfidenceThreshold': softPixelConfidenceThreshold,
      'minProcessIntervalMs': minProcessIntervalMs,
    };
    if (ExerciseBase.kLandscapeRotationEnabled) {
      arguments.addAll(<String, dynamic>{
        'initialOrientation': initialOrientation.channelCode,
        'isFrontCamera': isFrontCamera,
      });
    }

    final response = await _methodChannel.invokeMapMethod<String, dynamic>(
      'initialize',
      arguments,
    );
    return response ?? const <String, dynamic>{'success': true};
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

  Future<Map<String, dynamic>> start() async {
    final response =
        await _methodChannel.invokeMapMethod<String, dynamic>('start');
    return response ?? const <String, dynamic>{'success': true};
  }

  Future<Map<String, dynamic>> stop() async {
    final response =
        await _methodChannel.invokeMapMethod<String, dynamic>('stop');
    return response ?? const <String, dynamic>{'success': true};
  }

  Future<Map<String, dynamic>> dispose() async {
    final response =
        await _methodChannel.invokeMapMethod<String, dynamic>('dispose');
    return response ?? const <String, dynamic>{'success': true};
  }

  Future<Map<String, dynamic>> requestSample() async {
    final response =
        await _methodChannel.invokeMapMethod<String, dynamic>('requestSample');
    return response ?? const <String, dynamic>{'success': true};
  }
}
