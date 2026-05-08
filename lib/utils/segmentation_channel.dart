import 'package:flutter/services.dart';

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
  }) async {
    final response = await _methodChannel.invokeMapMethod<String, dynamic>(
      'initialize',
      <String, dynamic>{
        'pixelConfidenceThreshold': pixelConfidenceThreshold,
        'softPixelConfidenceThreshold': softPixelConfidenceThreshold,
        'minProcessIntervalMs': minProcessIntervalMs,
      },
    );
    return response ?? const <String, dynamic>{'success': true};
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
